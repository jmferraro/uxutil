# UXUTIL/SETUP/CODEX

The Codex files installed into *~/.codex* (or *$CODEX_HOME*), and the script that installs them.

## Utilities:

### setup.sh
*codex/setup.sh \[-f\] \[-n\] \[-i|-I\] \[-h\]*
<br>Install *AGENTS.md* with the section in *setup-coding.md* appended, the skills in [*../skills/*](../skills/README.md) that its *manifest.toml* lists for *codex*, and merge *config.toml* into *~/.codex/config.toml*.  [*setup-agents.sh*](../README.md#setup-agentssh) runs it; it can also be run on its own.  *-f*, *-n*, *-i*, *-I* and a *config.ignore.txt* here work as they do for *setup-agents.sh*.

## Files:

### AGENTS.md
*(installed as ~/.codex/AGENTS.md)*
<br>My global instructions for Codex: add the *-OMP* suffix to review files written in *reviews/*; after each review, record in *RESULTS.codex.md* every reason the previous request fell short so the same failures do not recur; and use test-driven development (red first, then green with the same unchanged test) for every defect or behavior change.

### setup-coding.md
*(appended to ~/.codex/AGENTS.md)*
<br>The coding rules: keep code simple (KISS) and cyclomatic complexity minimal, use *goto* only where it lowers complexity, and treat a violation as a review finding.  It is appended to the installed *AGENTS.md* unless that file already has its heading (its first line), so it also reaches an *AGENTS.md* kept because it differs; an *AGENTS.md* listed in *config.ignore.txt* is left alone.  The same section is in [*../claude/setup-coding.md*](../claude/setup-coding.md).

### config.toml
*(merged into ~/.codex/config.toml)*
<br>Codex settings: the model (*gpt-5.5*) and its reasoning effort (*xhigh*).  It is merged line by line, so it may hold only *\[table\]* headers and one-line settings; the rest of the installed file, comments included, is kept as it is.  Machine-specific settings stay out of it: the per-project *trust_level* entries and the *tui.\** state.
