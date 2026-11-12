import assert from 'node:assert/strict';
import { test } from 'node:test';
import vm from 'node:vm';

import { PROBE_HOST, firefoxAnswer, firefoxProxies, goesDirect, pacScript, probePacScript } from '../src/pac.js';
import { DIRECT_SUFFIXES } from '../src/direct-domains.js';

const proxies = [
  { host: 'a.example.com', port: 8443, username: 'fortiva', password: '11111111-2222-3333-4444-555555555555', label: 'One' },
  { host: 'b.example.com', port: 443, username: 'fortiva', password: '11111111-2222-3333-4444-555555555555', label: 'Two' },
];

// Runs the PAC script the way a browser does: a sandbox with nothing but
// the script, then FindProxyForURL.
function findProxy(script, host) {
  const box = {};
  vm.createContext(box);
  vm.runInContext(script, box);
  return box.FindProxyForURL(`https://${host}/`, host);
}

test('Iranian, private and local names go direct; the rest through Fortiva', () => {
  const script = pacScript(proxies);
  const through = 'HTTPS a.example.com:8443; HTTPS b.example.com:443';
  for (const host of [
    'digikala.ir', 'www.shaparak.ir', 'IR', 'aparat.com', 'www.aparat.com',
    'localhost', 'printer', 'nas.local', 'router.lan',
    '192.168.1.1', '10.0.0.8', '172.20.1.1', '172.31.255.255', '127.0.0.1', '169.254.1.1', '100.64.0.1',
    '::1', '[fd00::1]', 'fe80::1',
  ]) {
    assert.equal(findProxy(script, host), 'DIRECT', host);
  }
  for (const host of ['www.google.com', 'youtube.com', 'notaparat.com', 'aparat.com.evil.net', '198.51.100.7', '203.0.113.9', '2001:db8::1']) {
    assert.equal(findProxy(script, host), through, host);
  }
});

test('the list holds the Iranian sites the app sends direct', () => {
  assert.ok(DIRECT_SUFFIXES.length > 100);
  assert.ok(DIRECT_SUFFIXES.includes('aparat.com'));
  assert.ok(DIRECT_SUFFIXES.every((s) => /^[a-z0-9.-]+$/.test(s)));
});

test('a proxy that is not a plain name and port never reaches the script', () => {
  const evil = [{ host: 'x"; return "DIRECT"; //', port: 1, username: 'a', password: 'b' }];
  assert.throws(() => pacScript(evil), /no usable proxy/);
  const mixed = pacScript([...evil, proxies[0]]);
  assert.ok(!mixed.includes('return "DIRECT"; //'));
  assert.equal(findProxy(mixed, 'example.org'), 'HTTPS a.example.com:8443');
});

test('Firefox gets the proxies in order, each with its credentials', () => {
  const got = firefoxProxies('example.org', proxies);
  assert.equal(got.length, 2);
  assert.equal(got[0].type, 'https');
  assert.equal(got[0].host, 'a.example.com');
  assert.equal(got[0].proxyAuthorizationHeader, 'Basic ' + btoa('fortiva:11111111-2222-3333-4444-555555555555'));
  assert.deepEqual(firefoxProxies('digikala.ir', proxies), { type: 'direct' });
  assert.deepEqual(firefoxProxies('example.org', []), { type: 'direct' });
});

test('goesDirect reads only what it is given', () => {
  assert.equal(goesDirect('example.org', ['example.org']), true);
  assert.equal(goesDirect('sub.example.org', ['example.org']), true);
  assert.equal(goesDirect('badexample.org', ['example.org']), false);
  assert.equal(goesDirect('example.org.', []), false);
});

test('while a proxy is checked, only the check goes through it', () => {
  const script = probePacScript(proxies[1]);
  assert.equal(findProxy(script, PROBE_HOST), 'HTTPS b.example.com:443');
  for (const host of ['www.google.com', 'example.org', 'gstatic.com', 'digikala.ir', '198.51.100.7']) {
    assert.equal(findProxy(script, host), 'DIRECT', host);
  }
  assert.throws(() => probePacScript({ host: 'x"; //', port: 1, username: 'a', password: 'b' }), /no usable proxy/);
});

test('Firefox follows the rules in effect: off, the check alone, or the full rules', () => {
  const probe = { mode: 'probe', proxies: [proxies[1]] };
  const got = firefoxAnswer(PROBE_HOST, probe);
  assert.equal(got.length, 1);
  assert.equal(got[0].host, 'b.example.com');
  assert.deepEqual(firefoxAnswer('example.org', probe), { type: 'direct' });
  assert.deepEqual(firefoxAnswer('example.org', { mode: 'off' }), { type: 'direct' });
  assert.deepEqual(firefoxAnswer(PROBE_HOST, { mode: 'off' }), { type: 'direct' });
  assert.deepEqual(firefoxAnswer('example.org', null), { type: 'direct' });
  assert.deepEqual(firefoxAnswer('example.org', { mode: 'full', proxies }), firefoxProxies('example.org', proxies));
  assert.deepEqual(firefoxAnswer('digikala.ir', { mode: 'full', proxies }), { type: 'direct' });
});
