# shellcheck shell=bash
# common/agent-lib.sh - functions shared by the coding-agent setup scripts
# (setup/<agent>/setup.sh); sourced, not run.
#
# Everything is merged the way setup-git.sh merges git settings:
#   missing from the destination  -> installed / set
#   identical                     -> left alone
#   different                     -> existing kept and a warning printed;
#                                    -f overwrites it instead
# Lists (JSON/YAML arrays) never conflict: entries they lack are appended.
# -n shows what would be done without changing anything.
# Anything named in the agent's config.ignore.txt (see read_ignore) is left
# alone, even with -f.  -i asks before each change the run would make (see
# ask): each addition, and with -f each overwrite too; -I asks about what
# config.ignore.txt lists as well.

# the setup/ directory: this file lives in setup/common
SETUP_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck disable=SC2034 # used by the agent scripts
readonly SETUP_DIR
WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/setup-agents.XXXXXX")
readonly WORKDIR
trap 'rm -rf "${WORKDIR}"' EXIT
unset CHANGED WARNED
IGNORE=()
IGNORE_LISTED=()
IGNORE_FILE=""
IGNORE_BASE=""

agent_options() {
  echo "Options:"
  echo "  -f : Overwrite files and settings that differ (default: keep them and warn)"
  echo "  -n : Show what would be done without making changes"
  echo "  -i : Ask before each addition (with -f, before each overwrite too): y makes it,"
  echo "       n skips it, i skips it and adds it to config.ignore.txt"
  echo "  -I : Like -i, but also ask about what config.ignore.txt lists; for those, r makes"
  echo "       the change and removes them from config.ignore.txt"
  echo "  -h : Show this help message"
  echo "Settings and files named in config.ignore.txt beside setup.sh are left alone, even with -f"
}

# parse_opts "$@" - handle -f, -n, -i, -I and -h; the caller defines usage()
parse_opts() {
  unset FORCE_OVERWRITE DRYRUN INTERACTIVE RECONSIDER
  local OPT OPTIND=1 ASK=""
  while getopts fniIh OPT; do
    case $OPT in
      f) FORCE_OVERWRITE=1 ;;
      n) DRYRUN=1 ;;
      i) INTERACTIVE=1; ASK+=i ;;
      I) INTERACTIVE=1; RECONSIDER=1; ASK+=I ;;
      h) usage; exit 0 ;;
      *) usage >&2; exit 22 ;;
    esac
  done
  shift $((OPTIND - 1))
  [[ $# -ne 0 ]] && { echo "Unexpected argument: $1" >&2; usage >&2; exit 22; }
  [[ $ASK == *i* && $ASK == *I* ]] && { echo "Error: -i and -I cannot be combined" >&2; usage >&2; exit 22; }
  [[ -n ${INTERACTIVE} && -n ${DRYRUN} ]] && { echo "Error: -i and -I cannot be combined with -n" >&2; usage >&2; exit 22; }
  return 0
}

# require CMD - exit unless CMD is installed
require() {
  command -v "$1" >/dev/null || { echo "Error: $1 is required but not installed" >&2; exit 1; }
}

# changed DONE WOULD - record a change: print DONE, or "Would WOULD" with -n
changed() {
  CHANGED=1
  [[ -n ${DRYRUN} ]] && echo "Would $2" || echo "$1"
}

# warn MESSAGE - print a warning about something left as it is
warn() {
  WARNED=1
  echo "Warning: $1"
}

# report NAME DIR [HINT] - summarize the run for agent NAME; HINT is printed
# when something changed
report() {
  [[ -z ${CHANGED} && -z ${WARNED} ]] && echo "$1 is up to date in $2"
  [[ -n ${CHANGED} && -z ${DRYRUN} && -n $3 ]] && echo "$3"
  return 0
}

# trim TEXT - print TEXT without leading and trailing whitespace
trim() {
  local S="$1"
  S="${S#"${S%%[![:space:]]*}"}"
  S="${S%"${S##*[![:space:]]}"}"
  printf '%s' "$S"
}

# ---- config.ignore.txt -----------------------------------------------------

# read_ignore FILE BASE - leave alone everything FILE (if it exists) names,
# one per line: a setting as setup prints it (e.g. theme.dark), or an
# installed file or directory by its full path or its path under BASE (e.g.
# skills/do-prompt).  A name covers everything under it.  Blank lines and
# lines starting with # are skipped.  With -I nothing is left alone, but the
# names are still read (into IGNORE_LISTED) so the questions can mention them
read_ignore() {
  local LINE
  IGNORE=()
  IGNORE_LISTED=()
  IGNORE_FILE="$1"
  IGNORE_BASE="$2"
  [[ -f $IGNORE_FILE ]] || return 0
  while IFS= read -r LINE || [[ -n $LINE ]]; do
    LINE=$(trim "$LINE")
    [[ -z $LINE || $LINE == \#* ]] && continue
    IGNORE_LISTED+=("$LINE")
  done < "$IGNORE_FILE"
  [[ -z ${RECONSIDER} ]] && IGNORE=("${IGNORE_LISTED[@]}")
  return 0
}

# setting_in NAME ENTRY... - succeed if setting NAME (e.g. modelRoles.default),
# or one it belongs to (modelRoles), is one of the ENTRYs
setting_in() {
  local NAME="$1" E
  shift
  for E in "$@"; do
    [[ $NAME == "$E" || $NAME == "$E".* ]] && return 0
  done
  return 1
}

# file_in DST ENTRY... - succeed if installed file DST, or a directory holding
# it, is one of the ENTRYs (by its full path or its path under IGNORE_BASE)
file_in() {
  local DST="$1" E REL="${1#"$IGNORE_BASE"/}"
  shift
  for E in "$@"; do
    E=${E%/}
    [[ $DST == "$E" || $DST == "$E"/* || $REL == "$E" || $REL == "$E"/* ]] && return 0
  done
  return 1
}

# ignored_setting NAME / ignored_file DST - succeed if setting NAME or file DST
# is to be left alone
ignored_setting() { setting_in "$1" "${IGNORE[@]}"; }
ignored_file() { file_in "$1" "${IGNORE[@]}"; }

# ignoring NAME - report that NAME is left alone because it is listed
ignoring() {
  echo "Ignoring $1 (listed in $IGNORE_FILE)"
}

# add_ignore NAME - add NAME to config.ignore.txt, unless it is there already,
# and leave it alone from now on
add_ignore() {
  local E
  for E in "${IGNORE_LISTED[@]}"; do
    [[ $E == "$1" ]] && { echo "Ignoring $1 (already listed in $IGNORE_FILE)"; return 0; }
  done
  if [[ ! -f $IGNORE_FILE ]]; then
    echo "# Settings and files the agent setup leaves alone on this machine (see setup/README.md)" > "$IGNORE_FILE"
  elif [[ -n $(tail -c1 "$IGNORE_FILE") ]]; then
    echo >> "$IGNORE_FILE"
  fi
  printf '%s\n' "$1" >> "$IGNORE_FILE"
  IGNORE_LISTED+=("$1")
  IGNORE+=("$1")
  echo "Ignoring $1 from now on (added to $IGNORE_FILE)"
}

# remove_ignore ENTRY... - remove the lines naming ENTRY from
# config.ignore.txt (comments and other lines are kept), and stop leaving
# ENTRY alone
remove_ignore() {
  local LINE E KEEP TMP="$WORKDIR/config.ignore.txt"
  local -a REST
  : > "$TMP"
  while IFS= read -r LINE || [[ -n $LINE ]]; do
    KEEP=1
    for E in "$@"; do
      [[ $(trim "$LINE") == "$E" ]] && KEEP=""
    done
    [[ -n $KEEP ]] && printf '%s\n' "$LINE" >> "$TMP"
  done < "$IGNORE_FILE"
  cp -- "$TMP" "$IGNORE_FILE"
  for E in "$@"; do
    REST=()
    for LINE in "${IGNORE_LISTED[@]}"; do
      [[ $LINE == "$E" ]] || REST+=("$LINE")
    done
    IGNORE_LISTED=("${REST[@]}")
    REST=()
    for LINE in "${IGNORE[@]}"; do
      [[ $LINE == "$E" ]] || REST+=("$LINE")
    done
    IGNORE=("${REST[@]}")
    echo "No longer ignoring $E (removed from $IGNORE_FILE)"
  done
}

# ---- -i and -I ---------------------------------------------------------------

# ask QUESTION NAME KIND - ask whether to make the change QUESTION describes to
# NAME, a setting or (KIND file) an installed file, reading the answer from
# the input: y makes it (succeeds); n, an empty answer or the end of the input
# skips it; i skips it and adds NAME (a file by its path under IGNORE_BASE)
# to config.ignore.txt.  When config.ignore.txt lists NAME (which only -I
# asks about), the question says so and r is offered as well: it makes the
# change and removes the lines that list NAME
ask() {
  local QUESTION="$1" NAME="$2" ANSWER E NOTE="" CHOICES="y/N/i" PLEASE="y, n or i"
  local -a LISTED=()
  for E in "${IGNORE_LISTED[@]}"; do
    if [[ $3 == file ]]; then
      file_in "$NAME" "$E" && LISTED+=("$E")
    else
      setting_in "$NAME" "$E" && LISTED+=("$E")
    fi
  done
  [[ $3 == file ]] && NAME=${NAME#"$IGNORE_BASE"/}
  if [[ ${#LISTED[@]} -gt 0 ]]; then
    NOTE=" (listed in ${IGNORE_FILE##*/})"
    CHOICES="y/N/i/r"
    PLEASE="y, n, i or r"
  fi
  while :; do
    printf '%s%s? [%s] ' "$QUESTION" "$NOTE" "$CHOICES" >&2
    IFS= read -r ANSWER || { echo >&2; return 1; }
    case $ANSWER in
      y|Y) return 0 ;;
      ''|n|N) return 1 ;;
      i|I)
        [[ ${#LISTED[@]} -gt 0 ]] && { echo "Ignoring $NAME (already listed in $IGNORE_FILE)"; return 1; }
        add_ignore "$NAME"
        return 1 ;;
      r|R) [[ ${#LISTED[@]} -gt 0 ]] && { remove_ignore "${LISTED[@]}"; return 0; } ;;
    esac
    echo "Please answer $PLEASE" >&2
  done
}

# allow_add QUESTION NAME KIND - succeed if NAME may be added: always, or with
# -i/-I if the answer to QUESTION is y
allow_add() {
  [[ -z ${INTERACTIVE} ]] || ask "$@"
}

# allow_overwrite QUESTION NAME KIND WARNING - succeed if NAME, which differs,
# may be overwritten: only with -f (otherwise print WARNING), and with -i/-I
# too only if the answer to QUESTION is y
allow_overwrite() {
  [[ -z ${FORCE_OVERWRITE} ]] && { warn "$4"; return 1; }
  [[ -z ${INTERACTIVE} ]] || ask "$1" "$2" "$3"
}

# ---- files -----------------------------------------------------------------

# install_file SRC DST - install file SRC as DST
install_file() {
  local SRC="$1" DST="$2" DONE=Installed WOULD=install
  [[ -f $DST ]] && cmp -s "$SRC" "$DST" && return 0
  ignored_file "$DST" && { ignoring "$DST"; return 0; }
  [[ -d $DST ]] && { warn "$DST is a directory, skipping $SRC"; return 0; }
  if [[ -e $DST || -L $DST ]]; then
    allow_overwrite "Overwrite $DST" "$DST" file "$DST differs from $SRC, keeping it (use -f to overwrite)" || return 0
    DONE=Overwrote
    WOULD=overwrite
  else
    allow_add "Install $DST" "$DST" file || return 0
  fi
  if [[ -z ${DRYRUN} ]]; then
    mkdir -p "$(dirname "$DST")"
    cp -- "$SRC" "$DST"
  fi
  changed "$DONE $DST" "$WOULD $DST"
}

# install_tree SRCDIR DSTDIR - install every file under SRCDIR into DSTDIR
install_tree() {
  local SRCDIR="$1" DSTDIR="$2" SRC
  [[ -d $SRCDIR ]] || return 0
  # the file names are read on fd 3: install_file may read answers from the input
  while IFS= read -r -d '' -u 3 SRC; do
    install_file "$SRC" "$DSTDIR/${SRC#"$SRCDIR"/}"
  done 3< <(find "$SRCDIR" -type f -print0 | sort -z)
  return 0
}

# install_skills SRCDIR DSTDIR - install each skill (a directory holding a
# SKILL.md) directly under SRCDIR as DSTDIR/<skill>
install_skills() {
  local SRCDIR="$1" DSTDIR="$2" SKILL
  for SKILL in "$SRCDIR"/*/SKILL.md; do
    [[ -f $SKILL ]] || continue
    SKILL=$(dirname "$SKILL")
    install_tree "$SKILL" "$DSTDIR/${SKILL##*/}"
  done
  return 0
}

# ---- JSON (and omp's settings, which 'omp config' presents as JSON) --------

# jq program for json_merge: merge $new[0] into $cur[0] by the rules at the
# top, leaving alone the settings named in $ignore (listed in $ignorefile)
# and, silently, those in $skip; emits {value, keys, warned, conflicts,
# questions, messages}, keys being the top-level keys whose value changed,
# conflicts the settings kept because their values differ, and questions
# {name, text} for -i, one per change made (not per conflict kept), in name
# order
# shellcheck disable=SC2016 # a jq program: its $names are jq variables
readonly JSON_MERGE='
def name: map(tostring) | join(".");
def ignored($path): ($path | name) as $n | any($ignore[]; . as $e | $n == $e or ($n | startswith($e + ".")));
def skipped($path): ($path | name) as $n | any($skip[]; . == $n);
def merge($cur; $new; $path):
  if ($cur | type) == "object" and ($new | type) == "object" then
    reduce ($new | keys_unsorted[]) as $k ({value: $cur, log: []};
      ($path + [$k]) as $p
      | if .value | has($k) then
          merge(.value[$k]; $new[$k]; $p) as $m
          | if $m.log == [] then .
            elif ignored($p) then .log += [{op: "ignore", path: $p}]
            elif skipped($p) then .
            else .value[$k] = $m.value | .log += $m.log end
        elif ignored($p) then .log += [{op: "ignore", path: $p}]
        elif skipped($p) then .
        else .value[$k] = $new[$k] | .log += [{op: "set", path: $p, new: $new[$k]}]
        end)
  elif ($cur | type) == "array" and ($new | type) == "array" then
    ($new - $cur) as $add
    | if $add == [] then {value: $cur, log: []}
      else {value: ($cur + $add), log: [{op: "add", path: $path, new: $add}]} end
  elif $cur == $new then {value: $cur, log: []}
  elif $force then {value: $new, log: [{op: "overwrite", path: $path, cur: $cur, new: $new}]}
  else {value: $cur, log: [{op: "keep", path: $path, cur: $cur, new: $new}]}
  end;
($cur[0] // {}) as $c
| ($new[0] // {}) as $n
| if ($c | type) != "object" or ($n | type) != "object" then error("settings must be a JSON object") else . end
| merge($c; $n; []) as $m
| {
    value: $m.value,
    keys: ([$m.log[] | select(.op != "keep" and .op != "ignore") | .path[0]] | unique),
    warned: any($m.log[]; .op == "keep"),
    conflicts: [$m.log[] | select(.op == "keep") | .path | name],
    questions: ([$m.log[] | select(.op == "set" or .op == "add" or .op == "overwrite") | {name: (.path | name), text: (
      if .op == "set" then "Set \(.path | name) = \(.new | tojson) (new)"
      elif .op == "add" then "Add \(.new | map(tojson) | join(", ")) to \(.path | name)"
      else "Overwrite \(.path | name) = \(.new | tojson) (was \(.cur | tojson))"
      end)}] | sort_by(.name)),
    messages: [$m.log[] |
      if .op == "set" then
        (if $dry then "Would set" else "Setting" end) + " \(.path | name) = \(.new | tojson)"
      elif .op == "add" then
        (if $dry then "Would add" else "Adding" end) + " \(.new | map(tojson) | join(", ")) to \(.path | name)"
      elif .op == "overwrite" then
        (if $dry then "Would overwrite" else "Overwriting" end) + " \(.path | name) = \(.new | tojson) (was \(.cur | tojson))"
      elif .op == "ignore" then
        "Ignoring \(.path | name) (listed in \($ignorefile))"
      else
        "Warning: \(.path | name) is already set to \(.cur | tojson), skipping new value \(.new | tojson)"
      end]
  }'

# jq_list ITEM... - print the ITEMs as a JSON array
jq_list() {
  jq -n '$ARGS.positional' --args "$@"
}

# json_merge CUR NEW RESULT [NEWNAME] - merge JSON file NEW into JSON file CUR
# (missing or empty counts as {}), print what changes, and write the
# JSON_MERGE result to RESULT; exits, changing nothing, if either file is not
# a JSON object, naming NEW as NEWNAME (default NEW).  With -i/-I each change
# (each addition, and with -f each overwrite) is asked about first, and only
# those answered y are made
json_merge() {
  local CUR="$1" NEW="$2" RESULT="$3" NEWNAME="${4:-$2}" FORCE=false DRY=false NAME TEXT
  local -a ARGS SKIP=()
  [[ -n ${FORCE_OVERWRITE} ]] && FORCE=true
  [[ -n ${DRYRUN} ]] && DRY=true
  [[ -f $CUR ]] || CUR=/dev/null
  ARGS=(--slurpfile cur "$CUR" --slurpfile new "$NEW" --argjson dry "$DRY"
    --argjson ignore "$(jq_list "${IGNORE[@]}")" --arg ignorefile "$IGNORE_FILE")
  if [[ -n ${INTERACTIVE} ]]; then
    jq -n "${ARGS[@]}" --argjson force "$FORCE" --argjson skip '[]' "$JSON_MERGE" > "$RESULT" ||
      { echo "Error: cannot merge $NEWNAME into $1" >&2; exit 1; }
    # the questions are read on fd 3: ask reads the answers from the input
    while IFS= read -r -u 3 NAME && IFS= read -r -u 3 TEXT; do
      ask "$TEXT" "$NAME" setting || SKIP+=("$NAME")
    done 3< <(jq -r '.questions[] | .name, .text' "$RESULT")
  fi
  jq -n "${ARGS[@]}" --argjson force "$FORCE" --argjson skip "$(jq_list "${SKIP[@]}")" "$JSON_MERGE" > "$RESULT" ||
    { echo "Error: cannot merge $NEWNAME into $1" >&2; exit 1; }
  jq -r '.messages[]' "$RESULT"
  [[ $(jq '.keys | length' "$RESULT") -gt 0 ]] && CHANGED=1
  [[ $(jq '.warned' "$RESULT") == true ]] && WARNED=1
  return 0
}

# merge_json SRC DST [SRCNAME] - merge the settings in JSON file SRC into DST;
# errors name SRC as SRCNAME (default SRC)
merge_json() {
  local SRC="$1" DST="$2" RESULT="$WORKDIR/merge.json"
  require jq
  json_merge "$DST" "$SRC" "$RESULT" "$3"
  [[ $(jq '.keys | length' "$RESULT") -eq 0 || -n ${DRYRUN} ]] && return 0
  mkdir -p "$(dirname "$DST")"
  jq '.value' "$RESULT" > "$WORKDIR/value.json"
  cp -- "$WORKDIR/value.json" "$DST"
}

# merge_json_dir SRCDIR MASK DST - merge the settings in every JSON file in
# SRCDIR whose name matches the glob MASK into DST in one pass: the files are
# first combined, in name order, by the rules at the top, except that two of
# them setting a value differently is an error (-f or not), since they are
# meant to hold separate parts of one file
merge_json_dir() {
  local SRCDIR="$1" MASK="$2" DST="$3" SRC CONFLICTS
  local COMBINED="$WORKDIR/combined.json" STEP="$WORKDIR/combine-step.json"
  require jq
  printf '{}\n' > "$COMBINED"
  # shellcheck disable=SC2231 # MASK is a glob, so it must not be quoted
  for SRC in "$SRCDIR"/$MASK; do
    [[ -f $SRC ]] || continue
    jq -n --slurpfile cur "$COMBINED" --slurpfile new "$SRC" --argjson force false --argjson dry false \
      --argjson ignore '[]' --argjson skip '[]' --arg ignorefile "" "$JSON_MERGE" > "$STEP" || { echo "Error: cannot merge $SRC" >&2; exit 1; }
    CONFLICTS=$(jq -r '.conflicts | join(", ")' "$STEP")
    [[ -n $CONFLICTS ]] && { echo "Error: $SRC sets $CONFLICTS differently from another file in $SRCDIR" >&2; exit 1; }
    jq '.value' "$STEP" > "$COMBINED"
  done
  merge_json "$COMBINED" "$DST" "$SRCDIR/$MASK"
}

# merge_omp_config SRC - merge the settings in omp config.yml SRC into omp's
# global settings via 'omp config'; skipped if omp is not installed
merge_omp_config() {
  local SRC="$1" RESULT="$WORKDIR/omp-merge.json" KEY VALUE
  command -v omp >/dev/null || { warn "omp not found in PATH, skipping $SRC"; return 0; }
  require jq
  # omp reads SRC from a scratch directory because it creates an agent.db
  # beside the config.yml it reads
  mkdir -p "$WORKDIR/omp"
  cp -- "$SRC" "$WORKDIR/omp/config.yml"
  PI_CODING_AGENT_DIR="$WORKDIR/omp" omp config list --scope=global --json | jq 'map_values(.value)' > "$WORKDIR/omp-new.json"
  omp config list --scope=global --json | jq 'map_values(.value)' > "$WORKDIR/omp-cur.json"
  json_merge "$WORKDIR/omp-cur.json" "$WORKDIR/omp-new.json" "$RESULT"
  [[ -n ${DRYRUN} ]] && return 0
  while IFS= read -r KEY; do
    VALUE=$(jq -r --arg key "$KEY" '.value[$key] | if type == "string" then . else tojson end' "$RESULT")
    omp config set "$KEY" "$VALUE" >/dev/null
  done < <(jq -r '.keys[]' "$RESULT")
  return 0
}

# ---- TOML (Codex) ----------------------------------------------------------
# A line-based merge, like setup-git.sh's: the source may hold only [table]
# headers and one-line "key = value" settings; the destination's other lines,
# comments included, are kept as they are.  Values are compared as text.

# toml_scan TEXT - set TOML_TEXT to TEXT without its comment and TOML_DEPTH to
# how many more [ than ] it has, both ignoring quoted strings
toml_scan() {
  local S="$1" C Q="" I
  TOML_DEPTH=0
  TOML_TEXT=$S
  for ((I = 0; I < ${#S}; I++)); do
    C=${S:I:1}
    if [[ -n $Q ]]; then
      [[ $C == "\\" && $Q == '"' ]] && { I=$((I + 1)); continue; }
      [[ $C == "$Q" ]] && Q=""
      continue
    fi
    case $C in
      \"|\') Q=$C ;;
      \#) TOML_TEXT=${S:0:I}; break ;;
      \[) TOML_DEPTH=$((TOML_DEPTH + 1)) ;;
      \]) TOML_DEPTH=$((TOML_DEPTH - 1)) ;;
    esac
  done
  TOML_TEXT=$(trim "$TOML_TEXT")
  return 0
}

# toml_open_string VALUE - print the delimiter of the multi-line string VALUE
# opens without closing (nothing if it does not)
toml_open_string() {
  local D=${1:0:3}
  [[ $D == '"""' || $D == "'''" ]] && [[ ${1:3} != *"$D"* ]] && printf '%s' "$D"
  return 0
}

# toml_header LINE - print the table name of header LINE ("[a.b]" -> "a.b");
# an array-of-tables header keeps its brackets so it never matches a table
toml_header() {
  local H
  [[ $1 == '[['* ]] && { printf '%s' "${1%%]]*}]]"; return 0; }
  H=${1#\[}
  H=${H%\]*}
  trim "$H"
}

# toml_parse SRC - read the settings of TOML file SRC into TOML_TABLES,
# TOML_KEYS and TOML_VALUES (declared by the caller)
toml_parse() {
  local SRC="$1" LINE TABLE="" KEY VALUE
  local -r HEADER_RE='^\[[^][]+\]$' SETTING_RE='^([^=[]+)=(.*)$'
  while IFS= read -r LINE || [[ -n $LINE ]]; do
    LINE=$(trim "$LINE")
    [[ -z $LINE || $LINE == \#* ]] && continue
    [[ $LINE =~ $HEADER_RE ]] && { TABLE=$(toml_header "$LINE"); continue; }
    if [[ $LINE =~ $SETTING_RE ]]; then
      KEY=$(trim "${BASH_REMATCH[1]}")
      toml_scan "${BASH_REMATCH[2]}"
      VALUE=$TOML_TEXT
      if [[ $TOML_DEPTH -le 0 && -z $(toml_open_string "$VALUE") ]]; then
        TOML_TABLES+=("$TABLE")
        TOML_KEYS+=("$KEY")
        TOML_VALUES+=("$VALUE")
        continue
      fi
    fi
    echo "Error: $SRC: cannot merge '$LINE' (only [table] headers and one-line settings are supported)" >&2
    exit 1
  done < "$SRC"
  return 0
}

# toml_find TABLE KEY - look for KEY of TABLE ("" = top level) in TOML_LINES
# (declared by the caller), stepping over multi-line values.  Sets
# TOML_KEY_AT (KEY's line, -1 if absent), TOML_KEY_VALUE, TOML_KEY_MULTILINE,
# and TOML_END (the line a new key of TABLE goes before, -1 if TABLE is absent)
toml_find() {
  local TABLE="$1" KEY="$2" SECTION="" I LINE IN K V OPEN="" DEPTH=0
  local -r SETTING_RE='^([^=]+)=(.*)$'
  TOML_KEY_AT=-1
  TOML_KEY_VALUE=""
  TOML_KEY_MULTILINE=""
  TOML_END=-1
  [[ -z $TABLE ]] && TOML_END=0
  for ((I = 0; I < ${#TOML_LINES[@]}; I++)); do
    LINE=$(trim "${TOML_LINES[I]}")
    IN=""
    [[ $SECTION == "$TABLE" ]] && IN=1
    if [[ -n $OPEN ]]; then
      # inside a multi-line string
      [[ $LINE == *"$OPEN"* ]] && OPEN=""
      [[ -n $IN ]] && TOML_END=$((I + 1))
      continue
    fi
    if [[ $DEPTH -gt 0 ]]; then
      # inside a multi-line array
      toml_scan "$LINE"
      DEPTH=$((DEPTH + TOML_DEPTH))
      [[ -n $IN ]] && TOML_END=$((I + 1))
      continue
    fi
    [[ -z $LINE || $LINE == \#* ]] && continue
    if [[ $LINE == \[* ]]; then
      SECTION=$(toml_header "$LINE")
      [[ $SECTION == "$TABLE" ]] && TOML_END=$((I + 1))
      continue
    fi
    [[ $LINE =~ $SETTING_RE ]] || continue
    K=$(trim "${BASH_REMATCH[1]}")
    V=$(trim "${BASH_REMATCH[2]}")
    toml_scan "$V"
    OPEN=$(toml_open_string "$V")
    DEPTH=$TOML_DEPTH
    [[ -n $IN ]] && TOML_END=$((I + 1))
    if [[ -n $IN && $K == "$KEY" ]]; then
      TOML_KEY_AT=$I
      TOML_KEY_VALUE=$TOML_TEXT
      [[ -n $OPEN || $DEPTH -gt 0 ]] && TOML_KEY_MULTILINE=1
    fi
  done
  return 0
}

# merge_toml SRC DST - merge the settings of TOML file SRC into DST
merge_toml() {
  local SRC="$1" DST="$2" I TABLE KEY VALUE NAME LINE EDITED=""
  local -a TOML_TABLES=() TOML_KEYS=() TOML_VALUES=() TOML_LINES=()
  toml_parse "$SRC"
  [[ -f $DST ]] && mapfile -t TOML_LINES < "$DST"
  for ((I = 0; I < ${#TOML_KEYS[@]}; I++)); do
    TABLE=${TOML_TABLES[I]}
    KEY=${TOML_KEYS[I]}
    VALUE=${TOML_VALUES[I]}
    NAME=${TABLE:+$TABLE.}$KEY
    LINE="$KEY = $VALUE"
    toml_find "$TABLE" "$KEY"
    [[ $TOML_KEY_AT -ge 0 && $TOML_KEY_VALUE == "$VALUE" ]] && continue
    ignored_setting "$NAME" && { ignoring "$NAME"; continue; }
    if [[ $TOML_KEY_AT -ge 0 ]]; then
      [[ -n $TOML_KEY_MULTILINE ]] && { warn "$NAME has a multi-line value in $DST, skipping new value $VALUE"; continue; }
      allow_overwrite "Overwrite $NAME = $VALUE (was $TOML_KEY_VALUE)" "$NAME" setting \
        "$NAME is already set to $TOML_KEY_VALUE, skipping new value $VALUE" || continue
      TOML_LINES[TOML_KEY_AT]=$LINE
      changed "Overwriting $NAME = $VALUE (was $TOML_KEY_VALUE)" "overwrite $NAME = $VALUE (was $TOML_KEY_VALUE)"
    else
      allow_add "Set $NAME = $VALUE (new)" "$NAME" setting || continue
      if [[ $TOML_END -ge 0 ]]; then
        TOML_LINES=("${TOML_LINES[@]:0:TOML_END}" "$LINE" "${TOML_LINES[@]:TOML_END}")
      else
        [[ ${#TOML_LINES[@]} -gt 0 && -n $(trim "${TOML_LINES[-1]}") ]] && TOML_LINES+=("")
        TOML_LINES+=("[$TABLE]" "$LINE")
      fi
      changed "Setting $NAME = $VALUE" "set $NAME = $VALUE"
    fi
    EDITED=1
  done
  [[ -z $EDITED || -n ${DRYRUN} ]] && return 0
  mkdir -p "$(dirname "$DST")"
  printf '%s\n' "${TOML_LINES[@]}" > "$WORKDIR/config.toml"
  cp -- "$WORKDIR/config.toml" "$DST"
}
