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

# the setup/ directory: this file lives in setup/common
SETUP_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck disable=SC2034 # used by the agent scripts
readonly SETUP_DIR
WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/setup-agents.XXXXXX")
readonly WORKDIR
trap 'rm -rf "${WORKDIR}"' EXIT
unset CHANGED WARNED

agent_options() {
  echo "Options:"
  echo "  -f : Overwrite files and settings that differ (default: keep them and warn)"
  echo "  -n : Show what would be done without making changes"
  echo "  -h : Show this help message"
}

# parse_opts "$@" - handle -f, -n and -h; the caller defines usage()
parse_opts() {
  unset FORCE_OVERWRITE DRYRUN
  local OPT OPTIND=1
  while getopts fnh OPT; do
    case $OPT in
      f) FORCE_OVERWRITE=1 ;;
      n) DRYRUN=1 ;;
      h) usage; exit 0 ;;
      *) usage >&2; exit 22 ;;
    esac
  done
  shift $((OPTIND - 1))
  [[ $# -ne 0 ]] && { echo "Unexpected argument: $1" >&2; usage >&2; exit 22; }
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

# ---- files -----------------------------------------------------------------

# install_file SRC DST - install file SRC as DST
install_file() {
  local SRC="$1" DST="$2" DONE=Installed WOULD=install
  [[ -f $DST ]] && cmp -s "$SRC" "$DST" && return 0
  [[ -d $DST ]] && { warn "$DST is a directory, skipping $SRC"; return 0; }
  if [[ -e $DST || -L $DST ]]; then
    [[ -z ${FORCE_OVERWRITE} ]] && { warn "$DST differs from $SRC, keeping it (use -f to overwrite)"; return 0; }
    DONE=Overwrote
    WOULD=overwrite
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
  while IFS= read -r -d '' SRC; do
    install_file "$SRC" "$DSTDIR/${SRC#"$SRCDIR"/}"
  done < <(find "$SRCDIR" -type f -print0 | sort -z)
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
# top; emits {value, keys, warned, conflicts, messages}, keys being the
# top-level keys whose value changed and conflicts the settings kept because
# their values differ
# shellcheck disable=SC2016 # a jq program: its $names are jq variables
readonly JSON_MERGE='
def name: map(tostring) | join(".");
def merge($cur; $new; $path):
  if ($cur | type) == "object" and ($new | type) == "object" then
    reduce ($new | keys_unsorted[]) as $k ({value: $cur, log: []};
      if .value | has($k) then
        merge(.value[$k]; $new[$k]; $path + [$k]) as $m
        | .value[$k] = $m.value | .log += $m.log
      else
        .value[$k] = $new[$k] | .log += [{op: "set", path: ($path + [$k]), new: $new[$k]}]
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
    keys: ([$m.log[] | select(.op != "keep") | .path[0]] | unique),
    warned: any($m.log[]; .op == "keep"),
    conflicts: [$m.log[] | select(.op == "keep") | .path | name],
    messages: [$m.log[] |
      if .op == "set" then
        (if $dry then "Would set" else "Setting" end) + " \(.path | name) = \(.new | tojson)"
      elif .op == "add" then
        (if $dry then "Would add" else "Adding" end) + " \(.new | map(tojson) | join(", ")) to \(.path | name)"
      elif .op == "overwrite" then
        (if $dry then "Would overwrite" else "Overwriting" end) + " \(.path | name) = \(.new | tojson) (was \(.cur | tojson))"
      else
        "Warning: \(.path | name) is already set to \(.cur | tojson), skipping new value \(.new | tojson)"
      end]
  }'

# json_merge CUR NEW RESULT [NEWNAME] - merge JSON file NEW into JSON file CUR
# (missing or empty counts as {}), print what changes, and write the
# JSON_MERGE result to RESULT; exits, changing nothing, if either file is not
# a JSON object, naming NEW as NEWNAME (default NEW)
json_merge() {
  local CUR="$1" NEW="$2" RESULT="$3" NEWNAME="${4:-$2}" FORCE=false DRY=false
  [[ -n ${FORCE_OVERWRITE} ]] && FORCE=true
  [[ -n ${DRYRUN} ]] && DRY=true
  [[ -f $CUR ]] || CUR=/dev/null
  jq -n --slurpfile cur "$CUR" --slurpfile new "$NEW" --argjson force "$FORCE" --argjson dry "$DRY" \
    "$JSON_MERGE" > "$RESULT" || { echo "Error: cannot merge $NEWNAME into $1" >&2; exit 1; }
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
      "$JSON_MERGE" > "$STEP" || { echo "Error: cannot merge $SRC" >&2; exit 1; }
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
    if [[ $TOML_KEY_AT -ge 0 ]]; then
      [[ $TOML_KEY_VALUE == "$VALUE" ]] && continue
      [[ -n $TOML_KEY_MULTILINE ]] && { warn "$NAME has a multi-line value in $DST, skipping new value $VALUE"; continue; }
      [[ -z ${FORCE_OVERWRITE} ]] && { warn "$NAME is already set to $TOML_KEY_VALUE, skipping new value $VALUE"; continue; }
      TOML_LINES[TOML_KEY_AT]=$LINE
      changed "Overwriting $NAME = $VALUE (was $TOML_KEY_VALUE)" "overwrite $NAME = $VALUE (was $TOML_KEY_VALUE)"
    elif [[ $TOML_END -ge 0 ]]; then
      TOML_LINES=("${TOML_LINES[@]:0:TOML_END}" "$LINE" "${TOML_LINES[@]:TOML_END}")
      changed "Setting $NAME = $VALUE" "set $NAME = $VALUE"
    else
      [[ ${#TOML_LINES[@]} -gt 0 && -n $(trim "${TOML_LINES[-1]}") ]] && TOML_LINES+=("")
      TOML_LINES+=("[$TABLE]" "$LINE")
      changed "Setting $NAME = $VALUE" "set $NAME = $VALUE"
    fi
    EDITED=1
  done
  [[ -z $EDITED || -n ${DRYRUN} ]] && return 0
  mkdir -p "$(dirname "$DST")"
  printf '%s\n' "${TOML_LINES[@]}" > "$WORKDIR/config.toml"
  cp -- "$WORKDIR/config.toml" "$DST"
}
