# Fortiva for browsers

A browser extension for Chrome, Edge, Brave, Opera and Firefox. One button
connects the browser through Fortiva; the popup shows the allowance, takes a
Premium code and offers the app's 18 languages. Only the browser's own
traffic goes through Fortiva. The Windows app covers every app on a PC.

## How it connects

A browser can send its traffic only to a proxy (HTTP, HTTPS or SOCKS). It
cannot run Xray or speak VLESS. So:

1. The extension registers as platform `browser` and asks
   `POST /api/v1/configs/browser` for its proxies. The backend answers with
   one HTTPS proxy per server (`host`, `port`, `label`) and this browser's
   credentials, and the allowance in the same shape `/configs/dedicated`
   sends it.
2. Each server runs a small HTTPS proxy (`edge/webproxy` in the backend
   repository). For each request it opens a VLESS connection to the
   server's own Xray, on an inbound that listens only on the server itself,
   as this browser's own client. The password is that client's id. So the
   allowance, Premium and the daily reset work for a browser exactly as for
   a phone, through the same counters.
3. Before a proxy carries a page, the extension checks it on its own: only
   the check (a page on `www.gstatic.com`) goes through that one proxy, and
   every other request goes direct. It checks each proxy this way, puts the
   ones that passed first and the others after them, and only then turns
   on the full rules and says Connected. Each browser starts the backend's
   list at its own place, taken from its device id, so browsers do not all
   start on the same server. The calls to the backend while it connects go
   direct, never through proxies it used before.
4. While connected, it checks again every two minutes through the full
   rules. When a check fails, or at once when a proxy refuses the
   credentials it was given, it first asks the backend for the proxies,
   direct. After a refusal it does not check through that proxy first:
   in Chrome, a request whose proxy credentials the extension cancelled
   does not end, so the check would wait for its own timeout.
   The edge proxy refuses credentials with a 403, not a 407, since its
   version 3: for a page load, Chrome answers a 407 with its own box asking
   the person for a password, even when the extension cancels the request
   (Chrome 157, tested on 2026-11-12). A 403 fails the request with no auth
   event, so a tunnel through a proxy of ours that fails while connected
   checks the connection at once, at most once in 30 seconds
   (`webRequest.onErrorOccurred`: `net::ERR_TUNNEL_CONNECTION_FAILED` in
   Chrome, `NS_ERROR_PROXY_*` with that proxy in Firefox). The check goes
   through the full rules first, so a site that is down changes nothing. A used-up allowance makes every proxy refuse
   the browser with a 407, and only the backend can tell that apart from a
   broken server, so the popup says the data is used up at once. Then it
   checks each proxy on its own and switches to the ones that pass. The
   popup says Connecting meanwhile.
5. When no proxy passes, it turns the proxies off: at once when the
   backend answered, and after a second failed check when the backend was
   out of reach too. While the proxies are off, the browser uses its normal
   network. The popup says Not connected and why, with an amber ring round
   the button. The extension tries again five minutes later, with each
   proxy on its own first, until the button stops the tries. When the
   backend answered with no proxy because no server takes browsers yet, it
   waits as long as the answer's `refresh_after_s` says (an hour), and never
   less than five minutes. Out of data, it waits for the reset. When a Premium code or a quota fetched since
   brings data back, it connects again at once.

When the backend cannot be reached on a connect (no answer, or a 5xx from
something in front of it) and an earlier answer's proxies are saved, the
extension checks those on its own, connects through the ones that pass,
and asks the backend again through them. They still take this browser's
credentials, because the password is the device's stable id. A browser
that has never had an answer still needs the backend direct; the
extension has no relays.

The rules in effect are kept in storage as the "route" (`src/core.js`):
off, only the check through one proxy, or the full rules. Firefox answers
every request from it, so a background that the browser stopped and
started again takes up the same rules.

The extension makes three calls: `devices/register`, `configs/browser` and
`devices/{id}/billing/redeem`. It sends no events to `devices/{id}/events`,
because the backend's alerts and dashboards read those rows as a phone's.
Browsers will get their own reporting later.

Iranian sites, every name under `.ir`, and local and private addresses go
direct, as the app sends them direct: they work without Fortiva and should
not use the allowance. The list is `src/direct-domains.js`, made from the
same routing data the app ships.

## Chrome and Firefox

The code is the same. Only the manifest and the proxy calls differ
(`build.mjs`, `src/background.js`):

| | Chrome, Edge, Brave, Opera | Firefox |
|---|---|---|
| Background | service worker | background script |
| Proxies | a PAC script (`pacScript` in `src/pac.js`, `probePacScript` while one proxy is checked) | `proxy.onRequest`, answered per request from the route (`firefoxAnswer`) |
| Credentials | given when the proxy asks (`webRequest.onAuthRequired`, needs `webRequestAuthProvider`) | sent with each request; when a proxy asks anyway, it has refused them, and the request is cancelled (`webRequest.onAuthRequired`) so that Firefox does not ask the person for a password |

In both browsers, a proxy the extension used before (`usedProxies`, the
last 64) that asks for credentials after the rules no longer hold it gets
a cancel too (`ownsProxy` in `src/core.js`). That happens when the
allowance runs out while pages are loading: requests sent through the
proxy before it was turned off are refused after. Left alone, the browser
would ask the person for the proxy's password.
| Least version | Chrome 116 | Firefox 140, Firefox for Android 142 (the first to ask about data collection; "What the extension sends" says why) |

Both decide "direct or Fortiva" with the same function, `goesDirect`. The
PAC script has no direct fallback: when every proxy fails, a page fails
rather than leaving without Fortiva, until the next check turns the proxies
off and says so. Neither browser moves on to the next proxy when one
answers with an error (a 502 when its server's Xray is down, or a 407);
they move on only when a proxy cannot be reached. That is why each proxy
is checked on its own.

Only one extension can set Chrome's proxy. When another one has, the popup
says so instead of connecting. When another one takes it while Fortiva is
connected, the extension finds out at once (`proxy.settings.onChange`) or
at the next check, clears its own setting, turns itself off and says so.

A proxy carries no UDP, and WebRTC can use UDP to ask a STUN server for
the person's own address. So while the full rules are on, the extension
sets WebRTC's IP handling policy to `disable_non_proxied_udp` (the
`privacy` permission), and it clears the setting whenever it clears the
proxies.

Neither browser runs an extension in private windows until the person
allows it in the browser's extension settings. Until then, private windows
go direct. The popup says so whenever `extension.isAllowedIncognitoAccess()`
answers false.

## What the extension sends

To Fortiva's backend:

- A device id that the extension makes at random the first time. It is
  this browser's account with Fortiva and its password on the proxies. It
  says nothing about the person or the computer.
- The extension's own version, with every call.
- When it registers: the browser and its major version (for example
  `Chrome 131`), the system (`Windows`, `macOS` and so on) and the
  language. Firefox sends these only with the person's leave (below).
- A Premium key or gift code, when the person types one.

Through Fortiva's proxies: every request of the browser that does not go
direct. The proxies carry the requests and do not store them.

Firefox shows a list of what an extension collects at install
(`browser_specific_settings.gecko.data_collection_permissions` in
`build.mjs`). This one declares `browsingActivity`, `websiteContent` and
`locationInfo` as required, and `technicalAndInteraction` as optional: the
browser, its version, the system and the language at registration, which
Firefox sends only with the person's leave (`shareTechnical` in
`src/background.js`).

The extension needs Firefox 140 or later, or Firefox for Android 142 or
later. Mozilla's add-on policies make an extension that installs on an
older Firefox, which has no such list, show a consent page of its own,
and this extension has none.

## Languages

The popup speaks the app's 18 languages. It follows the person's choice in
the popup, then the browser's language, then English. Most strings are the
app's own, read from `lib/l10n/app_<lang>.arb` at build time
(`tool/strings.mjs`, the `FROM_APP` list), so the extension says what the app
says. The few that only the extension needs are in `messages/<lang>.json`,
one file per language. The build refuses a language that lacks a string or
whose placeholders differ from English. As in the app, no string holds a
number the backend owns; amounts arrive through placeholders.

The store listing (the manifest's name and description) is English only.

## Files

```
browser/
  build.mjs              dist/chrome, dist/firefox and a zip of each
  src/manifest.json      what both manifests share
  src/background.js      the browser's side: storage, proxies, credentials, alarms, popup messages
  src/core.js            what the extension does, apart from any browser (tested in Node)
  src/api.js             the backend calls
  src/pac.js             which requests go where
  src/direct-domains.js  the Iranian sites that go direct
  src/i18n.js            languages, digits and amounts
  src/popup.*            the popup
  messages/<lang>.json   the extension's own strings
  icons/                 toolbar icons, drawn by tool/icons.py from the app icon
  tool/                  strings.mjs, icons.py, direct-domains.mjs
  test/                  unit tests (node --test; firefox.test.mjs runs background.js
                         with a fake Firefox), test/e2e/chrome.mjs and
                         test/e2e/firefox.mjs
```

## Building and trying it

```bash
node browser/build.mjs          # browser/dist/
```

Chrome: open `chrome://extensions`, turn on Developer mode, Load unpacked,
pick `browser/dist/chrome`. Firefox: open `about:debugging`, This Firefox,
Load Temporary Add-on, pick `browser/dist/firefox/manifest.json`.

To try it against a backend on this computer, run this in the extension's
service worker console (Chrome) or background console (Firefox):

```js
chrome.storage.local.set({ apiBase: 'http://127.0.0.1:8080' })
```

Only `http://127.0.0.1:<port>` and `http://localhost:<port>` are accepted.

## Tests

```bash
cd browser && npm test          # unit tests, no dependencies
node browser/build.mjs && node browser/test/e2e/chrome.mjs
FIREFOX=... GECKODRIVER=... SELENIUM=... node browser/test/e2e/firefox.mjs
npx addons-linter browser/dist/firefox   # Mozilla's checks for the Firefox build
```

The second one runs the built extension in Chromium with Playwright,
against two test HTTPS proxies and a fake backend. The backend sends first
a proxy that answers 502 to everything, then one that asks for credentials
and works. The test presses the popup's button while the backend is slow,
and checks that the popup keeps saying Connecting. It checks that a page
loaded while one proxy is checked goes direct, that the working proxy
carries the pages and got its credentials, and that WebRTC is kept to the
proxies while on and let go when off. Then it checks the amber button
after every proxy failed, a used-up allowance found as soon as the proxy
refuses, the note on private windows, that no events are sent, and the
popup in Persian. It needs Playwright and its Chromium (`npx playwright install
chromium`); `PLAYWRIGHT` and `CHROMIUM` point it at copies installed
elsewhere, and `SCREENSHOTS=<dir>` keeps pictures of the popup.

The third one runs the built Firefox extension in a real Firefox, driven
by selenium-webdriver and geckodriver, and checks the same path against
the same proxies and backend. Firefox sends the credentials with each
request, so there the test checks that the proxy never had to ask. The
backend also sends a proxy that cannot be reached, which must fail its
check: Firefox does not go direct for the check when its proxy is out of
reach. The test also checks that a background Firefox stopped takes up
the stored rules, and that a proxy refusing the credentials brings up no
password dialog, also for a page in another tab whose request the proxy
refuses only after the proxies were turned off. Without `ownsProxy`,
Firefox shows the dialog there. The same case in Chrome is checked only
by `test/chrome.test.mjs`: Chrome gives up on a proxy connection held that
long by itself.
`FIREFOX`, `GECKODRIVER` and `SELENIUM` name the Firefox program,
geckodriver and selenium-webdriver's `index.js`. The file's header says
where to get each, and none of them has to be installed for the whole
system. It has passed on Firefox 140.0, the least version, and on 160.0.

## Publishing

Nothing is published yet. Each store needs its own account and its own
review: the Chrome Web Store (also serves Brave and Opera), Microsoft Edge
Add-ons and Firefox Add-ons. Upload `fortiva-browser-<version>-chrome.zip`
to the first two and `-firefox.zip` to the third. The Firefox data
collection list above must be confirmed first. Firefox signs the
extension during review; until then it loads only as a temporary add-on.

The servers must run the proxy and have `web_proxy_host` and
`web_proxy_port` set before the backend offers any to a browser.
