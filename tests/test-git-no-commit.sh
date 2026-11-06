#!/usr/bin/env bash
# test-git-no-commit.sh - tests for git/git-no-commit
#
# Each test makes a scratch repository, with the global and system git config
# switched off, so nothing outside it is read or touched.

set -o pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readonly REPO_DIR
readonly GNC="$REPO_DIR/git/git-no-commit"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/test-git-no-commit.XXXXXX")
trap 'rm -rf "${WORK}"' EXIT
PASSED=0
FAILED=0

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com

# ---- harness ---------------------------------------------------------------

# repo_new NAME - set T to a new test dir holding a repository (R) with one
# commit (BASE)
repo_new() {
  TEST="$1"
  T="$WORK/$1"
  R="$T/repo"
  unset SHOWN
  mkdir -p "$T"
  git init -q -b master "$R"
  git -C "$R" commit -q --allow-empty -m base
  BASE=$(git -C "$R" rev-parse HEAD)
}

# run [-C DIR] CMD... - run CMD in DIR (default the repository); output to
# $T/out, status to RC
run() {
  local DIR="$R"
  [[ $1 == -C ]] && { DIR=$2; shift 2; }
  (cd "$DIR" && "$@") > "$T/out" 2>&1
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
head_is_base() { [[ $(git -C "$R" rev-parse HEAD) == "$BASE" ]]; }
ours() { [[ -x $R/.git/hooks/$1 ]] && grep -q 'git-no-commit' "$R/.git/hooks/$1"; }
absent() { [[ ! -e $1 && ! -L $1 ]]; }
pull_ff_is() { [[ $(git -C "$R" config --get pull.ff) == "$1" ]]; }

# foreign HOOK - give the repository its own HOOK, which allows everything
foreign() {
  printf '#!/bin/sh\n# my own hook\nexit 0\n' > "$R/.git/hooks/$1"
  chmod +x "$R/.git/hooks/$1"
  cp -p "$R/.git/hooks/$1" "$T/$1.orig"
}

# ---- tests -----------------------------------------------------------------

test_blocks_commits() {
  repo_new blocks_commits
  run "$GNC"
  check "exit 0" rc_is 0
  check "pre-commit installed" ours pre-commit
  check "pre-merge-commit installed" ours pre-merge-commit
  check "pull.ff set to only" pull_ff_is only
  run git commit -q --allow-empty -m x
  check "commit refused" rc_not 0
  check "says why" out_has "read-only"
  check "no commit made" head_is_base
  run git commit -q --allow-empty --amend -m y
  check "amend refused" rc_not 0
  check "no amend made" head_is_base
}

test_blocks_merges() {
  repo_new blocks_merges
  git -C "$R" checkout -q -b other && git -C "$R" commit -q --allow-empty -m other && git -C "$R" checkout -q master
  run "$GNC"
  check "exit 0" rc_is 0
  run git merge -q --no-ff -m m other
  check "merge commit refused" rc_not 0
  check "no merge made" head_is_base
}

test_from_subdir() {
  repo_new from_subdir
  mkdir -p "$R/a/b"
  run -C "$R/a/b" "$GNC"
  check "exit 0" rc_is 0
  check "installed in the repository's hooks" ours pre-commit
}

test_idempotent() {
  repo_new idempotent
  run "$GNC"
  cp -p "$R/.git/hooks/pre-commit" "$T/pre-commit.1"
  run "$GNC"
  check "again: exit 0" rc_is 0
  check "again: hook unchanged" cmp -s "$R/.git/hooks/pre-commit" "$T/pre-commit.1"
  check "again: says so" out_has "already"
}

test_keeps_existing_pre_commit() {
  repo_new keeps_existing_pre_commit
  foreign pre-commit
  run "$GNC"
  check "exit 17" rc_is 17
  check "names the hook it keeps" out_has "$R/.git/hooks/pre-commit"
  check "existing hook kept" cmp -s "$R/.git/hooks/pre-commit" "$T/pre-commit.orig"
  check "nothing installed" absent "$R/.git/hooks/pre-merge-commit"
  check "pull.ff not set" pull_ff_is ""
}

test_keeps_existing_pre_merge_commit() {
  repo_new keeps_existing_pre_merge_commit
  foreign pre-merge-commit
  run "$GNC"
  check "exit 17" rc_is 17
  check "existing hook kept" cmp -s "$R/.git/hooks/pre-merge-commit" "$T/pre-merge-commit.orig"
  check "nothing installed" absent "$R/.git/hooks/pre-commit"
}

test_keeps_existing_symlink() {
  repo_new keeps_existing_symlink
  printf '#!/bin/sh\nexit 0\n' > "$T/shared-hook"
  chmod +x "$T/shared-hook"
  ln -s "$T/shared-hook" "$R/.git/hooks/pre-commit"
  run "$GNC"
  check "exit 17" rc_is 17
  check "symlink kept" test "$(readlink "$R/.git/hooks/pre-commit")" == "$T/shared-hook"
  check "linked file kept" file_unchanged
}
file_unchanged() { [[ $(cat "$T/shared-hook") == $'#!/bin/sh\nexit 0' ]]; }

test_hooks_path() {
  repo_new hooks_path
  mkdir -p "$T/shared"
  git -C "$R" config core.hooksPath "$T/shared"
  run "$GNC"
  check "refused" rc_not 0
  check "says why" out_has "core.hooksPath"
  check "shared hooks dir untouched" test -z "$(ls -A "$T/shared")"
  check "nothing installed" absent "$R/.git/hooks/pre-commit"
}

test_remove() {
  repo_new remove
  run "$GNC"
  check "installed first" ours pre-commit
  run "$GNC" --remove
  check "exit 0" rc_is 0
  check "pre-commit removed" absent "$R/.git/hooks/pre-commit"
  check "pre-merge-commit removed" absent "$R/.git/hooks/pre-merge-commit"
  check "says so" out_has "Removed"
  run git commit -q --allow-empty -m x
  check "commits work again" rc_is 0
}

# --remove has no short form: -r is an unknown option and changes nothing
test_no_short_remove() {
  repo_new no_short_remove
  run "$GNC"
  run "$GNC" -r
  check "-r: exit 22" rc_is 22
  check "-r: unknown option" out_has "Unknown option: '-r'"
  check "-r: hooks still installed" ours pre-commit
  run "$GNC" -h
  check "-h: no -r option in the usage" no_short_r_in_out
}
# no -r in the output except inside --remove
no_short_r_in_out() { ! grep -qE -- '(^|[^-])-r([^[:alnum:]-]|$)' "$T/out"; }

test_remove_keeps_foreign() {
  repo_new remove_keeps_foreign
  foreign pre-commit
  run "$GNC" --remove
  check "exit 0" rc_is 0
  check "existing hook kept" cmp -s "$R/.git/hooks/pre-commit" "$T/pre-commit.orig"
  check "says it kept it" out_has "$R/.git/hooks/pre-commit"
}

test_not_a_repo() {
  repo_new not_a_repo
  mkdir -p "$T/plain"
  run -C "$T/plain" env GIT_CEILING_DIRECTORIES="$T" "$GNC"
  check "exit 2" rc_is 2
}

test_bad_arguments() {
  repo_new bad_arguments
  run "$GNC" -z
  check "unknown option: exit 22" rc_is 22
  run "$GNC" extra
  check "extra argument: exit 22" rc_is 22
  run "$GNC" -h
  check "-h: exit 0" rc_is 0
  check "-h: usage" out_has "Usage:"
}

# ---- main ------------------------------------------------------------------

TESTS=(
  test_blocks_commits test_blocks_merges test_from_subdir test_idempotent
  test_keeps_existing_pre_commit test_keeps_existing_pre_merge_commit test_keeps_existing_symlink
  test_hooks_path test_remove test_no_short_remove test_remove_keeps_foreign test_not_a_repo test_bad_arguments
)
[[ $# -gt 0 ]] && TESTS=("$@")

for FN in "${TESTS[@]}"; do
  "$FN"
done
echo "checks: PASSED $PASSED, FAILED $FAILED"
[[ $FAILED -eq 0 ]]
