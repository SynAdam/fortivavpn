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
    },
    alarms: { create() {}, onAlarm: listener },
    action: { async setIcon() {} },
    i18n: { getUILanguage: () => 'en' },
    privacy: { network: { webRTCIPHandlingPolicy: { async set() {}, async clear() {} } } },
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
