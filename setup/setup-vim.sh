#!/usr/bin/env bash

set -e

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly VIMRC_SRC="$SCRIPT_DIR/../vim/vimrc"
readonly COLORSCHEME_SRC="$SCRIPT_DIR/../vim/ferraro.vim"
readonly VIMRC_DST="$HOME/.vimrc"
readonly COLORS_DIR="$HOME/.vim/colors"

usage() {
  echo "Usage: $(basename "$0") [OPTIONS]"
  echo "Options:"
  echo "  -f : Overwrite existing .vimrc"
  echo "  -n : Show what would be done without making changes"
  echo "  -h : Show this help message"
  exit 0
}

# link SRC DST - create symlink, checking for existing files
link() {
  SRC="$1"
  DST="$2"

  # already a symlink pointing to the right place
  if [[ -L "$DST" ]] && [[ "$(readlink "$DST")" == "$SRC" ]]; then
    echo "$DST is already linked"
    return
  fi

  # exists as a regular file
  if [[ -f "$DST" && ! -L "$DST" ]]; then
    if diff -q "$SRC" "$DST" >/dev/null 2>&1; then
      echo "$DST matches, replacing with symlink"
    else
      [[ -z ${FORCE_OVERWRITE} ]] && { echo "Error: $DST already exists and differs (use -f to overwrite)"; exit 1; }
      echo "Warning: overwriting existing $DST"
    fi
    [[ -z ${DRYRUN} ]] && rm "$DST"
  fi

  [[ -n ${DRYRUN} ]] && { echo "Would link $DST -> $SRC"; return; }
  ln -s "$SRC" "$DST"
  echo "Linked $DST -> $SRC"
}

unset FORCE_OVERWRITE DRYRUN
while getopts fnh OPT
do
  case $OPT in
    f) FORCE_OVERWRITE=1 ;;
    n) DRYRUN=1 ;;
    h) usage ;;
    *) exit 22 ;;
  esac
done
shift $((OPTIND - 1))

[[ ! -f "$VIMRC_SRC" ]] && { echo "Error: vimrc not found at $VIMRC_SRC"; exit 1; }
[[ ! -f "$COLORSCHEME_SRC" ]] && { echo "Error: ferraro.vim not found at $COLORSCHEME_SRC"; exit 1; }

# install .vimrc
link "$VIMRC_SRC" "$VIMRC_DST"

# install colorscheme
[[ -n ${DRYRUN} ]] && echo "Would create $COLORS_DIR" || mkdir -p "$COLORS_DIR"
link "$COLORSCHEME_SRC" "$COLORS_DIR/ferraro.vim"

# ensure swap file directory exists (parsed from the installed vimrc)
SWAP_DIR=$(grep -E '^\s*set\s+dir=' "$VIMRC_SRC" | sed 's/.*set dir=//; s/\s.*//' | sed "s|\$HOME|$HOME|; s|~|$HOME|")
if [[ -n ${SWAP_DIR} ]]; then
  [[ -n ${DRYRUN} ]] && echo "Would create swap directory $SWAP_DIR" || { mkdir -p "$SWAP_DIR"; echo "Created swap directory $SWAP_DIR"; }
fi

echo "Vim setup complete!"
