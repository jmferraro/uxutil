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
# Claude Code's own config: in CLAUDE_CONFIG_DIR when that is set, not under it
readonly CLAUDE_JSON="${CLAUDE_CONFIG_DIR:-$HOME}/.claude.json"

usage() {
  echo "Usage: claude/setup.sh [-f] [-n] [-i|-I] [-h]"
  echo "Merge CLAUDE.md and the skills in $SETUP_DIR/skills and"
  echo "$SRC_DIR/skills into $DEST_DIR, and every"
  echo "$SRC_DIR/settings/$SETTINGS_MASK into its settings.json;"
  echo "warn unless $CLAUDE_JSON turns off \"← opens agents\""
  agent_options
}

# check_left_arrow - warn unless CLAUDE_JSON turns off "← opens agents".  It is
# only checked, never set: Claude Code rewrites the file while it runs, so the
# change is left to /config, which lists it only while agent view is on
check_left_arrow() {
  jq -e '.leftArrowOpensAgents == false' "$CLAUDE_JSON" >/dev/null 2>&1 ||
    warn "leftArrowOpensAgents is not false in $CLAUDE_JSON, so ← on an empty prompt opens agent view: turn off \"← opens agents\" in /config (it is listed only while agent view is on; claude --settings '{\"disableAgentView\":false}' turns it on for one session)"
}

parse_opts "$@"
read_ignore "$SRC_DIR/config.ignore.txt" "$DEST_DIR"
install_file "$SRC_DIR/CLAUDE.md" "$DEST_DIR/CLAUDE.md"
install_tree "$SRC_DIR/hooks" "$DEST_DIR/hooks"
merge_json_dir "$SRC_DIR/settings" "$SETTINGS_MASK" "$DEST_DIR/settings.json"
install_skills "$SETUP_DIR/skills" "$DEST_DIR/skills"
install_skills "$SRC_DIR/skills" "$DEST_DIR/skills"
check_left_arrow
report "Claude Code" "$DEST_DIR"
