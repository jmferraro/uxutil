#!/usr/bin/env bash
# Set up Codex: global instructions, settings and skills

set -eo pipefail

SRC_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
readonly SRC_DIR
# shellcheck source-path=SCRIPTDIR/../common source=agent-lib.sh
source "$SRC_DIR/../common/agent-lib.sh"

readonly DEST_DIR="${CODEX_HOME:-$HOME/.codex}"

usage() {
  echo "Usage: codex/setup.sh [-f] [-n] [-i|-I] [-h]"
  echo "Merge AGENTS.md (plus setup-coding.md), config.toml and the skills in $SETUP_DIR/skills"
  echo "listed for codex in its manifest.toml into $DEST_DIR"
  agent_options
}

parse_opts "$@"
read_ignore "$SRC_DIR/config.ignore.txt" "$DEST_DIR"
install_instructions "$SRC_DIR/AGENTS.md" "$DEST_DIR/AGENTS.md" "$SRC_DIR/setup-coding.md"
merge_toml "$SRC_DIR/config.toml" "$DEST_DIR/config.toml"
install_skills "$SETUP_DIR/skills" "$DEST_DIR/skills" codex
report "Codex" "$DEST_DIR"
