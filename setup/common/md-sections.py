#!/usr/bin/env python3
"""Check the sections of markdown instruction files (CLAUDE.md, AGENTS.md).

  md-sections.py check INSTALLED SOURCE [SECTION_FILE...]
      Each "## " section of SOURCE and of each SECTION_FILE (and SOURCE's text
      before its first "## " heading) must be in INSTALLED exactly once, with
      the same text.  Prints each section that is missing, repeated or
      different.
  md-sections.py refs FILE...
      Each quoted section name in FILE must be the exact name of a heading or
      of a label line (an unindented line ending in ":") in FILE.  A quoted
      phrase is taken as a section name when it follows "under", "in", "see",
      "per" or "from", or closely resembles a section name.  Prints each one
      that names no section.

Exits 1 if it printed anything.  Headings inside ``` or ~~~ fences are ignored.
"""
import difflib
import pathlib
import re
import sys

PREAMBLE = "(text before the first ## heading)"
FENCE = re.compile(r"\s*(```|~~~)")
HEADING = re.compile(r"#+\s+(.*?)\s*$")
LIST_ITEM = re.compile(r"([-*+]|\d+\.)\s")
QUOTED = re.compile(r'"([^"\n]{3,})"')
REFERS = re.compile(r"\b(under|in|see|per|from)\s*$", re.I)


def lines(path):
    """Yield (line number, line) for each line of PATH outside code fences."""
    fenced = False
    for number, line in enumerate(pathlib.Path(path).read_text().splitlines(), 1):
        if FENCE.match(line):
            fenced = not fenced
        elif not fenced:
            yield number, line


def sections(path):
    """Map each "## " heading of PATH (and PREAMBLE) to the list of texts
    under it, heading line included and trailing blank lines dropped."""
    found, name, body = {}, PREAMBLE, []

    def close():
        text = "\n".join(body).rstrip()
        if text:
            found.setdefault(name, []).append(text)

    for _, line in lines(path):
        if line.startswith("## "):
            close()
            name, body = line[3:].strip(), []
        body.append(line)
    close()
    return found


def check(installed, *sources):
    have, problems = sections(installed), []
    for source in sources:
        for name, (text, *_) in sections(source).items():
            got = have.get(name, [])
            if not got:
                problems.append(f"{installed}: missing section {name!r} (from {source})")
            elif len(got) > 1:
                problems.append(f"{installed}: section {name!r} appears {len(got)} times")
            elif got[0] != text:
                diff = difflib.unified_diff(text.splitlines(), got[0].splitlines(), source, installed, n=0, lineterm="")
                problems.append(f"{installed}: section {name!r} differs from {source}:")
                problems += ["    " + d for d in list(diff)[2:8]]
    return list(dict.fromkeys(problems))


def names(path):
    """The names a reference in PATH can use: its headings and label lines
    (an unindented line, not a list item, that starts a paragraph and ends
    in ":")."""
    found, previous = set(), ""
    for _, line in lines(path):
        heading = HEADING.match(line)
        if heading:
            found.add(heading.group(1))
        elif (line.rstrip().endswith(":") and line[:1].strip() and not LIST_ITEM.match(line)
              and (not previous.strip() or HEADING.match(previous))):
            found.add(line.rstrip()[:-1].strip())
        previous = line
    return found


def refs(path):
    known, problems = names(path), []
    lower = {name.lower(): name for name in known}
    for number, line in lines(path):
        for quoted in QUOTED.finditer(line):
            text = quoted.group(1)
            close = difflib.get_close_matches(text.lower(), lower, n=1, cutoff=0.8)
            if text in known or not (close or REFERS.search(line[: quoted.start()])):
                continue
            hint = f' (did you mean "{lower[close[0]]}"?)' if close else ""
            problems.append(f'{path}:{number}: "{text}" names no section{hint}')
    return problems


def main(argv):
    if len(argv) >= 4 and argv[1] == "check":
        problems = check(*argv[2:])
    elif len(argv) >= 3 and argv[1] == "refs":
        problems = [p for path in argv[2:] for p in refs(path)]
    else:
        sys.exit(__doc__)
    print(*problems, sep="\n") if problems else None
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
