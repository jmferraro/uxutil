# shellcheck shell=bash
# uxbrace.sh - brace-glob expansion shared by the uxutil search tools.
#
# This file is sourced, not executed.  It provides:
#
#   expand_braces <pattern>
#       Prints one glob per line for a pattern that may contain brace
#       alternations, e.g. *.{c,cpp,h} -> *.c, *.cpp, *.h
#
# Braces are matched by depth, so nested and repeated groups expand correctly
# instead of silently producing garbage globs.  Expanding here means find only
# ever sees plain -name globs and grep only plain --include globs; neither
# understands brace alternation itself, and both would quietly match nothing if
# handed the brace form.
#
# Note this deliberately does not use bash's own brace expansion via eval:
# that would word-split any glob containing a space, e.g. 'my file.c'.

expand_braces()
{
  local PAT=$1
  local LEN=${#PAT}
  local IDX=0 OPEN=-1 CLOSE=-1 DEPTH=0 CH

  while [[ $IDX -lt $LEN ]]
  do
    [[ ${PAT:IDX:1} == '{' ]] && { OPEN=$IDX; break; }
    IDX=$((IDX+1))
  done
  [[ $OPEN -lt 0 ]] && { printf '%s\n' "$PAT"; return; }

  IDX=$OPEN
  while [[ $IDX -lt $LEN ]]
  do
    CH=${PAT:IDX:1}
    if [[ $CH == '{' ]]; then
      DEPTH=$((DEPTH+1))
    elif [[ $CH == '}' ]]; then
      DEPTH=$((DEPTH-1))
      [[ $DEPTH -eq 0 ]] && { CLOSE=$IDX; break; }
    fi
    IDX=$((IDX+1))
  done
  # An unbalanced brace is not an alternation; treat it as a literal
  [[ $CLOSE -lt 0 ]] && { printf '%s\n' "$PAT"; return; }

  local PRE=${PAT:0:OPEN}
  local BODY=${PAT:OPEN+1:CLOSE-OPEN-1}
  local SUF=${PAT:CLOSE+1}
  local ALTS=() CUR='' ALT
  DEPTH=0
  IDX=0
  LEN=${#BODY}
  while [[ $IDX -lt $LEN ]]
  do
    CH=${BODY:IDX:1}
    if [[ $CH == ',' && $DEPTH -eq 0 ]]; then
      ALTS+=("$CUR")
      CUR=''
    else
      [[ $CH == '{' ]] && DEPTH=$((DEPTH+1))
      [[ $CH == '}' ]] && DEPTH=$((DEPTH-1))
      CUR+=$CH
    fi
    IDX=$((IDX+1))
  done
  ALTS+=("$CUR")

  for ALT in "${ALTS[@]}"
  do
    expand_braces "$PRE$ALT$SUF"
  done
}
