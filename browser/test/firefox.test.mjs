// Runs src/background.js as Firefox runs it, with a fake `browser`:
// storage whose calls take a turn, as they do in Firefox, and a fetch that
// asks proxy.onRequest which way each request goes, as Firefox does for the
// extension's own requests too.

import assert from 'node:assert/strict';
import { test } from 'node:test';

const PASSWORD = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';
const OLD = { server_id: 1, host: 'old.example.com', port: 9443, username: 'fortiva', password: PASSWORD, label: 'Old' };
const NEW = { server_id: 2, host: 'new.example.com', port: 9443, username: 'fortiva', password: PASSWORD, label: 'New' };
const QUOTA = { unlimited: true, limit_bytes: 0, used_bytes: 0, remaining_bytes: 0, blocked: false };
const PROBE = 'https://www.gstatic.com/generate_204';
const PAGE = 'https://example.org/';

const turn = () => new Promise((r) => setTimeout(r, 1));

let loaded = 0;

// firefox starts a background with data in storage. Only the proxies in
// alive carry a request; the others fail as a dead server does.
// dataCollection is what the person allowed at install.
async function firefox(data, { alive = [NEW.host], answer = { proxies: [NEW], quota: QUOTA, refresh_after_s: 3600 }, dataCollection = [] } = {}) {
  // webrtc is the WebRTC policy the extension set, or null. registered
  // holds the bodies of the register calls.
  const ff = { data, log: [], on: { changed: [] }, webrtc: null, registered: [] };
  globalThis.browser = {
    runtime: {
      id: 'fortiva',
      getBrowserInfo() {},
      getManifest: () => ({ version: '2.3.0' }),
      onInstalled: { addListener() {} },
      onStartup: { addListener() {} },
      onMessage: { addListener: (f) => (ff.on.message = f) },
    },
    storage: {
      local: {
        async get(keys) {
          await turn();
          return Object.fromEntries(keys.filter((k) => k in data).map((k) => [k, structuredClone(data[k])]));
        },
        async set(values) {
          const changes = Object.fromEntries(Object.entries(values).map(([k, v]) => [k, { oldValue: data[k], newValue: v }]));
          Object.assign(data, structuredClone(values));
          await turn();
          setTimeout(() => ff.on.changed.forEach((f) => f(changes, 'local')), 0);
        },
      },
      onChanged: { addListener: (f) => ff.on.changed.push(f) },
    },
    proxy: { onRequest: { addListener: (f) => (ff.on.request = f) } },
    webRequest: {
      onAuthRequired: {
        addListener: (f, filter, extra) => {
          ff.on.auth = f;
          ff.authExtra = extra;
        },
      },
    },
    alarms: { create() {}, onAlarm: { addListener: (f) => (ff.on.alarm = f) } },
    action: { async setIcon() {} },
    i18n: { getUILanguage: () => 'en' },
    permissions: { getAll: async () => ({ permissions: [], origins: [], data_collection: dataCollection }) },
    privacy: {
      network: {
        webRTCIPHandlingPolicy: {
          async set({ value }) { ff.webrtc = value; return true; },
          async clear() { ff.webrtc = null; return true; },
        },
      },
    },
  };
  // How a request to url would go now: "direct" or the proxies' hosts.
  ff.way = async (url) => {
    const answer = await ff.on.request({ url, tabId: -1 });
    return Array.isArray(answer) ? answer.map((p) => p.host).join(',') : answer.type;
  };
  globalThis.fetch = async (url, init) => {
    const way = await ff.way(url);
    if (url.endsWith('/devices/register')) ff.registered.push(JSON.parse(init.body));
    ff.log.push(`${new URL(url).pathname} via ${way}`);
    if (url === PROBE) ff.log.push(`a page meanwhile via ${await ff.way(PAGE)}`);
    if (way !== 'direct' && !alive.includes(way.split(',')[0])) throw new TypeError('NetworkError when attempting to fetch resource.');
    if (url === PROBE) return new Response(null, { status: 204 });
    if (url.endsWith('/configs/browser')) return Response.json(answer);
    return Response.json({});
  };
  // A new copy of the module for each test, as a background that starts.
  await import(`../src/background.js?firefox=${++loaded}`);
  ff.send = (msg) => new Promise((respond) => ff.on.message(msg, { id: 'fortiva' }, respond));
  ff.until = async (ok) => {
    for (let i = 0; i < 400 && !ok(); i++) await turn();
  };
  return ff;
}

test('Firefox: a try after a failure asks the backend direct, never through the proxies it had', async () => {
  const ff = await firefox({
    deviceId: '11111111-2222-4333-8444-555555555555',
    registeredVersion: '2.3.0',
    wanted: true,
    status: 'failed',
    error: 'stopped',
    lastTryAt: 0,
    // A server that has gone away, still stored as the rules in use, as a
    // background stopped in the middle of a change leaves them.
    proxies: [OLD],
    route: { mode: 'full', proxies: [OLD] },
  });
  ff.on.alarm({ name: 'fortiva-tick' });
  await ff.until(() => ff.data.status === 'on');
  assert.equal(ff.data.status, 'on', ff.log.join('\n'));
  assert.deepEqual(ff.log, [
    '/api/v1/configs/browser via direct',
    '/generate_204 via new.example.com',
    'a page meanwhile via direct',
  ]);
  assert.equal(await ff.way(PAGE), 'new.example.com');
});

test('Firefox: a background that starts again takes up the stored rules', async () => {
  const ff = await firefox({ wanted: true, status: 'on', route: { mode: 'full', proxies: [NEW] } });
  assert.equal(await ff.way(PAGE), 'new.example.com');
  const probing = await firefox({ wanted: true, status: 'connecting', route: { mode: 'probe', proxies: [NEW] } });
  assert.equal(await probing.way(PAGE), 'direct');
  assert.equal(await probing.way(PROBE), 'new.example.com');
  // Proxies kept from an older version, with no rules stored, carry nothing.
  const older = await firefox({ wanted: true, status: 'connecting', proxies: [OLD] });
  assert.equal(await older.way(PAGE), 'direct');
});

test('Firefox: a connect checks each proxy on its own and puts a dead one last', async () => {
  const ff = await firefox(
    { deviceId: '00000000-0000-4000-8000-000000000000', registeredVersion: '2.3.0' },
    { answer: { proxies: [OLD, NEW], quota: QUOTA, refresh_after_s: 3600 } },
  );
  const snap = await ff.send({ type: 'connect' });
  assert.equal(snap.status, 'on', ff.log.join('\n'));
  assert.equal(snap.location, 'New');
  assert.deepEqual(ff.log, [
    '/api/v1/configs/browser via direct',
    '/generate_204 via old.example.com',
    'a page meanwhile via direct',
    '/generate_204 via new.example.com',
    'a page meanwhile via direct',
  ]);
  assert.equal(await ff.way(PAGE), 'new.example.com,old.example.com');
  // WebRTC may use UDP only through a proxy while connected.
  assert.equal(ff.webrtc, 'disable_non_proxied_udp');
  const off = await ff.send({ type: 'disconnect' });
  assert.equal(off.status, 'off');
  assert.equal(await ff.way(PAGE), 'direct');
  assert.equal(ff.webrtc, null);
});

test('Firefox: the registration carries the browser, system and language only with the person\'s leave', async () => {
  const no = await firefox({});
  await no.send({ type: 'connect' });
  assert.equal(no.registered.length, 1);
  assert.deepEqual(Object.keys(no.registered[0]).sort(), ['app_version', 'device_id', 'platform']);
  const yes = await firefox({}, { dataCollection: ['technicalAndInteraction'] });
  await yes.send({ type: 'connect' });
  assert.equal(yes.registered[0].os_version !== undefined, true);
  assert.equal(yes.registered[0].language, 'en');
  assert.match(yes.registered[0].device_model, /^(Firefox|Browser)/);
});

test('Firefox: a request whose proxy refused the credentials is cancelled, and the connection checked at once', async () => {
  const usedUp = { unlimited: false, limit_bytes: 100, used_bytes: 100, remaining_bytes: 0, blocked: true, resets_at: new Date(Date.now() + 3600e3).toISOString() };
  const ff = await firefox(
    {
      deviceId: '11111111-2222-4333-8444-555555555555',
      registeredVersion: '2.3.0',
      wanted: true,
      status: 'on',
      proxies: [NEW],
      route: { mode: 'full', proxies: [NEW] },
      fetchedAt: Date.now(),
      refreshAfterS: 3600,
    },
    // The allowance ran out: the proxy refuses this browser, and the
    // backend sends no proxies.
    { alive: [], answer: { proxies: [], quota: usedUp, refresh_after_s: 3600 } },
  );
  // Firefox lets a blocking listener answer with a promise.
  assert.deepEqual(ff.authExtra, ['blocking']);
  // A site's own request for a password, and a proxy that is not ours, are
  // left to Firefox.
  assert.deepEqual(await ff.on.auth({ isProxy: false, challenger: { host: 'example.org', port: 443 } }), {});
  assert.deepEqual(await ff.on.auth({ isProxy: true, challenger: { host: 'proxy.example.net', port: 3128 } }), {});
  assert.equal(ff.data.status, 'on');
  // Firefox sent the credentials with the request, so a proxy of ours that
  // asks has refused them.
  assert.deepEqual(await ff.on.auth({ isProxy: true, challenger: { host: NEW.host, port: NEW.port } }), { cancel: true });
  await ff.until(() => ff.data.status === 'out_of_data');
  assert.equal(ff.data.status, 'out_of_data', ff.log.join('\n'));
  assert.equal(await ff.way(PAGE), 'direct');
  // The proxies are off and the backend sent none, but a page's request
  // sent through the proxy before that can still be refused by it. It is
  // cancelled too, so Firefox does not ask the person for a password.
  assert.deepEqual(ff.data.proxies, []);
  assert.deepEqual(await ff.on.auth({ isProxy: true, challenger: { host: NEW.host, port: NEW.port } }), { cancel: true });
  assert.deepEqual(await ff.on.auth({ isProxy: true, challenger: { host: 'proxy.example.net', port: 3128 } }), {});
});
