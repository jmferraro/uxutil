#!/usr/bin/env bash
# setup-agents.sh - set up the coding agents (Claude Code, Codex, omp) by
# running each agent's setup.sh from its subdirectory of setup/

set -eo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
readonly SCRIPT_DIR

# agents - list the agents: the subdirectories holding a setup.sh
agents() {
  local SETUP
  for SETUP in "$SCRIPT_DIR"/*/setup.sh; do
    [[ -f $SETUP ]] && basename "$(dirname "$SETUP")"
  done
  return 0
}

usage() {
  echo "Usage: $(basename "$0") [-f] [-n] [-h] [AGENT...]"
  echo "Set up each AGENT (default: all of them): $(agents | tr '\n' ' ')"
  echo "Options:"
  echo "  -f : Overwrite files and settings that differ (default: keep them and warn)"
  echo "  -n : Show what would be done without making changes"
  echo "  -h : Show this help message"
}

unset OPTS
OPTS=()
while getopts fnh OPT; do
  case $OPT in
    f|n) OPTS+=("-$OPT") ;;
    h) usage; exit 0 ;;
    *) usage >&2; exit 22 ;;
  esac
done
shift $((OPTIND - 1))

SELECTED=("$@")
[[ $# -eq 0 ]] && mapfile -t SELECTED < <(agents)
for AGENT in "${SELECTED[@]}"; do
  [[ -f $SCRIPT_DIR/$AGENT/setup.sh ]] || { echo "Unknown agent: $AGENT" >&2; usage >&2; exit 22; }
done

RET=0
for AGENT in "${SELECTED[@]}"; do
  echo "== $AGENT"
  "$SCRIPT_DIR/$AGENT/setup.sh" "${OPTS[@]}" || RET=1
done
exit $RET
