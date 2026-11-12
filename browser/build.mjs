// Builds the extension for each browser family into browser/dist/:
//
//   dist/chrome/    Chrome, Edge, Brave, Opera (load it unpacked to try it)
//   dist/firefox/   Firefox
//   fortiva-browser-<version>-chrome.zip and -firefox.zip, for the stores
//
//   node browser/build.mjs
//
// The two differ only in their manifest: Chrome runs the background as a
// service worker, Firefox as a background script (src/background.js).
// Both ask for webRequestAuthProvider in src/manifest.json, for a proxy's
// request for credentials. Chrome answers it. Firefox has sent the
// credentials with the request already, so the extension cancels the
// request, rather than let Firefox ask the person for a password.

import { execFileSync } from 'node:child_process';
import { cpSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..');
const dist = join(here, 'dist');

execFileSync(process.execPath, [join(here, 'tool', 'strings.mjs')], { stdio: 'inherit' });

// The app's version, without its build number. Browsers want one to four
// numbers with dots.
const pubspec = readFileSync(join(root, 'pubspec.yaml'), 'utf8');
const version = /^version:\s*([0-9]+\.[0-9]+\.[0-9]+)/m.exec(pubspec)?.[1];
if (!version) throw new Error('no version in pubspec.yaml');

const base = JSON.parse(readFileSync(join(here, 'src', 'manifest.json'), 'utf8'));

export const manifests = {
  chrome: {
    ...base,
    version,
    background: { service_worker: 'background.js', type: 'module' },
  },
  firefox: (() => {
    const m = {
      ...base,
      version,
      background: { scripts: ['background.js'], type: 'module' },
      browser_specific_settings: {
        gecko: {
          id: 'browser@fortivavpn.com',
          // Firefox asks the person about data collection, from this
          // manifest, from version 140 on. Mozilla's add-on policies make
          // an extension that installs on an older Firefox show a consent
          // page of its own, which this one does not have.
          strict_min_version: '140.0',
          // What Firefox shows the person at install, and asks leave for.
          // README.md, "What the extension sends", says why these.
          data_collection_permissions: {
            required: ['browsingActivity', 'websiteContent', 'locationInfo'],
            optional: ['technicalAndInteraction'],
          },
        },
        // Firefox for Android asks from version 142 on, for the same
        // reason.
        gecko_android: { strict_min_version: '142.0' },
      },
    };
    delete m.minimum_chrome_version;
    return m;
  })(),
};

rmSync(dist, { recursive: true, force: true });
for (const [name, manifest] of Object.entries(manifests)) {
  const out = join(dist, name);
  mkdirSync(join(out, 'icons'), { recursive: true });
  for (const file of readdirSync(join(here, 'src'))) {
    if (file === 'manifest.json') continue;
    cpSync(join(here, 'src', file), join(out, file));
  }
  cpSync(join(here, 'icons'), join(out, 'icons'), { recursive: true });
  cpSync(join(root, 'LICENSE'), join(out, 'LICENSE'));
  writeFileSync(join(out, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
  const zip = join(dist, `fortiva-browser-${version}-${name}.zip`);
  execFileSync('zip', ['-q', '-r', '-X', zip, '.'], { cwd: out });
  console.log(`built ${name}: ${zip}`);
}
