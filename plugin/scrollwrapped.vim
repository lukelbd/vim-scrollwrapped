"------------------------------------------------------------------------------
" Author: Luke Davis (lukelbd@gmail.com)
" Date:   2018-09-03
"------------------------------------------------------------------------------
" Over-engineered solution to scrolling wrapped lines in vim. This plugin replaces
" native, exact-line-count scrolling with an almost-line-count scrolling algorithm
" that preserves window-relative line and column numbers.
" Note: Function may misbehave in special circumstances -- i.e. vim always
" coerces current topline to the next one if we try to put cursor on the bottom
" line when it runs off-screen. Not sure of robust way to fix this. Probably
" best to just let cursor get 'pushed' up the screen when this happens.
"------------------------------------------------------------------------------
" Options
" Note: Local scrolloff added in patch 8.1.0864. Toggling on-off will silently fail in
" older versions. See https://github.com/vim/vim/commit/375e339?diff-split
if !exists('g:scrollwrapped_nomap')
  let g:scrollwrapped_nomap = 0
endif
if !exists('g:scrollwrapped_tolerance')
  let g:scrollwrapped_tolerance = 100
endif
if !exists('g:scrollwrapped_wrap_filetypes')
  let g:scrollwrapped_wrap_filetypes = ['bib', 'liquid', 'markdown', 'rst', 'tex']
endif

" Autocommands
augroup scrollwrapped
  au!
  exe 'au FileType ' . join(g:scrollwrapped_wrap_filetypes, ',') . ' call scrollwrapped#toggle(1, 1)'
augroup END

" Toggle command and others
command! -nargs=? WrapToggle call scrollwrapped#toggle(<args>)
command! WrapHeight echom 'Current wrapped line height: ' . len(scrollwrapped#starts('.'))
command! WrapStarts echom 'Current wrapped line starts: ' . join(scrollwrapped#starts('.'), ', ')

" Add default maps
if !g:scrollwrapped_nomap
  noremap <C-f> <Cmd>call scrollwrapped#scroll(winheight(0), 0)<CR>
  noremap <C-b> <Cmd>call scrollwrapped#scroll(winheight(0), 1)<CR>
  noremap <C-d> <Cmd>call scrollwrapped#scroll(winheight(0) / 2, 0)<CR>
  noremap <C-u> <Cmd>call scrollwrapped#scroll(winheight(0) / 2, 1)<CR>
  noremap <C-j> <Cmd>call scrollwrapped#scroll(winheight(0) / 4, 0)<CR>
  noremap <C-k> <Cmd>call scrollwrapped#scroll(winheight(0) / 4, 1)<CR>
endif
