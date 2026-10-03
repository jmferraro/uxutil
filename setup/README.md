# setup

Scripts to run after cloning the repository to configure a new machine.

### gitsetup.sh
*gitsetup.sh \[-f|--force\]*
<br>Apply the git configuration from [*../git/gitconfig*](../git/gitconfig) to the user's global git config (via *git config --global*).  By default any setting that already differs is preserved and a warning is printed; *-f* (*--force*) overwrites existing values without warning.

### vimsetup.sh
*vimsetup.sh \[-f\] \[-n\]*
<br>Symlink the Vim configuration into the home directory: [*../vim/vimrc*](../vim/vimrc) to *~/.vimrc* and the [*../vim/ferraro.vim*](../vim/ferraro.vim) colorscheme to *~/.vim/colors/ferraro.vim*, and create the swap-file directory declared in the vimrc.  An existing *~/.vimrc* that differs is left in place unless *-f* is given; *-n* shows what would be done without making any changes.
