#!/usr/bin/env bash
# test-git-install-hook.sh - tests for git/git-install-hook
#
# Each test makes a scratch repository with its own user config file, with the
# real global and system git config switched off, so nothing outside the
# scratch directory is read or touched.

set -o pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readonly REPO_DIR
readonly INSTALL="$REPO_DIR/git/git-install-hook"
readonly HOOK_DIR="$REPO_DIR/git/hooks"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/test-git-install-hook.XXXXXX")
trap 'rm -rf "${WORK}"' EXIT
PASSED=0
FAILED=0

export GIT_CONFIG_SYSTEM=/dev/null

# ---- harness ---------------------------------------------------------------

# repo_new NAME - set T to a new test dir holding a repository (R), and a user
# config file (GIT_CONFIG_GLOBAL) of its own
repo_new() {
  TEST="$1"
  T="$WORK/$1"
  R="$T/repo"
  unset SHOWN
  mkdir -p "$T"
  export GIT_CONFIG_GLOBAL="$T/user.gitconfig"
  printf '[user]\n  name = Test\n  email = test@example.com\n' > "$GIT_CONFIG_GLOBAL"
  git init -q "$R"
}

# run CMD... - run CMD in the repository; output to $T/out, status to RC
run() {
  (cd "$R" && "$@") > "$T/out" 2>&1
  RC=$?
}

# check NAME CMD... - count CMD succeeding as a pass; on the first failure in
# a test, also print the output of the last run
check() {
  local NAME="$1"
  shift
  if "$@"; then
    PASSED=$((PASSED + 1))
  else
    FAILED=$((FAILED + 1))
    echo "FAIL: $TEST: $NAME"
    [[ -n $SHOWN ]] || { SHOWN=1; sed 's/^/    /' "$T/out"; echo; }
  fi
}

rc_is() { [[ $RC -eq $1 ]]; }
rc_not() { [[ $RC -ne $1 ]]; }
out_has() { grep -qF -- "$1" "$T/out"; }

# linked HOOK - HOOK in R is a link to the hook of that name in HOOK_DIR
linked() {
  [[ -L $R/.git/hooks/$1 && $(readlink -f "$R/.git/hooks/$1") == "$(readlink -f "$HOOK_DIR/$1")" ]]
}

# absent HOOK - R has no HOOK (git's *.sample files do not count)
absent() { [[ ! -e $R/.git/hooks/$1 && ! -L $R/.git/hooks/$1 ]]; }

# ---- tests -----------------------------------------------------------------

# green control: with no options every hook is installed
test_default_installs_all() {
  repo_new default_installs_all
  run bash "$INSTALL"
  check "passes" rc_is 0
  check "pre-commit linked" linked pre-commit
  check "pre-push linked" linked pre-push
}

# green control: a hook name installs only that hook
test_name_installs_one() {
  repo_new name_installs_one
  run bash "$INSTALL" pre-push
  check "passes" rc_is 0
  check "pre-push linked" linked pre-push
  check "pre-commit not installed" absent pre-commit
}

# more than one hook name is an invalid argument
test_two_names_rejected() {
  repo_new two_names_rejected
  run bash "$INSTALL" pre-commit pre-push
  check "invalid argument" rc_is 22
  check "nothing installed" absent pre-commit
}

# a hook that does not exist is an error
test_unknown_hook_fails() {
  repo_new unknown_hook_fails
  run bash "$INSTALL" nosuch
  check "fails" rc_not 0
  check "says why" out_has "does not exist"
  check "nothing installed" absent nosuch
}

# -i asks for each hook, in name order, and installs only those answered y
test_interactive_answers() {
  repo_new interactive_answers
  run bash "$INSTALL" -i <<< $'y\nn'
  check "passes" rc_is 0
  check "pre-commit (y) linked" linked pre-commit
  check "pre-push (n) not installed" absent pre-push
}

# -i with no answer installs nothing
test_interactive_default_no() {
  repo_new interactive_default_no
  run bash "$INSTALL" -i < /dev/null
  check "passes" rc_is 0
  check "pre-commit not installed" absent pre-commit
  check "pre-push not installed" absent pre-push
}

# -i also asks about the one hook named
test_interactive_with_hook() {
  repo_new interactive_with_hook
  run bash "$INSTALL" -i pre-push <<< y
  check "pre-push linked" linked pre-push
  check "pre-commit not installed" absent pre-commit
}

test_help() {
  repo_new help
  run bash "$INSTALL" -h
  check "passes" rc_is 0
  check "prints usage" out_has "Usage: git install-hook"
  check "nothing installed" absent pre-commit
}

test_bad_option() {
  repo_new bad_option
  run bash "$INSTALL" --bogus
  check "invalid argument" rc_is 22
  check "prints usage" out_has "Usage: git install-hook"
  check "nothing installed" absent pre-commit
}

# ---- main ------------------------------------------------------------------

TESTS=(
  test_default_installs_all test_name_installs_one test_two_names_rejected
  test_unknown_hook_fails test_interactive_answers test_interactive_default_no
  test_interactive_with_hook test_help test_bad_option
)
[[ $# -gt 0 ]] && TESTS=("$@")

for FN in "${TESTS[@]}"; do
  "$FN"
done
echo "checks: PASSED $PASSED, FAILED $FAILED"
[[ $FAILED -eq 0 ]]
