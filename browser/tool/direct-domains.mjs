// Writes browser/src/direct-domains.js from the JSON windows/core/cmd/geotrim
// writes with -domains. See that file for the commands.
//
//   node browser/tool/direct-domains.mjs FILE.json

import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const target = join(dirname(fileURLToPath(import.meta.url)), '..', 'src', 'direct-domains.js');
const list = JSON.parse(readFileSync(process.argv[2], 'utf8'));
if (list.code !== 'CATEGORY-IR' || !Array.isArray(list.suffix) || list.suffix.length < 50) {
  throw new Error(`${process.argv[2]} is not geotrim's CATEGORY-IR list`);
}
const old = readFileSync(target, 'utf8');
const head = old.slice(0, old.indexOf('export const DIRECT_SUFFIXES'));
writeFileSync(target, head + 'export const DIRECT_SUFFIXES = ' + JSON.stringify(list.suffix, null, 1) + ';\n');
console.log(`direct-domains: ${list.suffix.length} names`);
