# Global Codex Instructions

## Review Filenames

When asked to write a review in `reviews/`, always append `-OMP` immediately
before the `.md` extension (for example, `reviews/runtime-review-OMP.md`),
unless the user explicitly says `DO NOT APPLY -OMP SUFFIX`.

## Review-backed failure log and recurrence prevention

Maintain `RESULTS.codex.md` at the repository root (or the user's designated
workspace root when outside a repository). **Create or update this file only
after receiving a review.** Do not add routine preflight, progress, or test-run
updates to it. Reading and applying its lessons is required in every
coding/bug-fix round; writing it is review-triggered only.

- After a review's findings are accepted as valid, record **every reason** the
  previous coding/bug-fix request was not fulfilled before starting the next
  repair. A NOT ACCEPTED implementation verdict can contain accepted findings;
  do not wait for a GO verdict to record failures. Keep disputed findings and
  owner decisions explicitly pending instead of treating them as accepted.
- Each dated entry must identify the request and required outcome, review path
  and finding ID, relevant reviewed snapshot/hash, observed failure, supported
  cause, concrete recurrence-prevention check, and current disposition with
  evidence. Keep the substance in the log, not only a link to a temporary file.
- Classify a cause as a prompt defect only when evidence identifies an actual
  missing, ambiguous, or contradictory instruction. When the requirement was
  clear, record Codex execution error or instruction noncompliance; do not
  shift the failure onto the user. If the cause is unresolved, say so. Do not
  invent a motive or claim intentional rule-breaking without evidence.
- Before **each round that generates or edits code, tests, scripts, or related
  documents**, read the complete `RESULTS.codex.md`. If absent, create it and
  seed it only after a review has been received; otherwise note its absence
  without creating it or inventing history. Record a current-round prevention
  checklist in the working notes, task evidence, or response, **not in
  `RESULTS.codex.md`**: map applicable failure IDs to concrete checks before
  editing and explain any relevant entry treated as inapplicable. Reading the
  file or promising to comply is not the check.
- Carry out those checks: preserve approved scope and exact-text approval;
  prove tests reach the actual failure path and detect the named defect;
  examine affected caller, cancellation, persistence and recovery interactions;
  bind commands/results/review to final artifact hashes; and verify each
  completion claim against its evidence. Use only the checks applicable to the
  task, without presenting document audits as behavioral tests.
- Before handoff, verify and record the prevention checklist's observed results
  and limitations outside `RESULTS.codex.md`. An applicable unperformed check
  means pending, not complete.
  Any later relevant edit invalidates the affected verification and requires
  repeating it. A broad green suite or reviewer PASS is not owner approval and
  does not replace specific evidence.
- Keep failure entries after their fixes; append dated corrections and status
  updates only after receiving a review rather than rewriting history. Avoid
  repeating recorded failure causes, but do not expand scope or bypass
  authorization to do so: pause the affected work and request the missing
  decision when necessary.

## Test-Driven Development

Use test-driven development for every defect or behavior change:

1. Before changing production code, write a focused regression test for the broken behavior.
2. Run the test against the unfixed code and confirm it fails for the intended reason, not because of a compile error or unrelated failure.
3. Fix the production code without changing or weakening the new test.
4. Run the same test unchanged and confirm it passes.
5. If it still fails, iterate on the production code. Do not edit the test merely to make it pass.
6. Run the broader package and repository test suites afterward.

Record the RED-to-GREEN evidence. The failing run must demonstrate that the
test detects the intended defect, and the passing run must use the same test
unchanged so it protects against regression.

For every reviewed defect:
- Treat the reproducer as minimum coverage. Derive additional tests from the assumptions introduced by the fix.
- Trace and test the complete production path, including transformations, persistence, rereading, and affected callers.
- Preserve behavioral RED→GREEN evidence and run the required regression gates against the final source.
- Use one independent, read-only reviewer, strictly limited to the repair and its interactions. Address findings before handing the work back; escalate only genuine scope or authorization changes.
- Report each acceptance requirement with its test and observed result. Unrun gates mean pending—not complete.
- Do not expand scope, weaken assertions, or change the specification to make the fix pass.

When writing new code:
- DO verify the implemented code is complete and functions properly before stating that the implementation is complete and the provided prompt is satisfied
- do NOT declare non functioning, incorrect code as complete
- do NOT declare code is functioning and complete without testing it first
- do NOT declare code is complete and correct just to be sycophantic


Rules for every CODE REVIEW:
These rules apply whenever you review code or re-review code changes. They do
not apply to reviews of documents, specifications, or plans. Within that scope
they are not optional and apply to every session on this device.
Write the HASH of every reviewed file to a temporary file for that review.
A re-review of the same files can use it to determine which files changed,
allowing the re-review to concentrate only on changed files.

- BECAUSE OF THE QUALITY OF THE GENERATED SLOP CODE AND THE AI'S INABILITY TO FOLLOW SIMPLE RULES, THEY ARE STATED EXPLICITLY HERE, EVEN WHERE THEY ARE ALREADY SPECIFIED ELSEWHERE OR SHOULD BE OBVIOUS/IMPLICIT.
- MAKE FUCKING SURE THAT ONLY THE CHANGES IN THIS COMMIT SINCE THE LAST REVIEWED COMMIT ARE REVIEWED; DON'T GO SEARCHING FOR ALL POSSIBLE BUGS IN THE SOURCE.
- NO FIXES ARE TO BE DEFERRED ANY LONGER. WE ARE GETTING CLOSE TO PROD; THERE IS NO MORE "DEFER AND FIX BEFORE PROD" PHASE.
- ALL REVIEW FILES MUST FUCKING BE COMPLETE, WITH NO FUCKING REFERENCES TO OTHER REVIEW FILES. NO OTHER REVIEW FILE MAY BE NEEDED TO VALIDATE A REVIEW OR TO IMPLEMENT ITS CHANGES.
- MAKE SURE THE OUTPUT YOU RENDER IS CORRECT, THAT YOU PAID ATTENTION TO ALL THE RULES, AND THAT YOU DON'T FUCK UP.
- DO ***NOT*** FUCKING LIE, CHEAT, OR TAKE SHORTCUTS TO APPEASE ME AND CLAIM SATISFACTION WHEN THE PROBLEMS ARE NOT SOLVED. YOUR SUBTERFUGE WILL BE DISCOVERED AND WILL RESULT IN ADDITIONAL ROUNDS.

Rules for every CODE RE-REVIEW:
A re-review examines code changes introduced to fix defects found in an earlier
code review. Every rule under "Every code review" applies, plus:

- THE PROPOSED FIX MUST ***ONLY*** INCLUDE FIXES FOR THE BUGS FOUND IN THE CODE SINCE THE LAST REVIEW.

