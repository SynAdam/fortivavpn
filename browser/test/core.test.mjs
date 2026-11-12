import assert from 'node:assert/strict';
import { test } from 'node:test';

import { ApiError } from '../src/api.js';
import { Controller, Status, arrange, locationsOf, rotate, spread } from '../src/core.js';

const PASSWORD = '11111111-2222-3333-4444-555555555555';
const PROXY = { server_id: 7, host: 'p.example.com', port: 8443, label: 'Germany', username: 'fortiva', password: PASSWORD };
const A = { server_id: 1, host: 'a.example.com', port: 443, label: 'One', username: 'fortiva', password: PASSWORD };
const B = { server_id: 2, host: 'b.example.com', port: 443, label: 'Two', username: 'fortiva', password: PASSWORD };
const QUOTA = { unlimited: false, limit_bytes: 20 * 2 ** 30, used_bytes: 2 ** 30, remaining_bytes: 19 * 2 ** 30, blocked: false };
// A device id whose place in a list of two is the start (spread is even).
const EVEN_ID = '00000000-0000-4000-8000-000000000000';

// A browser and a backend that do what the test says, and remember what
// they were asked.
function world({ proxies = [PROXY], quota = QUOTA, healthy = true, other = false } = {}) {
  const data = {};
  const w = {
    clock: 1_800_000_000_000,
    // The proxies of the full rules while they are on, else null.
    applied: null,
    // The rules in effect in the browser, as core.js set them.
    route: { mode: 'off' },
    cleared: 0,
    // How many times the full rules were turned on.
    fulls: 0,
    calls: [],
    // The rules in effect at each backend call.
    via: [],
    // What each check went through: a proxy's host, "full" or "direct".
    checks: [],
    // The hosts of proxies that answer every request with an error, as a
    // proxy does whose server lost its Xray (502) or this browser (407).
    broken: new Set(),
    registered: [],
    configCalls: 0,
    healthy,
    other,
    answer: () => ({ proxies, quota, refresh_after_s: 3600 }),
  };
  w.env = {
    now: () => w.clock,
    store: {
      async get(keys) {
        return Object.fromEntries(keys.filter((k) => k in data).map((k) => [k, structuredClone(data[k])]));
      },
      async set(values) {
        Object.assign(data, structuredClone(values));
      },
    },
    proxy: {
      async full(p) { w.applied = p; w.fulls++; w.route = { mode: 'full', proxies: p }; },
      async probe(p) { w.route = { mode: 'probe', proxies: [p] }; },
      async clear() { w.applied = null; w.cleared++; w.route = { mode: 'off' }; },
      async controlledByOther() { return w.other; },
    },
    // A browser does not move on to the next proxy after an error answer,
    // so the full rules carry the check only when their first proxy works.
    health: async () => {
      const r = w.route;
      if (r.mode === 'off') {
        w.checks.push('direct');
        return true;
      }
      w.checks.push(r.mode === 'probe' ? r.proxies[0].host : 'full');
      return w.healthy && !w.broken.has(r.proxies[0].host);
    },
    info: { version: '2.3.0', model: 'Chrome 131', os: 'Windows', language: () => 'fa' },
    api: {
      async register(body) { w.calls.push('register'); w.via.push(w.route.mode); w.registered.push(body); },
      async browserConfigs() {
        w.calls.push('configs');
        w.via.push(w.route.mode);
        w.configCalls++;
        const a = w.answer();
        if (a instanceof Error) throw a;
        return a;
      },
      async redeem(id, code) {
        w.calls.push('redeem');
        if (code === 'GOOD') return { kind: 'premium', moved: true };
        throw new ApiError(400, 'expired');
      },
    },
  };
  w.data = data;
  w.controller = new Controller(w.env);
  return w;
}

test('connecting turns the proxies on once they carry a check', async () => {
  const w = world();
  const snap = await w.controller.connect();
  assert.equal(snap.status, Status.ON);
  assert.equal(snap.location, 'Germany');
  assert.equal(snap.quota.remaining_bytes, QUOTA.remaining_bytes);
  assert.deepEqual(w.applied, [PROXY]);
  // Only these calls: the backend reads events as a phone's.
  assert.deepEqual(w.calls, ['register', 'configs']);
  assert.equal(w.registered.length, 1);
  assert.equal(w.registered[0].device_model, 'Chrome 131');
  assert.equal(w.registered[0].language, 'fa');
  assert.match(w.data.deviceId, /^[0-9a-f-]{36}$/);
  assert.deepEqual(await w.controller.credentialsFor('p.example.com', 8443), { username: 'fortiva', password: PROXY.password });
  assert.equal(await w.controller.credentialsFor('other.example.com', 8443), null);
});

test('proxies that carry nothing are turned off again', async () => {
  const w = world({ healthy: false });
  const snap = await w.controller.connect();
  assert.equal(snap.status, Status.FAILED);
  assert.equal(snap.error, 'unreachable');
  assert.equal(w.applied, null);
});

test('a browser whose data is used up gets no proxies and says so', async () => {
  const w = world({ proxies: [], quota: { ...QUOTA, remaining_bytes: 0, blocked: true, resets_at: '2027-01-15T20:30:00Z' } });
  const snap = await w.controller.connect();
  assert.equal(snap.status, Status.NO_DATA);
  assert.equal(w.applied, null);
  // It waits for the reset rather than asking again on every check.
  w.clock += 10 * 60 * 1000;
  const calls = w.configCalls;
  await w.controller.tick();
  assert.equal(w.configCalls, calls);
});

test('no server for browsers is a failure, not a used-up allowance', async () => {
  const w = world({ proxies: [] });
  const snap = await w.controller.connect();
  assert.equal(snap.status, Status.FAILED);
  assert.equal(snap.error, 'no_servers');
});

test('with no server for browsers, the next try waits as long as the backend said', async () => {
  // No server takes browsers: the backend says an hour.
  const w = world({ proxies: [] });
  w.answer = () => ({ proxies: [], quota: QUOTA, refresh_after_s: 3600 });
  await w.controller.connect();
  const calls = w.configCalls;
  w.clock += 5 * 60 * 1000 + 1;
  await w.controller.tick();
  assert.equal(w.configCalls, calls, 'it asked again after 5 minutes, before the hour the backend gave');
  w.clock += 55 * 60 * 1000;
  w.answer = () => ({ proxies: [PROXY], quota: QUOTA, refresh_after_s: 3600 });
  await w.controller.tick();
  assert.equal(w.configCalls, calls + 1);
  assert.equal((await w.controller.snapshot()).status, Status.ON);

  // A server's panel did not answer: the backend says 5 minutes. A shorter
  // answer still waits RETRY_MS.
  const v = world({ proxies: [] });
  v.answer = () => ({ proxies: [], quota: QUOTA, refresh_after_s: 60 });
  await v.controller.connect();
  const before = v.configCalls;
  v.clock += 60 * 1000 + 1;
  await v.controller.tick();
  assert.equal(v.configCalls, before, 'it asked again before RETRY_MS');
  v.clock += 4 * 60 * 1000;
  await v.controller.tick();
  assert.equal(v.configCalls, before + 1);
});

test('a refused credential asks the backend at once, not through the proxy that refused', async () => {
  const usedUp = { unlimited: false, limit_bytes: 100, used_bytes: 100, remaining_bytes: 0, blocked: true, resets_at: new Date(1_800_000_000_000 + 3600e3).toISOString() };
  const w = world();
  await w.controller.connect();
  const checks = w.checks.length;
  const calls = w.configCalls;
  w.answer = () => ({ proxies: [], quota: usedUp, refresh_after_s: 3600 });
  await w.controller.verify({ refused: true });
  assert.equal(w.configCalls, calls + 1);
  assert.deepEqual(w.checks.slice(checks), [], 'it checked through a proxy before asking the backend');
  assert.equal((await w.controller.snapshot()).status, Status.NO_DATA);
  assert.equal(w.applied, null);

  // A refusal with data left: each proxy is checked on its own again.
  const v = world();
  await v.controller.connect();
  const before = v.configCalls;
  await v.controller.verify({ refused: true });
  assert.equal(v.configCalls, before + 1);
  assert.equal((await v.controller.snapshot()).status, Status.ON);
});

test('the backend out of reach is told apart from a refusal', async () => {
  const w = world();
  w.answer = () => new ApiError(0, 'network');
  assert.equal((await w.controller.connect()).error, 'network');
  w.answer = () => new ApiError(500, '');
  assert.equal((await w.controller.connect()).error, 'server');
});

test('an unknown browser registers again and connects', async () => {
  const w = world();
  let first = true;
  w.answer = () => {
    if (first) {
      first = false;
      return new ApiError(404, '');
    }
    return { proxies: [PROXY], quota: QUOTA, refresh_after_s: 3600 };
  };
  await w.env.store.set({ registeredVersion: '2.3.0' });
  const snap = await w.controller.connect();
  assert.equal(snap.status, Status.ON);
  assert.equal(w.registered.length, 1);
});

test('another extension holding the proxy setting is reported', async () => {
  const w = world({ other: true });
  const snap = await w.controller.connect();
  assert.equal(snap.status, Status.OTHER);
  assert.equal(snap.wanted, false);
  assert.equal(w.applied, null);
});

test('a connection that stops carrying traffic, with the backend out of reach too, is turned off after two checks, then tried again', async () => {
  const w = world();
  await w.controller.connect();
  w.healthy = false;
  w.answer = () => new ApiError(0, 'network');
  await w.controller.tick();
  assert.equal((await w.controller.snapshot()).status, Status.ON, 'one missed check is not enough');
  await w.controller.tick();
  const snap = await w.controller.snapshot();
  assert.equal(snap.status, Status.FAILED);
  assert.equal(snap.error, 'stopped');
  assert.equal(w.applied, null);

  // Not at once: the next try waits five minutes.
  w.healthy = true;
  w.answer = () => ({ proxies: [PROXY], quota: QUOTA, refresh_after_s: 3600 });
  await w.controller.tick();
  assert.equal((await w.controller.snapshot()).status, Status.FAILED);
  w.clock += 5 * 60 * 1000 + 1;
  await w.controller.tick();
  assert.equal((await w.controller.snapshot()).status, Status.ON);
});

test('credentials are fetched again when they are due', async () => {
  const w = world();
  await w.controller.connect();
  const calls = w.configCalls;
  w.clock += 30 * 60 * 1000;
  await w.controller.tick();
  assert.equal(w.configCalls, calls, 'not due yet');
  w.clock += 31 * 60 * 1000;
  await w.controller.tick();
  assert.equal(w.configCalls, calls + 1);

  // The allowance ran out meanwhile: the proxies go off.
  w.answer = () => ({ proxies: [], quota: { ...QUOTA, remaining_bytes: 0, blocked: true } });
  w.clock += 61 * 60 * 1000;
  await w.controller.tick();
  assert.equal((await w.controller.snapshot()).status, Status.NO_DATA);
  assert.equal(w.applied, null);
});

test('turning it off clears the proxies and says so', async () => {
  const w = world();
  await w.controller.connect();
  w.clock += 90_000;
  const snap = await w.controller.disconnect();
  assert.equal(snap.status, Status.OFF);
  assert.equal(w.applied, null);
  assert.deepEqual(w.calls, ['register', 'configs']);
  // Off stays off: a check does nothing.
  w.clock += 60 * 60 * 1000;
  await w.controller.tick();
  assert.equal((await w.controller.snapshot()).status, Status.OFF);
});

test('a code is applied and its refusal keeps the backend reason', async () => {
  const w = world();
  assert.deepEqual(await w.controller.redeem('GOOD'), { ok: true, kind: 'premium', moved: true });
  assert.deepEqual(await w.controller.redeem('OLD'), { ok: false, reason: 'expired', status: 400 });
});

test('a click and a check at once do one thing at a time', async () => {
  const w = world();
  await Promise.all([w.controller.connect(), w.controller.tick(), w.controller.connect()]);
  assert.equal((await w.controller.snapshot()).status, Status.ON);
});

test('a connect makes its backend calls direct, never through proxies saved before', async () => {
  // A server that has gone away, still in storage from the last connect,
  // even with the full rules stored as on, as a stopped background leaves
  // them.
  const w = world({ proxies: [B] });
  w.broken.add(A.host);
  await w.env.store.set({
    deviceId: EVEN_ID, wanted: true, status: Status.FAILED, error: 'stopped', lastTryAt: 0,
    proxies: [A], route: { mode: 'full', proxies: [A] },
  });
  w.route = { mode: 'full', proxies: [A] };
  await w.controller.tick();
  assert.deepEqual(w.via, ['off', 'off'], 'register and configs/browser went direct');
  assert.deepEqual(w.checks, [B.host]);
  const snap = await w.controller.snapshot();
  assert.equal(snap.status, Status.ON);
  assert.equal(snap.location, 'Two');
  assert.deepEqual(w.applied, [B]);
});

test('a proxy that answers with an error goes behind one that works', async () => {
  const w = world({ proxies: [A, B] });
  w.broken.add(A.host);
  await w.env.store.set({ deviceId: EVEN_ID });
  const snap = await w.controller.connect();
  assert.equal(snap.status, Status.ON);
  // Each was checked on its own, and the full rules were never checked.
  assert.deepEqual(w.checks, [A.host, B.host]);
  assert.deepEqual(w.applied, [B, A]);
  assert.equal(snap.location, 'Two');
  assert.deepEqual(await w.controller.credentialsFor(B.host, B.port), { username: 'fortiva', password: PASSWORD });
});

test('each browser starts the list at its own place, the same on every run', () => {
  const list = [A, B, PROXY];
  const firsts = ['00000000', '00000001', '00000002'].map((h) => rotate(list, spread(`${h}-0000-4000-8000-000000000000`))[0]);
  assert.deepEqual(firsts, [A, B, PROXY]);
  const id = 'c3f1a2b4-0000-4000-8000-000000000000';
  assert.deepEqual(rotate(list, spread(id)), rotate(list, spread(id)));
  assert.deepEqual(rotate([], 5), []);
  assert.equal(spread('not an id'), 0);
});

test('a failed check while connected switches to a proxy that still works', async () => {
  const w = world({ proxies: [A, B] });
  await w.env.store.set({ deviceId: EVEN_ID });
  await w.controller.connect();
  assert.deepEqual(w.applied, [A, B]);
  w.broken.add(A.host);
  w.checks = [];
  await w.controller.tick();
  assert.deepEqual(w.checks, ['full', A.host, B.host]);
  const snap = await w.controller.snapshot();
  assert.equal(snap.status, Status.ON);
  assert.equal(snap.location, 'Two');
  assert.deepEqual(w.applied, [B, A]);
  assert.equal(w.data.misses, 0);
});

test('tries after a failure never put the browser behind proxies that failed their check', async () => {
  const w = world({ proxies: [A, B] });
  w.broken.add(A.host);
  w.broken.add(B.host);
  const snap = await w.controller.connect();
  assert.equal(snap.status, Status.FAILED);
  assert.equal(snap.wanted, true);
  w.clock += 5 * 60 * 1000 + 1;
  await w.controller.tick();
  assert.equal((await w.controller.snapshot()).status, Status.FAILED);
  assert.equal(w.fulls, 0, 'the full rules were never turned on');
  assert.ok(!w.checks.includes('full'));
  assert.deepEqual(w.route, { mode: 'off' });
});

test('new servers from a refresh go after the ones that passed a check', async () => {
  const w = world({ proxies: [A] });
  await w.env.store.set({ deviceId: EVEN_ID });
  await w.controller.connect();
  w.answer = () => ({ proxies: [A, B], quota: QUOTA, refresh_after_s: 3600 });
  w.clock += 61 * 60 * 1000;
  w.checks = [];
  await w.controller.tick();
  assert.deepEqual(w.applied, [A, B]);
  assert.deepEqual(w.checks, ['full'], 'no proxy was checked on its own');

  // None of the proxies in use is sent any more: the new ones are checked
  // before they carry a page.
  const C = { ...B, host: 'c.example.com', label: 'Three' };
  w.answer = () => ({ proxies: [C], quota: QUOTA, refresh_after_s: 3600 });
  w.clock += 61 * 60 * 1000;
  w.checks = [];
  await w.controller.tick();
  assert.deepEqual(w.checks, [C.host, 'full']);
  assert.deepEqual(w.applied, [C]);
  assert.equal((await w.controller.snapshot()).location, 'Three');
});

test('turning it off after a failure stops the tries', async () => {
  const w = world({ healthy: false });
  assert.equal((await w.controller.connect()).wanted, true);
  const snap = await w.controller.disconnect();
  assert.equal(snap.status, Status.OFF);
  assert.equal(snap.wanted, false);
  const calls = w.configCalls;
  w.clock += 60 * 60 * 1000;
  await w.controller.tick();
  assert.equal(w.configCalls, calls);
});

test('another extension taking the proxy setting while connected turns ours off and says so', async () => {
  const w = world();
  await w.controller.connect();
  w.other = true;
  w.checks = [];
  await w.controller.tick();
  const snap = await w.controller.snapshot();
  assert.equal(snap.status, Status.OTHER);
  assert.equal(snap.error, 'other_controls');
  assert.equal(snap.wanted, false);
  assert.equal(w.applied, null, 'what is ours is cleared');
  assert.deepEqual(w.checks, [], 'the check would pass through the other extension');
  // verify, out of turn, does the same.
  const v = world();
  await v.controller.connect();
  v.other = true;
  await v.controller.verify();
  assert.equal((await v.controller.snapshot()).status, Status.OTHER);
});

test('a used-up allowance is found at the first failed check, from the backend, direct', async () => {
  const w = world();
  await w.controller.connect();
  // The panel switched this browser off: its proxy refuses every request.
  w.broken.add(PROXY.host);
  w.answer = () => ({ proxies: [], quota: { ...QUOTA, remaining_bytes: 0, blocked: true, resets_at: '2027-01-15T20:30:00Z' } });
  w.via = [];
  await w.controller.tick();
  const snap = await w.controller.snapshot();
  assert.equal(snap.status, Status.NO_DATA);
  assert.deepEqual(w.via, ['off'], 'the backend was asked direct');
  assert.equal(w.applied, null);
});

test('proxies that stop working while the backend answers are turned off at the first failed check', async () => {
  const w = world();
  await w.controller.connect();
  w.broken.add(PROXY.host);
  await w.controller.tick();
  const snap = await w.controller.snapshot();
  assert.equal(snap.status, Status.FAILED);
  assert.equal(snap.error, 'stopped');
  assert.equal(snap.wanted, true);
  assert.equal(w.applied, null);
});

test('the backend out of reach: the saved proxies are checked, then the backend is asked through them', async () => {
  const w = world({ proxies: [A, B] });
  await w.env.store.set({ deviceId: EVEN_ID });
  await w.controller.connect();
  await w.controller.disconnect();
  // The backend's name is filtered: only a call through a proxy gets there.
  const fresh = { ...B, label: 'Two, fresh' };
  w.answer = () => (w.route.mode === 'full' ? { proxies: [A, fresh], quota: QUOTA, refresh_after_s: 3600 } : new ApiError(0, 'network'));
  w.broken.add(A.host);
  w.via = [];
  w.checks = [];
  const snap = await w.controller.connect();
  assert.equal(snap.status, Status.ON);
  assert.deepEqual(w.checks, [A.host, B.host]);
  assert.deepEqual(w.via, ['off', 'full'], 'direct first, then through the proxy that passed');
  assert.deepEqual(w.applied, [fresh, A]);
  assert.equal(snap.location, 'Two, fresh');
});

test('the backend out of reach with no saved proxy, or refusing, is a failure with no check', async () => {
  const w = world();
  w.answer = () => new ApiError(0, 'network');
  assert.equal((await w.controller.connect()).error, 'network');
  assert.deepEqual(w.checks, []);
  // A refusal is not a backend out of reach, even with proxies saved.
  const r = world();
  await r.controller.connect();
  r.answer = () => new ApiError(403, '');
  r.checks = [];
  const snap = await r.controller.connect();
  assert.equal(snap.status, Status.FAILED);
  assert.equal(snap.error, 'server');
  assert.deepEqual(r.checks, []);
});

test('the saved proxies all failing while the backend is out of reach is a network failure', async () => {
  const w = world();
  await w.controller.connect();
  w.answer = () => new ApiError(0, 'network');
  w.broken.add(PROXY.host);
  const snap = await w.controller.connect();
  assert.equal(snap.status, Status.FAILED);
  assert.equal(snap.error, 'network');
  assert.equal(w.applied, null);
});

test('a code that brings data back to a browser out of data connects it again', async () => {
  const used = { ...QUOTA, remaining_bytes: 0, blocked: true, resets_at: '2027-01-15T20:30:00Z' };
  const w = world({ proxies: [], quota: used });
  assert.equal((await w.controller.connect()).status, Status.NO_DATA);
  w.answer = () => ({ proxies: [PROXY], quota: { ...QUOTA, remaining_bytes: 2 ** 30 }, refresh_after_s: 3600 });
  assert.equal((await w.controller.redeem('GOOD')).ok, true);
  assert.equal((await w.controller.snapshot()).status, Status.CONNECTING, 'the popup shows the connect at once');
  await w.controller.busy;
  assert.equal((await w.controller.snapshot()).status, Status.ON);
  assert.deepEqual(w.applied, [PROXY]);
});

test('a browser turned off while out of data stays off when data comes back', async () => {
  const used = { ...QUOTA, remaining_bytes: 0, blocked: true, resets_at: '2027-01-15T20:30:00Z' };
  const w = world({ proxies: [], quota: used });
  await w.controller.connect();
  await w.controller.disconnect();
  w.answer = () => ({ proxies: [PROXY], quota: QUOTA, refresh_after_s: 3600 });
  await w.controller.redeem('GOOD');
  await w.controller.busy;
  assert.equal((await w.controller.snapshot()).status, Status.OFF);
  assert.equal(w.applied, null);
});

test('out of data, a check connects again once the quota fetched since has data', async () => {
  const used = { ...QUOTA, remaining_bytes: 0, blocked: true, resets_at: '2027-01-15T20:30:00Z' };
  const w = world({ proxies: [], quota: used });
  await w.controller.connect();
  // Data came back, and the quota stored says so, but the reset is still
  // ahead.
  await w.env.store.set({ quota: { ...QUOTA, resets_at: '2027-01-15T20:30:00Z' } });
  w.answer = () => ({ proxies: [PROXY], quota: QUOTA, refresh_after_s: 3600 });
  w.clock += 2 * 60 * 1000;
  await w.controller.tick();
  assert.equal((await w.controller.snapshot()).status, Status.ON);
  // Opening the popup does the same.
  const p = world({ proxies: [], quota: used });
  await p.controller.connect();
  p.answer = () => ({ proxies: [PROXY], quota: QUOTA, refresh_after_s: 3600 });
  await p.controller.refreshQuota();
  await p.controller.busy;
  assert.equal((await p.controller.snapshot()).status, Status.ON);
});

test('without the person\'s leave, the registration carries no browser, system or language', async () => {
  const w = world();
  w.env.info.shareTechnical = async () => false;
  await w.controller.connect();
  assert.equal(w.registered.length, 1);
  assert.deepEqual(Object.keys(w.registered[0]), ['device_id']);
});

const DE = { server_id: 13, host: 'de.example.com', port: 9443, label: 'Germany', username: 'fortiva', password: PASSWORD };
const FI1 = { server_id: 14, host: 'fi1.example.com', port: 9443, label: 'Finland', username: 'fortiva', password: PASSWORD };
const FI2 = { server_id: 17, host: 'fi2.example.com', port: 9443, label: 'Finland', username: 'fortiva', password: PASSWORD };

test('arrange keeps the backend order when it is ordered, and puts a chosen location first', () => {
  // A device id whose place in a list of three is not the start.
  const id = '00000001-0000-4000-8000-000000000000';
  assert.notEqual(spread(id) % 3, 0);
  assert.deepEqual(arrange([DE, FI1, FI2], { id, ordered: true }).map((p) => p.server_id), [13, 14, 17]);
  assert.deepEqual(arrange([DE, FI1, FI2], { id }), rotate([DE, FI1, FI2], spread(id)));
  assert.deepEqual(arrange([DE, FI1, FI2], { id, ordered: true, chosen: 'Finland' }).map((p) => p.server_id), [14, 17, 13]);
  // A location no longer offered changes nothing.
  assert.deepEqual(arrange([DE, FI1], { id, ordered: true, chosen: 'Japan' }).map((p) => p.server_id), [13, 14]);
  assert.deepEqual(locationsOf([DE, FI1, FI2]), ['Germany', 'Finland']);
});

test('an ordered answer is checked in its own order', async () => {
  const w = world({ proxies: [FI1, DE] });
  w.answer = () => ({ proxies: [FI1, DE], quota: QUOTA, refresh_after_s: 3600, ordered: true });
  w.broken.add(FI1.host);
  const snap = await w.controller.connect();
  // Finland first as the backend ordered it; it fails, so Germany carries.
  assert.deepEqual(w.checks.filter((c) => c !== 'direct'), [FI1.host, DE.host]);
  assert.equal(snap.location, 'Germany');
  assert.deepEqual(snap.locations, ['Finland', 'Germany']);
  assert.equal(snap.chosenLocation, '');
});

test('choosing a location connects again with it first, and falls back when it fails', async () => {
  const w = world({ proxies: [DE, FI1, FI2] });
  w.answer = () => ({ proxies: [DE, FI1, FI2], quota: QUOTA, refresh_after_s: 3600, ordered: true });
  assert.equal((await w.controller.connect()).location, 'Germany');
  let snap = await w.controller.setLocation('Finland');
  assert.equal(snap.status, Status.ON);
  assert.equal(snap.location, 'Finland');
  assert.equal(snap.chosenLocation, 'Finland');
  assert.deepEqual(w.applied.map((p) => p.server_id), [14, 17, 13]);

  // Both Finland servers fail: Germany still carries the browser.
  w.broken.add(FI1.host);
  w.broken.add(FI2.host);
  snap = await w.controller.connect();
  assert.equal(snap.status, Status.ON);
  assert.equal(snap.location, 'Germany');
  assert.equal(snap.chosenLocation, 'Finland');

  // Back to automatic.
  w.broken.clear();
  snap = await w.controller.setLocation('');
  assert.equal(snap.location, 'Germany');
  assert.equal(snap.chosenLocation, '');
});

test('choosing a location while off only keeps it for the next connect', async () => {
  const w = world({ proxies: [DE, FI1] });
  w.answer = () => ({ proxies: [DE, FI1], quota: QUOTA, refresh_after_s: 3600, ordered: true });
  const calls = w.configCalls;
  const snap = await w.controller.setLocation('Finland');
  assert.equal(snap.status, Status.OFF);
  assert.equal(w.configCalls, calls);
  assert.equal((await w.controller.connect()).location, 'Finland');
});
