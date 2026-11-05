# Global instructions (all projects, this device)

These apply to every session regardless of project. Project-level `CLAUDE.md`
files may add to or override them.

## Test-first bug fixing (strict red-green TDD)

Fix every bug and review finding with strict red-green TDD, in whatever
language the code is written in:

1. WITHOUT touching the failing code, write a test that exercises the
   defective condition.
2. Build and run it, and CONFIRM it FAILS — and fails for the RIGHT reason
   (the actual defect, not a compile/link error, a wrong assertion, or an
   exhausted fake). A test that never fails against the broken code proves
   nothing. Watch for false reds: a change that doesn't compile reports
   "0 failures" but was never actually exercised — confirm the test binary
   built and the case ran.
3. The new test must add ONLY its own failure — run the whole affected test
   target/suite and confirm exactly the new test fails and everything else
   stays green.
4. Fix the code.
5. Rebuild and re-run the SAME UNCHANGED test — it must now pass. If it
   doesn't, fix the code again; NEVER edit the test to make it pass.

Rules:
- Test seams are test-side, not "changing the failing code": a probe that
  reads state mid-run, a fake/mock/stub, an injected fault (a forced write
  failure, a truncated input) — all fine.
- If the fix needs new production surface (a field, a function), add it as
  INERT plumbing first (the suite stays green, proving no behavior change),
  write the red test against OBSERVABLE behavior so it fails on the old
  logic, then add the logic (green).
- Updating OTHER existing tests for a legitimate refactor is normal (keep
  their assertions; fix fixtures/harness). Rewriting a test that ENCODED the
  old buggy behavior is expected — flag it. The "don't change the test" rule
  applies to the NEW test for THIS bug.
- Never edit the spec/plan to match what the code does without explicit
  sign-off.
- For a heavy integration test that can't be cheaply reverted one line at a
  time, red-first still holds at coarser granularity: run it against the
  artifact built BEFORE the fix exists, watch it fail on the real absence,
  then add the fix and watch it pass.
- NOT every test in a change is red. New behavior gets a red-first pin;
  pre-existing correct behavior is a NAMED GREEN CONTROL; a deliberately
  changed expectation is a SANCTIONED INVERSION with a stated reason.
  Claiming red for all three is a false claim — and the green controls are
  what prove the fix didn't over-reach.
- A fixture that models an external tool's output MUST be validated against
  that tool's real output on a representative host. A fixture encoding a
  shape the tool never emits passes forever and proves nothing — it can hide
  a defect that reaches every user while the suite stays green.
- A search returning zero proves a SPELLING absent, not a CASE absent.
  Before writing "nothing tests this" or "no code does X", construct the
  search and state it — a table-driven or variable-fed test cannot be found
  by grepping a literal. If the search can't be constructed, downgrade the
  claim to "I did not find" and name the search you ran.

Before claiming done, run the project's own gates and report them explicitly:
formatter clean, static analysis/linter clean, the full affected test suite
green, and any sanitizer or race build the project provides. State the
red→green evidence for each fix.
