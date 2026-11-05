# UXUTIL/SETUP/CLAUDE

The Claude Code files installed into *~/.claude* (or *$CLAUDE_CONFIG_DIR*), and the script that installs them.

## Utilities:

### setup.sh
*claude/setup.sh \[-f\] \[-n\] \[-h\]*
<br>Install *CLAUDE.md*, the generic skills in [*../skills/*](../skills/README.md) and any in a *skills/* directory here, and merge the sections in *settings/* into *settings.json*.  [*setup-agents.sh*](../README.md#setup-agentssh) runs it; it can also be run on its own.  Needs *jq*.  *-f* and *-n* work as they do for *setup-agents.sh*.

## Files:

### CLAUDE.md
*(installed as ~/.claude/CLAUDE.md)*
<br>My global instructions for Claude Code: fix every bug and review finding with strict red-green TDD, and run and report the project's gates (formatter, linter, the full affected test suite) before calling a change done.

### settings/
*(merged into ~/.claude/settings.json)*
<br>Claude Code's *settings.json*, kept in sections: one *setting_\<section\>.json* per section.  Any file added here whose name matches *setting_\*.json* is picked up, and other files are ignored.  The sections are combined, in name order, before anything is merged, so *-n* reports each setting once; two sections setting the same value differently stop the run with an error, even with *-f* (lists, as everywhere, are combined).
* [*setting_general.json*](settings/setting_general.json) -- *xhigh* effort (also for *claude-opus-5-5* in *modelSettings*), the *dark-daltonized* theme, auto-compact off, and the workflow usage warning skipped
* [*setting_spinner.json*](settings/setting_spinner.json) -- my spinner verbs, appended to Claude Code's own
