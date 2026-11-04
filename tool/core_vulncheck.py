#!/usr/bin/env python3
"""Decide whether the cores may ship, from govulncheck's results.

    python3 -I tool/core_vulncheck.py <scan-dir> android/core/vulncheck-accept.txt

tool/core_vulncheck.sh runs android/core/build-in-linux.sh --vulncheck, which
writes <scan-dir>, then runs this. The folder holds:

- for each ABI the Android core ships, source-<abi>.json (govulncheck in
  source mode) and binary-<abi>.json (govulncheck -mode=binary on that ABI's
  libgojni.so);
- for the Windows tunnel (windows/core), source-windows-amd64.json and
  source-windows-arm64.json;
- replaced.txt, which lists the modules a go.mod replaces with a folder, and
  for each one query-<n>.json (govulncheck -mode=query at the version go.mod
  requires);
- facts.txt, and the result of android/core/x509distrust/, which fails while
  the cores' Go trusts the eight eMudhra intermediates. A failed test blocks.

A source-mode finding blocks when its trace reaches a function, which means
the core's code can call the vulnerable code. A finding in a module or
package the core links but never calls does not block.

govulncheck cannot see into a module that go.mod replaces with a folder
(Xray-core and Psiphon's quic-go fork, which the core patches): it looks the
module up under the folder's path and has no version for it. So every
advisory query mode lists for such a module blocks, called or not.

The binary scans are only printed: the core is linked with -s, which removes
the symbol table, so govulncheck can only match modules and versions there.

The accept file lets a release ship while a finding has no fix yet. Each line
is

    GO-YYYY-NNNN until YYYY-MM-DD: why it may ship meanwhile

and lasts until the end of that day, at most 31 days from today. Lines that
start with # and empty lines are ignored.

Exit status: 0 when nothing blocks, 1 when a finding blocks, a scan file is
missing or unreadable, or the accept file is wrong. Standard library only.
"""

from __future__ import annotations

import datetime as dt
import json
import re
import sys
import textwrap
from pathlib import Path

ABIS = ("arm64-v8a", "armeabi-v7a", "x86_64", "x86")
# The builds of windows/core/build.sh. Only their source is scanned, because
# no Windows build is committed.
WINDOWS = ("windows-amd64", "windows-arm64")
SOURCES = ABIS + WINDOWS
QUERY_FILE = re.compile(r"^query-\d+\.json$")
MAX_ACCEPT_DAYS = 31
ACCEPT_LINE = re.compile(r"^(GO-\d{4}-\d{4,}) until (\d{4}-\d{2}-\d{2}): (\S.*)$")


class ScanError(Exception):
    """A scan file or the accept file cannot be used."""


def read_stream(path: Path) -> list[dict]:
    """The JSON objects govulncheck -format json writes, one after another."""
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as e:
        raise ScanError(f"cannot read {path}: {e.strerror}") from e
    dec = json.JSONDecoder()
    objs, i = [], 0
    while True:
        while i < len(text) and text[i].isspace():
            i += 1
        if i >= len(text):
            break
        try:
            obj, i = dec.raw_decode(text, i)
        except json.JSONDecodeError as e:
            raise ScanError(f"{path} is not govulncheck JSON: {e}") from e
        if not isinstance(obj, dict):
            raise ScanError(f"{path} is not govulncheck JSON")
        objs.append(obj)
    if not any("config" in o for o in objs):
        raise ScanError(f"{path} has no govulncheck config, so the scan did not run")
    return objs


def _frame(f: dict) -> str:
    name = f.get("function") or f.get("package") or f.get("module", "?")
    pkg = f.get("package", "")
    recv = f.get("receiver")
    if f.get("function") and pkg:
        name = f"{pkg}.{recv + '.' if recv else ''}{f['function']}"
    return name


def called_findings(objs: list[dict]) -> dict[str, dict]:
    """Findings in code the core calls, by OSV id.

    govulncheck writes a trace from the vulnerable symbol (trace[0]) to the
    core's own entry point (the last frame). trace[0] names a function only
    when that symbol is reachable. One advisory can cover several modules
    (the standard library's net/http and golang.org/x/net/http2, say), so
    each id lists every module it was found in, with the version found and
    the fixed version. Each id keeps its first call path, printed from the
    entry point to the vulnerable symbol.
    """
    summaries = {o["osv"]["id"]: o["osv"].get("summary", "") for o in objs if "osv" in o}
    out: dict[str, dict] = {}
    for o in objs:
        f = o.get("finding")
        if not f:
            continue
        trace = f.get("trace") or []
        if not trace or not trace[0].get("function"):
            continue
        vid = f["osv"]
        if vid not in out:
            out[vid] = {
                "id": vid,
                "modules": {},
                "path": " -> ".join(_frame(x) for x in reversed(trace)),
                "summary": summaries.get(vid, ""),
            }
        out[vid]["modules"].setdefault(
            trace[0].get("module", "?"),
            (trace[0].get("version", "?"), f.get("fixed_version") or "none"))
    return out


def read_replaced(scan_dir: Path) -> list[tuple[str, str, str]]:
    """(file, module, version) for each module a go.mod replaces with a folder."""
    path = scan_dir / "replaced.txt"
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as e:
        raise ScanError(f"cannot read {path}: {e.strerror}, so the modules go.mod"
                        " replaces with a folder were not looked up") from e
    out = []
    for n, line in enumerate(lines, 1):
        parts = line.split()
        if len(parts) != 3 or not QUERY_FILE.match(parts[0]):
            raise ScanError(f"{path}:{n}: not 'query-N.json <module> <version>'")
        out.append((parts[0], parts[1], parts[2]))
    return out


def _version(v: str) -> str:
    return v if v.startswith("v") else f"v{v}"


def query_findings(objs: list[dict], module: str, version: str) -> dict[str, dict]:
    """Every advisory query mode lists for module@version, by OSV id.

    Query mode lists only the advisories whose ranges hold that version, and
    it has no call information. Withdrawn advisories are left out.
    """
    config = next(o["config"] for o in objs if "config" in o)
    if config.get("scan_mode") != "query":
        raise ScanError(f"the scan of {module}@{version} is not a query-mode scan")
    out: dict[str, dict] = {}
    for o in objs:
        entry = o.get("osv")
        if not entry or entry.get("withdrawn"):
            continue
        fixed = sorted({_version(ev["fixed"])
                        for a in entry.get("affected", [])
                        if a.get("package", {}).get("name") == module
                        for r in a.get("ranges", [])
                        for ev in r.get("events", []) if "fixed" in ev})
        out[entry["id"]] = {
            "id": entry["id"],
            "modules": {module: (version, " or ".join(fixed) or "none")},
            "summary": entry.get("summary", ""),
        }
    return out


def module_findings(objs: list[dict]) -> set[str]:
    """Ids of every finding, called or not."""
    return {o["finding"]["osv"] for o in objs if "finding" in o}


def distrust_result(scan_dir: Path) -> tuple[bool, str]:
    """(passed, test output) of go test ./x509distrust/."""
    try:
        status = (scan_dir / "x509distrust.status").read_text(encoding="utf-8").strip()
        output = (scan_dir / "x509distrust.txt").read_text(encoding="utf-8")
    except OSError as e:
        raise ScanError(f"no result of go test ./x509distrust/ in {scan_dir}: {e.strerror}") from e
    if status not in ("pass", "fail"):
        raise ScanError(f"x509distrust.status in {scan_dir} says {status!r}, not pass or fail")
    return status == "pass", output


def load_accept(path: Path, today: dt.date) -> dict[str, tuple[dt.date, str]]:
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as e:
        raise ScanError(f"cannot read {path}: {e.strerror}") from e
    out: dict[str, tuple[dt.date, str]] = {}
    errors = []
    for n, raw in enumerate(lines, 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        m = ACCEPT_LINE.match(line)
        if not m:
            errors.append(f"{path}:{n}: not 'GO-YYYY-NNNN until YYYY-MM-DD: reason'")
            continue
        vid, day, reason = m.groups()
        try:
            until = dt.date.fromisoformat(day)
        except ValueError:
            errors.append(f"{path}:{n}: {day} is not a date")
            continue
        if until < today:
            errors.append(f"{path}:{n}: {vid} expired on {until}; fix it or accept it again in a pull request")
        elif (until - today).days > MAX_ACCEPT_DAYS:
            errors.append(f"{path}:{n}: {vid} is accepted until {until}, more than {MAX_ACCEPT_DAYS} days from today")
        elif vid in out:
            errors.append(f"{path}:{n}: {vid} is listed twice")
        else:
            out[vid] = (until, reason)
    if errors:
        raise ScanError("\n".join(errors))
    return out


def decide(scans: dict[str, list[dict]], accept: dict[str, tuple[dt.date, str]],
           queried: dict[str, dict] | None = None):
    """(blocking, accepted, stale): blocking and accepted map an id to its
    finding, with the builds a source scan found it on ("abis") and whether
    query mode found it in a replaced module ("replaced"); stale lists
    accepted ids that no scan reports any more."""
    merged: dict[str, dict] = {}
    for target in SOURCES:
        for vid, f in called_findings(scans.get(target, [])).items():
            if vid not in merged:
                merged[vid] = dict(f, modules=dict(f["modules"]), abis=[], replaced=False)
            else:
                for m, v in f["modules"].items():
                    merged[vid]["modules"].setdefault(m, v)
            merged[vid]["abis"].append(target)
    for vid, f in (queried or {}).items():
        if vid not in merged:
            merged[vid] = dict(f, modules=dict(f["modules"]), abis=[], path="", replaced=True)
        else:
            for m, v in f["modules"].items():
                merged[vid]["modules"].setdefault(m, v)
            merged[vid]["replaced"] = True
            merged[vid]["summary"] = merged[vid]["summary"] or f["summary"]
    blocking = {v: f for v, f in merged.items() if v not in accept}
    accepted = {v: f for v, f in merged.items() if v in accept}
    stale = sorted(v for v in accept if v not in merged)
    return blocking, accepted, stale


def _table(findings: dict[str, dict]) -> list[str]:
    rows = []
    for vid in sorted(findings):
        f = findings[vid]
        mods = "; ".join(f"{m} {found}, fixed in {fixed}"
                         for m, (found, fixed) in sorted(f["modules"].items()))
        rows.append(f"  {vid}  {mods}")
        if f["abis"]:
            rows.append(f"      on {', '.join(f['abis'])}")
        if f["summary"]:
            rows.append(f"      {f['summary']}")
        if f["path"]:
            rows.append(f"      called: {f['path']}")
        if f["replaced"]:
            rows.append("      in a module go.mod replaces with a patched folder: query mode found it,")
            rows.append("      and it cannot tell whether the core calls the code")
    return rows


def main(argv: list[str], today: dt.date | None = None) -> int:
    if len(argv) != 3:
        print(__doc__.split("\n\n")[1], file=sys.stderr)
        return 2
    scan_dir, accept_path = Path(argv[1]), Path(argv[2])
    today = today or dt.date.today()
    try:
        accept = load_accept(accept_path, today)
        scans = {t: read_stream(scan_dir / f"source-{t}.json") for t in SOURCES}
        binaries = {abi: read_stream(scan_dir / f"binary-{abi}.json") for abi in ABIS}
        replaced = read_replaced(scan_dir)
        queried: dict[str, dict] = {}
        for name, module, version in replaced:
            for vid, f in query_findings(read_stream(scan_dir / name), module, version).items():
                if vid in queried:
                    queried[vid]["modules"].update(f["modules"])
                else:
                    queried[vid] = f
        distrust_ok, distrust_out = distrust_result(scan_dir)
    except ScanError as e:
        print(f"error: {e}", file=sys.stderr)
        print("The core could not be checked, so it may not ship.", file=sys.stderr)
        return 1

    facts = scan_dir / "facts.txt"
    if facts.is_file():
        for line in facts.read_text(encoding="utf-8").splitlines():
            print(f"  {line}")

    blocking, accepted, stale = decide(scans, accept, queried)
    found = {**blocking, **accepted}

    def count(kind: str) -> str:
        ids = [v for v, f in found.items() if (f["abis"] if kind == "source" else f["replaced"])]
        return f"{len(ids)} advisories, {sum(v in accepted for v in ids)} of them accepted"

    print(f"  source mode: {count('source')}, in code the cores call"
          f" ({len(ABIS)} Android ABIs, {len(WINDOWS)} Windows builds)")
    print(f"  query mode: {count('query')}, in the modules go.mod replaces with a folder:")
    for _, module, version in replaced:
        print(f"    {module} {version}")
    if not replaced:
        print("    none")
    if distrust_ok:
        print("  x509distrust: the core's Go rejects the eight eMudhra intermediates")
    in_binary = sorted(set().union(*(module_findings(b) for b in binaries.values())))
    line = (f"binary mode: {len(in_binary)} advisories match a linked module or version"
            + (f" ({', '.join(in_binary)})" if in_binary else "")
            + ". The core has no symbol table, so this mode cannot tell"
            " whether the code is called. It does not block.")
    print(textwrap.fill(line, width=78, initial_indent="  ", subsequent_indent="    "))

    for vid in stale:
        print(f"  warn  {vid} is in {accept_path} but no scan reports it any more; remove the line")
    if accepted:
        print(f"Accepted in {accept_path}:")
        for line in _table(accepted):
            print(line)
        for vid in sorted(accepted):
            until, reason = accept[vid]
            print(f"  {vid} until {until}: {reason}")

    # What follows goes to stderr; print the summary above first.
    sys.stdout.flush()
    if not distrust_ok:
        print("The core's Go still trusts the eight eMudhra intermediates"
              " (go test ./x509distrust/ in android/core failed):", file=sys.stderr)
        for line in distrust_out.splitlines():
            print(f"      {line}", file=sys.stderr)
        print("Move the toolchain line in android/core/go.mod and windows/core/go.mod, and\n"
              "GO_VERSION and GO_SHA256 in android/core/Dockerfile, to go1.26.10 or later,\n"
              "then rebuild the Android core.\n", file=sys.stderr)

    if not blocking:
        return 0 if distrust_ok else 1

    print("A core contains code with a known vulnerability:", file=sys.stderr)
    for line in _table(blocking):
        print(line, file=sys.stderr)
    print(
        "\nTo fix it:\n"
        "  - for a module, in android/core for an Android ABI or windows/core for a\n"
        "    Windows build, run android/core/stage-xray.sh and android/core/stage-psiphon.sh,\n"
        "    then GOFLAGS= go get <module>@<fixed version> && GOFLAGS= go mod tidy;\n"
        "  - for a module go.mod replaces with a patched folder, move it to a fixed\n"
        "    version as android/core/README.md says (\"Bumping the core\" for Xray-core,\n"
        "    \"Bumping Psiphon\" for Psiphon's quic-go fork);\n"
        "  - for the standard library (module stdlib), move the toolchain line in both\n"
        "    go.mod files, and GO_VERSION and GO_SHA256 in android/core/Dockerfile, to\n"
        "    the fixed Go.\n"
        "Then rebuild the Android core with android/core/build-in-linux.sh, test a\n"
        "connection on a device, and commit the .aar with checksums.txt. For\n"
        "windows/core, run go test ./... there. If no fix exists yet, or a patch in\n"
        f"android/core/patches/ already fixes it, add the id to {accept_path}\n"
        "with a reason, in a pull request.",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
