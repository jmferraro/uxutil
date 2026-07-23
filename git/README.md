# UXUTIL/GIT

Utilities I've developed specifically for git.  As with the general utilities above, I use many of them daily.

Most follow the `git-<command>` convention, so with the *git/* directory in your *PATH* they can be run either directly (e.g. *git-who*) or as a git subcommand (e.g. *git who*).

## Utilities:

### compare_branch_merge.sh
*compare_branch_merge.sh --from \<source_branch\> --into \<target_branch\> \[options\]*
<br>Compare two branches and analyze merge differences, categorizing the differing files into: changed after the source branch's last commit (expected newer), should-match-but-differ (worth investigating), and files unique to each branch.
Options: *--verbose* for detailed output, *--no-color* to disable colored output, and *--help*.

### git-add-mod
*git add-mod \[-n\] \[-v\] \[.\]*
<br>Stage only files that are already tracked and modified, skipping untracked/new files (i.e. *git add* the modified files but nothing new).  A *.* argument limits the operation to the current directory.
Specifying *-n* performs a dry run (show the command only); *-v* is verbose.

### git-alias
*git alias \[--global|--local\] \[\<pattern\> | \<name\> \<command\>\]*
<br>List, search, or create git aliases.  With no arguments it lists all aliases; with a single argument it shows the aliases matching that pattern; with two arguments it creates an alias.  *--global* / *--local* select the config scope.  (Based on *git-extras*.)

### git-branch-diff
*git branch-diff \[OPTIONS\] \<branch1\> \<branch2\> -- \<file1\> \[file2...\]*
<br>Compare the diffs of the specified file(s) between two branches.

### git-checkout-pr
*git checkout-pr \[-f\] \[-l\] \[-r \<remote\>\] \[-v\] \<pull request number\>*
<br>Fetch and check out a pull request by number (Bitbucket-style *refs/pull-requests/*).
Specifying *-l* lists the open pull requests instead of checking one out; *-r* selects the remote (default *origin*); *-f* forces the checkout; *-v* is verbose.

### git-editors
*git editors \<file\> \[file...\]*
<br>List the distinct authors of the specified file(s) (via *git blame*), de-duplicated.  For multiple files, the unique set of authors across all of them is shown.  (See *git-who* for a per-author line count.)

### git-get-branch
*git get-branch \[-v\] \[remote\] \<branch\>*
<br>Create a local tracking branch for a remote branch (default remote: *origin*) and check it out.  Reports an error if a branch of that name already exists.  *-v* is verbose.

### git-install-hook
*git install-hook \[\<hook-name\>\]*
<br>Symlink git hooks from the *hooks/* directory of this repository into the current repo's *.git/hooks/*.  With no argument, every executable hook found is installed; with a name, only that hook is installed.  Existing or stale links are replaced.

### git-pre-commit
*git pre-commit \[args\]*
<br>Run the current repository's *.git/hooks/pre-commit* hook manually (locates the repo root and executes the hook, passing along any arguments).  Does nothing if no executable pre-commit hook is installed.

### git-save-stashed
*git save-stashed*
<br>For each file in the most recent stash (*stash@{0}*), write its stashed contents to a sibling *\<file\>.SAVE_STASH* file, letting you recover stashed content without applying the stash.  Deletions are skipped, and it stops if a *.SAVE_STASH* file already exists.

### git-show-blobs
*git show-blobs*
<br>List every blob in the entire repository history, sorted by size, with human-readable sizes -- useful for finding the large objects bloating a repository.
(Requires GNU *numfmt*; on macOS install it via *brew install coreutils*.)

### git-stash-diff
*git stash-diff \[--meld\]*
<br>Visually diff each file in the most recent stash against its working-tree copy using *tkdiff* (or *meld* if *--meld* is specified).  Added, modified, and deleted stash entries are all handled.

### git-trace
*git trace \<git-command\> \[args\]*
<br>Run a git command with full tracing enabled (*GIT_TRACE*, *GIT_TRACE_PACKET*, *GIT_CURL_VERBOSE*) -- useful for debugging git operations, particularly network/transport behavior.

### git-who
*git who \<file\> \[file...\]*
<br>Show the authors of the specified file(s) with a per-author line count (via *git blame --line-porcelain*), sorted by descending count.  (See *git-editors* for just the distinct author names.)
