#!/usr/bin/env python3
"""Extract Claude Code's built-in spinner verbs from the installed binary.

The verb list lives baked inside the `claude` executable (native binary or
cli.js bundle) as a minified JS array. This regenerates /tmp/claude/spinner.txt
whenever a Claude Code update changes the list. The file is disposable: it is
recreated on demand and need not survive a reboot.

Resolution order for the binary (override with --binary):
  1. --binary PATH
  2. `claude` on $PATH, with symlinks resolved
  3. newest ~/.local/share/claude/versions/*
  4. common npm global @anthropic-ai/claude-code/cli.js locations

Extraction is version-resilient: it locates the array by the stable
`spinnerVerbs` resolver (`... .mode==="replace" ...`), not by the minified
variable name or the first/last verb.

Usage:
  extract-spinner-verbs.py                 # print single-line comma list to stdout
  extract-spinner-verbs.py -o FILE         # write single-line list to FILE
  extract-spinner-verbs.py --update        # overwrite /tmp/claude/spinner.txt
                                           #   (timestamped backup made first)
  extract-spinner-verbs.py --check [REF]   # diff vs REF (default spinner.txt);
                                           #   exit 1 if the list changed
Options:
  --binary PATH     explicit path to the claude executable / cli.js
  --lines           print one verb per line instead of a comma-separated line

Exit: 0 ok / unchanged, 1 --check found a difference, 2 error.
"""
import argparse
import glob
import os
import re
import shutil
import sys
from datetime import datetime

REF_DEFAULT = "/tmp/claude/spinner.txt"  # regenerable; need not survive a reboot


def die(msg):
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(2)


def resolve_binary(explicit):
    if explicit:
        if not os.path.isfile(explicit):
            die(f"--binary path not found: {explicit}")
        return explicit
    found = shutil.which("claude")
    if found:
        return os.path.realpath(found)
    versions = glob.glob(os.path.expanduser("~/.local/share/claude/versions/*"))
    versions = [v for v in versions if os.path.isfile(v)]
    if versions:
        def vkey(p):
            nums = re.findall(r"\d+", os.path.basename(p))
            return tuple(int(n) for n in nums)
        return max(versions, key=vkey)
    for cand in (
        "/opt/homebrew/lib/node_modules/@anthropic-ai/claude-code/cli.js",
        "/usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js",
        os.path.expanduser("~/.claude/local/node_modules/@anthropic-ai/claude-code/cli.js"),
    ):
        if os.path.isfile(cand):
            return cand
    die("could not locate a claude binary; pass one with --binary")


def decode_js_string(s):
    """Decode \\xNN and \\uNNNN escapes from a minified JS string literal."""
    s = re.sub(r"\\x([0-9A-Fa-f]{2})",
               lambda m: chr(int(m.group(1), 16)), s)
    s = re.sub(r"\\u([0-9A-Fa-f]{4})",
               lambda m: chr(int(m.group(1), 16)), s)
    return s


def parse_verbs(array_src):
    """Decode the string literals of a JS array body into candidate verbs.

    Keeps only short capitalized single tokens, which is what spinner verbs are.
    """
    raw = re.findall(r'"((?:[^"\\]|\\.)*)"', array_src)
    verbs = [decode_js_string(v) for v in raw]
    return [v for v in verbs if v and v[0].isupper() and " " not in v]


def die_out_of_date(path):
    die(f"no spinner verbs found in {path} — this extractor is out of date "
        "with this version of claude (the verb array's format has likely "
        "changed); extract-spinner-verbs.py likely needs to be updated")


def extract_verbs(path):
    text = open(path, "rb").read().decode("latin-1")

    verbs = []

    # Primary: find the variable the spinnerVerbs resolver returns as its
    # default (`if(!r)return O;if(r.mode==="replace")...`), then take that
    # variable's array literal. The `.mode==="replace"` comparison is a stable
    # literal tied to spinnerVerbs semantics. Minified names are reused all
    # over the bundle, so the variable is assigned many times; take the first
    # assignment AFTER the resolver that holds verbs, else the nearest before.
    m = re.search(r'return\s*([\w$]+)\s*;\s*if\([^)]*\.mode\s*===\s*"replace"', text)
    if m:
        var = m.group(1)
        pat = re.compile(r"(?<![\w$])" + re.escape(var) + r"\s*=\s*\[([^\[\]]*)\]")
        found = [(a.start(), parse_verbs(a.group(1))) for a in pat.finditer(text)]
        found = [(pos, v) for pos, v in found if v]
        after = [v for pos, v in found if pos >= m.start()]
        before = [v for pos, v in found if pos < m.start()]
        if after:
            verbs = after[0]
        elif before:
            verbs = before[-1]

    # Fallback: the array literal (no nested brackets) that contains several
    # verbs almost certain to persist across versions.
    if not verbs:
        best = None
        for arr in re.finditer(r"\[([^\[\]]*)\]", text):
            body = arr.group(1)
            if all(f'"{w}"' in body for w in ("Thinking", "Working", "Pondering", "Creating")):
                if best is None or len(body) > len(best):
                    best = body
        if best is not None:
            verbs = parse_verbs(best)

    if not verbs:
        die_out_of_date(path)

    # sanity: a real list has dozens of verbs
    if len(verbs) < 20:
        die(f"extracted only {len(verbs)} verbs — result looks wrong, aborting")
    return verbs


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("--binary")
    ap.add_argument("-o", "--out")
    ap.add_argument("--update", action="store_true",
                    help=f"overwrite {REF_DEFAULT} (backup made first)")
    ap.add_argument("--check", nargs="?", const=REF_DEFAULT, metavar="REF",
                    help="diff against REF and exit 1 if changed")
    ap.add_argument("--lines", action="store_true")
    args = ap.parse_args()

    binary = resolve_binary(args.binary)
    verbs = extract_verbs(binary)
    print(f"extracted {len(verbs)} verbs from {binary}", file=sys.stderr)

    one_line = ",".join(verbs) + "\n"
    payload = "\n".join(verbs) + "\n" if args.lines else one_line

    if args.check is not None:
        ref = args.check
        try:
            old_raw = open(ref, encoding="utf-8").read()
        except OSError as e:
            die(f"cannot read reference {ref}: {e}")
        old = [w.strip() for w in old_raw.replace("\n", ",").split(",") if w.strip()]
        old_set, new_set = set(old), set(verbs)
        added = sorted(new_set - old_set)
        removed = sorted(old_set - new_set)
        if not added and not removed:
            print(f"✓ unchanged — {len(verbs)} verbs match {ref}")
            return 0
        print(f"✗ spinner verb list changed vs {ref}:")
        for v in added:
            print(f"    + {v}")
        for v in removed:
            print(f"    - {v}")
        print(f"\n  run with --update to refresh {REF_DEFAULT}")
        return 1

    target = REF_DEFAULT if args.update else args.out
    if target:
        os.makedirs(os.path.dirname(os.path.abspath(target)), exist_ok=True)
        if os.path.exists(target):
            ts = datetime.now().strftime("%y%m%d-%H%M%S")
            backup = f"{target}.{ts}"
            shutil.copy2(target, backup)
            print(f"backed up existing -> {backup}", file=sys.stderr)
        with open(target, "w", encoding="utf-8") as fh:
            fh.write(one_line)
        print(f"wrote {len(verbs)} verbs -> {target}", file=sys.stderr)
    else:
        sys.stdout.write(payload)
    return 0


if __name__ == "__main__":
    sys.exit(main())
