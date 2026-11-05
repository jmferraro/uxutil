#!/usr/bin/env bash
# Set up Codex: global instructions, settings and skills

set -eo pipefail

SRC_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
readonly SRC_DIR
# shellcheck source-path=SCRIPTDIR/../common source=agent-lib.sh
source "$SRC_DIR/../common/agent-lib.sh"

readonly DEST_DIR="${CODEX_HOME:-$HOME/.codex}"

usage() {
  echo "Usage: codex/setup.sh [-f] [-n] [-h]"
  echo "Merge AGENTS.md, config.toml and the skills in $SETUP_DIR/skills"
  echo "and $SRC_DIR/skills into $DEST_DIR"
  agent_options
}

parse_opts "$@"
install_file "$SRC_DIR/AGENTS.md" "$DEST_DIR/AGENTS.md"
merge_toml "$SRC_DIR/config.toml" "$DEST_DIR/config.toml"
install_skills "$SETUP_DIR/skills" "$DEST_DIR/skills"
install_skills "$SRC_DIR/skills" "$DEST_DIR/skills"
report "Codex" "$DEST_DIR"
