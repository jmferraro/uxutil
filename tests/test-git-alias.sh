#!/usr/bin/env bash
# test-git-alias.sh - tests for git/git-alias
#
# Each test makes a scratch repository and its own user config file, with the
# real global and system git config switched off, so nothing outside the
# scratch directory is read or touched.

set -o pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readonly REPO_DIR
readonly GA="$REPO_DIR/git/git-alias"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/test-git-alias.XXXXXX")
trap 'rm -rf "${WORK}"' EXIT
PASSED=0
FAILED=0

export GIT_CONFIG_SYSTEM=/dev/null

# ---- harness ---------------------------------------------------------------

# repo_new NAME - set T to a new test dir holding a repository (R) and a user
# config file (GIT_CONFIG_GLOBAL) of its own
repo_new() {
  TEST="$1"
  T="$WORK/$1"
  R="$T/repo"
  unset SHOWN
  mkdir -p "$T"
  export GIT_CONFIG_GLOBAL="$T/user.gitconfig"
  : > "$GIT_CONFIG_GLOBAL"
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
out_has() { grep -qF -- "$1" "$T/out"; }
out_lacks() { ! grep -qF -- "$1" "$T/out"; }

# ---- tests -----------------------------------------------------------------

test_help_scopes() {
  repo_new help_scopes
  run "$GA" -h
  check "exit 0" rc_is 0
  check "--global is the user config" out_has "--global  Show or create alias in your user config (~/.gitconfig)"
  check "--local is the current repository's config" \
    out_has "--local   Show or create alias in the current repository's config (.git/config)"
  check "no mention of the system config" out_lacks "system config"
}

test_help_defaults() {
  repo_new help_defaults
  run "$GA" -h
  check "--global marked as the default for creating" line_after_is "--global  Show" "              (default when creating an alias)"
  check "--local not marked as a default" line_after_is_not "--local   Show" "              (default when creating an alias)"
  check "says what listing and searching read" \
    out_has "With neither option, listing and searching show the aliases from every config"
}
# line_after_is PREFIX LINE - the output line after the one containing PREFIX is LINE
line_after_is() { [[ $(grep -A1 -F -- "$1" "$T/out" | sed -n 2p) == "$2" ]]; }
line_after_is_not() { ! line_after_is "$@"; }

# creating with no option uses the user config: the aliases are for every
# project, and only --local limits one to the current repository
test_default_create_is_global() {
  repo_new default_create_is_global
  run "$GA" lg "log --oneline"
  check "exit 0" rc_is 0
  check "created in the user config" test "$(git config --global --get alias.lg)" == "log --oneline"
  check "not in the repository's config" test -z "$(git -C "$R" config --local --get alias.lg)"
}

test_default_create_outside_repo() {
  repo_new default_create_outside_repo
  mkdir -p "$T/plain"
  (cd "$T/plain" && GIT_CEILING_DIRECTORIES="$T" "$GA" lg "log --oneline") > "$T/out" 2>&1
  RC=$?
  check "exit 0 outside a repository" rc_is 0
  check "created in the user config" test "$(git config --global --get alias.lg)" == "log --oneline"
}

# green controls: an explicit scope works as before
test_create_with_scope() {
  repo_new create_with_scope
  run "$GA" --local lc "log --oneline"
  check "--local: exit 0" rc_is 0
  check "--local: in the repository's config" test "$(git -C "$R" config --local --get alias.lc)" == "log --oneline"
  check "--local: not in the user config" test -z "$(git config --global --get alias.lc)"
  run "$GA" --global lg "log --graph"
  check "--global: exit 0" rc_is 0
  check "--global: in the user config" test "$(git config --global --get alias.lg)" == "log --graph"
  check "--global: not in the repository's config" test -z "$(git -C "$R" config --local --get alias.lg)"
}

# green controls: listing with no option reads every config
test_default_list_reads_all() {
  repo_new default_list_reads_all
  git config --global alias.co checkout
  git -C "$R" config alias.st status
  run "$GA"
  check "lists the user config's alias" out_has "co = checkout"
  check "lists the repository's alias" out_has "st = status"
  run "$GA" --global
  check "--global: only the user config's" out_lacks "st = status"
  run "$GA" --local
  check "--local: only the repository's" out_lacks "co = checkout"
}

# only alias.* settings are aliases: other settings whose names merely contain
# "alias" (a branch or remote named after it) must not be listed or found
test_lists_only_aliases() {
  repo_new lists_only_aliases
  git -C "$R" config alias.st status
  git -C "$R" config branch.alias-fix.remote origin
  git -C "$R" config remote.alias.url https://example.com/r.git
  run "$GA"
  check "list: the alias" out_has "st = status"
  check "list: no branch setting" out_lacks "branch.alias-fix"
  check "list: no remote setting" out_lacks "remote.alias"
  run "$GA" --local
  check "--local list: the alias" out_has "st = status"
  check "--local list: no branch setting" out_lacks "branch.alias-fix"
  run "$GA" origin
  check "search: a setting's value is not found" out_lacks "branch.alias-fix"
  run "$GA" st
  check "search: the alias found" out_has "st = status"
  check "search: nothing else" test "$(wc -l < "$T/out")" -eq 1
}

# ---- main ------------------------------------------------------------------

TESTS=(
  test_help_scopes test_help_defaults test_default_create_is_global test_default_create_outside_repo
  test_create_with_scope test_default_list_reads_all test_lists_only_aliases
)
[[ $# -gt 0 ]] && TESTS=("$@")

for FN in "${TESTS[@]}"; do
  "$FN"
done
echo "checks: PASSED $PASSED, FAILED $FAILED"
[[ $FAILED -eq 0 ]]
