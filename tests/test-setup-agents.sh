#!/usr/bin/env bash
# test-setup-agents.sh - tests for setup/setup-agents.sh and setup/*/setup.sh
#
# Each test copies setup/, replaces its data files with small fixtures, and
# runs it against an empty scratch HOME, so the real home directory is never
# touched.  Needs jq and python3 3.11+ (tomllib checks the TOML results); the
# omp tests need omp in PATH and are skipped without it.

set -o pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readonly REPO_DIR
# shared with each scratch HOME so omp needn't unpack 100+ MB per test
readonly REAL_OMP_NATIVES="$HOME/.omp/natives"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/test-setup-agents.XXXXXX")
trap 'rm -rf "${WORK}"' EXIT
PASSED=0
FAILED=0
SKIPPED=0

command -v jq >/dev/null || { echo "Error: jq is required"; exit 1; }
python3 -c 'import tomllib' 2>/dev/null || { echo "Error: python3 3.11+ (tomllib) is required"; exit 1; }

# ---- harness ---------------------------------------------------------------

# env_new NAME [real] - set T to a new test dir holding a copy of setup/ (its
# data files replaced by fixtures unless "real" is given) and an empty HOME
env_new() {
  TEST="$1"
  T="$WORK/$1"
  unset SHOWN
  mkdir -p "$T/home"
  cp -R "$REPO_DIR/setup" "$T/setup"
  # this host's own config.ignore.txt files must not leak into the tests
  rm -f "$T"/setup/*/config.ignore.txt
  [[ -d $REAL_OMP_NATIVES ]] && { mkdir -p "$T/home/.omp"; ln -s "$REAL_OMP_NATIVES" "$T/home/.omp/natives"; }
  # Claude Code's own config, as /config leaves it with "← opens agents" off
  printf '{"leftArrowOpensAgents": false}\n' > "$T/home/.claude.json"
  [[ $2 == real ]] && return 0
  rm -rf "$T/setup/omp/commands" "$T/setup/omp/skills" "$T/setup/skills" "$T/setup/claude/settings" "$T/setup/claude/hooks"
  mkdir -p "$T/setup/omp/commands" "$T/setup/omp/skills/ompskill" "$T/setup/skills/gen/ref" "$T/setup/claude/settings"
  printf 'claude rules\n' > "$T/setup/claude/CLAUDE.md"
  printf '{"theme": "dark", "effortLevel": "xhigh", "list": ["a", "b"], "modelSettings": {"m": {"effortLevel": "xhigh"}}}\n' > "$T/setup/claude/settings/setting_general.json"
  printf 'codex rules\n' > "$T/setup/codex/AGENTS.md"
  printf 'model = "m1"\nmodel_reasoning_effort = "xhigh"\n\n[tui]\nalt = true\n' > "$T/setup/codex/config.toml"
  printf 'modelRoles:\n  default: prov/big\n  smol: prov/small\ntheme:\n  dark: obsidian\nenabledProviders:\n  - codex\n' > "$T/setup/omp/config.yml"
  printf 'cmd\n' > "$T/setup/omp/commands/cmd.md"
  printf 'omp skill\n' > "$T/setup/omp/skills/ompskill/SKILL.md"
  printf 'generic skill\n' > "$T/setup/skills/gen/SKILL.md"
  printf 'notes\n' > "$T/setup/skills/gen/ref/notes.md"
  return 0
}

# run CMD... - run CMD with HOME=$T/home; output to $T/out, status to RC
run() {
  env -u CLAUDE_CONFIG_DIR -u CODEX_HOME -u PI_CODING_AGENT_DIR HOME="$T/home" "$@" > "$T/out" 2>&1
  RC=$?
}

# run_with ANSWERS CMD... - run CMD with ANSWERS (printf %b, e.g. 'y\nn\n') as
# its input, for -i and -I
run_with() {
  local ANSWERS="$1"
  shift
  run "$@" < <(printf '%b' "$ANSWERS")
}

# check DESC CMD... - pass if CMD succeeds; on the test's first failure show
# the output of the last run
check() {
  local DESC="$1"
  shift
  "$@" && { PASSED=$((PASSED + 1)); return 0; }
  FAILED=$((FAILED + 1))
  echo "FAIL: $TEST: $DESC"
  # awk, not sed: the output may end in a prompt with no newline
  [[ -z ${SHOWN} ]] && awk '{ print "    | " $0 }' "$T/out"
  SHOWN=1
  return 0
}

rc_is() { [[ $RC -eq $1 ]]; }
out_has() { grep -qF -- "$1" "$T/out"; }
out_lacks() { ! grep -qF -- "$1" "$T/out"; }
file_is() { [[ -f $1 && $(cat "$1") == "$2" ]]; }
json_is() { jq -e --argjson WANT "$2" '. == $WANT' "$1" >/dev/null 2>&1; }
toml_is() {
  python3 -c 'import json, sys, tomllib
sys.exit(tomllib.load(open(sys.argv[1], "rb")) != json.loads(sys.argv[2]))' "$1" "$2" 2>/dev/null
}
omp_is() {
  env -u PI_CODING_AGENT_DIR HOME="$T/home" omp config list --scope=global --json 2>/dev/null |
    jq -e --argjson WANT "$1" 'map_values(.value) == $WANT' >/dev/null
}
# home_sum - checksum of every file under the scratch HOME (omp's natives
# link excluded)
home_sum() {
  (cd "$T/home" && find . -path ./.omp/natives -prune -o -type f -print0 | sort -z | xargs -0 -r sha256sum)
}

# ---- setup-agents.sh -------------------------------------------------------

test_dispatch_help() {
  env_new dispatch_help
  run "$T/setup/setup-agents.sh" -h
  check "exit 0" rc_is 0
  check "lists the agents" out_has "claude codex omp"
}

test_dispatch_unknown_agent() {
  env_new dispatch_unknown_agent
  run "$T/setup/setup-agents.sh" bogus
  check "exit 22" rc_is 22
  check "names the agent" out_has "Unknown agent: bogus"
}

test_dispatch_selected_agent() {
  env_new dispatch_selected_agent
  run "$T/setup/setup-agents.sh" -n codex
  check "exit 0" rc_is 0
  check "runs codex" out_has "== codex"
  check "skips claude" out_lacks "== claude"
  check "skips omp" out_lacks "== omp"
}

test_agent_bad_arguments() {
  env_new agent_bad_arguments
  run "$T/setup/claude/setup.sh" extra
  check "extra argument: exit 22" rc_is 22
  local OPTS
  for OPTS in "-i -n" "-I -n" "-i -I"; do
    # shellcheck disable=SC2086 # OPTS holds two options
    run "$T/setup/claude/setup.sh" $OPTS
    check "$OPTS: exit 22" rc_is 22
    # shellcheck disable=SC2086
    run "$T/setup/setup-agents.sh" $OPTS
    check "setup-agents.sh $OPTS: exit 22" rc_is 22
  done
  run "$T/setup/claude/setup.sh" -x
  check "unknown option: exit 22" rc_is 22
}

# ---- claude ----------------------------------------------------------------

CLAUDE_SEED='{"theme": "light", "extra": 1, "list": ["b", "c"], "modelSettings": {"m": {"other": 2}}}'

claude_seed() {
  mkdir -p "$T/home/.claude"
  printf '%s\n' "$CLAUDE_SEED" > "$T/home/.claude/settings.json"
  printf 'mine\n' > "$T/home/.claude/CLAUDE.md"
}

test_claude_fresh() {
  env_new claude_fresh
  run "$T/setup/claude/setup.sh"
  check "exit 0" rc_is 0
  check "CLAUDE.md installed" file_is "$T/home/.claude/CLAUDE.md" "claude rules"
  check "settings.json installed" json_is "$T/home/.claude/settings.json" "$(cat "$T/setup/claude/settings/setting_general.json")"
  check "generic skill installed" file_is "$T/home/.claude/skills/gen/SKILL.md" "generic skill"
  check "skill subdirectory installed" file_is "$T/home/.claude/skills/gen/ref/notes.md" "notes"
  check "omp skill not installed" test ! -e "$T/home/.claude/skills/ompskill"
}

test_claude_merge() {
  env_new claude_merge
  claude_seed
  run "$T/setup/claude/setup.sh"
  check "exit 0" rc_is 0
  check "settings merged" json_is "$T/home/.claude/settings.json" \
    '{"theme": "light", "extra": 1, "list": ["b", "c", "a"], "modelSettings": {"m": {"other": 2, "effortLevel": "xhigh"}}, "effortLevel": "xhigh"}'
  check "conflict warned" out_has 'Warning: theme is already set to "light", skipping new value "dark"'
  check "missing key reported" out_has 'Setting modelSettings.m.effortLevel = "xhigh"'
  check "array entries reported" out_has 'Adding "a" to list'
  check "differing CLAUDE.md kept" file_is "$T/home/.claude/CLAUDE.md" "mine"
  check "differing CLAUDE.md warned" out_has "Warning: $T/home/.claude/CLAUDE.md differs"
}

test_claude_force() {
  env_new claude_force
  claude_seed
  run "$T/setup/claude/setup.sh" -f
  check "exit 0" rc_is 0
  check "conflict overwritten, rest merged" json_is "$T/home/.claude/settings.json" \
    '{"theme": "dark", "extra": 1, "list": ["b", "c", "a"], "modelSettings": {"m": {"other": 2, "effortLevel": "xhigh"}}, "effortLevel": "xhigh"}'
  check "CLAUDE.md overwritten" file_is "$T/home/.claude/CLAUDE.md" "claude rules"
}

test_claude_dry_run() {
  env_new claude_dry_run
  claude_seed
  local BEFORE
  BEFORE=$(home_sum)
  run "$T/setup/claude/setup.sh" -n
  check "exit 0" rc_is 0
  check "HOME unchanged" test "$BEFORE" == "$(home_sum)"
  check "reports the change" out_has 'Would set effortLevel = "xhigh"'
  check "reports the skill" out_has "Would install $T/home/.claude/skills/gen/SKILL.md"
}

test_claude_idempotent() {
  env_new claude_idempotent
  run "$T/setup/claude/setup.sh"
  run "$T/setup/claude/setup.sh"
  check "exit 0" rc_is 0
  check "second run is up to date" out_has "Claude Code is up to date in $T/home/.claude"
  check "second run changes nothing" out_lacks "Install"
}

test_claude_invalid_settings() {
  env_new claude_invalid_settings
  mkdir -p "$T/home/.claude"
  printf '{bad\n' > "$T/home/.claude/settings.json"
  run "$T/setup/claude/setup.sh"
  check "fails" test "$RC" -ne 0
  check "names the sources, not the scratch file" out_has "Error: cannot merge $T/setup/claude/settings/setting_*.json into $T/home/.claude/settings.json"
  check "settings.json untouched" file_is "$T/home/.claude/settings.json" "{bad"
}

test_claude_sections() {
  env_new claude_sections
  printf '{"list": ["b", "c"], "modelSettings": {"m": {"other": 3}}, "extra": true}\n' > "$T/setup/claude/settings/setting_tools.json"
  printf '{"theme": "light", "ignored": true}\n' > "$T/setup/claude/settings/other.json"
  run "$T/setup/claude/setup.sh" -n
  check "dry run: exit 0" rc_is 0
  check "dry run: list reported once, combined" out_has 'Would set list = ["a","b","c"]'
  check "dry run: no per-file list" out_lacks 'Would set list = ["b","c"]'
  run "$T/setup/claude/setup.sh"
  check "exit 0" rc_is 0
  check "sections combined" json_is "$T/home/.claude/settings.json" \
    '{"theme": "dark", "effortLevel": "xhigh", "list": ["a", "b", "c"], "modelSettings": {"m": {"effortLevel": "xhigh", "other": 3}}, "extra": true}'
  run "$T/setup/claude/setup.sh"
  check "second run is up to date" out_has "Claude Code is up to date in $T/home/.claude"
}

test_claude_sections_conflict() {
  env_new claude_sections_conflict
  claude_seed
  printf '{"theme": "light", "effortLevel": "xhigh", "modelSettings": {"m": {"effortLevel": "low"}}}\n' > "$T/setup/claude/settings/setting_tools.json"
  local OPT
  for OPT in "" -f; do
    run "$T/setup/claude/setup.sh" ${OPT:+"$OPT"}
    check "${OPT:-no option}: fails" test "$RC" -ne 0
    check "${OPT:-no option}: names the file and settings" \
      out_has "Error: $T/setup/claude/settings/setting_tools.json sets theme, modelSettings.m.effortLevel differently"
    check "${OPT:-no option}: settings.json untouched" json_is "$T/home/.claude/settings.json" "$CLAUDE_SEED"
  done
}

test_claude_sections_invalid() {
  env_new claude_sections_invalid
  claude_seed
  printf '{bad\n' > "$T/setup/claude/settings/setting_tools.json"
  run "$T/setup/claude/setup.sh"
  check "fails" test "$RC" -ne 0
  check "names the file" out_has "Error: cannot merge $T/setup/claude/settings/setting_tools.json"
  check "settings.json untouched" json_is "$T/home/.claude/settings.json" "$CLAUDE_SEED"
}

test_claude_ignore() {
  env_new claude_ignore
  claude_seed
  printf '# kept on this machine\n\n  theme  \nlist\nmodelSettings.m.effortLevel\nCLAUDE.md\n' > "$T/setup/claude/config.ignore.txt"
  run "$T/setup/claude/setup.sh" -f
  check "exit 0" rc_is 0
  check "listed settings kept, even with -f; the rest merged" json_is "$T/home/.claude/settings.json" \
    '{"theme": "light", "extra": 1, "list": ["b", "c"], "modelSettings": {"m": {"other": 2}}, "effortLevel": "xhigh"}'
  check "listed file kept" file_is "$T/home/.claude/CLAUDE.md" "mine"
  check "unlisted skill installed" file_is "$T/home/.claude/skills/gen/SKILL.md" "generic skill"
  check "ignored setting reported" out_has "Ignoring theme (listed in $T/setup/claude/config.ignore.txt)"
  check "ignored file reported" out_has "Ignoring $T/home/.claude/CLAUDE.md (listed in"
  check "ignored setting not overwritten" out_lacks "Overwriting theme"
  run "$T/setup/claude/setup.sh"
  check "only ignored differences left: up to date" out_has "Claude Code is up to date in $T/home/.claude"
}

test_claude_interactive() {
  env_new claude_interactive
  claude_seed
  # CLAUDE.md (a bad answer, then i); the settings in name order: effortLevel
  # y, list i, modelSettings.m.effortLevel y, theme n; both skill files y
  run_with 'x\ni\ny\ni\ny\nn\ny\ny\n' "$T/setup/claude/setup.sh" -fi
  check "exit 0" rc_is 0
  check "bad answer asked again" out_has "Please answer y, n or i"
  check "file prompt" out_has "Overwrite $T/home/.claude/CLAUDE.md? [y/N/i]"
  check "setting prompt" out_has 'Overwrite theme = "dark" (was "light")? [y/N/i]'
  check "list prompt" out_has 'Add "a" to list? [y/N/i]'
  check "y applied, n and i skipped" json_is "$T/home/.claude/settings.json" \
    '{"theme": "light", "extra": 1, "list": ["b", "c"], "modelSettings": {"m": {"other": 2, "effortLevel": "xhigh"}}, "effortLevel": "xhigh"}'
  check "i skipped the file" file_is "$T/home/.claude/CLAUDE.md" "mine"
  check "skills installed" file_is "$T/home/.claude/skills/gen/ref/notes.md" "notes"
  check "i added the file" grep -qx "CLAUDE.md" "$T/setup/claude/config.ignore.txt"
  check "i added the setting" grep -qx "list" "$T/setup/claude/config.ignore.txt"
  check "n added nothing" test "$(grep -cv '^#' "$T/setup/claude/config.ignore.txt")" -eq 2
  check "i reported" out_has "Ignoring list from now on (added to $T/setup/claude/config.ignore.txt)"
  run "$T/setup/claude/setup.sh"
  check "next run: i answers ignored" out_has "Ignoring list (listed in"
  check "next run: n answer still differs" out_has 'Warning: theme is already set to "light"'
}

test_claude_interactive_adds() {
  env_new claude_interactive_adds
  claude_seed
  # without -f only additions are asked about: effortLevel y, list n,
  # modelSettings.m.effortLevel i; both skill files y.  CLAUDE.md and theme
  # differ, so they are kept with a warning, as without -i
  run_with 'y\nn\ni\ny\ny\n' "$T/setup/claude/setup.sh" -i
  check "exit 0" rc_is 0
  check "asked about an addition" out_has 'Set effortLevel = "xhigh" (new)? [y/N/i]'
  check "not asked about overwriting a setting" out_lacks "Overwrite theme"
  check "not asked about overwriting a file" out_lacks "Overwrite $T/home/.claude/CLAUDE.md"
  check "differing setting warned" out_has 'Warning: theme is already set to "light", skipping new value "dark"'
  check "differing file warned" out_has "Warning: $T/home/.claude/CLAUDE.md differs"
  check "only y answers applied, nothing overwritten" json_is "$T/home/.claude/settings.json" \
    '{"theme": "light", "extra": 1, "list": ["b", "c"], "modelSettings": {"m": {"other": 2}}, "effortLevel": "xhigh"}'
  check "differing file kept" file_is "$T/home/.claude/CLAUDE.md" "mine"
  check "skills installed" file_is "$T/home/.claude/skills/gen/SKILL.md" "generic skill"
  check "i added the setting" grep -qx "modelSettings.m.effortLevel" "$T/setup/claude/config.ignore.txt"
}

test_claude_reconsider_adds() {
  env_new claude_reconsider_adds
  claude_seed
  printf 'theme\neffortLevel\n' > "$T/setup/claude/config.ignore.txt"
  # -I without -f: the listed addition (effortLevel) is asked about, the
  # listed overwrite (theme) is not.  effortLevel y, list n,
  # modelSettings.m.effortLevel n; both skill files n
  run_with 'y\nn\nn\nn\nn\n' "$T/setup/claude/setup.sh" -I
  check "exit 0" rc_is 0
  check "listed addition asked about" out_has 'Set effortLevel = "xhigh" (new) (listed in config.ignore.txt)? [y/N/i/r]'
  check "listed overwrite not asked about" out_lacks "Overwrite theme"
  check "listed addition applied on y, nothing overwritten" json_is "$T/home/.claude/settings.json" \
    '{"theme": "light", "extra": 1, "list": ["b", "c"], "modelSettings": {"m": {"other": 2}}, "effortLevel": "xhigh"}'
}

test_claude_reconsider() {
  env_new claude_reconsider
  claude_seed
  printf 'theme\nCLAUDE.md\n' > "$T/setup/claude/config.ignore.txt"
  # CLAUDE.md i (already listed); effortLevel y, list y,
  # modelSettings.m.effortLevel y, theme y (listed); both skill files y
  run_with 'i\ny\ny\ny\ny\ny\ny\n' "$T/setup/claude/setup.sh" -fI
  check "exit 0" rc_is 0
  check "listed setting asked about, marked as listed" \
    out_has 'Overwrite theme = "dark" (was "light") (listed in config.ignore.txt)? [y/N/i/r]'
  check "listed setting applied on y" json_is "$T/home/.claude/settings.json" \
    '{"theme": "dark", "extra": 1, "list": ["b", "c", "a"], "modelSettings": {"m": {"other": 2, "effortLevel": "xhigh"}}, "effortLevel": "xhigh"}'
  check "listed file kept on i" file_is "$T/home/.claude/CLAUDE.md" "mine"
  check "ignore file unchanged: y removes nothing, i adds no duplicate" \
    file_is "$T/setup/claude/config.ignore.txt" "$(printf 'theme\nCLAUDE.md')"
}

test_claude_reconsider_remove() {
  env_new claude_reconsider_remove
  claude_seed
  printf '# mine\ntheme\nCLAUDE.md\nmodelSettings\n' > "$T/setup/claude/config.ignore.txt"
  # CLAUDE.md (listed) r, then y when asked again; effortLevel (not listed) r,
  # which is not offered, then y; list n; modelSettings.m.effortLevel (listed
  # as modelSettings) i; theme (listed) r, then y; both skill files y
  run_with 'r\ny\nr\ny\nn\ni\nr\ny\ny\ny\n' "$T/setup/claude/setup.sh" -fI
  check "exit 0" rc_is 0
  check "r offered for a listed item" out_has "Overwrite $T/home/.claude/CLAUDE.md (listed in config.ignore.txt)? [y/N/i/r]"
  check "r not offered for an unlisted item" out_has 'Set effortLevel = "xhigh" (new)? [y/N/i]'
  check "r refused for an unlisted item" out_has "Please answer y, n or i"
  check "r then y made the change" file_is "$T/home/.claude/CLAUDE.md" "claude rules"
  check "r then y, and y, applied; n and i skipped" json_is "$T/home/.claude/settings.json" \
    '{"theme": "dark", "extra": 1, "list": ["b", "c"], "modelSettings": {"m": {"other": 2}}, "effortLevel": "xhigh"}'
  check "r removed the lines, kept the rest; i added no duplicate" \
    file_is "$T/setup/claude/config.ignore.txt" "$(printf '# mine\nmodelSettings')"
  check "r reported" out_has "No longer ignoring theme (removed from $T/setup/claude/config.ignore.txt)"
  check "i on a covered item reported" out_has "Ignoring modelSettings.m.effortLevel (already listed in"
}

test_claude_reconsider_r_reasks() {
  env_new claude_reconsider_r_reasks
  claude_seed
  printf '# mine\ntheme\nCLAUDE.md\n' > "$T/setup/claude/config.ignore.txt"
  # r only stops ignoring, then asks again with just y/N: it never makes the
  # change by itself.  CLAUDE.md (listed, differs) r, then i (not offered
  # again), then n; effortLevel n, list n, modelSettings.m.effortLevel n;
  # theme (listed) r, then y; both skill files n
  run_with 'r\ni\nn\nn\nn\nn\nr\ny\nn\nn\n' "$T/setup/claude/setup.sh" -fI
  check "exit 0" rc_is 0
  check "r asks again with only y/N" out_has "IGNORE REMOVED: prompting again: Overwrite $T/home/.claude/CLAUDE.md? [y/N] "
  check "i refused when asked again" out_has "Please answer y or n"
  check "r then n keeps the file" file_is "$T/home/.claude/CLAUDE.md" "mine"
  check "r then n does not overwrite" out_lacks "Overwrote $T/home/.claude/CLAUDE.md"
  check "r then y applies the setting" json_is "$T/home/.claude/settings.json" \
    '{"theme": "dark", "extra": 1, "list": ["b", "c"], "modelSettings": {"m": {"other": 2}}}'
  check "r removed both lines, kept the rest; refused i added nothing" \
    file_is "$T/setup/claude/config.ignore.txt" "# mine"
  check "r reported for the file" out_has "No longer ignoring CLAUDE.md (removed from $T/setup/claude/config.ignore.txt)"
  check "r reported for the setting" out_has "No longer ignoring theme (removed from $T/setup/claude/config.ignore.txt)"
}

test_claude_interactive_no_answers() {
  env_new claude_interactive_no_answers
  claude_seed
  run "$T/setup/claude/setup.sh" -i < /dev/null
  check "exit 0" rc_is 0
  check "no answers: nothing changed" json_is "$T/home/.claude/settings.json" "$CLAUDE_SEED"
  check "no answers: nothing installed" test ! -e "$T/home/.claude/skills"
  check "no answers: nothing added" test ! -e "$T/setup/claude/config.ignore.txt"
}

test_claude_no_sections() {
  env_new claude_no_sections
  claude_seed
  rm -rf "$T/setup/claude/settings"
  run "$T/setup/claude/setup.sh"
  check "exit 0" rc_is 0
  check "settings.json untouched" json_is "$T/home/.claude/settings.json" "$CLAUDE_SEED"
}

# spinner_fixture - give the test a setting_spinner.json with two spinner verbs
spinner_fixture() {
  printf '{"spinnerVerbs": {"mode": "append", "verbs": ["Fooing", "Barring"]}}\n' > "$T/setup/claude/settings/setting_spinner.json"
}

# spinner_seed - seed settings.json with spinner verbs, one shared with the
# fixture, and a mode that conflicts with it
spinner_seed() {
  mkdir -p "$T/home/.claude"
  printf '{"theme": "light", "spinnerVerbs": {"mode": "replace", "verbs": ["Mine", "Barring"]}}\n' > "$T/home/.claude/settings.json"
}

test_claude_spinner_fresh() {
  env_new claude_spinner_fresh
  spinner_fixture
  run "$T/setup/claude/setup.sh"
  check "exit 0" rc_is 0
  check "settings and spinner verbs installed" json_is "$T/home/.claude/settings.json" \
    '{"theme": "dark", "effortLevel": "xhigh", "list": ["a", "b"], "modelSettings": {"m": {"effortLevel": "xhigh"}}, "spinnerVerbs": {"mode": "append", "verbs": ["Fooing", "Barring"]}}'
  run "$T/setup/claude/setup.sh"
  check "second run is up to date" out_has "Claude Code is up to date in $T/home/.claude"
}

test_claude_spinner_merge() {
  env_new claude_spinner_merge
  spinner_fixture
  spinner_seed
  run "$T/setup/claude/setup.sh"
  check "exit 0" rc_is 0
  check "missing verbs appended, existing ones and mode kept" json_is "$T/home/.claude/settings.json" \
    '{"theme": "light", "effortLevel": "xhigh", "list": ["a", "b"], "modelSettings": {"m": {"effortLevel": "xhigh"}}, "spinnerVerbs": {"mode": "replace", "verbs": ["Mine", "Barring", "Fooing"]}}'
  check "verbs reported" out_has 'Adding "Fooing" to spinnerVerbs.verbs'
  check "mode conflict warned" out_has 'Warning: spinnerVerbs.mode is already set to "replace", skipping new value "append"'
}

test_claude_spinner_dry_run() {
  env_new claude_spinner_dry_run
  spinner_fixture
  spinner_seed
  local BEFORE
  BEFORE=$(home_sum)
  run "$T/setup/claude/setup.sh" -n
  check "exit 0" rc_is 0
  check "HOME unchanged" test "$BEFORE" == "$(home_sum)"
  check "reports the verbs" out_has 'Would add "Fooing" to spinnerVerbs.verbs'
}

# claude_attribution_setup - give this test's (fixture) setup the real
# attribution hook and its settings section
claude_attribution_setup() {
  cp -R "$REPO_DIR/setup/claude/hooks" "$T/setup/claude/hooks"
  cp "$REPO_DIR/setup/claude/settings/setting_attribution.json" "$T/setup/claude/settings/"
}
# hook_payload COMMAND [CWD] - a PreToolUse event for the Bash tool, shaped
# like the one Claude Code 2.1.319 sends (captured from a real session)
hook_payload() {
  jq -n --arg c "$1" --arg d "${2:-$T}" '{session_id: "s", transcript_path: "/dev/null", cwd: $d,
    permission_mode: "default", hook_event_name: "PreToolUse", tool_name: "Bash",
    tool_input: {command: $c, description: "d"}, tool_use_id: "t", effort: "high", prompt_id: "p"}'
}
# hook_rc HOOK COMMAND [CWD] - run HOOK on the event for COMMAND; its status
# to HRC, its stderr to $T/hook.err
hook_rc() {
  hook_payload "$2" "$3" > "$T/payload.json"
  bash "$1" < "$T/payload.json" 2> "$T/hook.err" > /dev/null
  HRC=$?
}
# settings_hook_rc COMMAND - run the hook command settings.json holds (CMD) the
# way Claude Code does, through a shell, on the event for COMMAND; status to HRC
settings_hook_rc() {
  hook_payload "$1" > "$T/payload.json"
  env -u CLAUDE_CONFIG_DIR HOME="$T/home" sh -c "$CMD" < "$T/payload.json" 2> "$T/hook.err" > /dev/null
  HRC=$?
}
readonly TRAILER='Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
readonly PR_LINE='🤖 Generated with [Claude Code](https://claude.com/claude-code)'
ATTRIBUTION_SETTING='{"commit": "", "pr": "", "sessionUrl": false}'
OUR_HOOK='.matcher == "Bash" and any(.hooks[]; .type == "command" and (.command | contains("hooks/no-attribution.sh")))'

test_claude_attribution_fresh() {
  env_new claude_attribution_fresh
  claude_attribution_setup
  run "$T/setup/claude/setup.sh"
  check "exit 0" rc_is 0
  check "hook installed" cmp -s "$T/setup/claude/hooks/no-attribution.sh" "$T/home/.claude/hooks/no-attribution.sh"
  # shellcheck disable=SC2016 # $A is a jq variable
  check "attribution turned off" jq -e --argjson A "$ATTRIBUTION_SETTING" '.attribution == $A' "$T/home/.claude/settings.json"
  check "PreToolUse hook added for Bash" jq -e ".hooks.PreToolUse | map(select($OUR_HOOK)) | length == 1" "$T/home/.claude/settings.json"
  # the command settings.json holds must run the installed hook
  local CMD
  CMD=$(jq -r ".hooks.PreToolUse[] | select($OUR_HOOK) | .hooks[0].command" "$T/home/.claude/settings.json")
  settings_hook_rc "git commit -m 'x

$TRAILER'"
  check "settings command blocks an attributed commit" test "$HRC" -eq 2
  settings_hook_rc "git commit -m 'plain'"
  check "settings command allows a plain commit" test "$HRC" -eq 0
  rm "$T/home/.claude/hooks/no-attribution.sh"
  settings_hook_rc "git commit -m 'x

$TRAILER'"
  check "settings command is a no-op when the hook file is missing" test "$HRC" -eq 0
}

test_claude_attribution_hook() {
  env_new claude_attribution_hook
  claude_attribution_setup
  local H="$T/setup/claude/hooks/no-attribution.sh"
  printf 'Fix it\n\n%s\n' "$TRAILER" > "$T/msg.txt"
  printf 'Fix it\n' > "$T/clean.txt"
  printf 'Body\n\n%s\n' "$PR_LINE" > "$T/body.md"
  # blocked: attribution in a commit or PR message, inline or in a file
  hook_rc "$H" "git commit -m 'Fix it

$TRAILER'"
  check "blocks -m with a Co-Authored-By trailer" test "$HRC" -eq 2
  check "says why" grep -qi 'attribution' "$T/hook.err"
  hook_rc "$H" "git commit -F - <<'EOF'
Fix it

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF"
  check "blocks a heredoc message" test "$HRC" -eq 2
  hook_rc "$H" "git -c user.name=t commit -q -F msg.txt"
  check "blocks -F FILE (git global options before commit)" test "$HRC" -eq 2
  hook_rc "$H" "git commit --file=msg.txt"
  check "blocks --file=FILE" test "$HRC" -eq 2
  hook_rc "$H" "git commit -m 'x

co-authored-by: claude <noreply@anthropic.com>'"
  check "blocks regardless of case" test "$HRC" -eq 2
  hook_rc "$H" "gh pr create --title t --body 'Body

$PR_LINE'"
  check "blocks gh pr create --body" test "$HRC" -eq 2
  hook_rc "$H" "gh pr edit 3 --body-file body.md"
  check "blocks gh pr edit --body-file" test "$HRC" -eq 2
  # every co-author or attribution tag is blocked, whoever it names
  local TAG
  for TAG in 'Co-authored-by: Codex <codex@openai.com>' 'Co-authored-by: Copilot <copilot@github.com>' \
    'Co-Authored-By: Jane Doe <jane@example.com>' 'Co-developed-by: Jane Doe <jane@example.com>' \
    'Assisted-by: Gemini' 'Generated-by: aider' 'Claude-Session: https://claude.ai/code/session_x'; do
    hook_rc "$H" "git commit -m 'Fix it

$TAG'"
    check "blocks '${TAG%%:*}: ${TAG#*: }'" test "$HRC" -eq 2
  done
  hook_rc "$H" "git commit -m \$'Fix it\\n\\nCo-authored-by: Codex <codex@openai.com>'"
  check "blocks a tag inside a one-line \$'...' message" test "$HRC" -eq 2
  hook_rc "$H" "gh pr create --title t --body 'Body

Generated with [Cursor](https://cursor.com)'"
  check "blocks another tool's credit line" test "$HRC" -eq 2
  hook_rc "$H" "gh pr create --title t --body 'Body

🤖 Generated by Codex'"
  check "blocks a credit line with 'Generated by'" test "$HRC" -eq 2
  # allowed: no attribution, or not a commit or PR
  hook_rc "$H" "git commit -m 'Fix it'"
  check "allows a plain commit" test "$HRC" -eq 0
  hook_rc "$H" "git commit -F clean.txt"
  check "allows a plain message file" test "$HRC" -eq 0
  hook_rc "$H" "git commit -m 'Regenerate the stubs generated with protoc'"
  check "allows 'generated with' in prose" test "$HRC" -eq 0
  hook_rc "$H" "git commit -m 'Fix the co-authored-by parser'"
  check "allows the words without a tag" test "$HRC" -eq 0
  hook_rc "$H" "git commit -m 'Fix it

Signed-off-by: Joe Ferraro <joe@example.com>'"
  check "allows a Signed-off-by sign-off" test "$HRC" -eq 0
  hook_rc "$H" "git cat-file commit HEAD | grep -qiE 'co-authored-by: claude|noreply@anthropic'"
  check "allows reading a commit and searching it" test "$HRC" -eq 0
  hook_rc "$H" "git log --all --format=%B | grep -ci 'noreply@anthropic'"
  check "allows searching the log" test "$HRC" -eq 0
  hook_rc "$H" "grep -rn '$TRAILER' ."
  check "allows grep for the trailer" test "$HRC" -eq 0
  hook_rc "$H" "gh pr view 3 | grep 'Generated with'"
  check "allows gh pr view" test "$HRC" -eq 0
  printf '{"tool_name": "Edit", "tool_input": {"file_path": "x"}}' > "$T/payload.json"
  bash "$H" < "$T/payload.json" 2> /dev/null > /dev/null
  check "allows an event with no command" test $? -eq 0
}

test_claude_attribution_keeps_hooks() {
  env_new claude_attribution_keeps_hooks
  claude_attribution_setup
  local SEED='{"theme": "light", "hooks": {
    "PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "my-bash-check"}]},
                   {"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "my-edit-check"}]}],
    "PostToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "my-post"}]}],
    "Stop": [{"hooks": [{"type": "command", "command": "my-stop"}]}]}}'
  mkdir -p "$T/home/.claude/hooks"
  printf '%s\n' "$SEED" > "$T/home/.claude/settings.json"
  printf 'my own hook\n' > "$T/home/.claude/hooks/mine.sh"
  # shellcheck disable=SC2016 # $S is a jq variable
  local OPT KEPT='(.hooks.PreToolUse[0:2] == $S.hooks.PreToolUse) and (.hooks.PostToolUse == $S.hooks.PostToolUse) and (.hooks.Stop == $S.hooks.Stop)'
  for OPT in "" -f; do
    run "$T/setup/claude/setup.sh" $OPT
    check "${OPT:-plain}: exit 0" rc_is 0
    check "${OPT:-plain}: other hooks kept, in place" jq -e --argjson S "$SEED" "$KEPT" "$T/home/.claude/settings.json"
    check "${OPT:-plain}: ours added once, after them" jq -e "(.hooks.PreToolUse | length == 3) and (.hooks.PreToolUse[2] | $OUR_HOOK)" "$T/home/.claude/settings.json"
    check "${OPT:-plain}: other hook file kept" file_is "$T/home/.claude/hooks/mine.sh" "my own hook"
  done
  local BEFORE
  BEFORE=$(home_sum)
  run "$T/setup/claude/setup.sh" -f
  check "again: nothing changed" test "$(home_sum)" == "$BEFORE"
}

# left_arrow_warning FILE - the start of the warning that FILE does not turn
# off "← opens agents"
left_arrow_warning() { echo "Warning: leftArrowOpensAgents is not false in $1"; }

test_claude_left_arrow() {
  env_new claude_left_arrow
  local STATE
  # installed first, so only the warning can keep each run below from being
  # up to date
  run "$T/setup/claude/setup.sh"
  # leftArrowOpensAgents is only ever changed in /config, so each state is
  # warned about and the file is left exactly as it was
  for STATE in missing '{}' '{"leftArrowOpensAgents": true}' '{bad'; do
    rm -f "$T/home/.claude.json"
    [[ $STATE == missing ]] || printf '%s\n' "$STATE" > "$T/home/.claude.json"
    run "$T/setup/claude/setup.sh"
    check "$STATE: exit 0" rc_is 0
    check "$STATE: warned, naming the file" out_has "$(left_arrow_warning "$T/home/.claude.json")"
    check "$STATE: points to /config" out_has 'turn off "← opens agents" in /config'
    check "$STATE: says how to reach it with agent view off" out_has "claude --settings '{\"disableAgentView\":false}'"
    check "$STATE: not up to date" out_lacks "Claude Code is up to date"
    if [[ $STATE == missing ]]; then
      check "$STATE: not created" test ! -e "$T/home/.claude.json"
    else
      check "$STATE: left as it was" file_is "$T/home/.claude.json" "$STATE"
    fi
  done
  run "$T/setup/claude/setup.sh" -n
  check "dry run: warned too" out_has "$(left_arrow_warning "$T/home/.claude.json")"
  run "$T/setup/setup-agents.sh" claude
  check "setup-agents.sh: warned" out_has "$(left_arrow_warning "$T/home/.claude.json")"
  # green control: turned off, nothing is said
  printf '{"leftArrowOpensAgents": false, "other": 1}\n' > "$T/home/.claude.json"
  run "$T/setup/claude/setup.sh"
  check "false: not warned" out_lacks "leftArrowOpensAgents"
  check "false: up to date" out_has "Claude Code is up to date in $T/home/.claude"
}

test_claude_left_arrow_config_dir() {
  env_new claude_left_arrow_config_dir
  # with CLAUDE_CONFIG_DIR set, Claude Code keeps .claude.json there, not in HOME
  mkdir -p "$T/cfg"
  printf '{}\n' > "$T/cfg/.claude.json"
  run env CLAUDE_CONFIG_DIR="$T/cfg" "$T/setup/claude/setup.sh"
  check "exit 0" rc_is 0
  check "CLAUDE_CONFIG_DIR's file warned about" out_has "$(left_arrow_warning "$T/cfg/.claude.json")"
  # green control: off in CLAUDE_CONFIG_DIR, so HOME's file is not consulted
  printf '{"leftArrowOpensAgents": false}\n' > "$T/cfg/.claude.json"
  printf '{}\n' > "$T/home/.claude.json"
  run env CLAUDE_CONFIG_DIR="$T/cfg" "$T/setup/claude/setup.sh"
  check "off there: not warned" out_lacks "leftArrowOpensAgents"
}

# ---- codex -----------------------------------------------------------------

test_codex_fresh() {
  env_new codex_fresh
  run "$T/setup/codex/setup.sh"
  check "exit 0" rc_is 0
  check "AGENTS.md installed" file_is "$T/home/.codex/AGENTS.md" "codex rules"
  check "config.toml installed" toml_is "$T/home/.codex/config.toml" \
    '{"model": "m1", "model_reasoning_effort": "xhigh", "tui": {"alt": true}}'
  check "generic skill installed" file_is "$T/home/.codex/skills/gen/SKILL.md" "generic skill"
}

test_codex_merge() {
  env_new codex_merge
  mkdir -p "$T/home/.codex"
  printf '# my codex config\nmodel = "mine"\n\n[projects."/home/u/src"]\ntrust_level = "trusted"\n' > "$T/home/.codex/config.toml"
  run "$T/setup/codex/setup.sh"
  check "exit 0" rc_is 0
  check "merged: top-level key stays top-level, new table added" toml_is "$T/home/.codex/config.toml" \
    '{"model": "mine", "model_reasoning_effort": "xhigh", "projects": {"/home/u/src": {"trust_level": "trusted"}}, "tui": {"alt": true}}'
  check "conflict warned" out_has 'Warning: model is already set to "mine", skipping new value "m1"'
  check "comment kept" grep -qx '# my codex config' "$T/home/.codex/config.toml"
}

test_codex_existing_table() {
  env_new codex_existing_table
  mkdir -p "$T/home/.codex"
  printf 'model = "m1"\nlist = [\n  "a",\n]\n\n[tui]\nother = 1\n\n[projects."x"]\ntrust_level = "trusted"\n' > "$T/home/.codex/config.toml"
  run "$T/setup/codex/setup.sh"
  check "exit 0" rc_is 0
  check "keys added to their own tables" toml_is "$T/home/.codex/config.toml" \
    '{"model": "m1", "list": ["a"], "model_reasoning_effort": "xhigh", "tui": {"other": 1, "alt": true}, "projects": {"x": {"trust_level": "trusted"}}}'
}

test_codex_force() {
  env_new codex_force
  mkdir -p "$T/home/.codex"
  printf 'model = "mine"\n' > "$T/home/.codex/config.toml"
  run "$T/setup/codex/setup.sh" -f
  check "exit 0" rc_is 0
  check "conflict overwritten" toml_is "$T/home/.codex/config.toml" \
    '{"model": "m1", "model_reasoning_effort": "xhigh", "tui": {"alt": true}}'
}

test_codex_dry_run() {
  env_new codex_dry_run
  mkdir -p "$T/home/.codex"
  printf 'model = "mine"\n' > "$T/home/.codex/config.toml"
  local BEFORE
  BEFORE=$(home_sum)
  run "$T/setup/codex/setup.sh" -n
  check "exit 0" rc_is 0
  check "HOME unchanged" test "$BEFORE" == "$(home_sum)"
  check "reports the change" out_has 'Would set model_reasoning_effort = "xhigh"'
}

test_codex_idempotent() {
  env_new codex_idempotent
  run "$T/setup/codex/setup.sh"
  run "$T/setup/codex/setup.sh"
  check "exit 0" rc_is 0
  check "second run is up to date" out_has "Codex is up to date in $T/home/.codex"
}

test_codex_escaped_quote() {
  env_new codex_escaped_quote
  printf 'model = "a\\"#c"\n' > "$T/setup/codex/config.toml"
  mkdir -p "$T/home/.codex"
  printf 'model = "a\\"#b"  # mine\n' > "$T/home/.codex/config.toml"
  run "$T/setup/codex/setup.sh"
  check "exit 0" rc_is 0
  check "values compared past the \\\" and # inside them" \
    out_has 'Warning: model is already set to "a\"#b", skipping new value "a\"#c"'
}

test_codex_multiline_value_kept() {
  env_new codex_multiline_value_kept
  mkdir -p "$T/home/.codex"
  printf 'model = [\n  "x",\n]\n' > "$T/home/.codex/config.toml"
  run "$T/setup/codex/setup.sh" -f
  check "exit 0" rc_is 0
  check "multi-line value warned" out_has "Warning: model has a multi-line value"
  check "multi-line value kept, file still valid" toml_is "$T/home/.codex/config.toml" \
    '{"model": ["x"], "model_reasoning_effort": "xhigh", "tui": {"alt": true}}'
}

test_codex_multiline_string() {
  env_new codex_multiline_string
  mkdir -p "$T/home/.codex"
  printf 'notes = """\n[tui]\nmodel = "zzz"\n"""\nmodel = "m1"\n' > "$T/home/.codex/config.toml"
  run "$T/setup/codex/setup.sh"
  check "exit 0" rc_is 0
  check "header and setting inside the string ignored" toml_is "$T/home/.codex/config.toml" \
    '{"notes": "[tui]\nmodel = \"zzz\"\n", "model": "m1", "model_reasoning_effort": "xhigh", "tui": {"alt": true}}'
}

test_codex_unsupported_source() {
  env_new codex_unsupported_source
  printf 'model = "m1"\nlist = [\n  "a",\n]\n' > "$T/setup/codex/config.toml"
  mkdir -p "$T/home/.codex"
  printf 'model = "mine"\n' > "$T/home/.codex/config.toml"
  run "$T/setup/codex/setup.sh"
  check "fails" test "$RC" -ne 0
  check "names the line" out_has "cannot merge 'list = ['"
  check "config.toml untouched" file_is "$T/home/.codex/config.toml" 'model = "mine"'
}

test_codex_interactive() {
  env_new codex_interactive
  mkdir -p "$T/home/.codex"
  printf 'model = "mine"\n' > "$T/home/.codex/config.toml"
  # AGENTS.md y; model i, model_reasoning_effort n, tui.alt y; both skill files y
  run_with 'y\ni\nn\ny\ny\ny\n' "$T/setup/codex/setup.sh" -fi
  check "exit 0" rc_is 0
  check "setting prompt" out_has 'Overwrite model = "m1" (was "mine")? [y/N/i]'
  check "new setting prompt says it is new" out_has 'Set model_reasoning_effort = "xhigh" (new)? [y/N/i]'
  check "y applied, n and i skipped" toml_is "$T/home/.codex/config.toml" '{"model": "mine", "tui": {"alt": true}}'
  check "y installed the file" file_is "$T/home/.codex/AGENTS.md" "codex rules"
  check "i added the setting" grep -qx "model" "$T/setup/codex/config.ignore.txt"
}

test_codex_ignore() {
  env_new codex_ignore
  mkdir -p "$T/home/.codex"
  printf 'model = "mine"\n' > "$T/home/.codex/config.toml"
  printf 'model\ntui\n' > "$T/setup/codex/config.ignore.txt"
  run "$T/setup/codex/setup.sh" -f
  check "exit 0" rc_is 0
  check "listed key and table kept, even with -f" toml_is "$T/home/.codex/config.toml" \
    '{"model": "mine", "model_reasoning_effort": "xhigh"}'
  check "key in an ignored table reported" out_has "Ignoring tui.alt (listed in"
}

# ---- omp -------------------------------------------------------------------

OMP_SEED='modelRoles:\n  default: prov/mine\ntheme:\n  dark: titanium\nenabledProviders:\n  - anthropic\nsymbolPreset: unicode\n'

test_omp_fresh() {
  env_new omp_fresh
  run "$T/setup/omp/setup.sh"
  check "exit 0" rc_is 0
  check "command installed" file_is "$T/home/.omp/agent/commands/cmd.md" "cmd"
  check "omp skill installed" file_is "$T/home/.omp/agent/skills/ompskill/SKILL.md" "omp skill"
  check "generic skill installed" file_is "$T/home/.omp/agent/skills/gen/SKILL.md" "generic skill"
  check "settings installed" omp_is '{"modelRoles": {"default": "prov/big", "smol": "prov/small"}, "theme.dark": "obsidian", "enabledProviders": ["codex"]}'
  check "reload hint" out_has "/reload-plugins"
}

test_omp_merge() {
  env_new omp_merge
  mkdir -p "$T/home/.omp/agent"
  printf '%b' "$OMP_SEED" > "$T/home/.omp/agent/config.yml"
  run "$T/setup/omp/setup.sh"
  check "exit 0" rc_is 0
  check "settings merged" omp_is '{"modelRoles": {"default": "prov/mine", "smol": "prov/small"}, "theme.dark": "titanium", "enabledProviders": ["anthropic", "codex"], "symbolPreset": "unicode"}'
  check "conflict warned" out_has 'Warning: theme.dark is already set to "titanium", skipping new value "obsidian"'
  check "nested conflict warned" out_has 'Warning: modelRoles.default is already set to "prov/mine"'
}

test_omp_force() {
  env_new omp_force
  mkdir -p "$T/home/.omp/agent"
  printf '%b' "$OMP_SEED" > "$T/home/.omp/agent/config.yml"
  run "$T/setup/omp/setup.sh" -f
  check "exit 0" rc_is 0
  check "conflicts overwritten" omp_is '{"modelRoles": {"default": "prov/big", "smol": "prov/small"}, "theme.dark": "obsidian", "enabledProviders": ["anthropic", "codex"], "symbolPreset": "unicode"}'
}

test_omp_dry_run() {
  env_new omp_dry_run
  mkdir -p "$T/home/.omp/agent"
  printf '%b' "$OMP_SEED" > "$T/home/.omp/agent/config.yml"
  cp "$T/home/.omp/agent/config.yml" "$T/seed.yml"
  run "$T/setup/omp/setup.sh" -n
  check "exit 0" rc_is 0
  check "config.yml unchanged" cmp -s "$T/seed.yml" "$T/home/.omp/agent/config.yml"
  check "commands not installed" test ! -e "$T/home/.omp/agent/commands"
  check "reports the change" out_has 'Would set modelRoles.smol = "prov/small"'
}

test_omp_idempotent() {
  env_new omp_idempotent
  run "$T/setup/omp/setup.sh"
  run "$T/setup/omp/setup.sh"
  check "exit 0" rc_is 0
  check "second run is up to date" out_has "omp is up to date in $T/home/.omp/agent"
}

test_omp_ignore() {
  env_new omp_ignore
  mkdir -p "$T/home/.omp/agent/commands"
  printf '%b' "$OMP_SEED" > "$T/home/.omp/agent/config.yml"
  printf 'old cmd\n' > "$T/home/.omp/agent/commands/cmd.md"
  printf 'theme.dark\nenabledProviders\n%s\nskills/ompskill\n' "$T/home/.omp/agent/commands/cmd.md" > "$T/setup/omp/config.ignore.txt"
  run "$T/setup/omp/setup.sh" -n -f
  check "dry run: exit 0" rc_is 0
  check "dry run: unlisted setting overwritten" out_has 'Would overwrite modelRoles.default = "prov/big" (was "prov/mine")'
  check "dry run: listed setting reported" out_has "Ignoring theme.dark (listed in $T/setup/omp/config.ignore.txt)"
  check "dry run: listed setting not overwritten" out_lacks "Would overwrite theme.dark"
  run "$T/setup/omp/setup.sh" -f
  check "exit 0" rc_is 0
  check "only unlisted settings changed" omp_is \
    '{"modelRoles": {"default": "prov/big", "smol": "prov/small"}, "theme.dark": "titanium", "enabledProviders": ["anthropic"], "symbolPreset": "unicode"}'
  check "file listed by its full path kept" file_is "$T/home/.omp/agent/commands/cmd.md" "old cmd"
  check "directory listed by its path in the agent's directory skipped" test ! -e "$T/home/.omp/agent/skills/ompskill"
  check "unlisted skill installed" file_is "$T/home/.omp/agent/skills/gen/SKILL.md" "generic skill"
  check "listed list reported" out_has "Ignoring enabledProviders (listed in"
}

test_omp_interactive() {
  env_new omp_interactive
  mkdir -p "$T/home/.omp/agent"
  printf '%b' "$OMP_SEED" > "$T/home/.omp/agent/config.yml"
  # cmd.md y, the generic skill's two files y, ompskill i; the settings in
  # name order: enabledProviders i, modelRoles.default y, modelRoles.smol n,
  # theme.dark n
  run_with 'y\ny\ny\ni\ni\ny\nn\nn\n' "$T/setup/setup-agents.sh" -fi omp
  check "exit 0" rc_is 0
  check "only the y answers applied" omp_is \
    '{"modelRoles": {"default": "prov/big"}, "theme.dark": "titanium", "enabledProviders": ["anthropic"], "symbolPreset": "unicode"}'
  check "y installed the command" file_is "$T/home/.omp/agent/commands/cmd.md" "cmd"
  check "i skipped the skill" test ! -e "$T/home/.omp/agent/skills/ompskill"
  check "i added the skill by its path in the agent's directory" grep -qx "skills/ompskill/SKILL.md" "$T/setup/omp/config.ignore.txt"
  check "i added the setting" grep -qx "enabledProviders" "$T/setup/omp/config.ignore.txt"
}

test_omp_not_installed() {
  env_new omp_not_installed
  run env PATH=/usr/bin:/bin "$T/setup/omp/setup.sh"
  check "exit 0" rc_is 0
  check "says omp is missing" out_has "omp not found"
  check "files still installed" file_is "$T/home/.omp/agent/commands/cmd.md" "cmd"
}

# ---- the real data files ---------------------------------------------------

test_real_files() {
  env_new real_files real
  run "$T/setup/setup-agents.sh"
  check "exit 0" rc_is 0
  check "CLAUDE.md" cmp -s "$T/setup/claude/CLAUDE.md" "$T/home/.claude/CLAUDE.md"
  # the real sections set separate settings, so a plain deep merge models them
  check "settings.json, every section merged in" json_is "$T/home/.claude/settings.json" \
    "$(jq -s 'reduce .[] as $s ({}; . * $s)' "$T/setup/claude/settings/"setting_*.json)"
  check "attribution hook" cmp -s "$T/setup/claude/hooks/no-attribution.sh" "$T/home/.claude/hooks/no-attribution.sh"
  check "AGENTS.md" cmp -s "$T/setup/codex/AGENTS.md" "$T/home/.codex/AGENTS.md"
  check "config.toml" toml_is "$T/home/.codex/config.toml" \
    "$(python3 -c 'import json, sys, tomllib; print(json.dumps(tomllib.load(open(sys.argv[1], "rb"))))' "$T/setup/codex/config.toml")"
  check "do-prompt skill" cmp -s "$T/setup/omp/skills/do-prompt/SKILL.md" "$T/home/.omp/agent/skills/do-prompt/SKILL.md"
  check "do-prompt command" cmp -s "$T/setup/omp/commands/do-prompt.md" "$T/home/.omp/agent/commands/do-prompt.md"
  check "config.yml" omp_is "$(PI_CODING_AGENT_DIR="$T/setup/omp" HOME="$T/home" omp config list --scope=global --json | jq 'map_values(.value)')"
}

# ---- main ------------------------------------------------------------------

TESTS=(
  test_dispatch_help test_dispatch_unknown_agent test_dispatch_selected_agent test_agent_bad_arguments
  test_claude_fresh test_claude_merge test_claude_force test_claude_dry_run test_claude_idempotent
  test_claude_invalid_settings test_claude_sections test_claude_sections_conflict test_claude_sections_invalid
  test_claude_ignore test_claude_interactive test_claude_interactive_adds test_claude_reconsider_adds test_claude_reconsider test_claude_reconsider_remove test_claude_reconsider_r_reasks test_claude_interactive_no_answers
  test_claude_no_sections test_claude_spinner_fresh test_claude_spinner_merge test_claude_spinner_dry_run
  test_claude_attribution_fresh test_claude_attribution_hook test_claude_attribution_keeps_hooks
  test_claude_left_arrow test_claude_left_arrow_config_dir
  test_codex_fresh test_codex_merge test_codex_existing_table test_codex_force test_codex_dry_run
  test_codex_idempotent test_codex_escaped_quote test_codex_multiline_value_kept test_codex_multiline_string
  test_codex_unsupported_source test_codex_ignore test_codex_interactive
)
OMP_TESTS=(
  test_omp_fresh test_omp_merge test_omp_force test_omp_dry_run test_omp_idempotent test_omp_ignore test_omp_interactive test_omp_not_installed
  test_real_files
)
if command -v omp >/dev/null; then
  TESTS+=("${OMP_TESTS[@]}")
else
  echo "SKIP: omp not in PATH: ${OMP_TESTS[*]}"
  SKIPPED=${#OMP_TESTS[@]}
fi
[[ $# -gt 0 ]] && TESTS=("$@")

for FN in "${TESTS[@]}"; do
  "$FN"
done
echo "checks: PASSED $PASSED, FAILED $FAILED; tests SKIPPED: $SKIPPED"
[[ $FAILED -eq 0 ]]
