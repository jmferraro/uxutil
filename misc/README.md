# UXUTIL/MISC

Helper files that are not commands in their own right: a library sourced by other utilities, a snippet meant to be pasted into a browser, and a couple of reference scripts.  Unlike the top-level directory and *git/*, this directory is not intended to be on your *PATH*.

## Files:

### claude-fetch.js
*(paste into the browser console on an open claude.ai conversation)*
<br>Save one *claude.ai* conversation as JSON, for conversion with [*claude2md*](../README.md#claude2md).  *Save Page As* and *Print* only capture the turns currently mounted in the DOM because the message list is virtualised; the full transcript is fetched by the web app in a single JSON request, and this snippet simply re-issues that request (with *tree=True&rendering_mode=messages&render_all_tools=true*, so tool blocks arrive intact) and downloads the response as *\<title\>-\<uuid8\>.json*.
Open *https://claude.ai/chat/\<uuid\>*, press *F12* and select *Console* (Chrome refuses pasted code until you type *allow pasting*), paste the whole file and press *Enter*.  Then: *claude2md -a conv.json > conv.md*.
Being a same-origin *fetch* run from the page itself, the (HttpOnly) session cookie is sent automatically; nothing is extracted, stored or published, and no public */share/* link is created.  Whole-account export is deliberately not attempted here -- use *Settings &rarr; Privacy &rarr; Export data* for that.

### colors.py
*python3 colors.py*
<br>Print the red/green/blue values of all 256 xterm colors as hex, in three groups: 0-15 (the ANSI and aixterm colors), 16-231 (the 6x6x6 color cube) and 232-255 (the grayscale ramp, which intentionally omits pure black and white).  The values follow the xterm sources (*256colres.pl* and *XTerm-col.ad*).

### uxbrace.sh
*. misc/uxbrace.sh; expand_braces \<pattern\>*
<br>Brace-glob expansion shared by [*uxrgrep*](../README.md#uxrgrep) and [*subgrep*](../README.md#subgrep).  *expand_braces* prints one plain glob per line for a pattern that may contain brace alternations, e.g. *\*.{c,{h,cpp}}* becomes *\*.c*, *\*.h* and *\*.cpp*.  Braces are matched by depth, so nested and repeated groups expand correctly, and an unbalanced brace is treated as a literal.  Expanding up front means *find* only ever sees plain *-name* globs and *grep* only plain *--include* globs; neither understands brace alternation itself, and both would quietly match nothing if handed the brace form.
It deliberately does not use bash's own brace expansion via *eval*, which would word-split any glob containing a space (e.g. *my file.c*).
This file is **sourced, never run**, and is intentionally not executable.  The two scripts locate it as *misc/uxbrace.sh* relative to their own (symlink-resolved) directory, so it must stay here.

### whites.sh
*whites.sh*
<br>Show how the terminal renders the various "white" escape codes -- *37*, *1;37* (bold), *97* (bright), the 256-color entries *15* and *231*, and truecolor *255;255;255* -- as labelled sample blocks on a black background, with notes on which of them terminals and themes commonly map to the same color.
