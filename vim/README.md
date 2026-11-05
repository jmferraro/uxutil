# UXUTIL/VIM

My Vim configuration.  [*setup-vim.sh*](../setup/README.md#setup-vimsh) symlinks both files into place.

## Files:

### vimrc
*(linked as ~/.vimrc)*
<br>My Vim settings: swap files in *~/tmp/vim*, incremental smart-case search with highlighting, 3-column indents with spaces (2 for Ruby, YAML, Lua, Perl and shell; 4 for Java, C, C++ and Python), trailing whitespace removed on every write, *matchit*, C99/C11 syntax, the *ferraro* colorscheme in gvim and xterms, and the cursor returned to its last position when a file is reopened.
Key mappings include emacs-style *Ctrl-A*, *Ctrl-E* and *Ctrl-K* (start of line, end of line, delete to end of line) in normal and insert mode, *Ctrl-\\* to clear the search highlight, *Q* as *A* and *F1* as *Esc* (the keys I hit by mistake), and *Shift-Insert* to paste from the clipboard in gvim.

### ferraro.vim
*(linked as ~/.vim/colors/ferraro.vim)*
<br>The *ferraro* colorscheme: Vim's defaults on a dark background (white on black in gvim), with bold yellow statements, blue comments, a brown search highlight, a grey cursor line, and in 256-color terminals a distinct color for each kind of keyword.
