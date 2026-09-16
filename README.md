# UXUTIL

A collection of open source utilities and file I've developed over the years.  I use many of them daily.  Some are quick implementations of utilities provided by other (installable) packages that I might not be able to access at wherever I might be working (e.g. *sponge*)

Some of these are grouped by the sub-directory for the group of functions they provide; git-specific utilities are documented in [*git/*](git/README.md), and the helper files that are not commands in their own right (a sourced library, a browser snippet, reference scripts) in [*misc/*](misc/README.md).

## Utilities:

### bash-trace
*bash-trace \<script\> \[args\]*
<br>Run the specified bash *script* under the trace option (*bash -x*), printing each line as it executes.  The trace prefix is configured to show the source file, line number, and function name of each traced command.

### claude2md
*claude2md \[-a\] \[-l\] \[-d dir\] \[-s pattern\] \<file.json\>*
<br>Convert *claude.ai* conversation JSON into readable markdown transcripts.  Accepts either a whole-account *conversations.json* (a JSON array) or a single conversation (a JSON object); with *-d* it writes one *&lt;date&gt;-&lt;title&gt;-&lt;uuid8&gt;.md* per conversation, otherwise it writes to stdout.
Notable options: *-a* include thinking and tool_use/tool_result blocks (default is message text only), *-l* list conversations without writing, and *-s* restrict to titles matching a case-insensitive regex.  Requires *jq*.

Saving a long conversation from the browser does not work — *claude.ai* virtualises the message list, so *Save Page As* and *Print* only capture the turns currently mounted in the DOM.  The full transcript arrives in a single JSON request, so there are two ways to get at it:

* **Whole account:** *Settings &rarr; Privacy &rarr; Export data*.  The emailed download link **expires 24 hours after delivery**, there is no published SLA on generation time, and deleted conversations are not included.  Unzip and run *claude2md* over *conversations.json*.
* **One conversation:** paste [*misc/claude-fetch.js*](misc/claude-fetch.js) into the browser console on the open chat.  A same-origin *fetch* sends the session cookie automatically, so nothing is extracted or stored and no public */share/* link is created.  It downloads JSON for *claude2md*.

Note that neither route carries the *bytes* of uploaded attachments or of files generated in-session — only references.  *claude2md* lists their filenames under each message so the gap is at least visible.  A conversation fetched with *tree=True* contains abandoned edit/regenerate branches; *claude2md* walks *current_leaf_message_uuid* back to the root to emit only the live thread, falling back to chronological order for exports (which drop the parent links).
Very large exports are read into memory by *jq* in one pass; a multi-hundred-MB *conversations.json* may need more RAM than a small machine has.

### cleandup
*cleandup \[options\] \[dir1 dir2\]*
<br>Delete files from *dir2* that are identical to files in *dir1*, recursing by default and removing any *dir2* directories that become empty.  A file that is a hard link to its *dir1* counterpart is left alone, so the only copy is never removed.  With no directories given, *dir1* defaults to the parent directory (*..*) and *dir2* to the current directory (with recursion disabled).
Notable options: *-n* dry run (show what would be deleted), *-B* delete both copies, *-R* do not recurse, *--no_hdr* ignore RCS *$Header*/*$Id* lines when comparing, and *-v* verbose.

### cleandup.rb
*cleandup.rb \[options\] \[dir1 dir2\]*
<br>A Ruby implementation of *cleandup* with the same options and behavior, for environments where Ruby is preferred or available.  See *cleandup* (the portable Perl version) for details.

### cmp-dirs
*cmp-dirs \[-v\] \[-x\] \<dir1\> \<dir2\>
<br>Compare all the files in specified directories, indicating differences in the files:
* IDENTICAL
* SAME DEVICE/INODE
* DIFFERS

Specifying *-v* will produce more verbose output
Specifying *-x* will produce extended output

NOTE: This command can be linked as *diff-dirs* or *meld-dirs*
If invoked as either of those names, it will invoke either *tkdiff* or *meld* on each of the differing files

### d2x
*d2x \<num1\> \[num2\] ...*
<br>Takes a list of input decimal values and converts to hexadecimal (opposite of *x2d*)

### dumppath
*dumppath \[env var\]*
<br>Split the contents of the specified environment variable (or *PATH* if none is specified) onto separate lines, splitting by the ':' delimiter
For example:
```
$ dumppath
01) /bin
02) /usr/bin
03) /usr/local/bin
```

### ffind
<br>Search the all in all subdirectories for specified file
```
$ ffind -h
Usage: [OPTS] <pattern>
where OPTS:
  -I      : do *NOT* exclude 'install' dirs
  -d dir  : specify directory to search (default current dir)
  -t type : specify the type of entry to seek (default f)
  -h      : this help text
```
The *-I* option is included since many build systems (particularly when building library code) place a copy of the source in an *'install'* directory somwhere in the project tree -- usually parallel to the source.
This can result in a situation where when looking for source to fix a proble using *ffind*, teh result may be the copy in the 'install' directory.
Issuing a command like: `vi $(which ffind *file*)` may ersult in editing the install version, which would disappear after the next clean build.

### filediff
*filediff \[-v\] \<file1\> \<dir|file2\>*
<br>Will indicate whether there are differences in the specified input files. (running diff will not produce output if there are not differences and visual confirmation may be desired)
If the second argument is a directory instead of a file, that directory will be searched for a file with the same name as the first argument.
If the *-v* command line option is specified and the files differ, the differences will be shown in the output (just as with diff)
```
$ echo foo > foo1
$ echo foo > foo2
$ ln foo1 fu
$ echo bar > bar

$ diff foo1 foo2
$ filediff foo1 foo2
foo1 and foo2 are identical

$ diff foo1 fu
$ filediff foo1 fu
Files foo1 and fu have the same device/inode

$ filediff foo bar
files foo and bar differ
$ filediff -v foo bar
1c1
< foo
---
> bar
```
### findcmd
*findcmd \<string\>*
<br>Search the PATH for an executable file, the name of which contains the specified string

### grep-all
*grep-all \[-d dir\] \[-n fileglob\] \<word\> \[word ...\]*
<br>List the files that contain **all** of the given *words*.  The search starts at *-d dir* (default: the current directory) and, by default, considers every file; give *-n fileglob* to restrict to names matching a `find -iname` pattern (e.g. `-n '*.txt'` -- quote it).  Matching is fixed-string and case-insensitive (*fgrep -i*), and only the file names are printed, not the matching text.  At least one *word* is required, and a *word* may itself contain spaces to match a phrase.  Exit status is 0 if any file matched, 1 if none, 22 for a usage error.

### grepdoc
*grepdoc \<pattern\> \[file ...\]*
<br>Grep the text of word-processor documents (`.doc`, `.docx`, `.odt`) for the specified *pattern*.  With no files given, it defaults to `*.doc` in the current directory.  Zip-based formats (`.docx`/`.odt`) are read directly; plain `.doc` files are converted with *textutil*, which must be installed.

### greplist
*greplist \<string\> \<filelist(s)\>*
<br>Will run the grep command, using the specified *string* on each of the files in the specified *filelist\(s\)

### gt-title
*gt-title \[-q\] \<title\>*
<br>Set the title of the current terminal window to the specified *title*, using the XTerm *OSC 0* escape sequence.
That sequence is honored by nearly every graphical terminal emulator, not just *gnome-terminal*: *mate-terminal*, *xterm*, *konsole*, *xfce4-terminal*, *terminator*, *tilix*, *alacritty*, *kitty*, *wezterm*, *foot*, *iTerm2*, *Terminal.app*, *PuTTY* and *Windows Terminal* all accept it.
Where it cannot work -- a Linux virtual console, *TERM* set to *dumb*/*linux*/*vt100*, an *emacs* shell buffer, output that is not a terminal, or inside *screen*/*tmux* when they are not configured to pass the title through -- the terminal is identified and a warning explaining why is written to stderr.
Specify *-q* to suppress that warning (useful when calling it from *PROMPT_COMMAND*).

### hashcat
*hashcat \[-c\] \[-m\] \[-w|W\] \<file\>*
<br>*cat* the specified file to the console, prepending the line number and hash of the line.
The default behavior is to compute the hash for each line independently
By specifying the *-c* option, the cumulative has for the file will be displayed at each line instead
specifying *-w* will cause the hash computation to ignore all leading and trailing whitespace
specifying *-W* will have produce the same hash computation but the whitespace will also be stripped from the output of the file
By default *hashcat* will use *shasum* to compute the hashes.  If it cannot be found, it will use *md5sum*.
The use of *md5sum* can be forced by specifying the *-m* command line option.

### i2time
*i2time \[-u\] \<time[.fract|s|m|u|n] ...\>*
<br>Convert the specified epoch times to human readable times.
If neither a fractional part of the time nor one of the *s*, *m*, *u*, *n* unit specifiers is present, it
will attempt to heuristically determine the units of the provided time.
If the *-u* parameter is specified, the output will be in UTC rather than local time.

### indir
*indir \<DIR\> \<cmd \<args\>\>*
<br>Temporarily chdir to the specified *DIR* and execute the *cmd*, passing any specified *args* to it

### jmake
*jmake \[options\] \[arguments\]*
<br>Run make on the using the specified parameters.
If the make command fails and the output of make will take more than a single screen of output, the results will be displayed in *less*.
```
$ jmake -h
Usage: jmake [OPTIONS] arguments
OPTIONS:
  -f : specify makefile name
  -L : do not display output of make in less when complete
  -k : keep the output file from the make command
  -- : remaining arguments will not be considered options
```
NOTE: This command is superceded by the use of *torl*.  Instead of running `jmake`, simply run `make | torl`.
There are more characters to type but using *torl* is more flexible since it can work with any build system. not just *make*
(e.g. *ninja* -- `ninja | torl`)

### notes
*notes \[-e|E\] \<string\>*
<br>Run without an argument will produce a list of all notes found
If an argument is found, will:
* search the a note with the specified name
* search the contents of all notes for a matching string

If specified with the option '*-e* option, the matching note will be displayed in the editor (and created if it does not exist)
Specifying *-E* will only show the file in the editor if it already exists.

### psef
Run the *ps* command searching the output for the specified argument(s) (ignoring the *psef* command itself, preserving the header line from the output)

### sep
*sep \[-C\] \[-count|/\]* \[char\]*
<br>The default behavior is to fill the screen (all rows and columns) with a dash in bold white/
If the count is specified, only that number of lines will be output.
*-/* indicates that only 1/2 of the screen should be filled.
Specifying the *-C* parameter prevents *sep* from changing the color of the output lines.
A different output character can be specified on the command line.

### sponge
*sponge \[-a\] \[file\]*
<br>Implemented in bash, like the linux *sponge* command available in either *coreutils* or *moreutils* depending on the distribution.
If *-a* is specified, the output will be appended to the specified file instead of overwriting it.
For example, to convert an entire file to uppercase:
```
$ #cat foo | tr '[:lower:]' '[:upper:]' > foo
$ cat foo | tr '[:lower:]' '[:upper:]' | sponge foo
```
The first command (commented) would cause *foo* to be empty.
By inserting *sponge * in the pipeline, the contents of the foo are converted as expected

### subgrep
*subgrep \[-c\] \[-d dir\] string \[file\(s\)\]*
<br>Search the all files in all subdirectories for the specified string.
If *file(s)* are specified, search only those files matching the files/globs specified.
If *-c* is specified, search only *cpp*, *c*, and *h* files
if -d* is specified , use the specified directory as the starting point for the search
<br>Files/globs may use brace alternation, e.g. *\*.{c,cpp,h}*.
<br>Uses the system *grep -r* when it supports *--include*, and falls back to *uxrgrep* when it does not; both produce the same output and the same exit status.

### symlinks
*symlinks \[-R\] \[-v\] \[dir\]*
<br>List the broken (dangling) symlinks found in the specified directory (default: the current directory).
Specifying *-R* will remove the broken symlinks instead of listing them.
Specifying *-v* enables verbose output.

### timestamp
*timestamp \-h\] \[-n\] \[-q\] \[-c\] \[-k\] \[-s\] \[file(s)\]*
<br>General tmestamp utility.
Run by itself, it will print the current timestamp (optionally with nanonsecond precision if *-n* is specified.
Using the *-q* option alow with one or more files will report the last modified time of each file.
The utility can also be used to mark the file with a timestamp.  The default behavior is to use the modifification time of the file.
Specifying *-c* will override this behavior, using the current timestamp instead.
if file(s) will be renamed to append the timestamp unless the *-k* option is specified, which will result in creating a copy of the file instead.

### torl
*torl \[filename\]*
<br>Read from standard input and write to standard output and files (like *tee*).  After execution, if the output is larger than the screen size, it will display the output in less.
If no file is specified, the command will create a temporary file to capture (and display) the output.  If created, the temporary file will be deleted once the command completes.
<br>(The name comes from: 'Tee OR Less')

### uxrgrep
Perform a recursive grep (fgrep, grep, or egrep) starting with the specified location using the specified options.
<br>Formerly *rgrep*, renamed because GNU grep now ships an *rgrep* of its own that takes its arguments in the opposite order (*rgrep pattern \[file...\]* versus *uxrgrep \<path\> \<pattern\> \[filepat\]...*), and whose *-e*, *-f* and *-h* options mean different things.
Whichever came first on *PATH* silently won, so the two now have distinct names.
```
$ uxrgrep -h
Usage: uxrgrep [-i] [-l] [-f|-e] [-n|v] [-h] <path> <pattern> [filepat]...
WHERE:
 -e : pattern is an extended regular expression (ERE)
 -f : pattern is an fixed string
 -i : ignore case
 -l : print only names of files containing matches
 -n : print 1-based line number with each output line
 -v : invert match; select non-matching lines
 -h : this help text
```
Each *filepat* may use brace alternation, e.g. *\*.{c,cpp,h}*; nested and repeated groups are supported.
<br>Needs only *find* and a plain non-recursive *grep*, so it still works where *grep* has no *-r* option.
It prefers *find -print0 | xargs -0*, falling back to *find -exec ... +* and then *find -exec ... \;* on systems lacking those.
<br>Sources *misc/uxbrace.sh*, located relative to the real (symlink-resolved) script directory.
<br>Exit status is 0 if any match was printed, 1 if none (a match found only inside a binary file is reported on stderr and does not count), 2 if *path* does not exist, and 22 for a usage error.

### vimln
Given an input of source:line or source:line:column, will start vim and position the cursor at the specified location.

### x2d
*x2d \<num1\> \[num2\]...*
<br>Takes a list of input hexadecimal values and converts to decimal (opposite of *d2x*)

