// Runs the built Firefox extension in a real Firefox and checks the same
// path as chrome.mjs: the popup's button, the backend calls, each proxy
// checked on its own, an HTTPS proxy that wants credentials and gets them,
// a page loaded through the proxy that works while one before it is out
// of reach and another answers 502, WebRTC kept to the proxies, the tries after a failure, a used-up
// allowance, the note on private windows and turning it off. It also
// checks two things only Firefox does: a background that Firefox stopped
// takes up the stored rules, and a proxy that refuses the credentials
// makes no password dialog appear.
//
//   node browser/build.mjs && \
//   FIREFOX=... GECKODRIVER=... SELENIUM=... node browser/test/e2e/firefox.mjs
//
// It needs these, and none of them has to be installed for the whole
// system:
//
//   FIREFOX      the firefox program, at least the manifest's
//                strict_min_version (build.mjs). On macOS, take the dmg
//                from https://archive.mozilla.org/pub/firefox/releases/,
//                check it against that release's SHA512SUMS, copy
//                Firefox.app out of it and name
//                Firefox.app/Contents/MacOS/firefox.
//   GECKODRIVER  the geckodriver program, from
//                https://github.com/mozilla/geckodriver/releases
//   SELENIUM     selenium-webdriver's entry file, after
//                `npm install selenium-webdriver` in a folder of your own:
//                <folder>/node_modules/selenium-webdriver/index.js
//
// On a Mac, for example:
//
//   v=160.0; d=$HOME/firefox-test/$v; mkdir -p $d/mnt && cd $d
//   curl -fL -o "Firefox $v.dmg" "https://archive.mozilla.org/pub/firefox/releases/$v/mac/en-US/Firefox%20$v.dmg"
//   curl -fLO "https://archive.mozilla.org/pub/firefox/releases/$v/SHA512SUMS"
//   grep " mac/en-US/Firefox $v.dmg$" SHA512SUMS | cut -d' ' -f1 > want
//   shasum -a 512 "Firefox $v.dmg" | cut -d' ' -f1 | cmp - want && echo checked
//   hdiutil attach -readonly -nobrowse -mountpoint mnt "Firefox $v.dmg"
//   cp -R mnt/Firefox.app . && hdiutil detach mnt
//
// It also needs openssl. Firefox refuses a proxy whose certificate no
// authority it trusts has signed, and it has no switch to skip that check
// for a proxy. So the test makes its own authority, signs the proxies'
// certificate with it, and adds it to the test profile's certificate
// store as the test starts. HEADED=1 shows the window. SCREENSHOTS=<dir>
// keeps pictures of the popup. E2E_DEBUG=1 prints each CONNECT the working
// proxy gets, and Firefox's own log. Everything runs on this computer
// except the pages it loads (www.gstatic.com and example.com), which the
// test proxy fetches, or Firefox fetches direct.

import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import http from 'node:http';
import https from 'node:https';
import { createRequire } from 'node:module';
import net from 'node:net';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const extension = join(here, '..', '..', 'dist', 'firefox');
const work = mkdtempSync(join(tmpdir(), 'fortiva-e2e-firefox-'));
const PASSWORD = '0b5c9c64-5b44-4e0f-9b1b-6f1d0f7d2a11';
// A device id whose place in any list is the start, so the proxies are
// checked in the order the backend sends them.
const DEVICE = '00000000-0000-4000-8000-000000000000';
const GB20 = 20 * 2 ** 30;
// The extension's id in build.mjs, and the uuid its pages get here, so the
// popup's address is known before it is installed.
const ADDON_ID = 'browser@fortivavpn.com';
const UUID = '5d0c4a2e-8b7f-4c1d-9e3a-6f2b1c0d9e8f';
const POPUP = `moz-extension://${UUID}/popup.html`;

// stop ends the test before Firefox starts; fail ends it once Firefox runs,
// so that the finally below can close Firefox.
function stop(why) {
  console.error(`FAIL: ${why}`);
  process.exit(1);
}
class Failure extends Error {}
function fail(why) {
  throw new Failure(why);
}

for (const name of ['FIREFOX', 'GECKODRIVER']) {
  if (!process.env[name]) stop(`${name} is not set; the file's header says where to get it`);
}

// SELENIUM names selenium-webdriver's entry file when it is not installed
// next to this repository.
const require = createRequire(process.env.SELENIUM || import.meta.url);
const seleniumEntry = process.env.SELENIUM || require.resolve('selenium-webdriver');
const { Builder, By } = require(seleniumEntry);
const firefox = require(join(dirname(seleniumEntry), 'firefox.js'));

// --- a test authority and the proxies' certificate ----------------------------
const ssl = (...args) => execFileSync('openssl', args, { cwd: work, stdio: ['ignore', 'ignore', 'pipe'] });
writeFileSync(join(work, 'ca.cnf'), [
  '[req]', 'distinguished_name = dn', 'prompt = no',
  '[dn]', 'CN = Fortiva e2e test authority',
  '[ca]', 'basicConstraints = critical, CA:TRUE', 'keyUsage = critical, keyCertSign, cRLSign', 'subjectKeyIdentifier = hash',
  '[leaf]', 'basicConstraints = CA:FALSE', 'keyUsage = critical, digitalSignature, keyEncipherment',
  'extendedKeyUsage = serverAuth', 'subjectAltName = DNS:localhost, IP:127.0.0.1', 'authorityKeyIdentifier = keyid',
  '',
].join('\n'));
ssl('req', '-x509', '-new', '-newkey', 'rsa:2048', '-nodes', '-days', '2', '-config', 'ca.cnf', '-extensions', 'ca',
  '-keyout', 'ca-key.pem', '-out', 'ca.pem');
ssl('req', '-new', '-newkey', 'rsa:2048', '-nodes', '-subj', '/CN=localhost', '-keyout', 'key.pem', '-out', 'req.pem');
ssl('x509', '-req', '-in', 'req.pem', '-CA', 'ca.pem', '-CAkey', 'ca-key.pem', '-set_serial', `0x${Date.now().toString(16)}`,
  '-days', '1', '-extfile', 'ca.cnf', '-extensions', 'leaf', '-out', 'cert.pem');
const tls = { key: readFileSync(join(work, 'key.pem')), cert: readFileSync(join(work, 'cert.pem')) };

// The authority, for Firefox's certificate store (nsIX509CertDB takes it
// as base64 without the PEM lines).
const authority = readFileSync(join(work, 'ca.pem'), 'utf8').replace(/-----[A-Z ]+-----|\s/g, '');

// --- test HTTPS proxies ---------------------------------------------------------
const ASK = 'HTTP/1.1 407 Proxy Authentication Required\r\nProxy-Authenticate: Basic realm="proxy"\r\nContent-Length: 0\r\n\r\n';

// A proxy that wants Basic credentials. It carries every request until
// refuseAll, which closes its tunnels and answers 407 to every request from
// then on, as when the panel switched this browser off. hold, when set, is
// called with a CONNECT to the check's host and returns a promise that lets
// it through. closeAll closes the tunnels it has open, so a request that
// still went through it would have to open a new one.
// late, when set to {target, arrived}, holds the first CONNECT to target
// unanswered and outside closeAll, and hands its socket to arrived: a
// request on its way through the proxy while the rules change.
function workingProxy() {
  const p = { challenged: 0, refused: 0, tunnels: [], mode: 'works', hold: null, late: null, open: new Set() };
  p.closeAll = () => {
    for (const s of p.open) s.destroy();
  };
  p.refuseAll = () => {
    p.mode = 'refuses';
    p.closeAll();
  };
  p.server = https.createServer(tls);
  p.server.on('connect', async (req, socket, head) => {
    socket.on('error', () => {});
    p.open.add(socket);
    socket.on('close', () => p.open.delete(socket));
    const auth = req.headers['proxy-authorization'] || '';
    if (process.env.E2E_DEBUG) console.log(`${Date.now() % 100000} CONNECT ${req.url} auth=${!!auth} mode=${p.mode}`);
    if (p.late && req.url === p.late.target) {
      const { arrived } = p.late;
      p.late = null;
      p.open.delete(socket);
      arrived(socket);
      return;
    }
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

const debug = (line) => process.env.E2E_DEBUG && console.log(`${Date.now() % 100000} ${line}`);
const good = workingProxy();
const bad = brokenProxy();
for (const p of [good, bad]) {
  await new Promise((r) => p.server.listen(0, '127.0.0.1', r));
  p.port = p.server.address().port;
  // A proxy certificate Firefox does not trust ends here, before any CONNECT.
  p.server.on('tlsClientError', (e) => debug(`TLS on the proxy at ${p.port} failed: ${e.message}`));
}
const count = (list, url) => list.filter((u) => u === url).length;
// A port where nothing listens, as on a server that is down. Firefox can
// fall back to a direct connection when every proxy is out of reach, but
// only for its own requests. If it did that for the check, a dead proxy
// would pass it.
const deadPort = await new Promise((r) => {
  const s = net.createServer().listen(0, '127.0.0.1', () => {
    const { port } = s.address();
    s.close(() => r(port));
  });
});

// --- a fake backend -----------------------------------------------------------
const calls = [];
const registers = [];
// A call the backend refused, which the test reports at the end.
let wrongCall = '';
const backend = {
  // The proxies it hands out, in server id order: one out of reach, the
  // broken one, then the one that works.
  proxies: () => [
    { server_id: 1, host: 'localhost', port: deadPort, label: 'Dead server', username: 'fortiva', password: PASSWORD },
    { server_id: 2, host: 'localhost', port: bad.port, label: 'Broken server', username: 'fortiva', password: PASSWORD },
    { server_id: 3, host: 'localhost', port: good.port, label: 'Test server', username: 'fortiva', password: PASSWORD },
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
    if (req.headers['x-app-platform'] !== 'browser') {
      wrongCall ||= `${req.url} came without X-App-Platform: browser`;
      res.writeHead(400);
      res.end();
      return;
    }
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
const options = new firefox.Options()
  .setBinary(process.env.FIREFOX)
  .setPreference('extensions.webextensions.uuids', JSON.stringify({ [ADDON_ID]: UUID }));
if (!process.env.HEADED) options.addArguments('-headless');
// Without system access, WebDriver may not open or drive an extension's
// pages (moz-extension://), and may not reach Firefox's own code, which
// adds the test authority and reads Firefox's settings.
const service = new firefox.ServiceBuilder(process.env.GECKODRIVER).addArguments('--allow-system-access');
if (process.env.E2E_DEBUG) {
  options.setPreference('devtools.console.stdout.chrome', true);
  service.setStdio('inherit');
}
let driver = null;

// --- the test -------------------------------------------------------------------
async function run() {
  const caps = await driver.getCapabilities();
  const version = caps.get('browserVersion');
  // A page that does not load fails its check in 30 seconds, not in the
  // default 300.
  await driver.manage().setTimeouts({ pageLoad: 30000, script: 30000 });
  // inFirefox runs script in Firefox's own code, which can read its
  // settings and the extension's state.
  async function inFirefox(script, ...args) {
    await driver.setContext(firefox.Context.CHROME);
    try {
      return await driver.executeScript(script, ...args);
    } finally {
      await driver.setContext(firefox.Context.CONTENT);
    }
  }
  // The profile's certificate store trusts the test authority for TLS
  // servers from now on, as the proxies are.
  await inFirefox(
    "Cc['@mozilla.org/security/x509certdb;1'].getService(Ci.nsIX509CertDB).addCertFromBase64(arguments[0], 'C,,')",
    authority,
  );
  // A temporary add-on, as about:debugging loads one. Firefox runs it in
  // private windows only when the person allows it, as for any other add-on.
  await driver.installWebExtension(extension, { permanent: false, allowPrivateBrowsing: false });

  const popupTab = await driver.getWindowHandle();
  await driver.switchTo().newWindow('tab');
  const pageTab = await driver.getWindowHandle();
  await driver.switchTo().window(popupTab);

  // inPopup runs fn(...args) in the popup's page, where `browser` is the
  // extension's own API, and returns what its promise gives.
  async function inPopup(fn, ...args) {
    await driver.switchTo().window(popupTab);
    const r = await driver.executeAsyncScript(
      `const done = arguments[arguments.length - 1];
       Promise.resolve().then(() => (${fn})(...Array.prototype.slice.call(arguments, 0, -1)))
         .then((ok) => done({ ok }), (e) => done({ err: String(e && e.message || e) }));`,
      ...args,
    );
    if (r && 'err' in r) throw new Error(r.err);
    return r ? r.ok : undefined;
  }
  const firefoxPref = (name) => inFirefox('return Services.prefs.getBoolPref(arguments[0], false)', name);
  // The extension's background: "running", "stopped" and so on.
  const backgroundState = () => inFirefox('return WebExtensionPolicy.getByID(arguments[0]).extension.backgroundState', ADDON_ID);
  const stored = () => inPopup(() => browser.storage.local.get(null));
  const webrtc = () => inPopup(() => browser.privacy.network.webRTCIPHandlingPolicy.get({}));
  async function text(sel) {
    await driver.switchTo().window(popupTab);
    return driver.executeScript('return document.querySelector(arguments[0]).textContent.trim()', sel);
  }
  async function attr(sel, name) {
    await driver.switchTo().window(popupTab);
    return driver.executeScript('const e = document.querySelector(arguments[0]); return e && e.getAttribute(arguments[1])', sel, name);
  }
  async function waitFor(ok, timeout) {
    const end = Date.now() + timeout;
    for (;;) {
      if (await ok()) return true;
      if (Date.now() > end) return false;
      await new Promise((r) => setTimeout(r, 200));
    }
  }
  async function statusIs(want, timeout) {
    if (await waitFor(async () => (await text('#status')) === want, timeout)) return;
    const s = await stored();
    fail(`the popup never said ${want}, it says ${await text('#status')}: ${JSON.stringify({ status: s.status, error: s.error, route: s.route && s.route.mode })}`);
  }
  async function powerIs(state, timeout) {
    return waitFor(async () => (await attr('#power', 'data-state')) === state, timeout);
  }
  async function click(sel) {
    await driver.switchTo().window(popupTab);
    await driver.findElement(By.css(sel)).click();
  }
  // open loads url in the page tab and returns the page's title, or '' when
  // it did not load.
  async function open(url) {
    await driver.switchTo().window(pageTab);
    const t0 = Date.now();
    try {
      await driver.get(url);
      return await driver.getTitle();
    } catch (e) {
      debug(`${url} did not load: ${e.message}`);
      return '';
    } finally {
      debug(`${url} took ${Date.now() - t0} ms`);
      await driver.switchTo().window(popupTab);
    }
  }
  const shots = process.env.SCREENSHOTS;
  async function shot(name) {
    if (!shots) return;
    await driver.switchTo().window(popupTab);
    const png = await driver.findElement(By.css('main')).takeScreenshot();
    writeFileSync(join(shots, name), Buffer.from(png, 'base64'));
  }

  await driver.get(POPUP);
  if (!(await waitFor(async () => (await text('#status')) !== '', 10000))) fail('the popup never showed a status');
  // What Firefox granted at install: the required data collection, and not
  // the optional technical data, which the person did not allow.
  const granted = await inPopup(() => browser.permissions.getAll());
  if (!Array.isArray(granted.data_collection)) fail(`Firefox ${version} has no data collection permissions: ${JSON.stringify(granted)}`);
  for (const k of ['browsingActivity', 'websiteContent', 'locationInfo']) {
    if (!granted.data_collection.includes(k)) fail(`Firefox did not grant ${k}: ${JSON.stringify(granted)}`);
  }
  if (granted.data_collection.includes('technicalAndInteraction')) fail('technical data was granted without the person allowing it');
  if (!granted.origins.includes('<all_urls>')) fail(`the host permission was not granted: ${JSON.stringify(granted)}`);

  await inPopup((values) => browser.storage.local.set(values), { apiBase, deviceId: DEVICE });
  // The refresh the popup sends when it opens is slow, as from Iran, so the
  // click below waits behind it.
  backend.delay = 2500;
  await driver.navigate().refresh();
  await statusIs('Not connected', 10000);

  // The add-on is not allowed in private windows, so the popup says they do
  // not go through Fortiva.
  if ((await attr('#private', 'hidden')) !== null) fail('the popup does not say that private windows go direct');
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

  await click('#power');
  // The connect waits behind the refresh; the popup keeps showing it.
  await new Promise((r) => setTimeout(r, 1500));
  if ((await text('#status')) !== 'Connecting') fail(`while a connect waited its turn, the popup said ${await text('#status')}`);
  if ((await attr('#power', 'disabled')) === null) fail('while a connect waited its turn, the button could be pressed again');

  try {
    await Promise.race([held, new Promise((_, no) => setTimeout(no, 30000))]);
  } catch {
    const s = await stored();
    fail(`the good proxy was never checked: good ${JSON.stringify(good.tunnels)}, bad ${JSON.stringify(bad.tunnels)}, status ${s.status}, error ${s.error}, calls ${calls}`);
  }
  // Only the check goes through the proxy being checked: a page goes direct.
  const direct = await open('https://example.com/?direct');
  if (!/Example Domain/.test(direct)) fail(`example.com did not load while a proxy was checked: ${JSON.stringify(direct)}`);
  if (good.tunnels.includes('example.com:443') || bad.tunnels.includes('example.com:443')) fail('a page went through a proxy while only the check should have');
  letCheckThrough();

  await statusIs('Connected', 30000);
  if (bad.tunnels.join() !== 'www.gstatic.com:443') fail(`the 502 proxy saw ${JSON.stringify(bad.tunnels)}`);
  if (!good.tunnels.includes('www.gstatic.com:443')) fail(`the check did not go through the good proxy: ${good.tunnels}`);
  if ((await text('#location')) !== 'Location: Test server') fail(`location: ${await text('#location')}`);
  // The proxy that passed comes first, then the ones that failed, in the
  // order they were checked.
  const order = (await stored()).route.proxies.map((p) => p.label).join(', ');
  if (order !== 'Test server, Dead server, Broken server') fail(`the rules use the proxies in this order: ${order}`);
  await shot('popup-connected-en-firefox.png');
  const quota = await text('#quotaLine');
  if (!/20\.0 GB of 20\.0 GB left/.test(quota)) fail(`quota line: ${quota}`);
  // Firefox sends the credentials with the first request, so the proxy never
  // has to ask.
  if (good.challenged) fail(`the proxy had to ask for credentials ${good.challenged} times`);

  // The 502 proxy does not keep the browser offline: the good one carries the page.
  const proxied = await open('https://example.com/?proxied');
  if (!/Example Domain/.test(proxied)) fail(`example.com did not load through the proxy: ${JSON.stringify(proxied)}`);
  if (!good.tunnels.includes('example.com:443')) fail(`the page did not go through the good proxy: ${good.tunnels}`);
  if (bad.tunnels.includes('example.com:443')) fail('the page went to the 502 proxy');
  if (good.refused) fail(`the proxy refused credentials ${good.refused} times`);

  // Firefox stops an idle background after 30 seconds and starts it again
  // for the next request. The background must then take up the stored
  // rules: the next page still goes through the proxy. The tunnels are
  // closed first, so the page has to open a new one.
  // A request while the background is stopping, such as one of Firefox's
  // own, keeps it running. So the test asks again until it has stopped.
  for (let i = 0; i < 10 && (await backgroundState()) !== 'stopped'; i++) {
    await inFirefox('WebExtensionPolicy.getByID(arguments[0]).extension.terminateBackground({ disableResetIdleForTest: true })', ADDON_ID);
    await waitFor(async () => (await backgroundState()) === 'stopped', 2000);
  }
  if ((await backgroundState()) !== 'stopped') fail(`the background did not stop: ${await backgroundState()}`);
  good.closeAll();
  const beforeStop = count(good.tunnels, 'example.com:443');
  const woken = await open('https://example.com/?woken');
  if (!/Example Domain/.test(woken)) fail(`example.com did not load after the background stopped: ${JSON.stringify(woken)}`);
  if (count(good.tunnels, 'example.com:443') !== beforeStop + 1) fail('after the background stopped, a page did not go through the proxy');
  if ((await backgroundState()) !== 'running') fail(`the page did not start the background again: ${await backgroundState()}`);

  let rtc = await webrtc();
  if (rtc.value !== 'disable_non_proxied_udp' || rtc.levelOfControl !== 'controlled_by_this_extension') fail(`WebRTC while on: ${JSON.stringify(rtc)}`);
  if ((await firefoxPref('media.peerconnection.ice.proxy_only_if_behind_proxy')) !== true) fail('Firefox does not keep WebRTC to the proxy while on');

  await click('#power');
  await statusIs('Not connected', 10000);
  if ((await stored()).route?.mode !== 'off') fail(`the rules stayed on after turning off: ${JSON.stringify((await stored()).route)}`);
  rtc = await webrtc();
  if (rtc.levelOfControl === 'controlled_by_this_extension') fail(`WebRTC stayed set after turning off: ${JSON.stringify(rtc)}`);
  if ((await firefoxPref('media.peerconnection.ice.proxy_only_if_behind_proxy')) !== false) fail('Firefox still keeps WebRTC to a proxy after turning off');
  // The next page goes direct. The proxy's tunnels are closed first, so a
  // page that still went through it would show as a new CONNECT.
  good.closeAll();
  const before = count(good.tunnels, 'example.com:443');
  const after = await open('https://example.com/?off');
  if (!/Example Domain/.test(after)) fail(`example.com did not load after turning off: ${JSON.stringify(after)}`);
  if (count(good.tunnels, 'example.com:443') !== before) fail('a page went through the proxy after turning off');
  // The extension sends no events: the backend reads them as a phone's.
  if (calls.some((u) => u.endsWith('/events'))) fail(`the extension sent events: ${calls}`);
  // Without the person's leave for technical data, the registration carries
  // no browser, system or language.
  if (registers[0]?.platform !== 'browser') fail(`registered as ${JSON.stringify(registers[0])}`);
  for (const k of ['device_model', 'os_version', 'language']) {
    if (k in registers[0]) fail(`the registration sent ${k} without the person's leave: ${JSON.stringify(registers[0])}`);
  }

  // Every proxy fails its check: not connected, and the button stops the tries.
  backend.proxies = () => [{ server_id: 1, host: 'localhost', port: bad.port, label: 'Broken server', username: 'fortiva', password: PASSWORD }];
  await click('#power');
  if (!(await powerIs('waiting', 30000))) fail(`after every proxy failed the button is ${await attr('#power', 'data-state')}`);
  if ((await text('#status')) !== 'Not connected') fail(`after a failure the popup says ${await text('#status')}`);
  if ((await text('#message')) !== 'Could not connect') fail(`after a failure the message is ${await text('#message')}`);
  if ((await attr('#power', 'aria-label')) !== 'Disconnect') fail('after a failure the button does not turn the tries off');
  if ((await stored()).route?.mode !== 'off') fail('a failed connect left proxies set');
  await shot('popup-waiting-en-firefox.png');
  await click('#power');
  if (!(await powerIs('off', 10000))) fail('the button did not turn the tries off');
  // The popup shows "off" at once; the background turns it off right after.
  if (!(await waitFor(async () => (await stored()).wanted === false, 10000))) fail('the button did not stop the tries');

  // The allowance runs out while connected: the proxy refuses every request,
  // and the extension finds out from the backend at once.
  backend.proxies = () => [{ server_id: 2, host: 'localhost', port: good.port, label: 'Test server', username: 'fortiva', password: PASSWORD }];
  await click('#power');
  await statusIs('Connected', 30000);
  // A page in another tab whose request is on its way through the proxy
  // when the allowance runs out. The proxy refuses it only after the
  // extension has turned the proxies off.
  const arrived = new Promise((resolve) => { good.late = { target: 'example.org:443', arrived: resolve }; });
  await driver.switchTo().newWindow('tab');
  const lateTab = await driver.getWindowHandle();
  await driver.executeScript('const url = arguments[0]; setTimeout(() => { location.href = url; }, 0);', 'https://example.org/?late');
  const lateSocket = await Promise.race([arrived, new Promise((r) => setTimeout(() => r(null), 15000))]);
  if (!lateSocket) fail('the late page never reached the proxy');
  backend.outOfData = true;
  good.refuseAll();
  // The extension cancels the page's request, and Firefox then keeps the
  // page it had, as when the person stops a load. So the test starts the
  // load and does not wait for it. The script returns before the load
  // starts: a load cancelled while WebDriver still ran the script could make
  // the command itself fail. A password dialog still fails the next step.
  await driver.switchTo().window(pageTab);
  await driver.executeScript('const url = arguments[0]; setTimeout(() => { location.href = url; }, 0);', 'https://example.com/?refused');
  if (!(await powerIs('waiting', 30000))) fail(`a used-up allowance was not found: status ${(await stored()).status}, the proxy refused ${good.refused} times`);
  // Firefox did not ask the person for a user name and password: WebDriver
  // refuses every command while such a dialog is open.
  try {
    await driver.switchTo().window(pageTab);
    debug(`the page tab shows ${await driver.getCurrentUrl()}`);
  } catch (e) {
    fail(`Firefox asked for the proxy's password: ${e.message}`);
  }
  if ((await stored()).status !== 'out_of_data') fail(`after the allowance ran out the status is ${(await stored()).status}`);
  // The proxies are off and the backend sent none. Now the proxy refuses
  // the late page's request. That must not reach the person either.
  if ((await stored()).route?.mode !== 'off') fail('out of data, proxies are still set');
  lateSocket.end(ASK);
  await new Promise((r) => setTimeout(r, 2000));
  try {
    await driver.switchTo().window(lateTab);
    debug(`the late tab shows ${await driver.getCurrentUrl()}`);
    await driver.close();
    await driver.switchTo().window(popupTab);
  } catch (e) {
    fail(`Firefox asked for the proxy's password for a request sent before the proxies went off: ${e.message}`);
  }
  if (!(await text('#message')).startsWith('Daily data used up')) fail(`out of data, the message is ${await text('#message')}`);
  await click('#power');
  await statusIs('Not connected', 10000);

  // The popup in Persian: right to left, the app's words.
  await inPopup(() => browser.storage.local.set({ language: 'fa' }));
  await driver.navigate().refresh();
  if (!(await waitFor(async () => (await attr('html', 'dir')) === 'rtl', 10000))) fail('the Persian popup is not right to left');
  const fa = await text('#status');
  await shot('popup-off-fa-firefox.png');
  if (fa !== 'وصل نیست' && !/[؀-ۿ]/.test(fa)) fail(`the Persian popup says ${fa}`);

  if (wrongCall) fail(wrongCall);
  return `passed on Firefox ${version}: good proxy challenged ${good.challenged}, refused ${good.refused}, tunnels ${[...new Set(good.tunnels)].join(', ')}; 502 proxy saw ${bad.tunnels.join(', ')}; calls ${[...new Set(calls)].join(', ')}`;
}

let code = 1;
try {
  driver = await new Builder().forBrowser('firefox').setFirefoxOptions(options).setFirefoxService(service).build();
  console.log(await run());
  code = 0;
} catch (e) {
  console.error(`FAIL: ${e instanceof Failure ? e.message : (e && e.stack) || e}`);
  if (wrongCall) console.error(`FAIL: ${wrongCall}`);
} finally {
  if (driver) await driver.quit().catch(() => {});
  good.server.close();
  bad.server.close();
  api.close();
  rmSync(work, { recursive: true, force: true });
}
process.exit(code);
