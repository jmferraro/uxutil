# UXUTIL/SETUP/CODEX

The Codex files installed into *~/.codex* (or *$CODEX_HOME*), and the script that installs them.

## Utilities:

### setup.sh
*codex/setup.sh \[-f\] \[-n\] \[-h\]*
<br>Install *AGENTS.md*, the generic skills in [*../skills/*](../skills/README.md) and any in a *skills/* directory here, and merge *config.toml* into *~/.codex/config.toml*.  [*setup-agents.sh*](../README.md#setup-agentssh) runs it; it can also be run on its own.  *-f* and *-n* work as they do for *setup-agents.sh*.

## Files:

### AGENTS.md
*(installed as ~/.codex/AGENTS.md)*
<br>My global instructions for Codex: add the *-OMP* suffix to review files written in *reviews/*, after each review, record in *RESULTS.codex.md* every reason the previous request fell short so the same failures do not recur, and use test-driven development (red first, then green with the same unchanged test) for every defect or behavior change.

### config.toml
*(merged into ~/.codex/config.toml)*
<br>Codex settings: the model (*gpt-5.5*) and its reasoning effort (*xhigh*).  It is merged line by line, so it may hold only *\[table\]* headers and one-line settings; the rest of the installed file, comments included, is kept as it is.  Machine-specific settings stay out of it: the per-project *trust_level* entries and the *tui.\** state.
