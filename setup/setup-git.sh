#!/usr/bin/env bash

set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
readonly SCRIPT_DIR
readonly GITCONFIG_FILE="$SCRIPT_DIR/../git/gitconfig"

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -f, --force             Replace existing git config settings that differ"
    echo "  -i, --interactive       Ask before each addition (with -f, before each replacement too)"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "By default, settings that differ are kept and reported as Conflicting."
    exit 0
}

unset FORCE_OVERWRITE INTERACTIVE

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE_OVERWRITE=1
            shift
            ;;
        -i|--interactive)
            INTERACTIVE=1
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1" && exit 22
            ;;
    esac
done

# confirm QUESTION - succeed unless -i is given and the answer is not y
# (the end of the input counts as n)
confirm() {
    local ANSWER
    [[ -z "$INTERACTIVE" ]] && return 0
    printf '%s? [y/N] ' "$1" >&2
    IFS= read -r ANSWER || { echo >&2; return 1; }
    [[ "$ANSWER" == [yY] ]]
}

[[ ! -f "$GITCONFIG_FILE" ]] && { echo "Error: Git config file not found at $GITCONFIG_FILE"; exit 1; }

echo "Setting up git configuration from $GITCONFIG_FILE"

CURRENT_SECTION=""

while IFS= read -r -u 3 LINE; do
    # Remove leading whitespace: sed 's/^[[:space:]]*//'
    LINE="${LINE#"${LINE%%[![:space:]]*}"}"
    # Remove trailing whitespace: sed 's/[[:space:]]*$//'
    LINE="${LINE%"${LINE##*[![:space:]]}"}"

    [[ -z "$LINE" || "$LINE" =~ ^# ]] && continue

    if [[ "$LINE" =~ ^\[([^]]+)\]$ ]]; then
        CURRENT_SECTION="${BASH_REMATCH[1]}"
        if [[ "$CURRENT_SECTION" =~ ^([^[:space:]]+)[[:space:]]+\"?([^\"]+)\"?$ ]]; then
            CURRENT_SECTION="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
        fi
        continue
    fi

    if [[ "$LINE" =~ ^([^=]+)=(.*)$ ]]; then
        KEY="${BASH_REMATCH[1]}"
        VALUE="${BASH_REMATCH[2]}"

        # Remove leading whitespace: sed 's/^[[:space:]]*//'
        KEY="${KEY#"${KEY%%[![:space:]]*}"}"
        # Remove trailing whitespace: sed 's/[[:space:]]*$//'
        KEY="${KEY%"${KEY##*[![:space:]]}"}"
        # Remove leading whitespace: sed 's/^[[:space:]]*//'
        VALUE="${VALUE#"${VALUE%%[![:space:]]*}"}"
        # Remove trailing whitespace: sed 's/[[:space:]]*$//'
        VALUE="${VALUE%"${VALUE##*[![:space:]]}"}"

        # Remove surrounding quotes: sed 's/^"\(.*\)"$/\1/'
        [[ "$VALUE" =~ ^\"(.*)\"$ ]] && VALUE="${BASH_REMATCH[1]}"

        FULL_KEY="$CURRENT_SECTION.$KEY"

        if EXISTING_VALUE=$(git config --global --get "$FULL_KEY" 2>/dev/null); then
            if [[ "$EXISTING_VALUE" == "$VALUE" ]]; then
                echo "Already present: $FULL_KEY = $VALUE"
                continue
            fi
            if [[ -z "$FORCE_OVERWRITE" ]]; then
                echo "Conflicting: $FULL_KEY is '$EXISTING_VALUE', keeping it (new value '$VALUE'; use -f to replace)"
                continue
            fi
            confirm "Replace $FULL_KEY '$EXISTING_VALUE' with '$VALUE'" || continue
            echo "Replacing $FULL_KEY: '$EXISTING_VALUE' -> '$VALUE'"
        else
            confirm "Add $FULL_KEY = $VALUE" || continue
            echo "Adding $FULL_KEY = $VALUE"
        fi
        git config --global "$FULL_KEY" "$VALUE"
    fi
done 3< "$GITCONFIG_FILE"

echo "Git configuration setup complete!"

