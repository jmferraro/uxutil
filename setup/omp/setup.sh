#!/usr/bin/env bash
# Set up omp: slash commands, skills and settings.  No global instructions
# file is installed for omp: besides its own ~/.omp/agent/AGENTS.md it reads
# ~/.claude/CLAUDE.md and ~/.codex/AGENTS.md (omp's disabledExtensions
# setting turns one off, e.g. "context-file:user:CLAUDE.md")

set -eo pipefail

SRC_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
readonly SRC_DIR
# shellcheck source-path=SCRIPTDIR/../common source=agent-lib.sh
source "$SRC_DIR/../common/agent-lib.sh"

readonly DEST_DIR="${PI_CODING_AGENT_DIR:-$HOME/.omp/agent}"

usage() {
  echo "Usage: omp/setup.sh [-f] [-n] [-h]"
  echo "Merge the commands, the skills in $SETUP_DIR/skills and"
  echo "$SRC_DIR/skills, and config.yml (via 'omp config') into $DEST_DIR"
  agent_options
}

parse_opts "$@"
install_tree "$SRC_DIR/commands" "$DEST_DIR/commands"
install_skills "$SETUP_DIR/skills" "$DEST_DIR/skills"
install_skills "$SRC_DIR/skills" "$DEST_DIR/skills"
merge_omp_config "$SRC_DIR/config.yml"
report "omp" "$DEST_DIR" "In omp, run /reload-plugins or start a new session to load the changes"
