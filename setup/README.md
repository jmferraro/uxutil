# setup

Scripts to run after cloning the repository to configure a new machine.

### setup-agents.sh
*setup-agents.sh \[-f\] \[-n\] \[AGENT...\]*
<br>Set up the coding agents (Claude Code, Codex, omp) by running each agent's *setup.sh* below; with no *AGENT* named, all of them are set up.  Each agent script can also be run on its own (e.g. *claude/setup.sh -n*).  Everything is merged the way *setup-git.sh* merges git settings: anything missing is installed, anything identical is left alone, and anything that differs is kept with a warning unless *-f* is given.  Lists (e.g. *enabledProviders*) never conflict: the entries they lack are appended.  *-n* shows what would be done without making any changes.

| Agent | Source | Installed into |
|---|---|---|
| *claude* | [*CLAUDE.md*](claude/CLAUDE.md), [*settings.json*](claude/settings.json) (merged key by key, needs *jq*), [*spinner.json*](claude/spinner.json) (custom spinner verbs, merged into *settings.json* the same way) | *~/.claude* (or *$CLAUDE_CONFIG_DIR*) |
| *codex* | [*AGENTS.md*](codex/AGENTS.md), [*config.toml*](codex/config.toml) (merged line by line: only *\[table\]* headers and one-line settings) | *~/.codex* (or *$CODEX_HOME*) |
| *omp* | [*commands/*](omp/commands), [*config.yml*](omp/config.yml) (merged through *omp config*, needs *jq*; skipped if *omp* is not installed) | *~/.omp/agent* (or *$PI_CODING_AGENT_DIR*) |

Generic skills, written for any agent, go in [*skills/*](skills) and are installed into every agent's skills directory; skills that only work with one agent go in that agent's own *skills/* directory (e.g. [*omp/skills/*](omp/skills)).  omp has no instructions file here: it also reads *~/.claude/CLAUDE.md* and *~/.codex/AGENTS.md*.

Machine-specific settings stay out of these files: Codex's per-project *trust_level* entries and *tui.\** state, and omp's *setupVersion*, *dev.autoqaConsent* and *disabledExtensions*.

Tests: [*../tests/test-setup-agents.sh*](../tests/test-setup-agents.sh) runs every agent script against a scratch HOME (needs *jq* and *python3* 3.11+; the omp tests need *omp*).

### setup-git.sh
*setup-git.sh \[-f|--force\]*
<br>Apply the git configuration from [*../git/gitconfig*](../git/gitconfig) to the user's global git config (via *git config --global*).  By default any setting that already differs is preserved and a warning is printed; *-f* (*--force*) overwrites existing values without warning.

### setup-vim.sh
*setup-vim.sh \[-f\] \[-n\]*
<br>Symlink the Vim configuration into the home directory: [*../vim/vimrc*](../vim/vimrc) to *~/.vimrc* and the [*../vim/ferraro.vim*](../vim/ferraro.vim) colorscheme to *~/.vim/colors/ferraro.vim*, and create the swap-file directory declared in the vimrc.  An existing *~/.vimrc* that differs is left in place unless *-f* is given; *-n* shows what would be done without making any changes.
