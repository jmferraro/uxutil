# UXUTIL/SETUP

Scripts to run after cloning the repository to configure a new machine.  Only the *setup-\** scripts live here; each coding agent has a sub-directory holding the files installed for it and the *setup.sh* that installs them, and the files supporting those scripts are in sub-directories too.  Each sub-directory has a README describing its contents:
* [*claude/*](claude/README.md) -- Claude Code: global instructions and settings
* [*codex/*](codex/README.md) -- Codex: global instructions and settings
* [*omp/*](omp/README.md) -- omp: a slash command, its skill, and settings
* [*skills/*](skills/README.md) -- generic skills, installed for every agent
* [*common/*](common/README.md) -- the library the agents' *setup.sh* scripts share

## Utilities:

### setup-agents.sh
*setup-agents.sh \[-f\] \[-n\] \[AGENT...\]*
<br>Set up the coding agents (Claude Code, Codex, omp) by running each agent's *setup.sh* below; with no *AGENT* named, all of them are set up.  Each agent script can also be run on its own (e.g. *claude/setup.sh -n*).  Everything is merged the way *setup-git.sh* merges git settings: anything missing is installed, anything identical is left alone, and anything that differs is kept with a warning unless *-f* is given.  Lists (e.g. *enabledProviders*) never conflict: the entries they lack are appended.  *-n* shows what would be done without making any changes.

| Agent | Source | Installed into |
|---|---|---|
| *claude* | [*CLAUDE.md*](claude/CLAUDE.md), every *setting_\*.json* in [*settings/*](claude/settings) (combined into one *settings.json*, then merged key by key, needs *jq*) | *~/.claude* (or *$CLAUDE_CONFIG_DIR*) |
| *codex* | [*AGENTS.md*](codex/AGENTS.md), [*config.toml*](codex/config.toml) (merged line by line: only *\[table\]* headers and one-line settings) | *~/.codex* (or *$CODEX_HOME*) |
| *omp* | [*commands/*](omp/commands), [*config.yml*](omp/config.yml) (merged through *omp config*, needs *jq*; skipped if *omp* is not installed) | *~/.omp/agent* (or *$PI_CODING_AGENT_DIR*) |

Every agent also gets the generic skills in [*skills/*](skills/README.md), plus any skills in its own *skills/* directory.
Tested by [*../tests/test-setup-agents.sh*](../tests/README.md#test-setup-agentssh).

### setup-git.sh
*setup-git.sh \[-f|--force\]*
<br>Apply the git configuration from [*../git/gitconfig*](../git/README.md#gitconfig) to the user's global git config (via *git config --global*).  By default any setting that already differs is preserved and a warning is printed; *-f* (*--force*) overwrites existing values without warning.

### setup-vim.sh
*setup-vim.sh \[-f\] \[-n\]*
<br>Symlink the Vim configuration into the home directory: [*../vim/vimrc*](../vim/README.md#vimrc) to *~/.vimrc* and the [*../vim/ferraro.vim*](../vim/README.md#ferrarovim) colorscheme to *~/.vim/colors/ferraro.vim*, and create the swap-file directory declared in the vimrc.  An existing *~/.vimrc* that differs is left in place unless *-f* is given; *-n* shows what would be done without making any changes.
