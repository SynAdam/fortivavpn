// Runs src/background.js as Chrome runs it, with a fake `chrome`, to test
// what it answers when a proxy asks for credentials.

import assert from 'node:assert/strict';
import { test } from 'node:test';

const PASSWORD = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';
const NEW = { server_id: 2, host: 'new.example.com', port: 9443, username: 'fortiva', password: PASSWORD, label: 'New' };

const turn = () => new Promise((r) => setTimeout(r, 1));

let loaded = 0;

// chrome starts a background with data in storage.
async function chrome(data) {
  const cr = { data, on: { changed: [] } };
  const listener = { addListener() {} };
  globalThis.chrome = {
    runtime: {
      id: 'fortiva',
      getManifest: () => ({ version: '2.3.0' }),
      onInstalled: listener,
      onStartup: listener,
      onMessage: listener,
    },
    storage: {
      local: {
        async get(keys) {
          await turn();
          return Object.fromEntries(keys.filter((k) => k in data).map((k) => [k, structuredClone(data[k])]));
        },
        async set(values) {
          Object.assign(data, structuredClone(values));
          await turn();
        },
      },
      onChanged: { addListener: (f) => cr.on.changed.push(f) },
    },
    proxy: {
      settings: {
        async set() {},
        async clear() {},
        async get() { return { levelOfControl: 'controlled_by_this_extension' }; },
        onChange: listener,
      },
    },
    webRequest: {
      onAuthRequired: {
        addListener: (f, filter, extra) => {
          cr.on.auth = f;
          cr.authExtra = extra;
        },
      },
      onErrorOccurred: { addListener: (f) => (cr.on.error = f) },
    },
    alarms: { create() {}, onAlarm: listener },
    action: { async setIcon() {} },
    i18n: { getUILanguage: () => 'en' },
    privacy: { network: { webRTCIPHandlingPolicy: { async set() {}, async clear() {} } } },
  };
  // The backend and the check page, as answer says. checkPasses is whether
  // a check through the proxy works.
  cr.calls = [];
  globalThis.fetch = async (url) => {
    cr.calls.push(new URL(url).pathname);
    if (url.includes('generate_204')) {
      if (cr.checkPasses) return new Response(null, { status: 204 });
      throw new TypeError('Failed to fetch');
    }
    if (url.endsWith('/configs/browser')) return Response.json(cr.answer);
    return Response.json({});
  };
  await import(`../src/background.js?chrome=${++loaded}`);
  // What the listener answers a proxy's request for credentials.
  let id = 0;
  cr.ask = (host, port) => new Promise((respond) => cr.on.auth({ requestId: String(++id), isProxy: true, challenger: { host, port } }, respond));
  return cr;
}

test('Chrome: a proxy of ours gets the credentials, and one it no longer uses gets a cancel, never a password dialog', async () => {
  const cr = await chrome({ wanted: true, status: 'on', proxies: [NEW], route: { mode: 'full', proxies: [NEW] } });
  assert.deepEqual(cr.authExtra, ['asyncBlocking']);
  assert.deepEqual(await cr.ask(NEW.host, NEW.port), { authCredentials: { username: 'fortiva', password: PASSWORD } });
  // A proxy that is not ours is left to Chrome.
  assert.deepEqual(await cr.ask('proxy.example.net', 3128), {});

  // The allowance ran out: the proxies are off and the backend sent none,
  // as the extension leaves them. A request sent through the proxy before
  // that is refused by it now. Chrome would ask the person for a password
  // if the listener left it alone.
  const after = await chrome({
    wanted: true,
    status: 'out_of_data',
    proxies: [],
    route: { mode: 'off' },
    usedProxies: [`${NEW.host}:${NEW.port}`],
  });
  assert.deepEqual(await after.ask(NEW.host, NEW.port), { cancelRequest: true });
  assert.deepEqual(await after.ask('proxy.example.net', 3128), {});
});

test('Chrome: a tunnel that failed while connected checks the connection at once', async () => {
  const usedUp = { unlimited: false, limit_bytes: 100, used_bytes: 100, remaining_bytes: 0, blocked: true, resets_at: new Date(Date.now() + 3600e3).toISOString() };
  const state = () => ({
    deviceId: '11111111-2222-4333-8444-555555555555',
    registeredVersion: '2.3.0',
    wanted: true,
    status: 'on',
    proxies: [NEW],
    route: { mode: 'full', proxies: [NEW] },
    fetchedAt: Date.now(),
    refreshAfterS: 3600,
  });
  // The allowance ran out: the proxy refuses this browser with 403, which
  // Chrome reports as a failed tunnel, with no auth event.
  const cr = await chrome(state());
  cr.answer = { proxies: [], quota: usedUp, refresh_after_s: 3600 };
  cr.checkPasses = false;
  // Another failure changes nothing.
  cr.on.error({ url: 'https://example.org/', error: 'net::ERR_ABORTED' });
  for (let i = 0; i < 50; i++) await turn();
  assert.deepEqual(cr.calls, []);
  cr.on.error({ url: 'https://example.org/', error: 'net::ERR_TUNNEL_CONNECTION_FAILED' });
  for (let i = 0; i < 400 && cr.data.status !== 'out_of_data'; i++) await turn();
  assert.equal(cr.data.status, 'out_of_data', cr.calls.join(', '));
  assert.deepEqual(cr.calls.slice(0, 2), ['/generate_204', '/api/v1/configs/browser']);

  // A site that is down fails its tunnel too, but the check passes, so
  // nothing changes.
  const up = await chrome(state());
  up.checkPasses = true;
  up.on.error({ url: 'https://example.org/', error: 'net::ERR_TUNNEL_CONNECTION_FAILED' });
  for (let i = 0; i < 400 && up.calls.length === 0; i++) await turn();
  for (let i = 0; i < 50; i++) await turn();
  assert.equal(up.data.status, 'on');
  assert.deepEqual(up.calls, ['/generate_204']);
});

test('Chrome: a tunnel that failed during a connect does not hold back the next check', async () => {
  const cr = await chrome({
    deviceId: '11111111-2222-4333-8444-555555555555',
    registeredVersion: '2.3.0',
    wanted: true,
    status: 'connecting',
    proxies: [NEW],
    route: { mode: 'probe', proxies: [NEW] },
    fetchedAt: Date.now(),
    refreshAfterS: 3600,
  });
  cr.checkPasses = true;
  // A proxy failing its check during the connect.
  cr.on.error({ url: 'https://www.gstatic.com/generate_204', error: 'net::ERR_TUNNEL_CONNECTION_FAILED' });
  for (let i = 0; i < 50; i++) await turn();
  assert.deepEqual(cr.calls, []);
  // Connected a moment later, a failed tunnel is checked at once.
  Object.assign(cr.data, { status: 'on', route: { mode: 'full', proxies: [NEW] } });
  cr.on.error({ url: 'https://example.org/', error: 'net::ERR_TUNNEL_CONNECTION_FAILED' });
  for (let i = 0; i < 400 && cr.calls.length === 0; i++) await turn();
  assert.deepEqual(cr.calls, ['/generate_204']);
});
