#!/usr/bin/env bash
# Set up Claude Code: global instructions, settings and skills

set -eo pipefail

SRC_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
readonly SRC_DIR
# shellcheck source-path=SCRIPTDIR/.. source=agent-lib.sh
source "$SRC_DIR/../agent-lib.sh"

readonly DEST_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

usage() {
  echo "Usage: claude/setup.sh [-f] [-n] [-h]"
  echo "Merge CLAUDE.md, settings.json and the skills in $SETUP_DIR/skills"
  echo "and $SRC_DIR/skills into $DEST_DIR; the spinner verbs in spinner.json"
  echo "are merged into settings.json too"
  agent_options
}

parse_opts "$@"
install_file "$SRC_DIR/CLAUDE.md" "$DEST_DIR/CLAUDE.md"
merge_json "$SRC_DIR/settings.json" "$DEST_DIR/settings.json"
merge_json "$SRC_DIR/spinner.json" "$DEST_DIR/settings.json"
install_skills "$SETUP_DIR/skills" "$DEST_DIR/skills"
install_skills "$SRC_DIR/skills" "$DEST_DIR/skills"
report "Claude Code" "$DEST_DIR"
