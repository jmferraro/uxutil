#!/usr/bin/env bash
# test-git-hooks.sh - tests for git/hooks/pre-commit and git/hooks/pre-push,
# and the .gitrules file they read
#
# Each test makes a scratch repository with its own user config file, with the
# real global and system git config switched off, so nothing outside the
# scratch directory is read or touched.

set -o pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readonly REPO_DIR
readonly PRE_COMMIT="$REPO_DIR/git/hooks/pre-commit"
readonly PRE_PUSH="$REPO_DIR/git/hooks/pre-push"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/test-git-hooks.XXXXXX")
trap 'rm -rf "${WORK}"' EXIT
PASSED=0
FAILED=0
readonly ZERO=0000000000000000000000000000000000000000

export GIT_CONFIG_SYSTEM=/dev/null

# ---- harness ---------------------------------------------------------------

# repo_new NAME - set T to a new test dir holding a repository (R) on branch
# 'work' (so pre-commit's main/master restriction never applies) with one
# commit, .gitrules listed in its .git/info/exclude, and a user config file
# (GIT_CONFIG_GLOBAL) of its own
repo_new() {
  TEST="$1"
  T="$WORK/$1"
  R="$T/repo"
  unset SHOWN
  mkdir -p "$T"
  export GIT_CONFIG_GLOBAL="$T/user.gitconfig"
  printf '[user]\n  name = Test\n  email = test@example.com\n' > "$GIT_CONFIG_GLOBAL"
  git init -q -b work "$R"
  git -C "$R" commit -q --allow-empty -m init
  echo .gitrules >> "$R/.git/info/exclude"
}

# stage_fixme PATH... - create each PATH in R holding a FIXME marker, and stage it
stage_fixme() {
  local P
  for P in "$@"; do
    mkdir -p "$R/$(dirname "$P")"
    echo "x = 1; // FIXME" > "$R/$P"
    git -C "$R" add -- "$P"
  done
}

# stage_clean PATH... - create each PATH in R holding nothing the hook refuses,
# and stage it
stage_clean() {
  local P
  for P in "$@"; do
    mkdir -p "$R/$(dirname "$P")"
    echo "x = 1;" > "$R/$P"
    git -C "$R" add -- "$P"
  done
}

# run CMD... - run CMD in the repository; output to $T/out, status to RC
run() {
  (cd "$R" && "$@") > "$T/out" 2>&1
  RC=$?
}

# push_to REF - run pre-push as git does for a push of the current HEAD to REF
push_to() {
  local SHA
  SHA=$(git -C "$R" rev-parse HEAD)
  (cd "$R" && printf 'refs/heads/work %s %s %s\n' "$SHA" "$1" "$ZERO" | bash "$PRE_PUSH" origin /dev/null) > "$T/out" 2>&1
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
out_lacks() { ! grep -qF -- "$1" "$T/out"; }

# ---- pre-commit: [ignore-commit-scan] ---------------------------------------

# a bare directory name matches that directory at any depth; comments, blank
# lines, indentation and other sections are ignored
test_pc_ignore_dir_name() {
  repo_new pc_ignore_dir_name
  cat > "$R/.gitrules" <<'EOF'
# rules for this checkout
[restrict-push]
main-thru

[ignore-commit-scan]
   firedancer    # upstream mirror: not our style rules
EOF
  stage_fixme patch/firedancer/a.cpp src/b.cpp
  run bash "$PRE_COMMIT"
  check "firedancer file not scanned" out_lacks "patch/firedancer/a.cpp contains"
  check "skip is reported" out_has "Skipping (.gitrules): patch/firedancer/a.cpp"
  check "other file still scanned" out_has "src/b.cpp contains"
  check "one failure" rc_is 1
}

# a sub-path entry matches the files under it
test_pc_ignore_subpath() {
  repo_new pc_ignore_subpath
  printf '[ignore-commit-scan]\npatch/firedancer\n' > "$R/.gitrules"
  stage_fixme patch/firedancer/x/a.cpp src/b.cpp
  run bash "$PRE_COMMIT"
  check "file under the path not scanned" out_lacks "patch/firedancer/x/a.cpp contains"
  check "other file still scanned" out_has "src/b.cpp contains"
}

# in a linked worktree the rules come from the main checkout's .gitrules
test_pc_rules_in_worktree() {
  repo_new pc_rules_in_worktree
  printf '[ignore-commit-scan]\nfiredancer\n' > "$R/.gitrules"
  git -C "$R" worktree add -q -b wt "$T/wt"
  R="$T/wt"
  stage_fixme patch/firedancer/a.cpp
  run bash "$PRE_COMMIT"
  check "main checkout's rules applied" out_lacks "patch/firedancer/a.cpp contains"
  check "passes" rc_is 0
}

# green control: only whole path components match
test_pc_partial_name_not_ignored() {
  repo_new pc_partial_name_not_ignored
  printf '[ignore-commit-scan]\nfire\n' > "$R/.gitrules"
  stage_fixme patch/firedancer/a.cpp
  run bash "$PRE_COMMIT"
  check "still scanned" out_has "patch/firedancer/a.cpp contains"
}

# green control: an entry in another section does not skip the scan
test_pc_other_section_not_ignored() {
  repo_new pc_other_section_not_ignored
  printf '[restrict-push]\nfiredancer\n' > "$R/.gitrules"
  stage_fixme patch/firedancer/a.cpp
  run bash "$PRE_COMMIT"
  check "still scanned" out_has "patch/firedancer/a.cpp contains"
}

# sanctioned inversion: hooks.precommitRules is no longer read, so a rules file
# it names neither skips files nor adds patterns
test_pc_precommit_rules_ignored() {
  repo_new pc_precommit_rules_ignored
  cat > "$T/rules" <<'EOF'
FAIL_REGEX+=("\bWIP\b")
hook_skip_file() { [[ "$1" =~ ^vendor/ ]]; }
EOF
  git -C "$R" config hooks.precommitRules "$T/rules"
  stage_fixme vendor/a.cpp
  mkdir -p "$R/src" && echo "WIP" > "$R/src/c.txt" && git -C "$R" add src/c.txt
  run bash "$PRE_COMMIT"
  check "vendor file still scanned" out_has "vendor/a.cpp contains"
  check "no extra pattern added" out_lacks "src/c.txt contains"
}

# green control: with no .gitrules every file is scanned
test_pc_no_rules() {
  repo_new pc_no_rules
  stage_fixme patch/firedancer/a.cpp src/b.cpp
  run bash "$PRE_COMMIT"
  check "firedancer file scanned" out_has "patch/firedancer/a.cpp contains"
  check "other file scanned" out_has "src/b.cpp contains"
  check "two failures" rc_is 2
}

# ---- pre-commit: [ignore-commit-scan] entry spellings -----------------------

# slash_skipped NAME ENTRY PATH - ENTRY in [ignore-commit-scan] skips PATH
slash_skipped() {
  repo_new "$1"
  printf '[ignore-commit-scan]\n%s\n' "$2" > "$R/.gitrules"
  stage_fixme "$3"
  run bash "$PRE_COMMIT"
  check "$2 skips $3" out_lacks "$3 contains"
  check "passes" rc_is 0
}

# a leading '/' or './', or a trailing '/', does not stop an entry matching
test_pc_ignore_slash_spellings() {
  slash_skipped pc_ignore_trailing_slash firedancer/ patch/firedancer/a.cpp
  slash_skipped pc_ignore_trailing_slash_root firedancer/ firedancer/a.cpp
  slash_skipped pc_ignore_leading_slash /firedancer patch/firedancer/a.cpp
  slash_skipped pc_ignore_dot_slash ./firedancer patch/firedancer/a.cpp
  slash_skipped pc_ignore_both_slashes /patch/firedancer/ patch/firedancer/a.cpp
}

# an entry ending in '/' that names a file in the checkout root is an error
test_pc_dir_entry_names_file() {
  repo_new pc_dir_entry_names_file
  printf '[ignore-commit-scan]\nfoo.cpp/\n' > "$R/.gitrules"
  stage_clean foo.cpp src/b.cpp
  run bash "$PRE_COMMIT"
  check "fails" rc_not 0
  check "names the entry" out_has "'foo.cpp/' is not a directory"
}

# an entry ending in '/' that names a link to a file is an error
test_pc_dir_entry_names_file_link() {
  repo_new pc_dir_entry_names_file_link
  printf '[ignore-commit-scan]\nfoo.cpp/\n' > "$R/.gitrules"
  stage_clean src/real.cpp
  ln -s src/real.cpp "$R/foo.cpp"   # an untracked, local link
  run bash "$PRE_COMMIT"
  check "fails" rc_not 0
  check "names the entry" out_has "'foo.cpp/' is not a directory"
}

# green control: an entry ending in '/' may name a link to a directory
test_pc_dir_entry_link_to_dir() {
  repo_new pc_dir_entry_link_to_dir
  printf '[ignore-commit-scan]\nfd/\n' > "$R/.gitrules"
  stage_clean patch/firedancer/a.cpp
  ln -s patch/firedancer "$R/fd"    # an untracked, local link
  run bash "$PRE_COMMIT"
  check "passes" rc_is 0
}

# green control: an entry ending in '/' that names nothing in the checkout root
# is not an error (it may match a directory deeper in the tree)
test_pc_dir_entry_absent() {
  repo_new pc_dir_entry_absent
  printf '[ignore-commit-scan]\nnothere/\n' > "$R/.gitrules"
  stage_clean src/b.cpp
  run bash "$PRE_COMMIT"
  check "passes" rc_is 0
}

# green control: an entry ending in '/' matches only a directory, so a file of
# that name deeper in the tree is still scanned
test_pc_dir_entry_skips_no_file() {
  repo_new pc_dir_entry_skips_no_file
  printf '[ignore-commit-scan]\nfoo.cpp/\n' > "$R/.gitrules"
  stage_fixme src/foo.cpp
  run bash "$PRE_COMMIT"
  check "file still scanned" out_has "src/foo.cpp contains"
}

# ---- pre-commit: .gitrules must be ignored ----------------------------------

# sanctioned inversion (user changed the rule from an error to a warning): a
# .gitrules that git does not ignore could be committed, so the hook warns,
# says how to fix it, and still passes
test_pc_rules_not_ignored() {
  repo_new pc_rules_not_ignored
  : > "$R/.git/info/exclude"
  printf '[ignore-commit-scan]\nfiredancer\n' > "$R/.gitrules"
  stage_clean src/b.cpp
  run bash "$PRE_COMMIT"
  check "warns" out_has "WARNING: .gitrules is not ignored"
  check "says how" out_has "info/exclude"
  check "still passes" rc_is 0
}

# sanctioned inversion, as above: a tracked .gitrules draws the warning even
# when .gitignore lists it
test_pc_rules_tracked() {
  repo_new pc_rules_tracked
  : > "$R/.git/info/exclude"
  echo .gitrules > "$R/.gitignore"
  printf '[ignore-commit-scan]\nfiredancer\n' > "$R/.gitrules"
  git -C "$R" add -f .gitignore .gitrules
  git -C "$R" commit -q -m rules
  stage_clean src/b.cpp
  run bash "$PRE_COMMIT"
  check "warns" out_has "WARNING: .gitrules is not ignored"
  check "says how" out_has "info/exclude"
  check "still passes" rc_is 0
}

# green control: .gitignore may be what ignores .gitrules
test_pc_rules_in_gitignore() {
  repo_new pc_rules_in_gitignore
  : > "$R/.git/info/exclude"
  echo .gitrules > "$R/.gitignore"
  printf '[ignore-commit-scan]\nfiredancer\n' > "$R/.gitrules"
  git -C "$R" add .gitignore
  stage_clean src/b.cpp
  run bash "$PRE_COMMIT"
  check "passes" rc_is 0
}

# green control: with no .gitrules there is nothing to ignore
test_pc_no_rules_not_ignored() {
  repo_new pc_no_rules_not_ignored
  : > "$R/.git/info/exclude"
  stage_clean src/b.cpp
  run bash "$PRE_COMMIT"
  check "passes" rc_is 0
}

# ---- pre-push: [restrict-push] -----------------------------------------------

test_pp_listed_branch_blocked() {
  repo_new pp_listed_branch_blocked
  printf '[restrict-push]\nrelease\nmain-thru\n' > "$R/.gitrules"
  push_to refs/heads/release
  check "push refused" rc_not 0
  check "names the branch" out_has "release"
}

# sanctioned inversion: main-thru is no longer hard-coded; with no .gitrules
# nothing is restricted
test_pp_no_rules_allows_all() {
  repo_new pp_no_rules_allows_all
  push_to refs/heads/main-thru
  check "push allowed" rc_is 0
}

# green control: a branch that is not listed may be pushed
test_pp_unlisted_branch_allowed() {
  repo_new pp_unlisted_branch_allowed
  printf '[restrict-push]\nrelease\n' > "$R/.gitrules"
  push_to refs/heads/feature
  check "push allowed" rc_is 0
}

# green control: main-thru is still refused when it is listed
test_pp_main_thru_listed_blocked() {
  repo_new pp_main_thru_listed_blocked
  printf '[restrict-push]\nmain-thru\n' > "$R/.gitrules"
  push_to refs/heads/main-thru
  check "push refused" rc_not 0
}

# a real git push through the installed hook: checks the hook against the
# input git actually gives it
test_pp_real_push() {
  repo_new pp_real_push
  git init -q --bare "$T/remote.git"
  git -C "$R" remote add origin "$T/remote.git"
  ln -s "$PRE_PUSH" "$R/.git/hooks/pre-push"
  printf '[restrict-push]\nrelease\n' > "$R/.gitrules"
  run git push -q origin work:release
  check "push to a listed branch refused" rc_not 0
  check "remote did not get it" test -z "$(git -C "$T/remote.git" branch --list release)"
  run git push -q origin work:feature
  check "push to an unlisted branch accepted" rc_is 0
  check "remote got it" test -n "$(git -C "$T/remote.git" branch --list feature)"
}

# ---- pre-push: attribution tags in the commits pushed -------------------------

# remote_new - give R a bare remote 'origin' and install pre-push in R
remote_new() {
  git init -q --bare "$T/remote.git"
  git -C "$R" remote add origin "$T/remote.git"
  ln -s "$PRE_PUSH" "$R/.git/hooks/pre-push"
}

# commit_msg MESSAGE - make a commit in R with MESSAGE
commit_msg() {
  git -C "$R" commit -q --allow-empty -m "$1"
}

# a real push of a commit carrying a Co-Authored-By trailer is refused
test_pp_attribution_real_push() {
  repo_new pp_attribution_real_push
  remote_new
  commit_msg "Add parser"$'\n\n'"Co-Authored-By: Claude <noreply@anthropic.com>"
  run git push -q origin work:feature
  check "push refused" rc_not 0
  check "names the commit" out_has "Add parser"
  check "remote did not get it" test -z "$(git -C "$T/remote.git" branch --list feature)"
}

# attr_refused NAME MESSAGE - a commit with MESSAGE is refused by pre-push
attr_refused() {
  repo_new "$1"
  commit_msg "$2"
  push_to refs/heads/feature
  check "push refused" rc_not 0
  check "names the commit" out_has "Tagged commit"
}

test_pp_attribution_tags() {
  attr_refused pp_attr_co_developed "Tagged commit"$'\n\n'"co-developed-by: Someone <a@b.c>"
  attr_refused pp_attr_assisted "Tagged commit"$'\n\n'"Assisted-by: Claude"
  attr_refused pp_attr_generated_by_trailer "Tagged commit"$'\n\n'"Generated-by: some tool"
  attr_refused pp_attr_session "Tagged commit"$'\n\n'"Claude-Session: https://claude.ai/code/session_x"
  attr_refused pp_attr_robot_credit "Tagged commit"$'\n\n'"🤖 Generated with [Claude Code](https://claude.com/claude-code)"
  attr_refused pp_attr_plain_credit "Tagged commit"$'\n\n'"Generated with Claude Code"
}

# green control: words in a sentence are not tags
test_pp_attribution_words_allowed() {
  repo_new pp_attribution_words_allowed
  commit_msg "Fix parsing of the Co-Authored-By trailer in mail import"
  commit_msg "Document which headers are generated by make"
  push_to refs/heads/feature
  check "push allowed" rc_is 0
}

# green control: a commit already on the remote is not checked again
test_pp_attribution_already_pushed() {
  repo_new pp_attribution_already_pushed
  remote_new
  commit_msg "Old commit"$'\n\n'"Co-Authored-By: Someone <a@b.c>"
  git -C "$R" push -q --no-verify origin work:feature
  commit_msg "New clean commit"
  run git push -q origin work:feature
  check "push allowed" rc_is 0
}

# green control: deleting a remote branch is allowed
test_pp_delete_allowed() {
  repo_new pp_delete_allowed
  remote_new
  git -C "$R" push -q origin work:feature
  run git push -q origin :feature
  check "delete allowed" rc_is 0
  check "remote branch gone" test -z "$(git -C "$T/remote.git" branch --list feature)"
}

# ---- main ------------------------------------------------------------------

TESTS=(
  test_pc_ignore_dir_name test_pc_ignore_subpath test_pc_rules_in_worktree
  test_pc_partial_name_not_ignored test_pc_other_section_not_ignored test_pc_no_rules
  test_pc_precommit_rules_ignored
  test_pc_ignore_slash_spellings test_pc_dir_entry_names_file test_pc_dir_entry_names_file_link
  test_pc_dir_entry_link_to_dir test_pc_dir_entry_absent test_pc_dir_entry_skips_no_file
  test_pc_rules_not_ignored test_pc_rules_tracked test_pc_rules_in_gitignore test_pc_no_rules_not_ignored
  test_pp_listed_branch_blocked test_pp_no_rules_allows_all test_pp_unlisted_branch_allowed
  test_pp_main_thru_listed_blocked test_pp_real_push
  test_pp_attribution_real_push test_pp_attribution_tags test_pp_attribution_words_allowed
  test_pp_attribution_already_pushed test_pp_delete_allowed
)
[[ $# -gt 0 ]] && TESTS=("$@")

for FN in "${TESTS[@]}"; do
  "$FN"
done
echo "checks: PASSED $PASSED, FAILED $FAILED"
[[ $FAILED -eq 0 ]]
