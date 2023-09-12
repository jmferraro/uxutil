" Vim color file

" This is almost all defaults, it just sets the background to dark
" Set all the color options back to the default and then just ocerride rge
" ones we want
" look at the default.vim colorscheme for more details
hi clear Normal
set bg&
hi clear

if exists("syntax_on")
  syntax reset
end

let colors_name = "ferraro"
set background=dark
hi Normal        guifg=white  guibg=black
hi Search        term=reverse ctermfg=0  ctermbg=3 guifg=Black guibg=Brown
hi Statement     term=bold    cterm=bold ctermfg=3 gui=bold    guifg=Yellow
hi Comment       term=bold    ctermfg=6            gui=bold    guifg=#1E90FF
hi Cursor        term=reverse ctermfg=NONE ctermbg=NONE gui=reverse guifg=NONE guibg=NONE
hi CursorLine    term=none    cterm=bold ctermfg=0 ctermbg=7 guibg=Grey40
hi CursorColumn  term=none    cterm=bold ctermfg=0 ctermbg=7 guibg=Grey40

if &term == "xterm" || &term == "xterm-256color"
  hi Comment       term=bold cterm=bold ctermfg=6   guifg=#80A0FF
  hi DiffCChange   term=bold            ctermbg=5   guibg=DarkMagenta
  hi Directory     term=bold cterm=bold ctermfg=6   guifg=Cyan
  hi MatchParen    term=reverse ctermfg=6           guibg=DarkCyan
  hi Search        term=reverse ctermfg=0
  hi Special       term=bold    cterm=bold ctermfg=1 guifg=Orange
  hi SpecialKey    term=bold    cterm=bold ctermfg=4 guifg=Cyan
  if &t_Co >= 256
    hi Statement   term=bold cterm=bold ctermfg=180 gui=bold guifg=#FFFF60
    hi Conditional term=bold cterm=bold ctermfg=215 gui=bold guifg=#FFFF60
  else " must be < 256
    hi Statement   term=bold cterm=bold ctermfg=3   gui=bold guifg=#FFFF60
 end
end

" Additional colorization for 256 color mode     
if &t_Co >= 256
  " why doesn't this work above for gvim?
  hi Comment     term=bold cterm=bold ctermfg=6            guifg=#80A0FF
  hi Boolean     term=underline       ctermfg=219          guifg=Magenta
  hi Repeat      term=bold cterm=bold ctermfg=142 gui=bold guifg=#FFFF60
  hi Label       term=bold cterm=bold ctermfg=130 gui=bold guifg=#FFFF60
  hi Operator    term=bold cterm=bold ctermfg=118 gui=bold guifg=#FFFF60
  hi Keyword     term=bold cterm=bold ctermfg=201 gui=bold guifg=#FFFF60
  hi Exception   term=bold cterm=bold ctermfg=194 gui=bold guifg=#FFFF60
  "hi Include     PreProc
  "hi Define      PreProc
  "hi Macro       PreProc
  "hi Precondit   PreProc
end

" vim sw=2
