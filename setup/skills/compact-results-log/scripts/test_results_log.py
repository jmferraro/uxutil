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


if __name__ == "__main__":
    unittest.main()
