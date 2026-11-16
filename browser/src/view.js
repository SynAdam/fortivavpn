// What the popup shows, worked out from the background's snapshot, apart
// from any page, so it is tested in Node: the shield's face, the names of
// the locations, and the code field's rules.

// The shield's face, as the app's power button draws it
// (lib/widgets/power_face.dart): dark eyes while off, a steel light that
// sweeps from eye to eye while connecting, green once a proxy carried the
// check, amber while it failed and tries again by itself, red when another
// extension holds the proxy setting, and the shield greyed while the
// allowance is used up.
export function faceOf(snap) {
  if (!snap) return 'off';
  if (snap.status === 'on') return 'on';
  if (snap.status === 'connecting') return 'connecting';
  if (snap.status === 'other_controls') return 'failed';
  if (snap.wanted && snap.status === 'out_of_data') return 'spent';
  if (snap.wanted && snap.status === 'failed') return 'waiting';
  return 'off';
}

// What a click on the button does: connect while it is off, and otherwise
// turn it off. A click while connecting stops the connect, as a tap does in
// the app; so does a click while the extension waits to try again.
export function clickConnects(snap) {
  const face = faceOf(snap);
  return face === 'off' || face === 'failed';
}

// The first code point of the regional indicator symbols, the letter A.
const REGIONAL_A = 0x1f1e6;
const isRegional = (cp) => cp >= REGIONAL_A && cp <= REGIONAL_A + 25;

// labelParts splits a proxy's label into its country and its place, as the
// app reads the label of its own links (VlessLink.parts in
// lib/utils/vless_link.dart). The backend writes "Fortiva {flag} {city}"
// (link_names.own_label), where the flag is a regional indicator pair or a
// bare upper-case code. A label with no country gives the rest as the
// place.
export function labelParts(label) {
  let rest = String(label || '').trim();
  if (rest.slice(0, 7).toLowerCase() === 'fortiva') rest = rest.slice(7).trimStart();
  const cps = [...rest].map((c) => c.codePointAt(0));
  if (cps.length >= 2 && isRegional(cps[0]) && isRegional(cps[1])) {
    const region = String.fromCharCode(cps[0] - REGIONAL_A + 65, cps[1] - REGIONAL_A + 65);
    return { region, place: [...rest].slice(2).join('').trimStart() };
  }
  // Upper case only, so a place that starts with a two-letter word ("Ho Chi
  // Minh City") is not read as a country.
  const bare = /^([A-Z]{2})(\s|$)/.exec(rest);
  if (bare) return { region: bare[1], place: rest.slice(2).trimStart() };
  return { region: '', place: rest };
}

// countryName is the country of a two-letter code in lang, from the
// browser's own CLDR tables, as the app's are (lib/utils/countries.dart).
// The code itself when the browser has no name for it.
export function countryName(region, lang) {
  if (!region) return '';
  try {
    return new Intl.DisplayNames([lang, 'en'], { type: 'region', fallback: 'code' }).of(region) || region;
  } catch {
    return region;
  }
}

// placeName is how a location reads in the popup: the city and the country
// in the person's language ("Helsinki, Finland"), as the app's server card
// writes it.
export function placeName(label, lang) {
  const { region, place } = labelParts(label);
  const country = countryName(region, lang);
  if (place && country) return `${place}, ${country}`;
  return place || country || String(label || '');
}

// flagOf is the flag emoji of a two-letter country code, or ''.
export function flagOf(region) {
  if (!/^[A-Z]{2}$/.test(region || '')) return '';
  return String.fromCodePoint(...[...region].map((c) => REGIONAL_A + c.charCodeAt(0) - 65));
}

// The code field takes what the app's does (lib/widgets/redeem_code_dialog.dart):
// letters, digits, dashes and spaces, up to 32 of them, in capitals, with
// Persian and Arabic digits made Latin. A key may be typed in groups or
// pasted as shown; the backend reads the rest.
export const LONGEST_CODE = 32;
const SHORTEST_CODE = 4;

export function cleanCode(text) {
  return String(text || '')
    .replace(/[۰-۹]/g, (d) => String(d.charCodeAt(0) - 0x6f0))
    .replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x660))
    .toUpperCase()
    .replace(/[^A-Z0-9\- ]/g, '')
    .slice(0, LONGEST_CODE);
}

// codeReady says whether a code has enough letters and digits to send.
export function codeReady(code) {
  return String(code || '').replace(/[^0-9A-Z]/gi, '').length >= SHORTEST_CODE;
}

// The share of the allowance left, from 0 to 100, for the bar.
export function leftShare(quota) {
  if (!quota || quota.unlimited || !(quota.limit_bytes > 0)) return 0;
  const left = Math.max(0, quota.remaining_bytes || 0);
  return Math.min(100, (left / quota.limit_bytes) * 100);
}
