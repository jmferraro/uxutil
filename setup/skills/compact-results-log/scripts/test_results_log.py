#!/usr/bin/env python3
"""Tests for results_log.py. Run: python3 -I test_results_log.py"""
import pathlib
import subprocess
import sys
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parent / "results_log.py"

LOG = """# RESULTS.codex.md

Rules header.

## 2026-11-15 — ISO-dated section

### RC-001 — first

- body one

## 16 November 2026 — day-month-year dated section

### RC-002 — second

- body two
"""


def run(command, repo):
    return subprocess.run([sys.executable, "-I", str(SCRIPT), command, str(repo)], capture_output=True, text=True)


class ArchiveTest(unittest.TestCase):
    def test_archives_both_date_heading_forms(self):
        with tempfile.TemporaryDirectory() as repo:
            root = pathlib.Path(repo)
            (root / "RESULTS.codex.md").write_text(LOG)
            self.assertEqual(run("archive", root).returncode, 0)
            main = (root / "RESULTS.codex.md").read_text()
            history = (root / "RESULTS.codex.archive.md").read_text()
            self.assertNotIn("## 2026-11-15", main)
            self.assertNotIn("## 16 November 2026", main)
            self.assertIn("## 2026-11-15 — ISO-dated section\n\n### RC-001 — first\n\n- body one\n\n", history)
            self.assertIn("## 16 November 2026 — day-month-year dated section\n\n### RC-002 — second\n\n- body two\n", history)


class SizeTest(unittest.TestCase):
    """`size` only reports; it never compacts, writes or deletes anything."""

    def files(self, root):
        return {path.name: path.read_bytes() for path in root.iterdir()}

    def test_under_limit_reports_without_warning(self):
        with tempfile.TemporaryDirectory() as repo:
            root = pathlib.Path(repo)
            (root / "RESULTS.codex.md").write_text(LOG)
            result = run("size", root)
            self.assertEqual(result.returncode, 0)
            self.assertIn("dated sections since the last compaction:", result.stdout)
            self.assertNotIn("warning", result.stdout)

    def test_over_limit_warns_and_changes_nothing(self):
        with tempfile.TemporaryDirectory() as repo:
            root = pathlib.Path(repo)
            (root / "RESULTS.codex.md").write_text(LOG + "## 2026-11-17 — large\n\n" + "x" * 50 * 1024 + "\n")
            before = self.files(root)
            result = run("size", root)
            self.assertEqual(result.returncode, 0)
            self.assertIn("warning:", result.stdout)
            self.assertIn("compact-results-log", result.stdout)
            self.assertEqual(self.files(root), before)

    def test_custom_limit_in_kb(self):
        with tempfile.TemporaryDirectory() as repo:
            root = pathlib.Path(repo)
            (root / "RESULTS.codex.md").write_text(LOG)
            result = subprocess.run([sys.executable, "-I", str(SCRIPT), "size", str(root), "0"],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0)
            self.assertIn("warning:", result.stdout)

    def test_missing_log_is_not_an_error(self):
        with tempfile.TemporaryDirectory() as repo:
            result = run("size", pathlib.Path(repo))
            self.assertEqual(result.returncode, 0)
            self.assertIn("no RESULTS.codex.md", result.stdout)
            self.assertEqual(list(pathlib.Path(repo).iterdir()), [])


if __name__ == "__main__":
    unittest.main()
