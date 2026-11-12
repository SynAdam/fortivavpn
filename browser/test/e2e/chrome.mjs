// Runs the built Chrome extension in Chromium and checks the whole path: the
// popup's button, the backend calls, each proxy checked on its own, an
// HTTPS proxy asking for credentials and getting them, a page loaded
// through the proxy that works while the first one answers 502, WebRTC kept
// to the proxies, the tries after a failure, a used-up allowance, and
// turning it off.
//
//   node browser/build.mjs && node browser/test/e2e/chrome.mjs
//
// Needs Playwright with its Chromium (npx playwright install chromium) and
// openssl. Set PLAYWRIGHT to its index.mjs when it is installed elsewhere.
// E2E_DEBUG=1 prints each CONNECT the working proxy gets.
// Everything runs on this computer except the pages it loads
// (www.gstatic.com and example.com), which the test proxy fetches, or the
// browser fetches direct.

import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync } from 'node:fs';
import http from 'node:http';
import https from 'node:https';
import net from 'node:net';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

// PLAYWRIGHT names Playwright's entry file when it is not installed here,
// for example .../node_modules/playwright/index.mjs.
const { chromium } = await import(process.env.PLAYWRIGHT || 'playwright');

const here = dirname(fileURLToPath(import.meta.url));
const extension = join(here, '..', '..', 'dist', 'chrome');
const work = mkdtempSync(join(tmpdir(), 'fortiva-e2e-'));
const PASSWORD = '0b5c9c64-5b44-4e0f-9b1b-6f1d0f7d2a11';
// A device id whose place in a list of two is the start, so the proxy that
// answers 502 is checked first.
const DEVICE = '00000000-0000-4000-8000-000000000000';
const GB20 = 20 * 2 ** 30;

function fail(why) {
  console.error(`FAIL: ${why}`);
  process.exit(1);
}

// --- test HTTPS proxies ---------------------------------------------------------
execFileSync('openssl', ['req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '1', '-subj', '/CN=localhost',
  '-keyout', join(work, 'key.pem'), '-out', join(work, 'cert.pem')], { stdio: 'ignore' });
const tls = { key: readFileSync(join(work, 'key.pem')), cert: readFileSync(join(work, 'cert.pem')) };
const ASK = 'HTTP/1.1 407 Proxy Authentication Required\r\nProxy-Authenticate: Basic realm="Fortiva"\r\nContent-Length: 0\r\n\r\n';

// A proxy that wants Basic credentials. It carries every request until
// refuseAll, which closes its tunnels and answers 407 to every request from
// then on, as when the panel switched this browser off. hold, when set, is
// called with a CONNECT to the check's host and returns a promise that lets
// it through.
function workingProxy() {
  const p = { challenged: 0, refused: 0, tunnels: [], mode: 'works', hold: null, open: new Set() };
  p.refuseAll = () => {
    p.mode = 'refuses';
    for (const s of p.open) s.destroy();
  };
  p.server = https.createServer(tls);
  p.server.on('connect', async (req, socket, head) => {
    socket.on('error', () => {});
    p.open.add(socket);
    socket.on('close', () => p.open.delete(socket));
    const auth = req.headers['proxy-authorization'] || '';
    if (process.env.E2E_DEBUG) console.log(`${Date.now() % 100000} CONNECT ${req.url} auth=${!!auth} mode=${p.mode}`);
    if (!auth) {
      p.challenged++;
      socket.end(ASK);
      return;
    }
    const [user, pass] = Buffer.from(auth.replace(/^Basic /, ''), 'base64').toString().split(':');
    if (pass !== PASSWORD || !user || p.mode === 'refuses') {
      p.refused++;
      socket.end(ASK);
      return;
    }
    if (p.hold && req.url === 'www.gstatic.com:443') {
      const release = p.hold;
      p.hold = null;
      await release();
    }
    p.tunnels.push(req.url);
    const [host, port] = req.url.split(':');
    const up = net.connect(Number(port), host, () => {
      socket.write('HTTP/1.1 200 Connection established\r\n\r\n');
      up.write(head);
      up.pipe(socket);
      socket.pipe(up);
    });
    up.on('error', () => socket.destroy());
    socket.on('error', () => up.destroy());
  });
  return p;
}

// A proxy whose server lost its Xray: it answers every CONNECT with 502.
function brokenProxy() {
  const p = { tunnels: [] };
  p.server = https.createServer(tls);
  p.server.on('connect', (req, socket) => {
    socket.on('error', () => {});
    p.tunnels.push(req.url);
    socket.end('HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\n\r\n');
  });
  return p;
}

const good = workingProxy();
const bad = brokenProxy();
for (const p of [good, bad]) {
  await new Promise((r) => p.server.listen(0, '127.0.0.1', r));
  p.port = p.server.address().port;
}

// --- a fake backend -----------------------------------------------------------
const calls = [];
const registers = [];
const backend = {
  // The proxies it hands out, in server id order: the broken one first.
  proxies: () => [
    { server_id: 1, host: 'localhost', port: bad.port, label: 'Broken server', username: 'fortiva', password: PASSWORD },
    { server_id: 2, host: 'localhost', port: good.port, label: 'Test server', username: 'fortiva', password: PASSWORD },
  ],
  outOfData: false,
  // Milliseconds the next configs/browser answer waits.
  delay: 0,
};
const api = http.createServer((req, res) => {
  let body = '';
  req.on('data', (c) => (body += c));
  req.on('end', async () => {
    const data = body ? JSON.parse(body) : {};
    const send = (obj) => {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(obj));
    };
    if (req.headers['x-app-platform'] !== 'browser') return fail(`${req.url} came without X-App-Platform: browser`);
    calls.push(req.url);
    if (req.url === '/api/v1/devices/register') {
      registers.push(data);
      return send({});
    }
    if (req.url === '/api/v1/configs/browser') {
      const wait = backend.delay;
      backend.delay = 0;
      if (wait) await new Promise((r) => setTimeout(r, wait));
      if (backend.outOfData) {
        return send({
          proxies: [],
          quota: { unlimited: false, limit_bytes: GB20, used_bytes: GB20, remaining_bytes: 0, blocked: true, resets_at: new Date(Date.now() + 5 * 3600e3).toISOString() },
          refresh_after_s: 3600,
        });
      }
      return send({
        proxies: backend.proxies(),
        quota: { unlimited: false, limit_bytes: GB20, used_bytes: 0, remaining_bytes: GB20, blocked: false },
        refresh_after_s: 3600,
      });
    }
    res.writeHead(404);
    res.end();
  });
});
await new Promise((r) => api.listen(0, '127.0.0.1', r));
const apiBase = `http://127.0.0.1:${api.address().port}`;

// --- the browser --------------------------------------------------------------
const context = await chromium.launchPersistentContext(join(work, 'profile'), {
  channel: 'chromium',
  // CHROMIUM names a Chromium to use instead of the one Playwright expects.
  executablePath: process.env.CHROMIUM || undefined,
  headless: true,
  ignoreHTTPSErrors: true,
  args: [
    `--disable-extensions-except=${extension}`,
    `--load-extension=${extension}`,
    // The test proxies' certificate is their own.
    '--ignore-certificate-errors',
  ],
});
let worker = context.serviceWorkers()[0];
if (!worker) worker = await context.waitForEvent('serviceworker');
const id = new URL(worker.url()).host;
await worker.evaluate((values) => chrome.storage.local.set(values), { apiBase, deviceId: DEVICE });

const stored = () => worker.evaluate(() => chrome.storage.local.get(null));
const webrtc = () => worker.evaluate(() => chrome.privacy.network.webRTCIPHandlingPolicy.get({}));
const text = (sel) => popup.evaluate((s) => document.querySelector(s).textContent.trim(), sel);
async function statusIs(want, timeout) {
  try {
    await popup.waitForFunction((w) => document.querySelector('#status').textContent.trim() === w, want, { timeout });
  } catch {
    const s = await stored();
    fail(`the popup never said ${want}, it says ${await text('#status')}: ${JSON.stringify({ status: s.status, error: s.error, route: s.route && s.route.mode })}`);
  }
}

const popup = await context.newPage();
await popup.setViewportSize({ width: 340, height: 600 });
// The refresh the popup sends when it opens is slow, as from Iran, so the
// click below waits behind it.
backend.delay = 2500;
await popup.goto(`chrome-extension://${id}/popup.html`);
await statusIs('Not connected', 10000);

// The extension is not allowed in incognito windows, so the popup says
// they do not go through Fortiva.
if (await popup.isHidden('#private')) fail('the popup does not say that private windows go direct');
if (!/^Private windows do not go through Fortiva/.test(await text('#private'))) fail(`private note: ${await text('#private')}`);

// The good proxy holds the check that goes through it until a page has been
// loaded meanwhile.
let checkHeld;
const held = new Promise((r) => (checkHeld = r));
let letCheckThrough;
const released = new Promise((r) => (letCheckThrough = r));
good.hold = () => {
  checkHeld();
  return released;
};

await popup.click('#power');
// The connect waits behind the refresh; the popup keeps showing it.
await new Promise((r) => setTimeout(r, 1500));
if ((await text('#status')) !== 'Connecting') fail(`while a connect waited its turn, the popup said ${await text('#status')}`);
if (!(await popup.isDisabled('#power'))) fail('while a connect waited its turn, the button could be pressed again');

try {
  await Promise.race([held, new Promise((_, no) => setTimeout(no, 30000))]);
} catch {
  fail(`the good proxy was never checked: good ${JSON.stringify(good.tunnels)}, bad ${JSON.stringify(bad.tunnels)}`);
}
// Only the check goes through the proxy being checked: a page goes direct.
const page = await context.newPage();
const direct = await page.goto('https://example.com/?direct', { timeout: 30000 });
if (!direct || !direct.ok()) fail(`example.com answered ${direct && direct.status()} while a proxy was checked`);
if (good.tunnels.includes('example.com:443') || bad.tunnels.includes('example.com:443')) fail('a page went through a proxy while only the check should have');
letCheckThrough();

await statusIs('Connected', 30000);
if (bad.tunnels.join() !== 'www.gstatic.com:443') fail(`the 502 proxy saw ${JSON.stringify(bad.tunnels)}`);
if (!good.tunnels.includes('www.gstatic.com:443')) fail(`the check did not go through the good proxy: ${good.tunnels}`);
if ((await text('#location')) !== 'Location: Test server') fail(`location: ${await text('#location')}`);
// SCREENSHOTS names a folder to keep pictures of the popup in.
const shots = process.env.SCREENSHOTS;
if (shots) await popup.screenshot({ path: join(shots, 'popup-connected-en.png'), fullPage: true });
const quota = await text('#quotaLine');
if (!/20\.0 GB of 20\.0 GB left/.test(quota)) fail(`quota line: ${quota}`);
if (good.challenged < 1) fail('the proxy never asked for credentials, so onAuthRequired was not tested');

// The 502 proxy does not keep the browser offline: the good one carries the page.
const res = await page.goto('https://example.com/?proxied', { timeout: 30000 });
if (!res || !res.ok()) fail(`example.com answered ${res && res.status()}`);
if (!good.tunnels.includes('example.com:443')) fail(`the page did not go through the good proxy: ${good.tunnels}`);
if (bad.tunnels.includes('example.com:443')) fail('the page went to the 502 proxy');
if (good.refused) fail(`the proxy refused credentials ${good.refused} times`);

let rtc = await webrtc();
if (rtc.value !== 'disable_non_proxied_udp' || rtc.levelOfControl !== 'controlled_by_this_extension') fail(`WebRTC while on: ${JSON.stringify(rtc)}`);

await popup.click('#power');
await statusIs('Not connected', 10000);
const settings = await worker.evaluate(() => chrome.proxy.settings.get({}));
if (settings.value.mode === 'pac_script') fail('the proxy stayed set after turning off');
rtc = await webrtc();
if (rtc.levelOfControl === 'controlled_by_this_extension') fail(`WebRTC stayed set after turning off: ${JSON.stringify(rtc)}`);
// The extension sends no events: the backend reads them as a phone's.
if (calls.some((u) => u.endsWith('/events'))) fail(`the extension sent events: ${calls}`);
if (registers[0]?.platform !== 'browser' || !/^Chrome \d+/.test(registers[0]?.device_model || '')) fail(`registered as ${JSON.stringify(registers[0])}`);

// Every proxy fails its check: not connected, and the button stops the tries.
backend.proxies = () => [{ server_id: 1, host: 'localhost', port: bad.port, label: 'Broken server', username: 'fortiva', password: PASSWORD }];
await popup.click('#power');
await popup.waitForSelector('#power[data-state="waiting"]', { timeout: 30000 });
if ((await text('#status')) !== 'Not connected') fail(`after a failure the popup says ${await text('#status')}`);
if ((await text('#message')) !== 'Could not connect') fail(`after a failure the message is ${await text('#message')}`);
if ((await popup.getAttribute('#power', 'aria-label')) !== 'Disconnect') fail('after a failure the button does not turn the tries off');
if ((await worker.evaluate(() => chrome.proxy.settings.get({}))).value.mode === 'pac_script') fail('a failed connect left a PAC script set');
if (shots) await popup.screenshot({ path: join(shots, 'popup-waiting-en.png'), fullPage: true });
await popup.click('#power');
await popup.waitForSelector('#power[data-state="off"]', { timeout: 10000 });
// The popup shows "off" at once; the background turns it off right after.
for (let i = 0; i < 50 && (await stored()).wanted !== false; i++) await new Promise((r) => setTimeout(r, 200));
if ((await stored()).wanted !== false) fail('the button did not stop the tries');

// The allowance runs out while connected: the proxy refuses every request,
// and the extension finds out from the backend at once.
backend.proxies = () => [{ server_id: 2, host: 'localhost', port: good.port, label: 'Test server', username: 'fortiva', password: PASSWORD }];
await popup.click('#power');
await statusIs('Connected', 30000);
backend.outOfData = true;
good.refuseAll();
await page.goto('https://example.com/?refused', { timeout: 30000 }).catch(() => {});
try {
  await popup.waitForSelector('#power[data-state="waiting"]', { timeout: 30000 });
} catch {
  fail(`a used-up allowance was not found: status ${(await stored()).status}, the proxy refused ${good.refused} times`);
}
if ((await stored()).status !== 'out_of_data') fail(`after the allowance ran out the status is ${(await stored()).status}`);
if (!(await text('#message')).startsWith('Daily data used up')) fail(`out of data, the message is ${await text('#message')}`);
await popup.click('#power');
await statusIs('Not connected', 10000);

// The popup in Persian: right to left, the app's words.
await worker.evaluate(() => chrome.storage.local.set({ language: 'fa' }));
await popup.reload();
await popup.waitForSelector('html[dir="rtl"]');
const fa = await text('#status');
if (shots) await popup.screenshot({ path: join(shots, 'popup-off-fa.png'), fullPage: true });
if (fa !== 'وصل نیست' && !/[؀-ۿ]/.test(fa)) fail(`the Persian popup says ${fa}`);

await context.close();
good.server.close();
bad.server.close();
api.close();
console.log(`passed: good proxy challenged ${good.challenged}, tunnels ${[...new Set(good.tunnels)].join(', ')}; 502 proxy saw ${bad.tunnels.join(', ')}; calls ${[...new Set(calls)].join(', ')}`);
process.exit(0);
