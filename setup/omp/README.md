# UXUTIL/SETUP/OMP

The omp files installed into *~/.omp/agent* (or *$PI_CODING_AGENT_DIR*), and the script that installs them.  There is no instructions file for omp: as well as its own *~/.omp/agent/AGENTS.md*, it reads *~/.claude/CLAUDE.md* and *~/.codex/AGENTS.md*.

## Utilities:

### setup.sh
*omp/setup.sh \[-f\] \[-n\] \[-h\]*
<br>Install the slash commands in *commands/*, the skills in *skills/* and the generic ones in [*../skills/*](../skills/README.md), and merge *config.yml* into omp's global settings through *omp config*.  [*setup-agents.sh*](../README.md#setup-agentssh) runs it; it can also be run on its own.  Needs *jq*; the settings are skipped, with a warning, if *omp* is not installed.  *-f* and *-n* work as they do for *setup-agents.sh*.  Afterwards run */reload-plugins* in omp, or start a new session, to load the changes.

## Files:

### commands/do-prompt.md
*/do-prompt \<prompt_file\> \[sha=\<sha256\>\] \[bullet=\<string\>\] \[plan=\<file\>\[,\<sha256\>\]\] \[review=\<file\>\[,\<sha256\>\]\] \[ref=\<file\>\[,\<sha256\>\]\]...*
<br>The */do-prompt* slash command: it passes its arguments, with any whitespace pasted into them cleaned up, to the *do-prompt* skill below.  Every file in *commands/* is installed as a command, so keep only commands there.

### skills/do-prompt/SKILL.md
*(installed as ~/.omp/agent/skills/do-prompt/SKILL.md)*
<br>The *do-prompt* skill: read an implementation or repair prompt, verify any SHA-256 pins on it and on the plan, review and reference files named, check that the plan is sound and that the prompt is correct and conforms to it, and then execute the prompt only if every check passes; otherwise print the concerns and change nothing.

### config.yml
*(merged into omp's global settings)*
<br>omp settings: the model roles (*default* and *smol*), *codex* as the enabled provider, the *obsidian* dark theme, *unicode* symbols and the *claude* composer shape.  Machine-specific settings stay out of it: *setupVersion*, *dev.autoqaConsent* and *disabledExtensions*.
