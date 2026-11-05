# UXUTIL/SETUP

Scripts to run after cloning the repository to configure a new machine.  Only the *setup-\** scripts live here; each coding agent has a sub-directory holding the files installed for it and the *setup.sh* that installs them, and the files supporting those scripts are in sub-directories too.  Each sub-directory has a README describing its contents:
* [*claude/*](claude/README.md) -- Claude Code: global instructions and settings
* [*codex/*](codex/README.md) -- Codex: global instructions and settings
* [*omp/*](omp/README.md) -- omp: a slash command, its skill, and settings
* [*skills/*](skills/README.md) -- generic skills, installed for every agent
* [*common/*](common/README.md) -- the library the agents' *setup.sh* scripts share

## Utilities:

### setup-agents.sh
*setup-agents.sh \[-f\] \[-n\] \[-i|-I\] \[AGENT...\]*
<br>Set up the coding agents (Claude Code, Codex, omp) by running each agent's *setup.sh* below; with no *AGENT* named, all of them are set up.  Each agent script can also be run on its own (e.g. *claude/setup.sh -n*).  Everything is merged the way *setup-git.sh* merges git settings: anything missing is installed, anything identical is left alone, and anything that differs is kept with a warning unless *-f* is given.  Lists (e.g. *enabledProviders*) never conflict: the entries they lack are appended.  *-n* shows what would be done without making any changes.

| Agent | Source | Installed into |
|---|---|---|
| *claude* | [*CLAUDE.md*](claude/CLAUDE.md), every *setting_\*.json* in [*settings/*](claude/settings) (combined into one *settings.json*, then merged key by key, needs *jq*) | *~/.claude* (or *$CLAUDE_CONFIG_DIR*) |
| *codex* | [*AGENTS.md*](codex/AGENTS.md), [*config.toml*](codex/config.toml) (merged line by line: only *\[table\]* headers and one-line settings) | *~/.codex* (or *$CODEX_HOME*) |
| *omp* | [*commands/*](omp/commands), [*config.yml*](omp/config.yml) (merged through *omp config*, needs *jq*; skipped if *omp* is not installed) | *~/.omp/agent* (or *$PI_CODING_AGENT_DIR*) |

Every agent also gets the generic skills in [*skills/*](skills/README.md), plus any skills in its own *skills/* directory.

To leave some settings or files alone on one machine (e.g. a theme you prefer there), list them in that agent's *config.ignore.txt* (e.g. *omp/config.ignore.txt*), which git ignores, so each machine keeps its own.  One name per line, written as setup prints it: a setting such as *theme.dark* or *modelRoles.default*, or an installed file by its full path or its path in the agent's directory (e.g. *skills/do-prompt/SKILL.md*).  A name covers everything under it (*modelRoles*, *skills/do-prompt*); blank lines and lines starting with *#* are skipped.  Listed items are never changed, even with *-f*, and each one that would have changed is reported as *Ignoring ...*:
```
$ cat omp/config.ignore.txt
theme.dark
enabledProviders
$ ./setup-agents.sh -f omp      # updates everything else that differs
```

*-i* asks before each change the run would make, using the wording *-n* prints: on its own, before each addition (a file to install, a setting to set, entries to add to a list), while anything that differs is kept with a warning as usual; with *-f* (*-fi*), before each overwrite too.  The answers are read from the input: *y* makes the change, *n* (or just Enter) skips it this time, and *i* skips it and adds its name to the agent's *config.ignore.txt*, so later runs leave it alone.  If the input runs out, the remaining changes are skipped.  *-I* (or *-fI* to overwrite) asks the same way but disregards *config.ignore.txt*, so what it lists can be reconsidered.  Each question about an item in *config.ignore.txt* says so and offers one more answer, *r*: make the change and remove the item's line from *config.ignore.txt*.  If a broader line covers the item (e.g. *modelRoles* for *modelRoles.default*), that line is removed, so nothing under it is ignored any more.  *y* makes the change once and leaves *config.ignore.txt* as it is, as does *i*; *n* skips it.  *-i* and *-I* cannot be combined with each other or with *-n*.

| | missing | differs |
|---|---|---|
| *(no option)* | added | kept, with a warning |
| *-i* | asked | kept, with a warning |
| *-f* | added | overwritten |
| *-fi* | asked | asked |
Tested by [*../tests/test-setup-agents.sh*](../tests/README.md#test-setup-agentssh).

### setup-git.sh
*setup-git.sh \[-f|--force\]*
<br>Apply the git configuration from [*../git/gitconfig*](../git/README.md#gitconfig) to the user's global git config (via *git config --global*).  By default any setting that already differs is preserved and a warning is printed; *-f* (*--force*) overwrites existing values without warning.

### setup-vim.sh
*setup-vim.sh \[-f\] \[-n\]*
<br>Symlink the Vim configuration into the home directory: [*../vim/vimrc*](../vim/README.md#vimrc) to *~/.vimrc* and the [*../vim/ferraro.vim*](../vim/README.md#ferrarovim) colorscheme to *~/.vim/colors/ferraro.vim*, and create the swap-file directory declared in the vimrc.  An existing *~/.vimrc* that differs is left in place unless *-f* is given; *-n* shows what would be done without making any changes.
