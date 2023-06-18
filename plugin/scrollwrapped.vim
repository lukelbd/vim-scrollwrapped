"------------------------------------------------------------------------------
" Name:   scrollwrapped.vim
" Author: Luke Davis (lukelbd@gmail.com)
" Date:   2018-09-03
"------------------------------------------------------------------------------
" Disgustingly over-engineered solution to scrolling wrapped lines in vim
" Note: Vim forces us to always start at beginning of wrapped line, but don't
" necessarily have to end on one. So, scrolling is ***always controlled***
" by the lines near the top of the screen!
" Note: Function may misbehave in special circumstances -- i.e. vim always
" coerces current topline to the next one if we try to put cursor on the bottom
" line when it runs off-screen. Not sure of robust way to fix this. Probably
" best to just let cursor get 'pushed' up the screen when this happens.
"------------------------------------------------------------------------------
" Options
if !exists('g:scrollwrapped_wrap_filetypes')
  let g:scrollwrapped_wrap_filetypes = ['bib', 'liquid', 'markdown', 'rst', 'tex']
endif
if !exists('g:scrollwrapped_scrolloff')
  let g:scrollwrapped_scrolloff = 4
endif
if !exists('g:scrollwrapped_tolerance')
  let g:scrollwrapped_tolerance = 100
endif

" Autocommands
augroup scrollwrapped
  au!
  au FileType * if !get(b:, 'wrap_toggle_applied', 0)
    \ | exe 'WrapToggle ' . (index(g:scrollwrapped_wrap_filetypes, &ft) != -1)
    \ | let b:wrap_toggle_applied = 1
    \ | endif
  au BufEnter * if &l:wrap
    \ | let &g:scrolloff = 0
    \ | else
    \ | let &g:scrolloff = g:scrollwrapped_scrolloff
    \ | endif
augroup END

" Toggle command and others
command! -nargs=? WrapToggle call scrollwrapped#toggle(<args>)
command! WrapHeight echom string(scrollwrapped#props('l', '.'))
command! WrapStarts echom string(scrollwrapped#props('c', '.'))

" Add default maps
noremap <C-f> <Cmd>call scrollwrapped#scroll(winheight(0), 'd', 1)<CR>
noremap <C-b> <Cmd>call scrollwrapped#scroll(winheight(0), 'u', 1)<CR>
noremap <C-d> <Cmd>call scrollwrapped#scroll(winheight(0) / 2, 'd', 1)<CR>
noremap <C-u> <Cmd>call scrollwrapped#scroll(winheight(0) / 2, 'u', 1)<CR>
noremap <C-j> <Cmd>call scrollwrapped#scroll(winheight(0) / 4, 'd', 1)<CR>
noremap <C-k> <Cmd>call scrollwrapped#scroll(winheight(0) / 4, 'u', 1)<CR>
