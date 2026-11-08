#!/usr/bin/env bash
# test-setup-git.sh - tests for setup/setup-git.sh
#
# Each test copies the script beside a small fixture git/gitconfig and runs it
# against a global git config file of its own (GIT_CONFIG_GLOBAL), so the real
# ~/.gitconfig is never read or touched.

set -o pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readonly REPO_DIR
WORK=$(mktemp -d "${TMPDIR:-/tmp}/test-setup-git.XXXXXX")
trap 'rm -rf "${WORK}"' EXIT
PASSED=0
FAILED=0

# ---- harness ---------------------------------------------------------------

# env_new NAME - set T to a new test dir with the script, a fixture gitconfig
# (user.name, alias.st and core.compression) and an empty global config
env_new() {
  TEST="$1"
  T="$WORK/$1"
  unset SHOWN
  mkdir -p "$T/setup" "$T/git"
  cp "$REPO_DIR/setup/setup-git.sh" "$T/setup/"
  printf '[user]\n   name = Joe\n[alias]\n   st = "status -uno"\n[core]\n   compression = 1\n' > "$T/git/gitconfig"
  : > "$T/global"
}

# run_with ANSWERS ARG... - run the script with ANSWERS (printf %b) as its input
run_with() {
  local ANSWERS="$1"
  shift
  GIT_CONFIG_GLOBAL="$T/global" GIT_CONFIG_SYSTEM=/dev/null "$T/setup/setup-git.sh" "$@" > "$T/out" 2>&1 < <(printf '%b' "$ANSWERS")
  RC=$?
}
run() { run_with '' "$@"; }

# g KEY - the global value of KEY
g() { GIT_CONFIG_GLOBAL="$T/global" GIT_CONFIG_SYSTEM=/dev/null git config --global --get "$1"; }
set_g() { GIT_CONFIG_GLOBAL="$T/global" GIT_CONFIG_SYSTEM=/dev/null git config --global "$1" "$2"; }

check() {
  local DESC="$1"
  shift
  "$@" && { PASSED=$((PASSED + 1)); return 0; }
  FAILED=$((FAILED + 1))
  echo "FAIL: $TEST: $DESC"
  [[ -z ${SHOWN} ]] && awk '{ print "    | " $0 }' "$T/out"
  SHOWN=1
  return 0
}

rc_is() { [[ $RC -eq $1 ]]; }
out_has() { grep -qF -- "$1" "$T/out"; }
out_lacks() { ! grep -qF -- "$1" "$T/out"; }
val_is() { [[ $(g "$1") == "$2" ]]; }
val_unset() { ! g "$1" >/dev/null; }

# ---- tests -----------------------------------------------------------------

test_add() {
  env_new add
  run
  check "exit 0" rc_is 0
  check "reports Adding" out_has "Adding user.name = Joe"
  check "sets the value" val_is user.name Joe
  check "sets the alias" val_is alias.st "status -uno"
}

test_already_present() {
  env_new already_present
  run
  run
  check "exit 0" rc_is 0
  check "reports Already present" out_has "Already present: user.name = Joe"
  check "does not say Adding" out_lacks "Adding"
  check "does not say Setting" out_lacks "Setting user.name"
}

test_conflict_kept() {
  env_new conflict_kept
  set_g user.name Other
  run
  check "reports Conflicting" out_has "Conflicting: user.name is 'Other'"
  check "keeps the value" val_is user.name Other
  check "does not say Replacing" out_lacks "Replacing"
  check "still adds the rest" val_is core.compression 1
}

test_empty_value_is_conflict() {
  env_new empty_value
  set_g user.name ""
  run
  check "reports Conflicting" out_has "Conflicting: user.name"
  check "keeps the empty value" val_is user.name ""
}

test_force_replaces() {
  env_new force_replaces
  set_g user.name Other
  run -f
  check "reports Replacing" out_has "Replacing user.name"
  check "mentions the old value" out_has "Other"
  check "replaces the value" val_is user.name Joe
  check "does not say Conflicting" out_lacks "Conflicting"
}

test_force_present_unchanged() {
  env_new force_present
  run
  run -f
  check "reports Already present" out_has "Already present: user.name = Joe"
  check "does not say Replacing" out_lacks "Replacing"
}

test_interactive_add_yes_no() {
  env_new interactive_add
  # keys in file order: user.name, alias.st, core.compression
  run_with 'y\nn\ny\n' -i
  check "exit 0" rc_is 0
  check "asks about user.name" out_has "user.name"
  check "y adds user.name" val_is user.name Joe
  check "n skips alias.st" val_unset alias.st
  check "y adds core.compression" val_is core.compression 1
}

test_interactive_eof_skips() {
  env_new interactive_eof
  run_with '' -i
  check "nothing added" val_unset user.name
}

test_interactive_present_not_asked() {
  env_new interactive_present
  run
  run_with '' -i
  check "reports Already present" out_has "Already present: user.name = Joe"
  check "asks nothing" out_lacks "[y/N]"
}

test_interactive_conflict_not_asked_without_force() {
  env_new interactive_conflict
  set_g user.name Other
  run_with 'y\ny\ny\n' -i
  check "reports Conflicting" out_has "Conflicting: user.name"
  check "keeps the value" val_is user.name Other
  check "the answers went to the two additions" val_is alias.st "status -uno"
}

test_interactive_force_replace() {
  env_new interactive_force
  set_g user.name Other
  set_g core.compression 9
  # replacements only are asked: user.name (n), core.compression (y); alias.st is an addition (y)
  run_with 'n\ny\ny\n' -i -f
  check "n keeps user.name" val_is user.name Other
  check "y replaces core.compression" val_is core.compression 1
  check "y adds alias.st" val_is alias.st "status -uno"
}

test_unknown_option() {
  env_new unknown_option
  run -x
  check "exit 22" rc_is 22
}

# ---- main ------------------------------------------------------------------

mapfile -t ALL < <(declare -F | awk '$3 ~ /^test_/ { print $3 }')
if [[ $# -gt 0 ]]; then TESTS=("$@"); else TESTS=("${ALL[@]}"); fi
for T_NAME in "${TESTS[@]}"; do
  declare -F "$T_NAME" >/dev/null || { echo "Error: no such test: $T_NAME" >&2; exit 22; }
  "$T_NAME"
done
echo "$PASSED passed, $FAILED failed"
[[ $FAILED -eq 0 ]]
