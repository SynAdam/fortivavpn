#!/usr/bin/env python3
"""Tests for tool/core_vulncheck.py. Run: python3 tool/core_vulncheck_test.py

The ids and modules are made up.
"""

from __future__ import annotations

import contextlib
import datetime as dt
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import core_vulncheck as cv  # noqa: E402

TODAY = dt.date(2099, 6, 1)
CONFIG = {"config": {"scanner_name": "govulncheck", "scanner_version": "v1.9.0", "go_version": "go1.99.1"}}
QUERY_CONFIG = {"config": {"scanner_name": "govulncheck", "scanner_version": "v1.9.0", "scan_mode": "query"}}


def osv(vid: str, summary: str = "A made-up advisory") -> dict:
    return {"osv": {"id": vid, "summary": summary}}


def called(vid: str, module: str = "example.com/m") -> dict:
    return {"finding": {"osv": vid, "fixed_version": "v1.2.4", "trace": [
        {"module": module, "version": "v1.2.3", "package": f"{module}/p", "function": "Parse"},
        {"module": "example.com/core", "package": "example.com/core/entry", "function": "Start"},
    ]}}


def module_only(vid: str, module: str = "example.com/m") -> dict:
    return {"finding": {"osv": vid, "fixed_version": "v1.2.4", "trace": [
        {"module": module, "version": "v1.2.3"},
    ]}}


def package_only(vid: str, module: str = "example.com/m") -> dict:
    return {"finding": {"osv": vid, "trace": [
        {"module": module, "version": "v1.2.3", "package": f"{module}/p"},
    ]}}


def queried(vid: str, module: str = "example.com/patched", summary: str = "A made-up advisory",
            fixed: str = "1.2.4", **extra) -> dict:
    """An advisory as govulncheck -mode=query writes it: OSV versions have no v."""
    return {"osv": {"id": vid, "summary": summary, **extra, "affected": [
        {"package": {"name": module},
         "ranges": [{"type": "SEMVER", "events": [{"introduced": "0"}, {"fixed": fixed}]}]},
    ]}}


def write_stream(path: Path, objs: list[dict]) -> None:
    path.write_text("\n".join(json.dumps(o, indent=2) for o in objs) + "\n", encoding="utf-8")


class Scan:
    """A scan folder as vulncheck.sh writes it: source-<target>.json for every
    Android ABI and Windows build, binary-<abi>.json for every ABI, and
    replaced.txt with one query-<n>.json for each (module, version, objs) in
    queries."""

    def __init__(self, source: dict[str, list[dict]] | None = None, binary: list[dict] | None = None,
                 missing: str | None = None, distrust: str = "pass",
                 queries: list[tuple[str, str, list[dict]]] | None = None):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        source = source or {}
        for target in cv.SOURCES:
            if f"source-{target}.json" != missing:
                write_stream(self.dir / f"source-{target}.json", [CONFIG, *source.get(target, [])])
        for abi in cv.ABIS:
            if f"binary-{abi}.json" != missing:
                write_stream(self.dir / f"binary-{abi}.json", [CONFIG, *(binary or [])])
        lines = []
        for n, (module, version, objs) in enumerate(queries or [], 1):
            write_stream(self.dir / f"query-{n}.json", [QUERY_CONFIG, *objs])
            lines.append(f"query-{n}.json {module} {version}\n")
        if missing != "replaced.txt":
            (self.dir / "replaced.txt").write_text("".join(lines), encoding="utf-8")
        for name, text in (("x509distrust.status", distrust + "\n"),
                           ("x509distrust.txt", "--- FAIL: TestEmudhraIntermediatesDistrusted\n"
                            if distrust == "fail" else "ok\n")):
            if name != missing:
                (self.dir / name).write_text(text, encoding="utf-8")
        self.accept = self.dir / "accept.txt"
        self.accept.write_text("# nothing accepted\n", encoding="utf-8")

    def run(self, accept_text: str | None = None) -> tuple[int, str, str]:
        if accept_text is not None:
            self.accept.write_text(accept_text, encoding="utf-8")
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = cv.main(["core_vulncheck.py", str(self.dir), str(self.accept)], today=TODAY)
        return code, out.getvalue(), err.getvalue()

    def close(self):
        self.tmp.cleanup()


def all_abis(*objs: dict) -> dict[str, list[dict]]:
    return {abi: list(objs) for abi in cv.ABIS}


class CoreVulncheckTest(unittest.TestCase):
    def scan(self, **kw) -> Scan:
        s = Scan(**kw)
        self.addCleanup(s.close)
        return s

    def test_no_findings_passes(self):
        code, _, err = self.scan().run()
        self.assertEqual(code, 0, err)

    def test_module_and_package_level_findings_pass(self):
        s = self.scan(source=all_abis(osv("GO-2099-0001"), module_only("GO-2099-0001"),
                                      osv("GO-2099-0002"), package_only("GO-2099-0002")),
                      binary=[module_only("GO-2099-0001"), module_only("GO-2099-0003")])
        code, out, err = s.run()
        self.assertEqual(code, 0, err)
        self.assertIn("binary mode: 2 advisories", out)
        self.assertIn("GO-2099-0003", out)

    def test_called_finding_blocks_and_names_its_id(self):
        s = self.scan(source={"arm64-v8a": [osv("GO-2099-0001", "Parser loops forever"), called("GO-2099-0001")]})
        code, _, err = s.run()
        self.assertEqual(code, 1)
        self.assertIn("GO-2099-0001", err)
        self.assertIn("example.com/m v1.2.3, fixed in v1.2.4", err)
        self.assertIn("Parser loops forever", err)
        self.assertIn("example.com/core/entry.Start -> example.com/m/p.Parse", err)
        self.assertIn("on arm64-v8a\n", err)

    def test_one_advisory_in_two_modules_names_both(self):
        s = self.scan(source={"arm64-v8a": [called("GO-2099-0001", "stdlib")],
                              "x86": [called("GO-2099-0001", "example.com/net")]})
        code, _, err = s.run()
        self.assertEqual(code, 1)
        self.assertIn("GO-2099-0001  example.com/net v1.2.3, fixed in v1.2.4; stdlib v1.2.3, fixed in v1.2.4", err)

    def test_same_finding_on_two_abis_is_listed_once_with_both(self):
        s = self.scan(source={"arm64-v8a": [called("GO-2099-0001")], "x86": [called("GO-2099-0001")]})
        code, _, err = s.run()
        self.assertEqual(code, 1)
        self.assertEqual(err.count("GO-2099-0001  "), 1)
        self.assertIn("on arm64-v8a, x86\n", err)

    def test_accepted_finding_passes(self):
        s = self.scan(source=all_abis(called("GO-2099-0001")))
        code, out, err = s.run("GO-2099-0001 until 2099-06-15: no fixed version yet\n")
        self.assertEqual(code, 0, err)
        self.assertIn("GO-2099-0001 until 2099-06-15: no fixed version yet", out)

    def test_accepted_finding_does_not_hide_another(self):
        s = self.scan(source=all_abis(called("GO-2099-0001"), called("GO-2099-0002", "example.com/n")))
        code, _, err = s.run("GO-2099-0001 until 2099-06-15: no fixed version yet\n")
        self.assertEqual(code, 1)
        self.assertIn("GO-2099-0002", err)
        self.assertNotIn("GO-2099-0001", err)

    def test_entry_lasts_through_its_day(self):
        s = self.scan(source=all_abis(called("GO-2099-0001")))
        code, _, err = s.run("GO-2099-0001 until 2099-06-01: last day\n")
        self.assertEqual(code, 0, err)

    def test_expired_entry_fails(self):
        s = self.scan(source=all_abis(called("GO-2099-0001")))
        code, _, err = s.run("GO-2099-0001 until 2099-05-31: no fixed version yet\n")
        self.assertEqual(code, 1)
        self.assertIn("expired on 2099-05-31", err)

    def test_entry_too_far_ahead_fails(self):
        s = self.scan()
        code, _, err = s.run("GO-2099-0001 until 2099-07-03: no fixed version yet\n")
        self.assertEqual(code, 1)
        self.assertIn("more than 31 days", err)
        code, _, err = s.run("GO-2099-0001 until 2099-07-02: no fixed version yet\n")
        self.assertEqual(code, 0, err)

    def test_malformed_entries_fail(self):
        s = self.scan()
        for text in ("GO-2099-0001: no date\n",
                     "GO-2099-0001 until 2099-06-10\n",
                     "GO-2099-0001 until 2099-02-30: not a day\n",
                     "CVE-2099-0001 until 2099-06-10: not a Go id\n",
                     "GO-2099-0001 until 2099-06-10: one\nGO-2099-0001 until 2099-06-11: twice\n"):
            code, _, err = s.run(text)
            self.assertEqual(code, 1, text)
            self.assertIn("accept.txt:", err)

    def test_comments_and_blank_lines_are_ignored(self):
        code, _, err = self.scan().run("# a comment\n\n   \n  # indented comment\n")
        self.assertEqual(code, 0, err)

    def test_stale_entry_warns_and_passes(self):
        s = self.scan(source=all_abis(module_only("GO-2099-0001")))
        code, out, err = s.run("GO-2099-0001 until 2099-06-15: fixed upstream, not yet here\n")
        self.assertEqual(code, 0, err)
        self.assertIn("warn  GO-2099-0001", out)

    def test_missing_source_scan_fails(self):
        code, _, err = self.scan(missing="source-x86.json").run()
        self.assertEqual(code, 1)
        self.assertIn("source-x86.json", err)

    def test_missing_binary_scan_fails(self):
        code, _, err = self.scan(missing="binary-armeabi-v7a.json").run()
        self.assertEqual(code, 1)
        self.assertIn("binary-armeabi-v7a.json", err)

    def test_scan_that_did_not_run_fails(self):
        s = self.scan()
        (s.dir / "source-x86_64.json").write_text("", encoding="utf-8")
        code, _, err = s.run()
        self.assertEqual(code, 1)
        self.assertIn("no govulncheck config", err)

    def test_broken_json_fails(self):
        s = self.scan()
        (s.dir / "source-x86_64.json").write_text('{"config": {}}\n{"finding": ', encoding="utf-8")
        code, _, err = s.run()
        self.assertEqual(code, 1)
        self.assertIn("not govulncheck JSON", err)

    def test_failed_distrust_test_blocks(self):
        code, _, err = self.scan(distrust="fail").run()
        self.assertEqual(code, 1)
        self.assertIn("eMudhra", err)
        self.assertIn("TestEmudhraIntermediatesDistrusted", err)

    def test_failed_distrust_test_and_called_finding_are_both_listed(self):
        code, _, err = self.scan(source=all_abis(called("GO-2099-0001")), distrust="fail").run()
        self.assertEqual(code, 1)
        self.assertIn("eMudhra", err)
        self.assertIn("GO-2099-0001", err)

    def test_missing_distrust_result_fails(self):
        code, _, err = self.scan(missing="x509distrust.status").run()
        self.assertEqual(code, 1)
        self.assertIn("x509distrust", err)

    def test_unknown_distrust_status_fails(self):
        code, _, err = self.scan(distrust="skipped").run()
        self.assertEqual(code, 1)
        self.assertIn("not pass or fail", err)

    def test_missing_accept_file_fails(self):
        s = self.scan()
        s.accept.unlink()
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = cv.main(["core_vulncheck.py", str(s.dir), str(s.accept)], today=TODAY)
        self.assertEqual(code, 1)
        self.assertIn("accept.txt", err.getvalue())

    def test_windows_called_finding_blocks(self):
        s = self.scan(source={"windows-amd64": [called("GO-2099-0001")]})
        code, out, err = s.run()
        self.assertEqual(code, 1)
        self.assertIn("on windows-amd64\n", err)
        self.assertIn("windows/core", err)
        self.assertIn("source mode: 1 advisories, 0 of them accepted", out)

    def test_same_finding_on_android_and_windows_is_listed_once(self):
        s = self.scan(source={"x86": [called("GO-2099-0001")], "windows-arm64": [called("GO-2099-0001")]})
        code, _, err = s.run()
        self.assertEqual(code, 1)
        self.assertEqual(err.count("GO-2099-0001  "), 1)
        self.assertIn("on x86, windows-arm64\n", err)

    def test_missing_windows_scan_fails(self):
        code, _, err = self.scan(missing="source-windows-arm64.json").run()
        self.assertEqual(code, 1)
        self.assertIn("source-windows-arm64.json", err)

    def test_replaced_module_with_no_advisory_passes(self):
        s = self.scan(queries=[("example.com/patched", "v1.2.3", [])])
        code, out, err = s.run()
        self.assertEqual(code, 0, err)
        self.assertIn("example.com/patched v1.2.3", out)

    def test_query_finding_blocks_without_a_call(self):
        # Query mode has no call information, and the source scan never
        # reports a module replaced by a folder, so every advisory blocks.
        s = self.scan(queries=[("example.com/patched", "v1.2.3",
                                [queried("GO-2099-0010", summary="Pinning can be bypassed")])])
        code, out, err = s.run()
        self.assertEqual(code, 1)
        self.assertIn("GO-2099-0010  example.com/patched v1.2.3, fixed in v1.2.4", err)
        self.assertIn("Pinning can be bypassed", err)
        self.assertIn("query mode found it", err)
        self.assertNotIn("called:", err)
        self.assertIn("Bumping the core", err)
        self.assertIn("1 advisories, 0 of them accepted", out)

    def test_accepted_query_finding_passes_and_is_not_stale(self):
        s = self.scan(queries=[("example.com/patched", "v1.2.3", [queried("GO-2099-0010")])])
        code, out, err = s.run("GO-2099-0010 until 2099-06-15: patches/fix.patch fixes it\n")
        self.assertEqual(code, 0, err)
        self.assertNotIn("warn", out)
        self.assertIn("GO-2099-0010 until 2099-06-15: patches/fix.patch fixes it", out)

    def test_accepted_query_finding_does_not_hide_another(self):
        s = self.scan(queries=[("example.com/patched", "v1.2.3", [queried("GO-2099-0010")]),
                               ("example.com/fork", "v0.0.0-20990101000000-aaaaaaaaaaaa",
                                [queried("GO-2099-0011", "example.com/fork")])])
        code, _, err = s.run("GO-2099-0010 until 2099-06-15: patches/fix.patch fixes it\n")
        self.assertEqual(code, 1)
        self.assertIn("GO-2099-0011  example.com/fork v0.0.0-20990101000000-aaaaaaaaaaaa", err)
        self.assertNotIn("GO-2099-0010", err)

    def test_withdrawn_query_advisory_is_ignored(self):
        s = self.scan(queries=[("example.com/patched", "v1.2.3",
                                [queried("GO-2099-0010", withdrawn="2099-01-01T00:00:00Z")])])
        code, _, err = s.run()
        self.assertEqual(code, 0, err)

    def test_called_and_queried_advisory_is_listed_once(self):
        s = self.scan(source={"arm64-v8a": [called("GO-2099-0010", "example.com/other")]},
                      queries=[("example.com/patched", "v1.2.3", [queried("GO-2099-0010")])])
        code, _, err = s.run()
        self.assertEqual(code, 1)
        self.assertEqual(err.count("GO-2099-0010  "), 1)
        self.assertIn("example.com/other v1.2.3, fixed in v1.2.4; example.com/patched v1.2.3, fixed in v1.2.4", err)
        self.assertIn("called:", err)
        self.assertIn("query mode found it", err)

    def test_missing_replaced_list_fails(self):
        code, _, err = self.scan(missing="replaced.txt").run()
        self.assertEqual(code, 1)
        self.assertIn("replaced.txt", err)

    def test_missing_query_file_fails(self):
        s = self.scan(queries=[("example.com/patched", "v1.2.3", [])])
        (s.dir / "query-1.json").unlink()
        code, _, err = s.run()
        self.assertEqual(code, 1)
        self.assertIn("query-1.json", err)

    def test_malformed_replaced_line_fails(self):
        s = self.scan()
        for text in ("query-1.json example.com/patched\n", "../x.json example.com/patched v1.2.3\n"):
            (s.dir / "replaced.txt").write_text(text, encoding="utf-8")
            code, _, err = s.run()
            self.assertEqual(code, 1, text)
            self.assertIn("replaced.txt:1", err)

    def test_query_file_from_another_mode_fails(self):
        s = self.scan(queries=[("example.com/patched", "v1.2.3", [])])
        write_stream(s.dir / "query-1.json", [CONFIG])
        code, _, err = s.run()
        self.assertEqual(code, 1)
        self.assertIn("not a query-mode scan", err)

    def test_wrong_arguments_exit_2(self):
        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            self.assertEqual(cv.main(["core_vulncheck.py"]), 2)


if __name__ == "__main__":
    unittest.main()
