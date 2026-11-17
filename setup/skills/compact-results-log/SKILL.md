---
name: "compact-results-log"
description: "Compact the repository's RESULTS.codex.md failure log. Fold its dated review entries into a short index of failure families, each with a concrete prevention check. Move the dated entries verbatim to RESULTS.codex.archive.md, so the file every coding round reads stays small and useful. Run only when the user explicitly asks to compact RESULTS.codex.md; never on an agent's own initiative, whatever the file's size. Never run it while another agent is working in the same repository."
---

# Compact RESULTS.codex.md

`RESULTS.codex.md` is read in full before every coding round, so its job is prevention. Repeated narratives of past
reviews bury the checks that matter. Compaction keeps three parts in the main file:
- the rules header;
- a short index of failure **families**, each with a prevention check;
- the open items.

Every dated entry moves verbatim to `RESULTS.codex.archive.md`. Nothing is erased: the archive is the history, and it
need not be read before each round.

## Steps

`<skill dir>` below means the directory holding this `SKILL.md`: `~/.codex/skills/compact-results-log` or
`~/.omp/agent/skills/compact-results-log`.

1. **Preconditions.** The user explicitly asked for this compaction; if not, stop and change nothing. Run from the
   repository root. No other agent may be working here. Record
   `sha256sum RESULTS.codex.md`.
2. **Read** the whole `RESULTS.codex.md`: header, any existing `## Failure families` and `## Open items` sections, and
   every dated section (`## YYYY-MM-DD — …` or `## D Month YYYY — …`), including its `### RC-NNN` entries.
3. **Archive mechanically:**
   `python3 <skill dir>/scripts/results_log.py archive .`
   - This appends every dated section verbatim to `RESULTS.codex.archive.md`, removes them from the main file, and keeps
     a copy at `RESULTS.codex.pre-compaction.md`.
   - Never edit the archive by hand.
4. **Rewrite the main file.** Keep the header, and add one sentence to it if it is not already there: "Dated entries
   are moved verbatim to `RESULTS.codex.archive.md` by compaction; that file is history and need not be read before
   each round." Then write two sections.
   - **`## Failure families`:** about 10–20 families. Merge entries whose cause and prevention check are the same, even
     when their wording or subsystem differs. Use stable IDs `F01`, `F02`, …, and keep existing family IDs when
     folding in new entries. Each family has:
     - a one-line name;
     - what goes wrong, in one or two sentences;
     - **Check:** a concrete, executable prevention check written as an instruction. For example: "for any new durable
       marker, trace daemon-start reconciliation with no containers running". Not "be careful with markers".
     - **Seen:** every RC ID it covers, with the date of the most recent one. Every RC ID in the pre-compaction file
       must appear under exactly one family.

     Order the families by how often they recurred, most frequent first.
   - **`## Open items`:** every disputed finding, pending owner decision and pending disposition from the dated
     entries, each with its RC ID and one line saying what is pending. Drop items whose later entries show them
     resolved.
5. **Verify:** `python3 <skill dir>/scripts/results_log.py check .`
   - It must print `PASS`: every dated section is archived verbatim, and every RC ID is listed in a family.
   - It also prints each line that mentioned "pending". Confirm that each one is in `## Open items` or was resolved.
   - Fix and re-run until it passes.
6. **Clean up and report.** Leave `RESULTS.codex.pre-compaction.md` for the user to delete; never run `rm`. Report:
   - the before and after sizes;
   - the number of families;
   - the merges you made, as `RC-a, RC-b → Fnn`;
   - any family whose check you could not make concrete.

## Rules

- Never drop an RC ID, a pending item or a dated entry. Compaction only moves dated entries and summarizes them.
- Do not change what any entry says happened. A family summarizes the cause and the check; it does not re-judge
  findings.
- Neither file is committed unless the user asks.
- Agents never start a compaction. `python3 <skill dir>/scripts/results_log.py size .` only reports the dated entries
  not yet compacted, and warns above 40 KB, so the user can decide when to run this skill.
