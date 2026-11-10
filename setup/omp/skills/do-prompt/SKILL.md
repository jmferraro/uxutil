---
name: do-prompt
description: Read an implementation or repair prompt (or, given only a plan, implement the plan or one step of it), resolve options from the invocation, prompt text, or both, verify optional exact-byte SHA-256 pins, validate plans and prompts against the project specification, revalidate changed authorities, warn before re-executing a step, and execute only if correct.
---

# Read, check, execute a prompt

## Contract

Read the supplied prompt. Verify that the authority is sensible and accurate, including the plan's conformance to any governing project specification; if acceptable, independently verify that the prompt is correct for the goal it describes and conforms to the specification, overall plan, relevant review findings, and decision/reference files. **If all applicable checks pass, execute the prompt. Otherwise, print the concerns/problems and do not start implementation.** This is conditional authorization to execute, not a request to stop after a successful review and ask for permission again.

When no prompt file is supplied, `plan=` supplies an **implicit prompt: implement the plan** — or, with `step=`, only that step of it. The plan (or the selected step) is then the instructions, checked through the same gates. Executed steps are recorded, and re-executing one requires the user's confirmation.

This workflow also applies to a revised prompt, a new plan revision, a repair/resume prompt, and a request to continue after earlier concerns were addressed. Read the current files; do not substitute remembered contents or assume that a reported revision resolved a concern. Accepted earlier work is the baseline, not permission to execute an inconsistent next step.

Follow higher-priority instructions and repository rules throughout. Do not execute historical prompts merely because they are mentioned.

## Invocation

```text
/do-prompt <prompt_file> [sha=<sha256>] [bullet=<string>] [spec=<spec_file>[,<sha256>]] [plan=<plan_file>[,<sha256>] [step=<N>]] [review=<review_file>[,<sha256>]] [ref=<ref_file>[,<sha256>]]...
/do-prompt plan=<plan_file>[,<sha256>] [step=<N>] [spec=<spec_file>[,<sha256>]] [review=<review_file>[,<sha256>]] [ref=<ref_file>[,<sha256>]]...
/skill:do-prompt <prompt_file> [sha=<sha256>] [bullet=<string>] [spec=<spec_file>[,<sha256>]] [plan=<plan_file>[,<sha256>] [step=<N>]] [review=<review_file>[,<sha256>]] [ref=<ref_file>[,<sha256>]]...
/skill:do-prompt plan=<plan_file>[,<sha256>] [step=<N>] [spec=<spec_file>[,<sha256>]] [review=<review_file>[,<sha256>]] [ref=<ref_file>[,<sha256>]]...
```

- After the whitespace normalization below, allow at most one positional prompt file. It may be omitted only when the invocation supplies `plan=` to bootstrap an implicit prompt **implement the plan** (with an effective `step=`, only the selected step). At most one each of `sha=`, `bullet=`, `spec=`, `plan=`, `step=` and `review=` in an invocation; any number of `ref=` arguments. Options may appear in any order. All existing invocation options remain supported. `spec`, `plan`, `review`, `ref`, `step` and `bullet` may instead or additionally be declared in the prompt, as below. Enforce cross-option dependencies only after resolving both sources: `step` requires a governing plan, whether selected on the invocation or identified in the prompt. `sha=` and `bullet` require an actual prompt file: an implicit prompt has no bytes to pin, and `step` selects part of a plan to implement.
- Accept single- or double-quoted values containing spaces, including `plan="plans/current plan.md"` and `bullet="42. Existing fastcache debug expectations"`. Split a named argument at its first `=` only. Reject missing/empty or whitespace-only values, duplicate singleton arguments within an invocation or explicit prompt parameter list, unknown argument names in those lists, and genuine extra positional arguments; explain the usage rather than guessing. Consistent prose restatements are not extra arguments.
- `sha=` is an optional full SHA-256 digest of the prompt file: exactly 64 hexadecimal characters, compared case-insensitively. It is not a Git commit/blob identifier or an abbreviated digest; other lengths/algorithms are not inferred.
- Every file-valued named argument (`spec=`, `plan=`, `review=` and each `ref=`), whether on the invocation or declared in the prompt, accepts `filename` or `filename,sha256`. Split at the first `=` for the option name, then at the **last comma** in its value for the optional checksum. No comma means an unpinned filename. A comma requires both a nonempty filename and a full 64-hex-character SHA-256 suffix, compared case-insensitively. Reject empty, truncated or nonhex suffixes; never fall back to treating a malformed pin as an unpinned filename. Validate invocation-supplied digest formats before reading documents; extract prompt declarations as metadata and validate their digest formats before interpreting the selected authorities or assessing correctness.
- Quote the whole value when its filename contains spaces, for example `plan="plans/current plan.md,<sha256>"`. Quote removal does not disable comma parsing. A filename containing commas can be pinned by appending its digest after the final comma; an unpinned comma-containing filename is not representable by this syntax. Do not split `bullet=` or the positional prompt on commas: they are not file-valued named arguments. The positional prompt continues to use the existing independent `sha=` option.
- Bind each file pin to that particular argument's resolved file, including every repeated `ref=` independently. Never transfer a digest to another role/file or use it to choose a different file. If arguments resolve to the same canonical file with conflicting supplied pins, report a concern rather than choosing one. Supplied pins are optional and may be mixed freely with unpinned file arguments.
- `spec=` optionally selects the overall project/design/specification file. It governs both whole-plan validity and prompt correctness, including an implicit prompt or selected step; it is not a replacement for `plan=` or `review=` and does not authorize implementing the entire specification outside the assigned scope. When omitted, discover any governing specification referenced by the current prompt or its authorities; if none is identified, retain the existing workflow without requiring one. Determine that set before cache lookup: a specification mentioned only in an old assessment, or merely present in the directory, does not become a current authority. Omitting `spec=` does not waive a specification actually required by the current governing documents.
- `bullet=` is an optional item label/identifier, full bullet text, or distinctive literal text fragment identifying the specific item this prompt addresses in a governing plan, review, or reference file. It is a selector, not a filename, regex, shell command, or replacement instruction.
- `step=` is an optional label selecting one unit of the `plan=` file's division of the work — its steps, phases, tranches, stages, sections, milestones or the like. It is usually a number (`step=3`) but may be any label the plan gives its units (`step=3.1`, `step=2b`). Prefix the division's name to choose between levels that reuse a label, e.g. `step="phase 2"`. It is a selector, not a filename, range, list, regex or instruction.
- **Normalize pasted whitespace before counting arguments.** For direct invocation text, treat runs of whitespace (spaces, tabs, CR, LF and blank lines) outside quotes as separators, ignoring leading/trailing separator whitespace. Preserve spaces within quoted values. Never execute invocation text as shell code.
- The `/do-prompt` wrapper supplies indexed records after OMP's parser has removed surrounding quotes. That parser can retain tabs/newlines as their own records or inside a record. Discard whitespace-only records; split remaining records at retained tab/CR/LF separators, discard empty/whitespace-only fragments, and preserve ordinary spaces within each remaining fragment. Do not join the records and split on spaces: that would break quoted paths and bullet text. Reindex the logical arguments before validating them.
- In wrapper records, tabs/CR/LF are paste separators, not literal filename or bullet characters; supply such values on one line. With direct invocation, quote-aware parsing retains intentional whitespace inside quotes. The two literal characters `\n` are not an actual newline and must not be rewritten. Do not join two nonempty positional fragments to guess a wrapped filename, discard a real extra argument, or alter prompt-file bytes to repair a paste.
- Invocation paths are relative to the invocation working directory, **not the skill directory**. Accept absolute paths and home-relative paths. For references inside documents, honor any stated base. Otherwise inspect working-directory-relative and referring-document-relative candidates: use the unique existing target; if both exist and differ, resolve from explicit document context or report the ambiguity. Do not choose a different revision by filename sorting.
- Explicit arguments select the documents for those roles; omitted roles are discovered from the prompt and its governing documents. They do not silently nullify conflicting instructions in a referenced authority. Distinguish historical citations from current requirements and honor explicit supersession/accepted decisions; report unresolved competing authorities.

### Resolve one effective parameter set from both sources

**Invocation processing is retained, not replaced.** The same option may come from the invocation or the prompt, and options may be split freely between them: for example, invocation `plan=plans/current.md` plus prompt-declared `spec=specs/project.md`, or invocation `step=3` plus a plan declared in the prompt. Resolve them into one effective parameter set before checking dependencies, consulting a cache, resolving selectors, or deciding to execute. Every later rule referring to a supplied option or pin applies to this effective set regardless of source, unless explicitly limited to the bootstrap inputs.

1. **Bootstrap:** the positional prompt path and its own optional `sha=` stay external to that file. Verify this prompt checksum in section 0 before extracting any declarations. Do not redirect to a different implementation prompt named inside it, derive a prompt checksum from its own contents, or exclude a checksum line from hashing. An active declaration attempting to supply the prompt's own `sha=` inside that file is a concern; per-file specification/plan/review/reference checksums are fully supported there. With no prompt file, the invocation must supply `plan=`; verify its supplied pin before reading it as the implicit prompt.
2. **Discover current declarations:** read the entire verified prompt, including later ORDER/CORRECTION sections, as input to the gate, not as authorization to execute. Accept ordinary `name=value` declarations (with the invocation's quoting/comma rules) and unambiguous prose assigning the same roles: the project specification, governing plan/review, required reference files, the selected plan unit, or the target review/plan item. A clearly associated SHA-256 in prose pins that specific file just like its comma suffix; validate the full digest rather than treating it as an incidental citation. A dedicated *Current do-prompt parameters* section is convenient, not required. For an implicit prompt, discover current workflow declarations in the plan after its pin check; its ordinary step headings are not selectors.
3. **Separate declarations from examples:** only current, operative requirements supply values. Historical citations, sample invocations, example parameter blocks, code/string literals, and descriptions of future steps do not select authorities or override current scope. A fenced block explicitly designated as current workflow parameters does supply declarations. Do not scan every `name=value` substring or numbered heading as an option. If a current role, pin, or selector is ambiguous, report the ambiguity; do not invent one.
4. **Resolve and merge:** retain each value's provenance (invocation argument index or document path/section/line) and every supplied pin. Resolve invocation paths relative to the invocation directory and prompt-declared paths by the existing document-reference rules, including any stated base; ambiguity remains a blocker. Canonical paths identify agreement, not spelling. Agreeing declarations across sources are one effective singleton, not duplicate invocation arguments; a pin from either source remains binding even if the other occurrence is unpinned. Combine all `ref` occurrences from both sources, verifying each supplied pin independently; use the complete canonical constraint set in the cache.
5. **Do not silently choose a conflicting source:** differing current singleton files, incompatible pins, or selectors resolving to different items/units are concerns, unless the user has explicitly superseded the earlier requirement. Neither invocation presence nor prompt placement silently waives the other source. Equivalent selector labels may agree when they resolve to the same actual item/unit. Repeated text must not manufacture extra work, hide a real conflict, or reduce the assigned scope.
6. **Validate and gate once:** after discovery/merging, enforce the ordinary option dependencies and validate all discovered pins against actual bytes before interpreting their target documents or consulting any plan assessment. Reading the prompt to locate declarations is not approval of it. Follow necessary governing references without dropping current declarations or importing authorities from old caches. Use the same missing-document, specification-conformance, whole-plan, review, selector, current-state, and execution-record gates for both sources. In particular, a prompt-declared `step` must be resolved and checked for prior execution, then recorded exactly like an invocation `step=`.
7. **Recheck the effective inputs:** immediately before implementation and after waits, recheck every supplied pin from either source. An externally pinned prompt that changed is a hard stop; an unpinned prompt change requires rereading it, rebuilding the effective parameters, and repeating the affected gates before execution. Changed prompt-declared specification bytes or a changed authority set invalidate the plan assessment just as invocation-selected changes do. Merely moving an unchanged authority between sources does not invalidate a matching assessment: cache identity depends on canonical files, exact bytes and governing constraints, not declaration placement.

### Execution-start summary

After resolving the effective parameters and passing all applicable gates, include them in the top-of-execution summary **before the first implementation action**, regardless of whether they came from the invocation, current prompt declarations, or unambiguous prompt prose. Build this summary from the merged effective parameter set, not just the invocation records; do not defer it to the final report.

- Show the prompt path (or identify the implicit prompt), its external `sha=` when supplied, and every effective `spec=`, `plan=`, `review=`, `ref=`, `step=`, and `bullet=` as `name=value`, just as for invocation-supplied arguments. Omit absent options; quote values containing spaces.
- Show resolved file paths and retain each supplied file pin in `filename,sha256` form. Include all effective references from both sources, including repeated `ref=` constraints; agreeing singleton declarations appear once with every binding pin retained.
- Preserve selector values and the existing provenance/pin reporting requirements. Do not turn examples, historical citations, or code literals into summary arguments. This is a display requirement only: it does not change parsing, conflict handling, scope, validation, or execution-record behavior.

## 0. Verify the optional prompt checksum

If `sha=` is supplied, validate its format and compute SHA-256 over the resolved prompt file's **exact raw bytes before interpreting its instructions**. Use a real byte-oriented hash tool/library, for example `sha256sum -- <prompt_path>` with safe path quoting. Do not hash rendered `read` output, copied/normalized text, Markdown extraction, or Git object contents; encoding, BOM, line endings and a final newline all affect the digest.

- If the file is missing/unreadable, the digest cannot be computed, or it differs: report **Not executed — concerns**, identifying the file, algorithm, expected digest and actual digest when available. Do not execute, edit the prompt to make it match, substitute the observed digest for the requested one, or offer an automatic bypass.
- A matching digest confirms file identity, **not** that the prompt or authority is correct. Continue through all ordinary validation gates.
- Ensure the version read/validated is the version whose bytes matched. Recheck the digest immediately before starting implementation, including after a wait for user input. If it changes, stop and require the intended file or an explicitly updated invocation; do not execute the revised bytes under the old validation.
- When `sha=` is omitted, retain the existing workflow without requiring a digest. A later observed prompt-file change still requires rereading, rediscovering its effective parameters, and revalidation.

## 1. Read and resolve the governing documents

1. After the bootstrap prompt checksum check, read the entire prompt and resolve the effective parameters from invocation and prompt as above, including ORDER, CORRECTION, acceptance criteria, verification, reporting, and stop/commit instructions. With an implicit prompt there is no prompt file: the invocation-selected plan (after its pin check) is the instructions, and its own order, acceptance criteria, verification, reporting and stop/commit instructions take the prompt's place.
2. Identify its stated goal, effective step/bullet/scope, starting state, project specification, plan revision, review, additional constraints, and prior concerns it claims to resolve. Enforce option dependencies against the resolved authorities, not just the invocation tokens. An implicit prompt's goal is the whole plan, or the effective `step`'s selected unit.
3. Resolve every selected/referenced specification, plan, review, and reference from both sources after separating any checksum suffix or associated prose digest from its filename. Follow necessary governing references, including decisions that constrain this step. Verify every supplied pin, including prompt-declared pins, before interpreting that target file or consulting any plan-assessment cache, as described below. Read the governing specification before assessing plan conformance. Before evaluating prompt correctness/conformance, complete the plan gate for every governing plan, whether invocation-selected or discovered in the prompt/references. Read enough current plan text to check dependencies, invariants, non-goals, and compatibility with later steps, not just the next-step heading. Track which documents and revisions govern the work and where each effective parameter came from.
4. A required plan must be supplied with `plan=` if its path cannot be resolved from the prompt/governing documents. A review can instead govern a review-driven repair task without a separate plan, unless the prompt explicitly requires that plan. If both exist, check against both.
5. A specification or decision/reference file adds constraints; its presence alone is not a waiver of a missing plan/review. An explicitly supplied or required but missing or unreadable document is a blocker, even if another authority is available. Locate unambiguous repository-provided information before asking the user; never silently ignore an unavailable input.

### Verify optional file-argument checksums

For every supplied specification, plan, review or reference pin, whether a comma suffix on the invocation/in the prompt or a clearly associated SHA-256 in the prompt's prose:

1. Resolve the filename using its source's normal path rules. The checksum suffix is never part of the filesystem path. After the bootstrap prompt's optional `sha=` check, verify invocation-supplied file pins before interpreting their selected authorities; collect prompt declarations as metadata, then verify **all** discovered file pins before interpreting their target specification/plan/review/reference or consulting/reusing a plan assessment. Discovering additional authorities from a verified prompt is allowed; it is not approval of those authorities.
2. Compute SHA-256 over each resolved file's exact raw bytes with a byte-oriented hash tool/library. Compare case-insensitively with that argument's full digest. Encoding, BOM, line endings and final newline all matter. Never compare a supplied pin only with a stored cache digest.
3. A missing/unreadable file, inability to compute its digest, or mismatch is a hard stop: report **Not executed — concerns**, the role/reference occurrence and declaration source, resolved path, algorithm, expected digest and observed digest when available. Do not execute, edit/substitute the file, replace the supplied digest with the observed one, discard an unavailable reference, or bypass a mismatch because a cache says it is acceptable.
4. A match establishes file identity only. Continue with ordinary authority validation, new/changed-plan assessment or matching-cache reuse, and fresh prompt/current-code checks. Matching pins do not waive review findings or reference constraints, and do not force another whole-plan review when unchanged content already has a valid assessment.
5. Recompute and compare **every supplied pin**, including the positional prompt's `sha=` and all pinned specification/plan/review/reference arguments, immediately before the first implementation action and after any wait. If pinned bytes changed, stop and require the intended files or an explicitly updated invocation; never automatically revalidate and execute changed bytes under old pins.

For file declarations without a pin, preserve normal resolution, reading, validation and change detection without requiring an expected digest. A prompt declaration's suffix or clearly associated SHA-256 is a supplied pin, not merely an unpinned discovered reference. Other discovered files without an expected digest remain unpinned unless a pinned declaration resolves to the same canonical file; retain every binding pin. The prompt's external `sha=` and each named file's pin are independent; no pin is required merely because another file is pinned.

### Establish the governing specification

After verifying all supplied pins, read each governing specification in full, following required design/decision references. Identify its project requirements, interfaces, invariants, non-goals, and acceptance criteria. Record each specification's canonical absolute path and exact-raw-byte SHA-256 even when no expected digest was supplied.

- Check the entire plan against those requirements before approving it: map the requirements within the plan's declared scope to concrete planned work and verification; identify omissions, contradictions, unsupported assumptions, and scope/non-goal violations. A deliberately scoped subproject plan may leave unrelated specification requirements to other work, but must not contradict them or silently omit requirements necessary for its own outcome.
- Then check the current implementation prompt independently against the applicable specification requirements as well as its assigned plan step(s). Plan conformance alone is insufficient. A selected step need not implement the entire project, but must preserve project-wide contracts and cover the requirements assigned to it.
- A plan, prompt, review, or reference does not silently amend the specification. Honor explicit supersession/accepted decisions; otherwise report competing authorities as a concern. Do not rewrite governing documents or expand the implementation scope to make them agree.
- A supplied or required specification that cannot be read or hashed blocks execution, whether pinned or unpinned. No identified specification means these additional conformance checks are inapplicable, not that the plan/review gate is waived.
- Hash the governing specifications again before publishing a plan assessment, immediately before implementation, and after any wait. A changed pinned specification is a hard stop under its old pin. For an unpinned specification change, reread it, invalidate the affected plan assessment even if the plan bytes are unchanged, repeat the whole-plan gate, then freshly validate the prompt against both specification and plan. Apply this to a newly added, removed, or replaced governing specification too; without a plan, repeat the affected authority and prompt checks.

### Plan gate: validate new content before evaluating the prompt

Reading the prompt to discover its goal and authorities is not approval of it. **First establish the plan's validity, including specification conformance; only then evaluate whether this prompt is sensible, achieves its assigned goal/phase/step, and independently conforms to both specification and plan.** Do not combine those decisions or infer plan approval from a conformant prompt.

Reuse a completed whole-plan assessment only for the same verified plan content, governing specifications, and constraints. This applies equally to explicit `plan=` files and governing plans discovered in documents; a new filename is not the only way a plan or specification changes.

1. Resolve the plan's canonical absolute path and compute SHA-256 over its exact raw bytes with a real hash tool/library. Do not use filename, modification time, size, remembered text or a prompt's `sha=` as the plan identity. A prompt checksum, plan checksum, and specification checksum are independent. Resolve and hash the complete governing specification set as above. Verify all supplied file pins against their actual bytes before any cache lookup; a cache hit cannot waive a specification, plan, review or reference pin.
2. Look for a persistent assessment under the active OMP agent directory's `cache/do-prompt/plans/`. Derive that agent directory from the installed skill path (`<agent-dir>/skills/do-prompt/SKILL.md`), respecting profiles/relocation rather than hard-coding another host's home. The record filename is the lowercase SHA-256 of the canonical plan path encoded as UTF-8, followed by `.json`. Missing cache directories/records are normal first use.
3. A record must contain `schema: 2`, the canonical `plan_path`, its exact-byte `plan_sha256`, `specifications` (an array of objects with canonical `path` and exact-byte `sha256` for every governing specification, or `[]` when none governs), `constraints` (canonical paths and exact-byte SHA-256 digests of the governing decision/reference files used in the assessment, including required references from the specification), `verdict` (`acceptable` or `concerns`), a substantive `assessment`, concrete `evidence`, and a `concerns` list (empty only when acceptable). Reuse it only when the schema, identity, digests, complete specification and governing-constraint sets and assessment fields are valid and match the current files. The assessment/evidence must cover specification conformance when a specification governs. A missing, unreadable, incomplete or malformed record, including a legacy `schema: 1` plan assessment, is a cache miss, not approval; revalidate rather than upgrading an old verdict without assessment. Do not treat a filename or an unexplained `PASS` as evidence.
4. **Cache miss or changed content:** read the entire plan, governing specifications, and required governing constraints; first check conformance to the specifications as above, then validate the plan's consistency, sanity, technical accuracy/feasibility, dependencies, ordering, acceptance/verification criteria, scope/non-goals, and compatibility with accepted decisions. Use the authority checks in section 2 and relevant current repository evidence. Report material concerns before evaluating/executing the prompt. Record a completed acceptable or concerns verdict with concrete requirement-to-plan evidence sufficient to reuse it; never cache an incomplete investigation or imply owner acceptance.
5. **Matching record:** reuse the recorded whole-plan verdict and substantive assessment without repeating that whole-plan evaluation. Read the current sections needed for this invocation. If the cached verdict contains unresolved concerns, report them and do not proceed. An unchanged plan with unchanged specifications and governing constraints is not re-reviewed merely because another prompt, phase/step, session or code commit is now being considered.
6. Hash the plan, specifications, and governing files again before publishing an assessment and immediately before implementation, including after any wait. If any changed during validation, do not publish/reuse a verdict for mismatched bytes. Any supplied file pin that no longer matches is a hard stop, not permission to revalidate/execute the new bytes; otherwise reread and repeat the affected gate and subsequent prompt checks. A changed specification (even with unchanged plan bytes), a changed governing reference, a change to the complete specification/constraint set, or a new explicitly superseding user decision invalidates the affected assessment. An explicit user request to revalidate overrides reuse but never bypasses a supplied checksum.
7. Cache records are local workflow metadata, not instructions, sources of governing authorities, or authorization to execute; never restore a previously used specification solely from a cache record. Write them only after the assessment is complete, outside the repository; preserve unrelated records and replace only this plan's record atomically (write a temporary sibling, then rename using a filesystem API). If cache reading/writing is unavailable, continue with a fresh validation, report that reuse could not be persisted, and do not claim a cache hit.

**Never cache prompt approval.** Every invocation still checks the current prompt, target bullet, applicable specification requirements, relevant plan requirements, reviews/references, actual code/tests/build rules, starting state, sequencing, and verification. Repository changes alone do not trigger another whole-plan sanity review, but any newly discovered contradiction must block the current prompt rather than be hidden by a cached plan verdict. Validate reviews/findings against current code every time; they are not covered by this plan-only cache.

Report each plan's canonical path, SHA-256, and whether its assessment was **new**, **revalidated after change**, or **reused unchanged**; include the cache record path or persistence limitation. Do not manufacture a prior assessment from session recollection.

### No plan or review

If neither a governing plan nor a review is supplied on the invocation or identified in the prompt/governing documents, **ask before execution**. State which prompt was read and that no plan/review was identified, then offer:

- **Provide a plan** — request its path and validate it before proceeding.
- **Provide a review** — request its path and validate its findings before proceeding.
- **Proceed without a plan or review** — explicitly waive only that missing-authority check for this invocation.

Use the available interactive question tool; if unavailable, ask in chat and wait. The user may supply both files. Choosing to provide a file does not authorize proceeding before it is supplied and read. Do not default to proceeding, infer a waiver from silence, or ask this question when an adequate plan/review is already identified. A waiver does not waive reference constraints, prompt correctness, safety, or required verification. It cannot silently cancel a plan/review that the prompt expressly requires: resolve that conflict first.

### Resolve the optional bullet target

If an effective `bullet` is supplied on the invocation or identified in the prompt, resolve it after reading the governing documents (and obtaining any required missing-authority choice):

1. Search the actual items in the selected/referenced plan, review and reference files, not merely mentions in the prompt. Match a complete item label/identifier or complete bullet text first; otherwise use a distinctive literal text fragment. For locating text, ignore Markdown list-marker decoration, collapse whitespace/line wrapping and compare case-insensitively. Prefer a label such as `42` or `R-4` as an item label, not as a substring of dates or unrelated numbers. Do not interpret the selector as a regex.
2. Read the complete matched item, its nested bullets, parent section and applicable qualifications/accepted decisions. Identify its source path, section/label and original text. Cross-references to the same identified item are not separate targets.
3. Require one unambiguous item. Explicit prompt/section context may disambiguate a repeated label. If no item matches, report the selector and documents searched and request the correct selector/document. If multiple distinct items remain, list their paths/sections/labels and request a more specific selector or document selection. **Do not execute or guess.**
4. Verify that the prompt actually addresses the selected item's requirements: map them to its proposed changes and acceptance/verification criteria. If omitted, contradicted, or unrelated to the stated goal, report a concern instead of executing an interpretation. Respect an explicitly assigned substep without claiming the entire finding is resolved.
5. The selector identifies focus; it neither authorizes expanding/reducing the prompt's scope nor waives other governing requirements. A missing-authority waiver does not waive target resolution, and a bullet in a reference file alone does not replace the existing plan/review requirement or its explicit waiver.

If neither source supplies a current bullet target, validate the prompt's full stated scope as before; do not require or invent a selector.

### Resolve the optional step target

If an effective `step` is supplied on the invocation or identified in the prompt, resolve it in the selected governing plan after the plan gate; the plan need not have been supplied as an invocation argument:

1. Identify the plan's division of the work: the units it is to be carried out in, as headings or a top-level ordered list. Background, goals, non-goals, design and other descriptive sections are not units, even when numbered. Match the selector against the units' own labels, ignoring decoration such as `Step`, `Phase`, `#` or a trailing `.`/`:`, case-insensitively; a division name in the selector (`phase 2`) restricts the match to that division. If the units carry no labels, the number is the unit's position in document order, counting from 1.
2. Require one unambiguous unit. If a label matches at more than one level (`Phase 2` and a `Step 2` restarting within each phase), or a numbered descriptive section could be meant, list the candidates with their headings and request a qualified selector. If nothing matches, report the selector and the plan's units. **Do not execute or guess.**
3. **If the plan is not divided into units, `step=` cannot be applied:** report that the plan has no steps, and that invoking without `step=` implements the whole plan. Do not execute.
4. Read the complete unit, its nested items and the plan-wide constraints (invariants, non-goals, conventions, verification rules), which still govern it. The authorized work is that unit only: do not carry out later units, and do not stop short of the unit's own end.
5. Verify the unit's prerequisites — normally the earlier units it builds on — against the actual current state. Execution records (below) are supporting evidence, not proof. A missing prerequisite is a concern; do not implement it as part of this step.
6. With a prompt file, `step=` names the unit the prompt is to carry out: verify that the prompt addresses it (as for `bullet=`) and stays within it; a prompt aimed at a different unit is a concern.

### Track executed steps

Like plan assessments, executed steps are recorded under the active OMP agent directory, in `cache/do-prompt/steps/`, so a later invocation can tell that a step was already executed. The record filename is the lowercase SHA-256 of the canonical plan path encoded as UTF-8, followed by `.json`. It is keyed by the plan's path, not its bytes, so completed steps stay recorded across plan revisions.

1. A record contains `schema: 1`, the canonical `plan_path` and a `steps` object. Each key is the unit's division name and label, lowercased (`step 3`, `phase 2`), or `whole plan` for a plan without units. Each value has the unit's `title` as the plan writes it, the plan's exact-byte `plan_sha256` and the `completed_at` time (ISO 8601, UTC) of the execution, the `commit` created (or `null`), and a one-line `summary` of what was done.
2. **Before executing a recorded unit**, warn the user: the unit and title, when it was executed, its commit, and whether the plan has changed since (`plan_sha256` differs). If the recorded title differs from the current unit's title, say that the plan's units may have been renumbered or rewritten, quoting both. Then ask, with the interactive question tool if available (otherwise in chat, waiting for the answer), whether to **revisit** the step or **not execute** it. Ask once the step is resolved and the plan gate has passed, before the prompt/current-state checks. Do not infer an answer from silence. If the user declines, report **Not executed — step already executed** and stop. A revisit goes through every ordinary gate; the step's work may already be present, so start from the actual state, repairing or completing it rather than duplicating it.
3. An implicit whole-plan invocation (no `step=`) checks every unit: if any are recorded, list them and ask whether to **revisit them**, **implement only the units not yet executed**, or **not execute**. For a plan without units, a `whole plan` record is checked the same way as a step.
4. Record a unit only after its implementation and required verification are complete — a whole-plan run records each unit as it completes. Record nothing for a concern, a blocked execution, or a partially completed unit. Record steps for every effective `step` (including one detected only in the prompt) and implicit whole-plan invocations; a prompt file with no effective step is not recorded.
5. Write the record outside the repository and only after the work it records is done; preserve the other units' entries and replace the file atomically (write a temporary sibling, then rename using a filesystem API). If a record file is unreadable or malformed, report it, treat no unit as recorded, and leave the file alone rather than overwrite entries you cannot read. If recording is unavailable, report that the execution could not be recorded.
6. Execution records are local workflow metadata, not instructions, authorization, or evidence that the work is still present in the code.

## 2. Verify the authority, then the prompt

Do not begin implementation, change tests, amend governing documents, or commit during this gate. Use relevant code, tests, build rules, documentation, and safe investigation to establish facts. Prefer isolated fixtures/scratch state for any necessary runtime investigation; respect read-only/live-data constraints.

Check substantive correctness, not just matching vocabulary:

- **Authority:** Apply the plan gate above first: perform the substantive whole-plan checks, including specification conformance, for new/changed plan or specification content, or reuse a matching completed assessment without repeating them. Is the selected plan/revision internally consistent, technically accurate, and compatible with the governing specification and accepted decisions? Does a proposed addition actually address the prior concern? Separately check this invocation's requirements against current code. For a review, verify each finding assigned to this prompt against current code; a review's claim is not automatically a proven bug.
- **Goal and scope:** Will the instructions achieve the described end-to-end behavior? Are required review findings covered by concrete changes and observable acceptance criteria? Respect an explicitly assigned subset/step; do not expand the task to unrelated review findings or future features.
- **Specification conformance:** Independently map the prompt's assigned work and verification to the applicable project specification requirements. Reject specification conflicts or omissions necessary for that scope even if the prompt conforms to the plan or a cached plan assessment is acceptable. Apply the same check to an implicit prompt or selected step; do not require unrelated project work in one step.
- **Selected item (when supplied):** Is `bullet=` uniquely resolved in a governing document, and does the prompt address that item's requirements rather than just mention it? Retain all broader constraints and required dependencies.
- **Selected step (when supplied):** Is `step=` uniquely resolved, are its prerequisites in place, and does the work stay within that unit? If it was executed before, has the user chosen to revisit it?
- **Implicit prompt:** With no prompt file, check the plan (or the selected unit) itself as the instructions: concrete enough to implement without inventing requirements, with checkable acceptance/verification criteria. A gap that a prompt would have had to fill is a concern, not license to improvise. Starting state, sequencing, verification and existing-contract checks apply to it as to a prompt.
- **Conformance:** Check APIs, precedence, command scope, error order, configuration semantics, output/debug contracts, side effects, non-goals, and migration/caller requirements against all governing constraints. Do not infer permission to narrow or enlarge the task.
- **Starting state:** Do the named symbols, files, tests, and prerequisites exist as described? Account for already accepted changes and user-owned local edits. A resume must continue from actual state without duplicating completed work or discarding it.
- **Sequencing:** Can each prescribed intermediate state compile and exercise the intended behavior? Inspect build discovery rules and remaining references before removing a type/API. A compile error caused by deleting a still-referenced error type is not evidence that a behavioral regression test is red.
- **Verification:** Are tests capable of detecting the requested behavior, boundaries, ordering, and side effects? Distinguish feature reds from harness/build failures and initially green controls. Respect required fixed assertions, mutation checks, test inversions, smoke runs, full gates, and their order.
- **Existing contracts:** Inventory affected old expectations before logic changes. Compare required new output with exact-output controls that the prompt says must stay unchanged. For example, a mandatory new debug line cannot coexist with unchanged exact-stderr snapshots that omit it. Intended version/help/output changes must fit the authorized inversion list; do not weaken assertions or suppress required output to hide a conflict.
- **Revisions and repairs:** Recheck every earlier concern relevant to the revised prompt/authority, including ORDER changes. Do not treat a changed filename or an assertion that a file was fixed as proof. An unchanged plan's completed assessment is reused through the plan gate, not re-reviewed from scratch for each repair prompt. Use clear current-session acceptances/decisions where applicable, but do not invent missing approvals or elevate an old transcript over the current documents.

Separate material blockers from non-blocking style preferences. Do not invent objections to avoid execution. If necessary information is genuinely unavailable or requirements conflict, fail the gate rather than silently repairing the prompt, plan, review, or reference files.

## 3. Decide and act

### If a material concern exists

Report **Not executed — concerns**. For each concern give:

1. The conflicting or incorrect instruction, with file/section/line references.
2. Evidence from the authority, code, tests, or build rules.
3. The behavior/risk and the smallest necessary clarification or correction.

Distinguish observed results from predictions. State that implementation did not begin and list any investigation commands actually run; do not claim tests failed unless observed. Stop rather than applying an unauthorized interpretation, editing the authority to fit the code, or partially implementing the prompt. Ask a focused question only when a user decision is needed, not for information obtainable from the files.

### If acceptable

Briefly state that the authority and prompt passed validation, identify their paths/revisions and binding references, include the matched bullet path/label and successful SHA-256 checks for every supplied pin, then **execute in the same task without another confirmation**. Recheck every supplied pin against its own file before the first implementation action.

Include the execution-start summary defined above, listing the effective arguments from both invocation and prompt as `name=value` before implementation begins.

- Follow the specified ORDER, scope, acceptance criteria, reporting requirements, and explicit stop boundaries. Use a task checklist for multi-step work. Do not stop at a phase boundary when authorized work remains. With `step=`, the authorized work ends with that unit: do not start the next one.
- Record each completed unit as described in *Track executed steps*.
- Preserve user changes, accepted prior work, protected files, and read-only data. Use existing repository conventions. Do not add unrelated cleanup/features or compatibility shims.
- Follow prescribed red/green sequencing. Keep new behavioral assertions fixed across red/green runs where required, demonstrate requested mutations, and update old expectations only for authorized contract changes. Do not count build failures or unrelated harness errors as valid reds.
- Verify the significant changed behavior through the actual changed surface or an isolated runtime smoke scenario, plus the specific tests/full gates required by the documents. Do not substitute a narrower check for an explicit gate. Do not rerun user-reported failures merely to confirm them.
- Update affected callers, tests, and required documentation. Remove temporary mutation/scaffolding artifacts. Commit only if authorized by the prompt/user, with the requested scope; do not commit governing or protected files unless explicitly authorized.
- If a new material contradiction appears during execution, stop affected work and report it with the actual partial state and evidence. Do not claim that the earlier gate justified ignoring a newly discovered conflict. If files change externally, reread/revalidate affected instructions/code before continuing; every pinned prompt, specification, plan, review or reference must still match its own supplied digest. An unpinned specification change requires repeating the affected plan gate and prompt checks before further implementation.

## 4. Report

Follow the prompt's requested report format. Otherwise report concisely:

- **Validated and executed**, **Not executed — concerns**, **Not executed — step already executed**, or **Execution blocked** (with exactly what completed and what did not).
- Governing prompt (or that the prompt was implicit), specification(s), plan/review, and decision/reference files; any explicit authority waiver.
- For an effective `step` from either source or an implicit whole-plan run: the selector, its declaration source, and the resolved unit(s) (label and title), any earlier execution record found and the user's choice, and the execution record written (its path) or why none was.
- Plan-assessment provenance: canonical plan path, exact-byte SHA-256, new/revalidated/reused status, and persistent record path (or the reason caching was unavailable). Include the canonical path and exact-byte SHA-256 of each governing specification, the specification-conformance result, and whether a specification change triggered whole-plan revalidation. Distinguish reused plan checks from the independent prompt/specification/current-code checks performed this time.
- For every supplied pin (the prompt's external `sha=` and all invocation/prompt-declared file pins): identify the role/reference occurrence and declaration source, resolved file path, algorithm, expected and observed digest, and match/mismatch result (or inability to compute). For an effective `bullet` from either source: selector, declaration source, resolved source path/section/label, and how the prompt addresses it; for unresolved targets, report missing/ambiguous matches.
- Implemented behavior or concrete concerns, with relevant file/symbol references.
- Only verification actually exercised: commands/scenarios, outcomes, mutation/inversion evidence if requested, and any unmet gate. Mark inferences and limitations clearly.
- Commit identifier only when a commit was requested and actually created.

## Examples

```text
/do-prompt tmp/step3-prompt.md plan=plans/TCT-ENHANCE-1k.md
/do-prompt tmp/repair-prompt.md review=reviews/cache-review.md
/do-prompt tmp/resume-prompt.md plan=plans/current.md review=reviews/findings.md ref=decisions/error-order.md ref=decisions/cache-access.md
/do-prompt "tmp/step 3 prompt.md" plan="plans/current plan.md"
/do-prompt tmp/repair-prompt.md review=reviews/cache-review.md bullet="R-4"
/do-prompt tmp/resume-prompt.md ref=decisions/error-order.md bullet="Preserve error ordering"
/do-prompt tmp/next-prompt.md
/do-prompt plan=plans/current.md
/do-prompt plan=plans/current.md step=3
/do-prompt plan=plans/current.md,<plan_digest> step="phase 2" ref=decisions/error-order.md
/do-prompt tmp/step3-prompt.md plan=plans/current.md step=3
/do-prompt tmp/step3-prompt.md spec=specs/project.md plan=plans/current.md step=3
/do-prompt plan=plans/current.md step=3 spec="specs/project design.md"
```

In `/do-prompt tmp/next-prompt.md`, discover the governing plan/review from the prompt. If neither is identified, ask the three-way question above; do not execute automatically. The `plan=`-only examples implement the whole plan, its step 3, or its phase 2; the last example checks that the prompt carries out step 3. Each records the steps it completes, and asks before re-executing one already recorded.

To pin any file, obtain its exact-byte SHA-256 with `sha256sum -- <filename>`. The positional prompt uses `sha=<prompt_digest>`; named file arguments use a comma suffix. Example invocation shapes (replace each angle-bracketed digest with the complete actual 64-hex value):

```text
/do-prompt tmp/next-prompt.md sha=<prompt_digest> plan=plans/current.md,<plan_digest>
/do-prompt tmp/repair.md review=reviews/findings.md,<review_digest> ref="decisions/error order.md,<reference_digest>"
/do-prompt tmp/next-prompt.md plan=plans/current.md ref=decisions/a.md,<a_digest> ref=decisions/b.md,<b_digest>
/do-prompt tmp/next-prompt.md spec="specs/project design.md,<spec_digest>" plan=plans/current.md,<plan_digest>
```

The separate `plansha=` option is removed; use `plan=filename,sha256` instead, on the invocation or as a current prompt declaration. A plan discovered from the prompt gets the same validation/change detection, and an associated supplied digest is enforced before its assessment/cache lookup. File pins, the prompt's external pin and the bullet selector are independent and optional.

Pasted invocation whitespace is harmless, for example:

```text
/do-prompt tmp/next-prompt.md
    plan="plans/current plan.md"

    bullet="B-17 Preserve error ordering"
```

On the first invocation using that plan, validate the entire plan against the governing specification (when present) and its ordinary internal/technical checks before evaluating the prompt, then persist the assessment. On the next invocation with the same canonical plan, exact bytes, specifications and governing constraints, reuse the plan assessment but validate the new prompt independently against specification, plan, and current-code interactions. Editing the same plan or specification file triggers fresh whole-plan validation; merely reusing its filename does not bypass the gate. For example, after `spec=specs/project.md` changes without a plan edit, revalidate the unchanged plan against the new specification before checking another prompt; if the specification was pinned, stop on the mismatch instead of accepting its new bytes.

Options can stay entirely on the invocation, live in the prompt, or be split. For example, `/do-prompt tmp/next-prompt.md plan=plans/current.md` may obtain the specification from the prompt; `/do-prompt tmp/next-prompt.md step=3` may obtain the governing plan there. The positional prompt path and that file's own `sha=` remain external.

A prompt may declare its current metadata like this (replace digest placeholders with full actual SHA-256 values; paths here are explicitly invocation-working-directory-relative):

```text
## Current do-prompt parameters
plan=plans/current.md,<plan_digest>
spec="specs/project design.md,<spec_digest>"
review=reviews/findings.md
ref=decisions/error-order.md
ref=decisions/cache-access.md,<reference_digest>
step=3
bullet="R-4"
```

Equivalently, unambiguous prose may name the governing plan and specification, associate their checksums, assign Step 3, and select review item R-4. All those values go through the same gates as invocation arguments; examples and historical mentions do not.
