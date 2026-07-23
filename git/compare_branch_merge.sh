#!/usr/bin/env bash

# Script to compare two branches and analyze merge differences
# Shows files that should match vs files that are expected to be newer

set -euo pipefail

# Default values
FROM_BRANCH=""
INTO_BRANCH=""
VERBOSE=0
NO_COLOR=0

# Color definitions
RED='\033[0;31m'
GRN='\033[0;32m'
YEL='\033[1;33m'
BLU='\033[0;34m'
MAG='\033[0;35m'
CYN='\033[0;36m'
NON='\033[0m'

# Usage function
usage() {
    cat << EOF
Usage: $0 --from <source_branch> --into <target_branch> [options]

Compare two branches and analyze merge differences.

Options:
    --from <branch>     Source branch (the one that was merged from)
    --into <branch>     Target branch (the one that received the merge)
    --verbose          Show detailed output
    --no-color         Disable colored output
    --help             Show this help message

Example:
    $0 --from user/verify-headers --into develop
    $0 --from feature/my-work --into main --verbose

The script categorizes differences into:
1. Files changed after the source branch's last commit (expected newer files)
2. Files that should match but differ (unexpected differences)
3. Files unique to each branch
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --from)
            FROM_BRANCH="$2"
            shift 2
            ;;
        --into)
            INTO_BRANCH="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=1
            shift
            ;;
        --no-color)
            NO_COLOR=1
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "Error: Unknown argument '$1'" >&2
            usage >&2
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$FROM_BRANCH" || -z "$INTO_BRANCH" ]]; then
    echo "Error: Both --from and --into arguments are required" >&2
    usage >&2
    exit 1
fi

# Disable colors if requested or if output is not a terminal
if [[ $NO_COLOR -eq 1 ]] || [[ ! -t 1 ]]; then
    RED='' GRN='' YEL='' BLU='' MAG='' CYN='' NON=''
fi

# Verify branches exist
if ! git rev-parse --verify "$FROM_BRANCH" >/dev/null 2>&1; then
    echo -e "${RED}Error: Branch '$FROM_BRANCH' does not exist${NON}" >&2
    exit 1
fi

if ! git rev-parse --verify "$INTO_BRANCH" >/dev/null 2>&1; then
    echo -e "${RED}Error: Branch '$INTO_BRANCH' does not exist${NON}" >&2
    exit 1
fi

# Get the last commit date from the source branch
echo -e "${BLU}=== Branch Merge Analysis ===${NON}"
echo -e "Analyzing merge from ${YEL}$FROM_BRANCH${NON} into ${YEL}$INTO_BRANCH${NON}"
echo

# Get last commit info from source branch
FROM_COMMIT_INFO=$(git log "$FROM_BRANCH" --oneline -1 --format="%cd %H %s" --date=iso)
FROM_COMMIT_DATE=$(echo "$FROM_COMMIT_INFO" | awk '{print $1" "$2}')
FROM_COMMIT_HASH=$(echo "$FROM_COMMIT_INFO" | awk '{print $4}')

echo -e "${CYN}Source branch last commit:${NON}"
echo -e "  Date: ${YEL}$FROM_COMMIT_DATE${NON}"
echo -e "  Hash: ${YEL}$FROM_COMMIT_HASH${NON}"
echo -e "  Message: $(echo "$FROM_COMMIT_INFO" | awk '{for(i=5;i<=NF;i++) printf "%s ", $i; print ""}')"
echo

# Create temporary files for analysis
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

ALL_DIFF_FILES="$TMP_DIR/all_different_files.txt"
NEWER_FILES="$TMP_DIR/newer_files.txt"
UNEXPECTED_DIFF="$TMP_DIR/unexpected_diff.txt"
EXPECTED_NEWER="$TMP_DIR/expected_newer.txt"

# Get all files that differ between branches
git diff --name-only "$FROM_BRANCH" "$INTO_BRANCH" | sort > "$ALL_DIFF_FILES"

# Get files changed in target branch after source branch's last commit
git log "$INTO_BRANCH" --since="$FROM_COMMIT_DATE" --name-only --pretty=format:"" | \
    sort -u | grep -v "^$" > "$NEWER_FILES"

# Categorize the differences
comm -23 "$ALL_DIFF_FILES" "$NEWER_FILES" > "$UNEXPECTED_DIFF"
comm -12 "$ALL_DIFF_FILES" "$NEWER_FILES" > "$EXPECTED_NEWER"

# Get files unique to each branch
ONLY_IN_TARGET="$TMP_DIR/only_in_target.txt"
ONLY_IN_SOURCE="$TMP_DIR/only_in_source.txt"

# Files that exist in target but not in source (Added when going from source to target)
git diff --name-only --diff-filter=A "$FROM_BRANCH" "$INTO_BRANCH" | sort > "$ONLY_IN_TARGET"
# Files that exist in source but not in target (Deleted when going from source to target)
git diff --name-only --diff-filter=D "$FROM_BRANCH" "$INTO_BRANCH" | sort > "$ONLY_IN_SOURCE"

# Count files
TOTAL_DIFF=$(wc -l < "$ALL_DIFF_FILES")
UNEXPECTED_COUNT=$(wc -l < "$UNEXPECTED_DIFF")
EXPECTED_COUNT=$(wc -l < "$EXPECTED_NEWER")
ONLY_TARGET_COUNT=$(wc -l < "$ONLY_IN_TARGET")
ONLY_SOURCE_COUNT=$(wc -l < "$ONLY_IN_SOURCE")

# Display summary
echo -e "${BLU}=== Summary ===${NON}"
echo -e "Total differing files: ${YEL}$TOTAL_DIFF${NON}"
echo -e "Files changed after source branch: ${GRN}$EXPECTED_COUNT${NON} (expected)"
echo -e "Files that should match but differ: ${RED}$UNEXPECTED_COUNT${NON} (investigate)"
echo -e "Files only in $INTO_BRANCH: ${CYN}$ONLY_TARGET_COUNT${NON}"
echo -e "Files only in $FROM_BRANCH: ${MAG}$ONLY_SOURCE_COUNT${NON}"
echo

# Display unexpected differences (these need investigation)
if [[ $UNEXPECTED_COUNT -gt 0 ]]; then
    echo -e "${RED}=== FILES THAT SHOULD MATCH BUT DIFFER (investigate these) ===${NON}"
    if [[ $VERBOSE -eq 1 ]]; then
        while IFS= read -r file; do
            echo -e "${RED}  $file${NON}"
        done < "$UNEXPECTED_DIFF"
    else
        echo -e "Found ${RED}$UNEXPECTED_COUNT${NON} files that unexpectedly differ."
        echo "Use --verbose to see the full list, or examine: $UNEXPECTED_DIFF"
        echo "First 10 files:"
        head -10 "$UNEXPECTED_DIFF" | sed 's/^/  /'
        if [[ $UNEXPECTED_COUNT -gt 10 ]]; then
            echo "  ... and $((UNEXPECTED_COUNT - 10)) more"
        fi
    fi
    echo
fi

# Display expected newer files
if [[ $EXPECTED_COUNT -gt 0 ]]; then
    echo -e "${GRN}=== FILES CHANGED AFTER SOURCE BRANCH (expected newer files) ===${NON}"
    if [[ $VERBOSE -eq 1 ]]; then
        while IFS= read -r file; do
            echo -e "${GRN}  $file${NON}"
        done < "$EXPECTED_NEWER"
    else
        echo -e "Found ${GRN}$EXPECTED_COUNT${NON} files that were legitimately updated after the source branch."
        echo "Use --verbose to see the full list, or examine: $EXPECTED_NEWER"
    fi
    echo
fi

# Display files unique to target branch
if [[ $ONLY_TARGET_COUNT -gt 0 ]]; then
    echo -e "${CYN}=== FILES ONLY IN $INTO_BRANCH (new additions) ===${NON}"
    if [[ $VERBOSE -eq 1 ]]; then
        while IFS= read -r file; do
            echo -e "${CYN}  $file${NON}"
        done < "$ONLY_IN_TARGET"
    else
        echo -e "Found ${CYN}$ONLY_TARGET_COUNT${NON} files that exist only in the target branch."
        echo "Use --verbose to see the full list, or examine: $ONLY_IN_TARGET"
    fi
    echo
fi

# Display files unique to source branch
if [[ $ONLY_SOURCE_COUNT -gt 0 ]]; then
    echo -e "${MAG}=== FILES ONLY IN $FROM_BRANCH (missing from target?) ===${NON}"
    if [[ $VERBOSE -eq 1 ]]; then
        while IFS= read -r file; do
            echo -e "${MAG}  $file${NON}"
        done < "$ONLY_IN_SOURCE"
    else
        echo -e "Found ${MAG}$ONLY_SOURCE_COUNT${NON} files that exist only in the source branch."
        echo "Use --verbose to see the full list, or examine: $ONLY_IN_SOURCE"
        echo "First 10 files:"
        head -10 "$ONLY_IN_SOURCE" | sed 's/^/  /'
        if [[ $ONLY_SOURCE_COUNT -gt 10 ]]; then
            echo "  ... and $((ONLY_SOURCE_COUNT - 10)) more"
        fi
    fi
    echo
fi

# Provide recommendations
echo -e "${BLU}=== Recommendations ===${NON}"
if [[ $UNEXPECTED_COUNT -eq 0 && $ONLY_SOURCE_COUNT -eq 0 ]]; then
    echo -e "${GRN}✓ Merge appears successful!${NON}"
    echo "  All files are either expected to be newer or are new additions."
elif [[ $UNEXPECTED_COUNT -gt 0 ]]; then
    echo -e "${YEL}⚠ Check unexpected differences:${NON}"
    echo "  $UNEXPECTED_COUNT files differ but weren't changed after the source branch."
    echo "  This could indicate squashed commits, merge conflicts, or missing changes."
fi

if [[ $ONLY_SOURCE_COUNT -gt 0 ]]; then
    echo -e "${RED}⚠ Missing files detected:${NON}"
    echo "  $ONLY_SOURCE_COUNT files exist in source but not in target."
    echo "  These changes may not have been merged."
fi

# Save detailed output if requested
if [[ $VERBOSE -eq 0 && ($UNEXPECTED_COUNT -gt 0 || $ONLY_SOURCE_COUNT -gt 0) ]]; then
    echo
    echo -e "${CYN}Detailed file lists saved in: $TMP_DIR${NON}"
    echo "Files will be automatically cleaned up when script exits."
    echo "Re-run with --verbose to see all files in output."
fi

# Exit with appropriate code
if [[ $UNEXPECTED_COUNT -gt 0 || $ONLY_SOURCE_COUNT -gt 0 ]]; then
    exit 1
else
    exit 0
fi