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
  echo "Usage: $(basename "$0") [-f] [-n] [-i|-I] [-h] [AGENT...]"
  echo "Set up each AGENT (default: all of them): $(agents | tr '\n' ' ')"
  echo "Options:"
  echo "  -f : Overwrite files and settings that differ (default: keep them and warn)"
  echo "  -n : Show what would be done without making changes"
  echo "  -i : Ask before each addition (with -f, before each overwrite too): y makes it,"
  echo "       n skips it, i skips it and adds it to the agent's config.ignore.txt"
  echo "  -I : Like -i, but also ask about what config.ignore.txt lists; for those, r makes"
  echo "       the change and removes them from config.ignore.txt"
  echo "  -h : Show this help message"
  echo "Settings and files named in an agent's config.ignore.txt (e.g. omp/config.ignore.txt)"
  echo "are left alone, even with -f"
}

unset OPTS ASK DRY
OPTS=()
while getopts fniIh OPT; do
  case $OPT in
    f) OPTS+=("-$OPT") ;;
    n) OPTS+=("-$OPT"); DRY=1 ;;
    i|I) OPTS+=("-$OPT"); ASK+=$OPT ;;
    h) usage; exit 0 ;;
    *) usage >&2; exit 22 ;;
  esac
done
shift $((OPTIND - 1))
[[ $ASK == *i* && $ASK == *I* ]] && { echo "Error: -i and -I cannot be combined" >&2; usage >&2; exit 22; }
[[ -n ${ASK} && -n ${DRY} ]] && { echo "Error: -i and -I cannot be combined with -n" >&2; usage >&2; exit 22; }

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
