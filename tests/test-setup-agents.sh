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
  # this host's own ignore lists must not leak into the tests
  rm -f "$T"/setup/*/config.ignore.txt
  [[ -d $REAL_OMP_NATIVES ]] && { mkdir -p "$T/home/.omp"; ln -s "$REAL_OMP_NATIVES" "$T/home/.omp/natives"; }
  [[ $2 == real ]] && return 0
  rm -rf "$T/setup/omp/commands" "$T/setup/omp/skills" "$T/setup/skills" "$T/setup/claude/settings"
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
  [[ -z ${SHOWN} ]] && sed 's/^/    | /' "$T/out"
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
  for OPTS in "-i -n" "-i -f" "-I -n" "-I -f" "-i -I"; do
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
  run_with 'x\ni\ny\ni\ny\nn\ny\ny\n' "$T/setup/claude/setup.sh" -i
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

test_claude_reconsider() {
  env_new claude_reconsider
  claude_seed
  printf 'theme\nCLAUDE.md\n' > "$T/setup/claude/config.ignore.txt"
  # CLAUDE.md i (already listed); effortLevel y, list y,
  # modelSettings.m.effortLevel y, theme y (listed); both skill files y
  run_with 'i\ny\ny\ny\ny\ny\ny\n' "$T/setup/claude/setup.sh" -I
  check "exit 0" rc_is 0
  check "listed setting asked about, marked as listed" \
    out_has 'Overwrite theme = "dark" (was "light") (listed in config.ignore.txt)? [y/N/i]'
  check "listed setting applied on y" json_is "$T/home/.claude/settings.json" \
    '{"theme": "dark", "extra": 1, "list": ["b", "c", "a"], "modelSettings": {"m": {"other": 2, "effortLevel": "xhigh"}}, "effortLevel": "xhigh"}'
  check "listed file kept on i" file_is "$T/home/.claude/CLAUDE.md" "mine"
  check "ignore file unchanged: y removes nothing, i adds no duplicate" \
    file_is "$T/setup/claude/config.ignore.txt" "$(printf 'theme\nCLAUDE.md')"
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
  run_with 'y\ni\nn\ny\ny\ny\n' "$T/setup/codex/setup.sh" -i
  check "exit 0" rc_is 0
  check "setting prompt" out_has 'Overwrite model = "m1" (was "mine")? [y/N/i]'
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
  run_with 'y\ny\ny\ni\ni\ny\nn\nn\n' "$T/setup/omp/setup.sh" -i
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
  test_claude_ignore test_claude_interactive test_claude_reconsider test_claude_interactive_no_answers
  test_claude_no_sections test_claude_spinner_fresh test_claude_spinner_merge test_claude_spinner_dry_run
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
