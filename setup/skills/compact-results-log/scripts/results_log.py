#!/usr/bin/env python3
"""Mechanical half of the compact-results-log skill.

  results_log.py archive <repo>   move every dated section ("## YYYY-MM-DD ..." or
                                  "## D Month YYYY ...") from
                                  RESULTS.codex.md to the end of RESULTS.codex.archive.md,
                                  verbatim, and save a pre-compaction copy for `check`
  results_log.py check <repo>     verify the compaction lost nothing

The agent writes the "Failure families" index between the two commands.
"""
import hashlib
import pathlib
import re
import sys

DATED = re.compile(r"^## (?:\d{4}-\d{2}-\d{2}|\d{1,2} [A-Z][a-z]+ \d{4})\b", re.M)
SECTION = re.compile(r"^## ", re.M)
RC_ID = re.compile(r"\bRC-\d{3}\b")
FAMILIES = "## Failure families"


def paths(repo):
    root = pathlib.Path(repo)
    return root / "RESULTS.codex.md", root / "RESULTS.codex.archive.md", root / "RESULTS.codex.pre-compaction.md"


def split_dated(text):
    """Return (kept, dated): the dated sections, and everything else in order."""
    starts = [m.start() for m in SECTION.finditer(text)] + [len(text)]
    kept, dated = text[: starts[0]], []
    for begin, end in zip(starts, starts[1:]):
        part = text[begin:end]
        if DATED.match(part):
            dated.append(part)
        else:
            kept += part
    return kept, dated


def archive(repo):
    main, arch, pre = paths(repo)
    text = main.read_text()
    kept, dated = split_dated(text)
    if not dated:
        print("no dated sections to archive")
        return 0
    pre.write_text(text)
    digest = hashlib.sha256(text.encode()).hexdigest()
    with arch.open("a") as out:
        out.write(f"\n<!-- archived from RESULTS.codex.md sha256 {digest} -->\n\n")
        out.write("".join(dated))
    main.write_text(kept.rstrip("\n") + "\n")
    print(f"archived {len(dated)} dated sections; pre-compaction copy at {pre}")
    return 0


def check(repo):
    main, arch, pre = paths(repo)
    before, after, history = pre.read_text(), main.read_text(), arch.read_text()
    failures = []
    _, dated = split_dated(before)
    failures += [f"dated section not archived verbatim: {d.splitlines()[0]}" for d in dated if d not in history]
    if FAMILIES not in after:
        failures.append(f"missing '{FAMILIES}' section")
    index = after.split(FAMILIES, 1)[-1]
    missing = sorted(set(RC_ID.findall(before)) - set(RC_ID.findall(index)))
    failures += [f"{rc} is not listed in any failure family" for rc in missing]
    for d in dated:
        for line in d.splitlines():
            if "pending" in line.lower():
                print(f"confirm carried to Open items: {line.strip()[:140]}")
    print(f"size: {len(before)} -> {len(after)} bytes (~{len(before) // 4} -> ~{len(after) // 4} tokens)")
    for f in failures:
        print("FAIL:", f)
    print("PASS" if not failures else f"{len(failures)} failure(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] not in ("archive", "check"):
        sys.exit(__doc__)
    sys.exit({"archive": archive, "check": check}[sys.argv[1]](sys.argv[2]))
