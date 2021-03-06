"------------------------------------------------------------------------------"
" Name:   scrollwrapped.vim
" Author: Luke Davis (lukelbd@gmail.com)
" Date:   2018-09-03
"------------------------------------------------------------------------------"
" Disgustingly over-engineered solution to scrolling wrapped lines in vim
" Note: vim forces us to always start at beginning of wrapped line, but don't
" necessarily have to end on one. So, scrolling is ***always controlled***
" by the lines near the top of the screen!
" Warning: Function may misbehave in special circumstances -- i.e. vim always
" coerces current topline to the next one if we try to put cursor on the bottom
" line when it runs off-screen. Not sure of robust way to fix this. Probably
" best to just let cursor get 'pushed' up the screen when this happens.
" Note: If cursor moves down screen instead of up the screen, some shit is wrong yo.
"------------------------------------------------------------------------------"
" Options
if !exists('g:scrollwrapped_wrap_filetypes')
  let g:scrollwrapped_wrap_filetypes = ['bib', 'tex', 'markdown', 'rst', 'liquid']
endif
if !exists('g:scrollwrapped_scrolloff')
  let g:scrollwrapped_scrolloff = 4
endif

" Autocommands
augroup scrollwrapped
  au!
  au FileType * exe 'WrapToggle ' . (index(g:scrollwrapped_wrap_filetypes, &ft) != -1)
  au BufEnter * if &l:wrap | let &g:scrolloff = 0 | else | let &g:scrolloff = g:scrollwrapped_scrolloff | endif
augroup END

" Toggle command and others
command! -nargs=? WrapToggle call scrollwrapped#wraptoggle(<args>)
command! LineHeight echom string(scrollwrapped#wrapped_line_props('l', '.'))
command! ColStarts echom string(scrollwrapped#wrapped_line_props('c', '.'))

" Normal mode maps
nnoremap <silent> <C-f> :call scrollwrapped#scroll(winheight(0), 'd', 1)<CR>
nnoremap <silent> <C-b> :call scrollwrapped#scroll(winheight(0), 'u', 1)<CR>
nnoremap <silent> <C-d> :call scrollwrapped#scroll(winheight(0)/2, 'd', 1)<CR>
nnoremap <silent> <C-u> :call scrollwrapped#scroll(winheight(0)/2, 'u', 1)<CR>
nnoremap <silent> <C-j> :call scrollwrapped#scroll(winheight(0)/4, 'd', 1)<CR>
nnoremap <silent> <C-k> :call scrollwrapped#scroll(winheight(0)/4, 'u', 1)<CR>

" Closest reasonable thing for visual mode
vnoremap <silent> <expr> <C-f>  winheight(0) . '<C-e>' . winheight(0) . 'gj'
vnoremap <silent> <expr> <C-b>  winheight(0) . '<C-y>' . winheight(0) . 'gk'
vnoremap <silent> <expr> <C-d>  (winheight(0)/2) . '<C-e>' . (winheight(0)/2) . 'gj'
vnoremap <silent> <expr> <C-u>  (winheight(0)/2) . '<C-y>' . (winheight(0)/2) . 'gk'
vnoremap <silent> <expr> <C-j>  (winheight(0)/4) . '<C-e>' . (winheight(0)/4) . 'gj'
vnoremap <silent> <expr> <C-k>  (winheight(0)/4) . '<C-y>' . (winheight(0)/4) . 'gk'

