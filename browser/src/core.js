// What the extension does, apart from any browser: get this browser's
// proxies from the backend, check each one, turn on the ones that carry
// traffic, and turn them off when they stop. background.js gives it the
// browser's storage, proxy settings and network; the tests give it fakes.
//
// Everything that must survive is in storage, because a browser stops the
// extension's background whenever it is idle and starts it again for the
// next event. That includes the rules in effect, the "route":
//
//   {mode: 'off'}                    every request goes direct
//   {mode: 'probe', proxies: [p]}    only the check goes through p
//   {mode: 'full', proxies: [...]}   the full rules (pac.js)
//
// Firefox answers each request from the route, so a background that
// starts again takes up the same rules.

import { ApiError } from './api.js';
import { validProxy } from './pac.js';

export const Status = Object.freeze({
  OFF: 'off',
  CONNECTING: 'connecting',
  ON: 'on',
  FAILED: 'failed',
  NO_DATA: 'out_of_data',
  OTHER: 'other_controls',
});

// How often the checks run (background.js sets an alarm with this period).
export const TICK_MINUTES = 2;
// Checks in a row that must fail before the proxies are turned off, while
// the backend is out of reach too. When the backend answers, one is enough.
const MISSES = 2;
// The least time between two tries after a failure.
const RETRY_MS = 5 * 60 * 1000;
// How long a "connecting" may last before a check starts it again: the
// browser may have stopped the background in the middle of it.
const STUCK_MS = 2 * 60 * 1000;

// retryWait is how long a failed connect waits before a check tries again.
// When the backend answered but sent no proxy, its refresh_after_s says when
// asking again can change that: 5 minutes while a server's panel did not
// answer, an hour when no server takes browsers. It is never less than
// RETRY_MS.
function retryWait(s) {
  if (s.error !== 'no_servers') return RETRY_MS;
  return Math.max(RETRY_MS, (s.refreshAfterS || 0) * 1000);
}

function uuid() {
  if (globalThis.crypto && crypto.randomUUID) return crypto.randomUUID();
  const b = crypto.getRandomValues(new Uint8Array(16));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  const h = [...b].map((x) => x.toString(16).padStart(2, '0')).join('');
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20)}`;
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

export const OFF_ROUTE = Object.freeze({ mode: 'off' });

// The most proxy addresses kept as ones this extension has used
// (usedProxies, ownsProxy).
const USED_MAX = 64;

function where(host, port) {
  return `${String(host).toLowerCase()}:${Number(port)}`;
}

// unreachable says whether a failed call means the backend could not be
// reached: no answer, or an answer from something in front of it (5xx).
function unreachable(e) {
  return !(e instanceof ApiError) || e.status === 0 || e.status >= 500;
}

// The usable proxies of a list from storage or the backend.
function usable(list) {
  return Array.isArray(list) ? list.filter(validProxy) : [];
}

// The proxies the full rules use now, or none.
function inUse(route) {
  return route && route.mode === 'full' ? usable(route.proxies) : [];
}

// spread is a number taken from the device id, the same on every run. The
// backend sends the proxies in server id order; each browser starts its
// list at its own place, so browsers do not all start on the same server.
export function spread(id) {
  const n = parseInt(String(id || '').replace(/-/g, '').slice(0, 8), 16);
  return Number.isFinite(n) ? n : 0;
}

// rotate starts list at place n, wrapping round.
export function rotate(list, n) {
  if (!list.length) return [];
  const k = n % list.length;
  return [...list.slice(k), ...list.slice(0, k)];
}

// arrange is the order in which this browser checks and uses proxies. The
// backend's order when it says the list is ordered for this browser's
// network (POST /configs/browser, ordered); otherwise the list from this
// device's own place (spread), so browsers do not all start on the same
// server. A location the person chose goes first, with the others after
// it, so a chosen location that fails still leaves a way through.
export function arrange(list, { id, ordered = false, chosen = '' } = {}) {
  const start = ordered ? [...list] : rotate(list, spread(id));
  if (!chosen) return start;
  return [...start.filter((p) => p.label === chosen), ...start.filter((p) => p.label !== chosen)];
}

// The locations of a list of proxies, each once, in the order given.
export function locationsOf(list) {
  return [...new Set(usable(list).map((p) => p.label).filter(Boolean))];
}

export function outOfData(quota) {
  if (!quota) return false;
  return quota.blocked === true || (!quota.unlimited && quota.limit_bytes > 0 && quota.remaining_bytes <= 0);
}

export class Controller {
  // env: {store: {get(keys), set(obj)}, proxy: {full(proxies),
  // probe(proxy), clear(), controlledByOther()}, api: Api,
  // health(): Promise<boolean>, info: {version, model, os, language(),
  // shareTechnical(): Promise<boolean>}, now(): ms}
  constructor(env) {
    this.env = env;
    this.now = env.now || Date.now;
    this.busy = null;
  }

  // One change at a time: a click and an alarm can arrive together.
  serial(fn) {
    const run = (this.busy || Promise.resolve()).then(fn, fn);
    this.busy = run.catch(() => {});
    return run;
  }

  async read() {
    return this.env.store.get([
      'deviceId', 'wanted', 'status', 'error', 'proxies', 'route', 'quota', 'fetchedAt',
      'refreshAfterS', 'registeredVersion', 'misses', 'lastTryAt', 'language',
      'chosenLocation', 'ordered',
    ]);
  }

  async deviceId() {
    const { deviceId } = await this.env.store.get(['deviceId']);
    if (typeof deviceId === 'string' && UUID_RE.test(deviceId)) return deviceId;
    const id = uuid();
    await this.env.store.set({ deviceId: id });
    return id;
  }

  // What the popup shows. The location is the first proxy the rules use.
  async snapshot() {
    const s = await this.read();
    const first = inUse(s.route)[0];
    return {
      status: s.status || Status.OFF,
      wanted: s.wanted === true,
      error: s.error || '',
      quota: s.quota || null,
      location: s.status === Status.ON && first ? first.label || '' : '',
      language: s.language || '',
      // The locations the person can choose, and the chosen one ('' for
      // automatic, also when the chosen one is no longer offered).
      locations: locationsOf(s.proxies),
      chosenLocation: locationsOf(s.proxies).includes(s.chosenLocation) ? s.chosenLocation : '',
    };
  }

  // useRoute puts route in storage, then in the browser. Storage comes
  // first: a background stopped between the two starts again with the new
  // rules.
  // The proxies of the new rules and of the rules they replace are also
  // kept in usedProxies (ownsProxy).
  async useRoute(route) {
    const { usedProxies, route: before } = await this.env.store.get(['usedProxies', 'route']);
    const old = Array.isArray(usedProxies) ? usedProxies : [];
    const added = [...usable(route.proxies), ...usable(before && before.proxies)].map((p) => where(p.host, p.port));
    const used = [...new Set([...added, ...old])].slice(0, USED_MAX);
    const values = { route };
    if (used.length !== old.length || used.some((k, i) => k !== old[i])) values.usedProxies = used;
    await this.env.store.set(values);
    if (route.mode === 'full') await this.env.proxy.full(route.proxies);
    else if (route.mode === 'probe') await this.env.proxy.probe(route.proxies[0]);
    else await this.env.proxy.clear();
  }

  // rank checks each proxy on its own: only the check goes through it, and
  // every other request goes direct, so a proxy that answers 502 or 407
  // cannot hide behind one that works, and no page waits on a dead one.
  // The list goes in this browser's order (arrange). It returns the
  // proxies that passed and those that failed, each in the order checked.
  async rank(id, proxies) {
    const passed = [];
    const failed = [];
    const { ordered, chosenLocation } = await this.env.store.get(['ordered', 'chosenLocation']);
    for (const p of arrange(proxies, { id, ordered: ordered === true, chosen: chosenLocation || '' })) {
      await this.useRoute({ mode: 'probe', proxies: [p] });
      (await this.env.health() ? passed : failed).push(p);
    }
    return { passed, failed };
  }

  // switchTo checks each of candidates and turns on the full rules with
  // the ones that passed first and the others after them. It reports
  // whether any passed; when none did, the last check's rules are left on.
  async switchTo(id, candidates) {
    const { passed, failed } = await this.rank(id, candidates);
    if (!passed.length) return false;
    await this.useRoute({ mode: 'full', proxies: [...passed, ...failed] });
    await this.env.store.set({ status: Status.ON, error: '', misses: 0 });
    return true;
  }

  connect() {
    return this.serial(() => this.connectNow());
  }

  async connectNow() {
    await this.env.store.set({ wanted: true, status: Status.CONNECTING, error: '', lastTryAt: this.now() });
    if (await this.env.proxy.controlledByOther()) return this.lostControl();
    // No proxy carries anything until it has passed its own check, so the
    // calls below go direct, and old proxies that stopped working cannot
    // hold them up.
    await this.useRoute(OFF_ROUTE);
    const id = await this.deviceId();
    await this.register(id);

    let cfg = null;
    let proxies;
    try {
      cfg = await this.fetchConfigs(id);
      proxies = usable(cfg.proxies);
    } catch (e) {
      // The backend out of reach, as where a network filters its name. The
      // proxies of its last answer still take this browser's credentials,
      // since the password is the device id: they are checked, and the
      // backend is asked again through the ones that pass.
      const { proxies: saved } = await this.env.store.get(['proxies']);
      proxies = usable(saved);
      if (!unreachable(e) || !proxies.length) {
        await this.env.store.set({ status: Status.FAILED, error: e instanceof ApiError && e.status === 0 ? 'network' : 'server' });
        return this.snapshot();
      }
    }
    if (!proxies.length) return this.noProxies(cfg.quota);

    if (!(await this.switchTo(id, proxies))) {
      await this.useRoute(OFF_ROUTE);
      await this.env.store.set({ status: Status.FAILED, error: cfg ? 'unreachable' : 'network' });
      return this.snapshot();
    }
    if (!cfg) await this.refreshWhileOn(id);
    return this.snapshot();
  }

  // lostControl clears what is ours once another extension controls the
  // proxy setting: ours would change nothing, and the person must be told.
  async lostControl() {
    await this.useRoute(OFF_ROUTE);
    await this.env.store.set({ wanted: false, status: Status.OTHER, error: 'other_controls' });
    return this.snapshot();
  }

  // noProxies turns everything off when the backend sent no proxy: the
  // allowance is used up, or no server takes browsers.
  async noProxies(quota) {
    await this.useRoute(OFF_ROUTE);
    const noData = outOfData(quota);
    await this.env.store.set({ status: noData ? Status.NO_DATA : Status.FAILED, error: noData ? '' : 'no_servers', lastTryAt: this.now() });
    return this.snapshot();
  }

  disconnect() {
    return this.serial(async () => {
      await this.useRoute(OFF_ROUTE);
      await this.env.store.set({ wanted: false, status: Status.OFF, error: '', misses: 0 });
      return this.snapshot();
    });
  }

  // tick runs on the alarm: it keeps a working connection fresh, turns off
  // one that stopped carrying traffic, and tries again after a failure.
  tick() {
    return this.serial(async () => {
      const s = await this.read();
      if (!s.wanted) return;
      const now = this.now();

      if (s.status === Status.ON) {
        await this.checkOn(s);
        return;
      }

      if (s.status === Status.NO_DATA) {
        // It waits for the reset, unless the quota fetched since says there
        // is data again.
        const reset = s.quota && Date.parse(s.quota.resets_at);
        if (outOfData(s.quota) && reset && reset > now) return;
      } else if (s.status === Status.CONNECTING) {
        if (now - (s.lastTryAt || 0) < STUCK_MS) return;
      } else if (now - (s.lastTryAt || 0) < retryWait(s)) {
        return;
      }
      await this.connectNow();
    });
  }

  // verify checks a working connection at once, out of turn: background.js
  // asks for it when another extension took the proxy setting, or, with
  // refused, when a proxy refused the credentials it was given. After a
  // refusal it asks the backend first (recover), because a used-up
  // allowance is the usual reason and only the backend can say so. A check
  // through the proxy that refused can hang: Chrome does not end a request
  // whose proxy credentials the extension cancelled.
  verify({ refused = false } = {}) {
    return this.serial(async () => {
      const s = await this.read();
      if (!s.wanted || s.status !== Status.ON) return;
      if (!refused) {
        await this.checkOn(s);
        return;
      }
      if (await this.env.proxy.controlledByOther()) {
        await this.lostControl();
        return;
      }
      await this.recover(s);
    });
  }

  // checkOn checks a working connection: that the proxy setting is still
  // ours, then the proxies again when they are due, then the check page
  // through the full rules. Another extension's proxy, or none, would carry
  // the check as well as ours.
  async checkOn(s) {
    if (await this.env.proxy.controlledByOther()) {
      await this.lostControl();
      return;
    }
    if (this.now() - (s.fetchedAt || 0) > (s.refreshAfterS || 3600) * 1000) {
      if (await this.refreshWhileOn(s.deviceId)) return;
    }
    if (await this.env.health()) {
      if (s.misses) await this.env.store.set({ misses: 0 });
      return;
    }
    await this.recover(await this.read());
  }

  // recover runs when a check failed while connected. Before it calls the
  // connection failed, it asks the backend, direct, for the proxies: a
  // used-up allowance looks like a proxy that refuses every request (407),
  // and only the backend can tell the two apart. Then it checks each proxy
  // on its own and switches to the ones that pass. While it does, every
  // other request goes direct, so the popup says "connecting".
  async recover(s) {
    const used = inUse(s.route);
    await this.env.store.set({ status: Status.CONNECTING, lastTryAt: this.now() });
    await this.useRoute(OFF_ROUTE);
    let candidates = used;
    let reached = false;
    try {
      const cfg = await this.fetchConfigs(s.deviceId);
      reached = true;
      candidates = usable(cfg.proxies);
      if (!candidates.length) {
        await this.noProxies(cfg.quota);
        return;
      }
    } catch {
      // Out of reach: the proxies in use are all there is to check.
    }
    if (await this.switchTo(s.deviceId, candidates)) return;
    const misses = (s.misses || 0) + 1;
    if (!reached && misses < MISSES && used.length) {
      // Neither the backend nor a proxy answers, so the network itself may
      // be down for a moment. The rules go back on until the next check:
      // a page fails rather than leaves without Fortiva.
      await this.useRoute({ mode: 'full', proxies: used });
      await this.env.store.set({ status: Status.ON, misses });
      return;
    }
    await this.useRoute(OFF_ROUTE);
    await this.env.store.set({ status: Status.FAILED, error: 'stopped', misses: 0, lastTryAt: this.now() });
  }

  // refreshWhileOn fetches the proxies again, through the proxies in use.
  // It reports true when it turned them off, because the allowance ran out
  // or no server is left.
  async refreshWhileOn(id) {
    let cfg;
    try {
      cfg = await this.fetchConfigs(id);
    } catch {
      return false;
    }
    const fresh = usable(cfg.proxies);
    if (!fresh.length) {
      await this.noProxies(cfg.quota);
      return true;
    }
    const { route } = await this.env.store.get(['route']);
    const used = inUse(route);
    const same = (a, b) => a.host === b.host && a.port === b.port && a.username === b.username && a.password === b.password;
    // The proxies in use that the backend still sends keep their places,
    // so the ones that passed a check stay first. New ones go after them:
    // a browser moves on to them only when the ones before cannot be
    // reached.
    const kept = used.map((u) => fresh.find((f) => same(f, u))).filter(Boolean);
    const { ordered, chosenLocation } = await this.env.store.get(['ordered', 'chosenLocation']);
    const added = arrange(fresh, { id, ordered: ordered === true, chosen: chosenLocation || '' }).filter((f) => !kept.includes(f));
    if (kept.length) {
      await this.useRoute({ mode: 'full', proxies: [...kept, ...added] });
      return false;
    }
    // None of the proxies in use is left: the new ones are checked first.
    await this.env.store.set({ status: Status.CONNECTING, lastTryAt: this.now() });
    if (!(await this.switchTo(id, fresh))) {
      await this.useRoute({ mode: 'full', proxies: used.length ? used : fresh });
      await this.env.store.set({ status: Status.ON });
    }
    return false;
  }

  // fetchConfigs asks the backend for this browser's proxies and quota,
  // through whatever rules are in effect, and keeps the answer.
  async fetchConfigs(id) {
    let cfg;
    try {
      cfg = await this.env.api.browserConfigs(id);
    } catch (e) {
      // An unknown device: the registration was lost or never made. Make
      // it now and ask once more.
      if (!(e instanceof ApiError) || e.status !== 404) throw e;
      await this.env.store.set({ registeredVersion: '' });
      await this.register(id);
      cfg = await this.env.api.browserConfigs(id);
    }
    await this.env.store.set({
      proxies: cfg.proxies.filter(validProxy),
      quota: cfg.quota,
      fetchedAt: this.now(),
      refreshAfterS: Number.isFinite(cfg.refresh_after_s) && cfg.refresh_after_s >= 60 ? cfg.refresh_after_s : 3600,
      ordered: cfg.ordered === true,
    });
    return cfg;
  }

  // The quota for the popup, fresh from the backend when it can be had.
  refreshQuota() {
    return this.serial(async () => {
      const s = await this.read();
      if (!s.deviceId || s.status === Status.CONNECTING) return this.snapshot();
      try {
        if (s.status === Status.ON) await this.refreshWhileOn(s.deviceId);
        else await this.fetchConfigs(s.deviceId);
      } catch {
        // The popup shows what it had.
      }
      await this.resumeIfData();
      return this.snapshot();
    });
  }

  // resumeIfData connects again, after the work at hand, when the quota
  // just fetched brought data back to a browser that was out of it and is
  // still wanted on: a code was redeemed, or the allowance was reset. The
  // status says "connecting" at once, so the popup shows it.
  async resumeIfData() {
    const s = await this.read();
    if (!s.wanted || s.status !== Status.NO_DATA || outOfData(s.quota)) return;
    await this.env.store.set({ status: Status.CONNECTING, error: '', lastTryAt: this.now() });
    this.serial(() => this.connectNow());
  }

  // register tells the backend about this browser, once per version. The
  // browser, the system and the language go only with the person's leave
  // where the browser asks for it (info.shareTechnical).
  async register(id) {
    const { registeredVersion } = await this.env.store.get(['registeredVersion']);
    if (registeredVersion === this.env.info.version) return;
    const share = this.env.info.shareTechnical ? await this.env.info.shareTechnical() : true;
    try {
      await this.env.api.register({
        device_id: id,
        ...(share && {
          device_model: this.env.info.model,
          os_version: this.env.info.os,
          language: this.env.info.language(),
        }),
      });
      await this.env.store.set({ registeredVersion: this.env.info.version });
    } catch {
      // configs/browser registers nothing; it will say so, and the next
      // connect registers again.
    }
  }

  // The credentials for a proxy that asked for them (Chrome's
  // onAuthRequired), or null for a proxy that is not ours.
  async credentialsFor(host, port) {
    const { proxies, route } = await this.env.store.get(['proxies', 'route']);
    const p = [...usable(route && route.proxies), ...usable(proxies)].find((x) => x.host === host && x.port === port);
    return p ? { username: p.username, password: p.password } : null;
  }

  // ownsProxy says whether host:port is a proxy of this extension: in the
  // rules now, in the backend's last answer, or used before. A request sent
  // through a proxy just before the rules changed can be refused by it after
  // they did, as when the allowance runs out with pages loading. That
  // refusal must not reach the person as a password dialog either.
  async ownsProxy(host, port) {
    if (await this.credentialsFor(host, port)) return true;
    const { usedProxies } = await this.env.store.get(['usedProxies']);
    return Array.isArray(usedProxies) && usedProxies.includes(where(host, port));
  }

  // redeem applies a Premium key or a gift code to this browser. It
  // returns {ok, kind, moved} or {ok: false, reason, status}.
  redeem(code) {
    return this.serial(async () => {
      const id = await this.deviceId();
      await this.register(id);
      let res;
      try {
        res = await this.env.api.redeem(id, String(code).trim());
      } catch (e) {
        return { ok: false, reason: e.reason || (e.status === 0 ? 'network' : ''), status: e.status || 0 };
      }
      const s = await this.read();
      try {
        if (s.status === Status.ON) await this.refreshWhileOn(id);
        else await this.fetchConfigs(id);
      } catch {
        // The quota updates on the next check.
      }
      await this.resumeIfData();
      return { ok: true, kind: res && res.kind || 'premium', moved: !!(res && res.moved) };
    });
  }

  async setLanguage(code) {
    await this.env.store.set({ language: code || '' });
  }

  // setLocation keeps the location the person chose ('' for automatic) and,
  // while the browser is on or trying, connects again with it first.
  setLocation(label) {
    return this.serial(async () => {
      await this.env.store.set({ chosenLocation: typeof label === 'string' ? label : '' });
      const s = await this.read();
      if (s.wanted && s.status !== Status.NO_DATA && s.status !== Status.OTHER) await this.connectNow();
      return this.snapshot();
    });
  }
}
