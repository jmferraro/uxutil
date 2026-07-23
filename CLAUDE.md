# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Structure

This is a collection of personal shell utilities and configuration files developed for daily use. The repository contains:

- **Root directory**: Individual bash utilities (executable scripts)
- **git/**: Git-specific utilities and hooks
- **vim/**: Vim configuration files
- **setup/**: Scripts for setting up new machines
- **dotfiles/**: Configuration files for linking to home directory
- **misc/**: Miscellaneous utilities

## Key Utilities Architecture

### Core Pipeline Utilities
- **torl**: "Tee OR Less" - captures command output and displays in less if output is large
- **rgrep**: Recursive grep with enhanced pattern matching, supports glob patterns with braces
- **sponge**: Bash implementation of the sponge command for safe in-place file editing

### File Comparison and Search
- **cmp-dirs**: Compare directories recursively, can invoke tkdiff/meld for differences
- **ffind**: Find files by pattern, excludes 'install' directories by default
- **subgrep**: Search all subdirectories for strings with optional file filtering

### Time and Data Utilities
- **i2time**: Convert epoch timestamps to human-readable format with unit detection
- **timestamp**: Multi-purpose timestamp utility for files and current time
- **hashcat**: Display file contents with line hashes (SHA or MD5)

### Git Integration
Git utilities follow the `git-<command>` naming convention and can be used as git subcommands when the git/ directory is in PATH.

## Development Patterns

- All utilities are implemented as bash scripts with consistent option parsing
- Most utilities include `-h` flag for help text
- Error handling uses exit codes (22 for invalid arguments is common)
- Utilities are designed to work in restricted environments without external dependencies
- Many utilities can be symlinked with alternative names for different behaviors

## Bash Coding Standards

### Variable Naming and Management
- All LOCAL variables in a BASH script should be defined in UPPERCASE
- Before parsing command line options, any environment variables set from those options should be unset before the loop

### Boolean Variable Testing
Always prefer:
```bash
[[ -n ${ENV} ]]  # or [[ -z ${ENV} ]]
```
to:
```bash
[[ ${ENV} == "true" ]] # or [[ ${ENV} != "true" ]]
```
when checking to see if a boolean variable is set

### Conditional Statement Style
Always prefer:
```bash
[[ -n ${VAR} ]] && foo || bar
```
to:
```bash
if [[ -n ${VAR} ]]; then
  foo
else
  bar
fi
```
unless the line length exceeds 20-30 characters

Likewise, always prefer:
```bash
[[ -n ${ENV} ]] && { echo "something"; exit 22; }
```
to:
```bash
if [[ -n ${ENV} ]]; then
  echo "something"
  exit 22
fi
```
with the same line length restrictions

### Command Substitution
Always prefer:
```bash
$(command)
```
to:
```bash
`command`
```

### Command Execution and Resource Management
- When creating a script that executes a command, use `exec` to execute the command if the script does not check the result of the command and the script does not have a trap
- If a script creates a temporary file, it should clean it up with a trap unless there is a command line option to preserve it. Use single quotes so the filename is expanded when the trap fires (not when it is defined), quote the variable, and use `rm -f` so an already-removed file is not an error:
```bash
TMPFILE=$(mktemp)
trap 'rm -f "${TMPFILE}"' EXIT
```

## Testing Approach

No formal test framework is used. Testing is typically done manually by:
- Running utilities with various input combinations
- Testing edge cases and error conditions
- Verifying behavior in different terminal environments

## Installation and Setup

The setup/ directory contains scripts for linking utilities and configuration files to appropriate locations in the user's environment.