// Which requests go through Fortiva, and through which proxies.
//
// Chrome takes the rules as a PAC script, a piece of JavaScript it runs on
// its own for every request; Firefox asks the extension for every request
// (proxy.onRequest). Both run goesDirect below, so the two browsers send
// the same sites direct. A PAC script cannot import anything, so goesDirect
// is written into it as source, with the list of names.

import { DIRECT_SUFFIXES } from './direct-domains.js';

// goesDirect says whether a request to host skips Fortiva: names on the
// local network, addresses that are private or the computer's own, every
// name under .ir and the Iranian sites in suffixes. Addresses are read only
// when host is one: nothing here looks a name up, which would leak it to
// the local resolver and slow every request.
export function goesDirect(host, suffixes) {
  host = String(host || '').toLowerCase().replace(/\.$/, '');
  if (host === '' || host.indexOf('.') < 0 && host.indexOf(':') < 0) return true;
  if (host === 'localhost' || /\.(localhost|local|lan|home\.arpa|internal)$/.test(host)) return true;
  if (host === 'ir' || /\.ir$/.test(host)) return true;
  var v4 = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/.exec(host);
  if (v4) {
    var a = +v4[1], b = +v4[2];
    return a === 10 || a === 127 || a === 0 || a >= 224 ||
      (a === 172 && b >= 16 && b <= 31) || (a === 192 && b === 168) ||
      (a === 169 && b === 254) || (a === 100 && b >= 64 && b <= 127);
  }
  if (host.indexOf(':') >= 0) {
    var v6 = host.replace(/^\[|\]$/g, '');
    return v6 === '::1' || v6 === '::' || /^f[cd]/.test(v6) || /^fe[89ab]/.test(v6);
  }
  for (var i = 0; i < suffixes.length; i++) {
    var s = suffixes[i];
    if (host === s || host.length > s.length && host.slice(-s.length - 1) === '.' + s) return true;
  }
  return false;
}

// A proxy as the backend hands it out (POST /api/v1/configs/browser).
// Only a name and a port reach a proxy string: anything else is refused, so
// an odd answer cannot write code into the PAC script.
export function validProxy(p) {
  return p && typeof p.host === 'string' && /^[a-z0-9.-]{1,253}$/i.test(p.host) &&
    Number.isInteger(p.port) && p.port > 0 && p.port < 65536 &&
    typeof p.username === 'string' && typeof p.password === 'string';
}

// The host of the page the extension loads to check a proxy
// (background.js). It is not on the direct list.
export const PROBE_HOST = 'www.gstatic.com';

// pacScript is Chrome's rules for proxies, tried in the order given. There
// is no DIRECT at the end: when every proxy fails a page fails, rather
// than leaving through the network without the person knowing. The
// extension checks the proxies itself and turns them off when none works.
export function pacScript(proxies) {
  const list = proxies.filter(validProxy).map((p) => `HTTPS ${p.host}:${p.port}`).join('; ');
  if (!list) throw new Error('no usable proxy');
  return [
    `var SUFFIXES = ${JSON.stringify(DIRECT_SUFFIXES)};`,
    `var goesDirect = ${goesDirect.toString()};`,
    'function FindProxyForURL(url, host) {',
    '  if (goesDirect(host, SUFFIXES)) return "DIRECT";',
    `  return ${JSON.stringify(list)};`,
    '}',
  ].join('\n');
}

// probePacScript is Chrome's rules while one proxy is checked on its own:
// the check's host goes through that proxy and nothing else, so an answer
// can only have come through it, and every other request goes direct.
export function probePacScript(proxy) {
  if (!validProxy(proxy)) throw new Error('no usable proxy');
  return [
    'function FindProxyForURL(url, host) {',
    `  if (host === ${JSON.stringify(PROBE_HOST)}) return ${JSON.stringify(`HTTPS ${proxy.host}:${proxy.port}`)};`,
    '  return "DIRECT";',
    '}',
  ].join('\n');
}

// firefoxProxies is Firefox's answer for one request: direct, or the
// proxies in order, each carrying its credentials. Firefox sends them with
// the first request, so no request is ever refused for want of them.
export function firefoxProxies(host, proxies) {
  if (goesDirect(host, DIRECT_SUFFIXES)) return { type: 'direct' };
  const list = proxies.filter(validProxy).map((p) => ({
    type: 'https',
    host: p.host,
    port: p.port,
    proxyAuthorizationHeader: 'Basic ' + btoa(`${p.username}:${p.password}`),
    // Seconds before Firefox moves on to the next proxy in the list.
    failoverTimeout: 5,
  }));
  return list.length ? list : { type: 'direct' };
}

// firefoxAnswer is Firefox's answer for one request to host under route,
// the rules core.js put in storage: everything direct ("off"), only the
// check through one proxy ("probe"), or the full rules ("full").
export function firefoxAnswer(host, route) {
  const proxies = route && Array.isArray(route.proxies) ? route.proxies : [];
  if (route && route.mode === 'full') return firefoxProxies(host, proxies);
  if (route && route.mode === 'probe' && String(host).toLowerCase() === PROBE_HOST) {
    return firefoxProxies(host, proxies.slice(0, 1));
  }
  return { type: 'direct' };
}
