#!/usr/bin/env bash
# Set up Claude Code: global instructions, settings and skills

set -eo pipefail

SRC_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
readonly SRC_DIR
# shellcheck source-path=SCRIPTDIR/../common source=agent-lib.sh
source "$SRC_DIR/../common/agent-lib.sh"

readonly DEST_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
# the sections of settings.json in $SRC_DIR/settings
readonly SETTINGS_MASK='setting_*.json'

usage() {
  echo "Usage: claude/setup.sh [-f] [-n] [-i|-I] [-h]"
  echo "Merge CLAUDE.md and the skills in $SETUP_DIR/skills and"
  echo "$SRC_DIR/skills into $DEST_DIR, and every"
  echo "$SRC_DIR/settings/$SETTINGS_MASK into its settings.json"
  agent_options
}

parse_opts "$@"
read_ignore "$SRC_DIR/config.ignore.txt" "$DEST_DIR"
install_file "$SRC_DIR/CLAUDE.md" "$DEST_DIR/CLAUDE.md"
merge_json_dir "$SRC_DIR/settings" "$SETTINGS_MASK" "$DEST_DIR/settings.json"
install_skills "$SETUP_DIR/skills" "$DEST_DIR/skills"
install_skills "$SRC_DIR/skills" "$DEST_DIR/skills"
report "Claude Code" "$DEST_DIR"
