#!/usr/bin/env python3
"""Report Claude Code spinner verbs that are duplicated — read-only.

Claude Code reads custom spinner verbs only from the `spinnerVerbs.verbs` array
of its settings files. This script checks these three, the ones a user edits:

  1. ./.claude/settings.json         project settings (checked in)
  2. ./.claude/settings.local.json   project-local settings (not checked in)
  3. ~/.claude/settings.json         user settings

(Two more sources exist but are not user-editable here: a file passed with
`claude --settings FILE`, and organisation-managed settings.)

A verb is reported when it
  - is already built into the claude executable (the built-in list,
    /tmp/claude/spinner.txt, regenerated from the claude binary by
    extract-spinner-verbs.py when missing), or
  - is repeated within one file, or
  - appears in more than one of the files.
Case-only near-matches of a built-in are shown as warnings and do not fail.

At the end, when duplicates were found, a table shows each duplicated verb, the
files it is in, and whether claude has it built in.

Missing files are skipped, not treated as errors. No file is ever modified.

Exit status:
  0  no duplicates found
  1  duplicate(s) found
  2  usage / read / JSON error

Usage:
  verify-spinner-verbs.py [FILE ...]
      default FILEs: ./.claude/settings.json ./.claude/settings.local.json ~/.claude/settings.json
Env:
  SPINNER_BUILTIN=/path/to/spinner.txt   # override the built-in list
"""
import json
import os
import subprocess
import sys
from collections import defaultdict

DEFAULT_BUILTIN = "/tmp/claude/spinner.txt"  # regenerated from the binary when missing
builtin_path = os.environ.get("SPINNER_BUILTIN", DEFAULT_BUILTIN)

DEFAULT_FILES = [
    ".claude/settings.json",
    ".claude/settings.local.json",
    os.path.expanduser("~/.claude/settings.json"),
]


def die(msg):
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(2)


def regenerate_default_builtins():
    """Rebuild the disposable default list from the installed claude binary."""
    extractor = os.path.join(os.path.dirname(os.path.abspath(__file__)), "extract-spinner-verbs.py")
    r = subprocess.run([sys.executable, "-I", extractor, "--update"],
                       capture_output=True, text=True)
    if r.returncode != 0:
        die(f"cannot create built-in list {builtin_path}: {r.stderr.strip()}")


def load_builtins():
    if builtin_path == DEFAULT_BUILTIN and not os.path.exists(builtin_path):
        regenerate_default_builtins()
    try:
        raw = open(builtin_path, encoding="utf-8").read()
    except OSError as e:
        die(f"cannot read built-in list {builtin_path}: {e}")
    return [w.strip() for w in raw.replace("\n", ",").split(",") if w.strip()]


def check_settings(path, builtin_lc):
    """Check spinnerVerbs.verbs in one settings file.

    Returns (failed, lines, flagged, verbs); flagged maps verb -> occurrences for
    every verb repeated in the file or already built in, and verbs is the file's
    full verb list (for the cross-file check).
    """
    try:
        settings = json.load(open(path, encoding="utf-8"))
    except json.JSONDecodeError as e:
        die(f"invalid JSON in {path}: {e}")
    sv = settings.get("spinnerVerbs") or {}
    verbs = sv.get("verbs") or []
    if not verbs:
        return False, ["  no spinnerVerbs.verbs — nothing to check"], {}, []

    mode = sv.get("mode", "append (default)")
    out = [f"  {len(verbs)} custom verb(s), mode: {mode}"]
    failed = False
    flagged = {}

    own = defaultdict(list)
    for v in verbs:
        own[v.lower()].append(v)
    internal = {k: vs for k, vs in own.items() if len(vs) > 1}
    if internal:
        failed = True
        out.append("  ✗ repeated within the verbs array:")
        for k in sorted(internal):
            out.append(f"      {', '.join(internal[k])}")
            flagged[internal[k][0]] = len(internal[k])

    exact, caseonly = set(), set()
    for v in verbs:
        canon = builtin_lc.get(v.lower())
        if canon is None:
            continue
        if v == canon:
            exact.add(v)
        else:
            caseonly.add((v, canon))
    if exact:
        failed = True
        out.append("  ✗ already built into claude (append mode lists these twice):")
        for v in sorted(exact):
            out.append(f"      {v}")
            flagged[v] = max(flagged.get(v, 0), own[v.lower()].count(v))
    if caseonly:
        out.append("  ⚠ differs from a built-in only by case:")
        for v, canon in sorted(caseonly, key=lambda t: t[0].lower()):
            out.append(f"      {v}  ~  {canon}")
    if not failed and not caseonly:
        out.append("  ✓ no clashes")
    return failed, out, flagged, verbs


def print_table(flagged_by_file, builtin_lc):
    """Print verb | file... | claude for every flagged verb.

    Only files that contributed a flagged verb get a column. A cell is "x" (or
    "xN" when the verb occurs N times in that file) or "0" when absent; the
    claude column is "x" when the verb is compiled into the claude executable.
    """
    paths = [p for p, fl in flagged_by_file.items() if fl]
    display = {}
    for p in paths:
        for verb in flagged_by_file[p]:
            display.setdefault(verb.lower(), builtin_lc.get(verb.lower(), verb))
    rows = []
    for key in sorted(display):
        cells = []
        for p in paths:
            n = next((c for v, c in flagged_by_file[p].items() if v.lower() == key), 0)
            cells.append("0" if n == 0 else "x" if n == 1 else f"x{n}")
        cells.append("x" if key in builtin_lc else "0")
        rows.append([display[key]] + cells)
    # label columns by basename, or by full path when basenames collide
    names = [os.path.basename(p) for p in paths]
    header = ["verb"] + [p if names.count(os.path.basename(p)) > 1 else os.path.basename(p)
                         for p in paths] + ["claude"]
    widths = [max(len(r[i]) for r in [header] + rows) for i in range(len(header))]
    for r in [header] + rows:
        print(" | ".join(c.ljust(widths[i]) for i, c in enumerate(r)).rstrip())


def main():
    files = sys.argv[1:] or DEFAULT_FILES
    builtins = load_builtins()
    builtin_lc = {}
    for b in builtins:
        builtin_lc.setdefault(b.lower(), b)

    print(f"Built-ins: {len(builtins)} verbs from {builtin_path}\n")

    any_failed = False
    flagged_by_file = {}
    verbs_by_file = {}
    for path in files:
        if not os.path.exists(path):
            print(f"{path}\n  skipped — file not found\n")
            continue
        if not os.path.isfile(path):
            die(f"not a regular file: {path}")
        try:
            failed, lines, flagged, verbs = check_settings(path, builtin_lc)
        except OSError as e:
            die(f"cannot read {path}: {e}")
        print(path)
        print("\n".join(lines))
        print()
        any_failed = any_failed or failed
        if flagged:
            flagged_by_file[path] = flagged
        if verbs:
            verbs_by_file[path] = verbs

    # verbs defined in more than one file
    where = defaultdict(list)  # lowercase verb -> files that define it
    for path, verbs in verbs_by_file.items():
        for key in {v.lower() for v in verbs}:
            where[key].append(path)
    shared = {k: ps for k, ps in where.items() if len(ps) > 1}
    if shared:
        any_failed = True
        print("✗ Defined in more than one file:")
        for key in sorted(shared):
            print("    " + next(v for v in verbs_by_file[shared[key][0]] if v.lower() == key))
            for p in shared[key]:
                spelled = next(v for v in verbs_by_file[p] if v.lower() == key)
                count = sum(1 for v in verbs_by_file[p] if v.lower() == key)
                prev = flagged_by_file.setdefault(p, {})
                prev[spelled] = max(prev.get(spelled, 0), count)
        print()

    if any_failed:
        print("Duplicate verbs (x = present, 0 = absent; claude = built into the claude executable):\n")
        print_table(flagged_by_file, builtin_lc)
        print("\nResult: duplicate(s) found — remove them from the files above.")
        return 1
    print("Result: no duplicate spinner verbs found.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
