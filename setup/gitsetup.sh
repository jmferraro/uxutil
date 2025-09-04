#!/bin/bash

set -e

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly GITCONFIG_FILE="$SCRIPT_DIR/../git/gitconfig"

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -f, --force             Force overwrite existing git config settings without warnings"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "By default, existing git config settings will be preserved and warnings will be shown."
    exit 1
}

unset FORCE_OVERWRITE

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE_OVERWRITE=1
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1" && usage
            ;;
    esac
done

[[ ! -f "$GITCONFIG_FILE" ]] && { echo "Error: Git config file not found at $GITCONFIG_FILE"; exit 1; }

echo "Setting up git configuration from $GITCONFIG_FILE"

local CURRENT_SECTION=""

while IFS= read -r LINE; do
    # Remove leading whitespace: sed 's/^[[:space:]]*//'
    LINE="${LINE#"${LINE%%[![:space:]]*}"}"
    # Remove trailing whitespace: sed 's/[[:space:]]*$//'
    LINE="${LINE%"${LINE##*[![:space:]]}"}"
    
    [[ -z "$LINE" || "$LINE" =~ ^# ]] && continue
    
    if [[ "$LINE" =~ ^\[([^]]+)\]$ ]]; then
        CURRENT_SECTION="${BASH_REMATCH[1]}"
        continue
    fi
    
    if [[ "$LINE" =~ ^([^=]+)=(.*)$ ]]; then
        local KEY="${BASH_REMATCH[1]}"
        local VALUE="${BASH_REMATCH[2]}"
        
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
        
        local FULL_KEY="$CURRENT_SECTION.$KEY"
        
        if [[ -z "$FORCE_OVERWRITE" ]]; then
            local EXISTING_VALUE=$(git config --global --get "$FULL_KEY" 2>/dev/null || echo "")
            
            if [[ -n "$EXISTING_VALUE" && "$EXISTING_VALUE" != "$VALUE" ]]; then
                echo "Warning: $FULL_KEY is already set to '$EXISTING_VALUE', skipping new value '$VALUE'"
                continue
            fi
        fi
        
        echo "Setting $FULL_KEY = $VALUE"
        git config --global "$FULL_KEY" "$VALUE"
    fi
done < "$GITCONFIG_FILE"

echo "Git configuration setup complete!"