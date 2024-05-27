# UXUTIL

A collection of open source utilities and file I've developed over the years.  I use many of them daily.  Some are quick implementations of utilities provided by other (installable) packages that I might not be able to access at wherever I might be working (e.g. *sponge*)

Some of these are grouped by the sub-directory for the group of functions they provide.

## Utilities:

### d2x
*d2x \<num1\> \[num2\] ...*
<br>Takes a list of input decimal values and converts to hexadecimal (opposite of *x2d*)

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

### greplist
*greplist \<string\> \<filelist(s)\>*
<br>Will run the grep command, using the specified *string* on each of the files in the specified *filelist\(s\)

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
Run make on the using the specified parameters.
<br>If the make command fails and the output of make will take more than a single screen of output, the results will be displayed in *less*.

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

### rgrep
Perform a recursive grep (fgrep, grep, or egrep) starting with the specified location using the specified options.
```
$ rgrep -h
Usage: rgrep [-i] [-l] [-f|-e] [-n|v] [-h] <path> <pattern> [filepat]...
WHERE:
 -e : pattern is an extended regular expression (ERE)
 -f : pattern is an fixed string
 -i : ignore case
 -l : print only names of files containing matches
 -n : print 1-based line number with each output line
 -v : invert match; select non-matching lines
 -h : this help text
```

### sep
*sep \[-C\] \[-count|/\]* \[char\]*
<br>The default behavior is to fill the screen (all rows and columns) with a dash in bold white/
If the count is specified, only that number of lines will be output.
*-/* indicates that only 1/2 of the screen should be filled.
Specifying the *-C* parameter prevents *sep* from changing the color of the output lines.
A different output character can be specified on the command line.

### sponge
*sponge \[-a\] [\file\]*
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

### torl
*torl \[filename\]
<br>read from standard input and write to standard output and files (like *tee*).  After execution, if the output is larger than the screen size, it will display the output in less.
If no file is specified, the command will create a temporary file to capture (and display) the output.  If created, the temporary file will be deleted once the command completes

### vimln
Given an input of source:line or source:line:column, will start vim and position the cursor at the specified location.

### x2d
*x2d \<num1\> \[num2\]...*
<br>Takes a list of input hexadecimal values and converts to decimal (opposite of *d2x*)

