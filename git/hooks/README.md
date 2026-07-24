# UXUTIL/GIT/HOOKS

Git hooks I use across my repositories.  Install a hook into a repo by
symlinking it into that repo's *.git/hooks/* — the *git-install-hook* utility
does exactly this for every executable hook found here.

## Hooks:

### pre-commit
*runs automatically on `git commit`; run it manually with `git pre-commit`, or `.git/hooks/pre-commit --all` to scan every tracked file (not just the staged ones)*
<br>Rejects the commit if any checked file contains:
* the markers *FIXME*, *NOCOMMIT*, or *XXX*
* leftover merge-conflict markers (*<<<<<<<*, *=======*, *>>>>>>>*)
* *NULL* in C++ source (allowed in *.c*, *.h*, and *.md* — use *nullptr* in C++)
* trailing whitespace (skipped for *.md*, which uses it for line breaks)
* TAB characters, except where tabs are required — *Makefile*, *.mk*, *.go*, and *go.mod*/*go.sum*/*go.work*

It also rejects tracked symlinks, warns when a file is both staged and further
modified in the working tree, and blocks commits made directly to the default
branch (*master*/*main*) unless a *.gitnorestrict* file exists in the repo root.

**Extending the rules:** project- or firm-specific rules live in an external
file so this hook stays generic.  Point git at one, once:
```
git config --global hooks.precommitRules ~/.config/git/pre-commit-rules
```
That file is *sourced* by the hook and may extend or make exceptions to the
base rules:
```
FAIL_REGEX+=("\bWIP\b")                                            # add a banned pattern
hook_skip_file()  { [[ "$1" =~ ^vendor/ ]]; }                     # skip whole files
hook_skip_regex() { [[ "$1" == '\bNULL\b' && "$2" =~ \.inc$ ]]; }  # except one rule for a file
hook_extra_check(){ grep -q BADAPI "$2" && echo "$1 uses BADAPI"; }  # add an extra check
```
Keep that file outside any repository so it applies everywhere and can never be
committed.  See *pre-commit-rules.example* for a template.

### pre-commit-rules.example
<br>A commented template for the external rules file described above.  Copy it
to your chosen location (e.g. *~/.config/git/pre-commit-rules*), adapt it, and
point *hooks.precommitRules* at it.
