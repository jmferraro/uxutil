# UXUTIL/SETUP/OMP

The omp files installed into *~/.omp/agent* (or *$PI_CODING_AGENT_DIR*), and the script that installs them.  There is no instructions file for omp: as well as its own *~/.omp/agent/AGENTS.md*, it reads *~/.claude/CLAUDE.md* and *~/.codex/AGENTS.md*.

## Utilities:

### setup.sh
*omp/setup.sh \[-f\] \[-n\] \[-i|-I\] \[-h\]*
<br>Install the slash commands in *commands/*, the skills in *skills/* and the generic ones in [*../skills/*](../skills/README.md), and merge *config.yml* into omp's global settings through *omp config*.  [*setup-agents.sh*](../README.md#setup-agentssh) runs it; it can also be run on its own.  Needs *jq*; the settings are skipped, with a warning, if *omp* is not installed.  *-f*, *-n*, *-i*, *-I* and a *config.ignore.txt* here work as they do for *setup-agents.sh*.  Afterwards run */reload-plugins* in omp, or start a new session, to load the changes.

## Files:

### commands/do-prompt.md
*/do-prompt \<prompt_file\> \[sha=\<sha256\>\] \[bullet=\<string\>\] \[spec=\<file\>\[,\<sha256\>\]\] \[plan=\<file\>\[,\<sha256\>\] \[step=\<N\>\]\] \[review=\<file\>\[,\<sha256\>\]\] \[ref=\<file\>\[,\<sha256\>\]\]...*
<br>*/do-prompt plan=\<file\>\[,\<sha256\>\] \[step=\<N\>\] \[spec=\<file\>\[,\<sha256\>\]\] \[review=\<file\>\[,\<sha256\>\]\] \[ref=\<file\>\[,\<sha256\>\]\]...*
<br>The */do-prompt* slash command: it passes its invocation arguments, with any whitespace pasted into them cleaned up, to the *do-prompt* skill below.  Existing invocation options remain supported; the skill also discovers current options in the prompt and combines both sources before validation.  Every file in *commands/* is installed as a command, so keep only commands there.

### skills/do-prompt/SKILL.md
*(installed as ~/.omp/agent/skills/do-prompt/SKILL.md)*
<br>The *do-prompt* skill: read an implementation or repair prompt, verify any SHA-256 pins on it and on the specification, plan, review and reference files named, check that the plan is sound and conforms to the project specification, independently check that the prompt is correct and conforms to both specification and plan, and then execute the prompt only if every check passes; otherwise print the concerns and change nothing.  Given *plan=* without a prompt file, it implements the plan, or with *step=* only that step (phase, section, etc.) of it.  Each step it completes is recorded in *~/.omp/agent/cache/do-prompt/steps*, and before executing a step again it warns that the step was already done and asks whether to revisit it.

*spec=\<file\>\[,\<sha256\>\]* optionally supplies the overall project/design/specification, with the same quoting, path resolution and exact-byte checksum rules as *plan=*.  A specification constrains the assigned scope; it neither expands a step to the entire project nor replaces a required plan/review.  If no specification is supplied or identified in the governing documents, the existing checks still apply.

*plan*, *spec*, *review*, repeated *ref*, *step*, and *bullet* may be supplied on the invocation, declared in the prompt, or split between both.  The skill recognizes current *name=value* declarations and unambiguous prose, including file-associated SHA-256 digests; a dedicated parameters section is optional.  Historical examples and code literals do not supply options.  All effective values go through the same checksum, authority, selector, cache, and execution-record gates.  An invocation *step=* can therefore use a plan identified only in the prompt.

Agreeing declarations across sources preserve every supplied pin.  References combine; conflicting singleton files, pins, or targets block execution rather than silently preferring one source.  Moving an unchanged authority between invocation and prompt does not itself invalidate its cached plan assessment.  The positional prompt path and that prompt file's own *sha=* remain external, avoiding self-referential hashing; invocation syntax and exact-byte prompt checksum semantics are unchanged.

Before implementation begins, the execution-start summary lists the merged effective arguments as *name=value*, whether they came from the invocation or the prompt (including unambiguous prose).  It includes supplied file pins, all references, and the selected step/bullet, with agreeing singleton declarations shown once.  Prompt-declared arguments are not deferred to the final report.

Plan assessments in *cache/do-prompt/plans/* bind the plan to the canonical paths and exact-byte SHA-256 hashes of its governing specifications and references.  Changing the specification revalidates the entire plan against it before checking the next prompt, even when the plan file is unchanged.  Adding, removing or replacing a governing specification also invalidates reuse.  A changed pinned specification stops execution on the checksum mismatch instead.  Legacy plan-assessment records are revalidated into schema 2; executed-step records are unchanged.

```text
/do-prompt prompts/step3.md plan=plans/tool.md spec=specs/tool.md
/do-prompt plan=plans/tool.md step=3 spec="specs/tool design.md,<sha256>"
```

For a mixed invocation, keep the plan on the command line:

```text
/do-prompt prompts/step3.md plan=plans/tool.md
```

The prompt can contain the remaining current declarations, with the same optional comma-suffixed file pins as invocation arguments:

```text
## Current do-prompt parameters
spec=specs/tool.md
review=reviews/findings.md
step=3
bullet=R-4
ref=decisions/output-contract.md
ref=decisions/error-order.md
```

### config.yml
*(merged into omp's global settings)*
<br>omp settings: the model roles (*default* and *smol*), *codex* as the enabled provider, the *obsidian* dark theme, *unicode* symbols and the *claude* composer shape.  Machine-specific settings stay out of it: *setupVersion*, *dev.autoqaConsent* and *disabledExtensions*.
