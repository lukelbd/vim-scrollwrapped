"------------------------------------------------------------------------------
" Author: Luke Davis (lukelbd@gmail.com)
" Date:   2018-09-03
"------------------------------------------------------------------------------
" Over-engineered solution to scrolling wrapped lines in vim. This plugin replaces
" native, exact-line-count scrolling with an almost-line-count scrolling algorithm
" that preserves window-relative line and column numbers.
" Note: Local scrolloff added in patch 8.1.0864. Toggling on-off will silently fail
" in older versions. See https://github.com/vim/vim/commit/375e339?diff-split
" Note: Vim coerces current topline to the next one if we try to put cursor
" on the bottom line when it runs off-screen, causing window-relative cursor
" position to drift up the screen. For now nut sure of robust way to fix this.
"------------------------------------------------------------------------------
" Global settings
exe exists('g:loaded_scrollwrapped') ? 'finish' : ''
let g:loaded_scrollwrapped = 1
if !exists('g:scrollwrapped_nomap')
  let g:scrollwrapped_nomap = 0
endif
if !exists('g:scrollwrapped_tolerance')
  let g:scrollwrapped_tolerance = 100
endif
if !exists('g:scrollwrapped_wrap_filetypes')
  let g:scrollwrapped_wrap_filetypes = ['bib', 'liquid', 'markdown', 'rst', 'tex']
endif

" Command and mappings
command! -nargs=? WrapToggle call scrollwrapped#toggle(<args>)
command! WrapHeight echom 'Current wrapped line height: ' . len(scrollwrapped#starts('.'))
command! WrapStarts echom 'Current wrapped line starts: ' . join(scrollwrapped#starts('.'), ', ')
augroup scrollwrapped
  au!
  exe 'au FileType ' . join(g:scrollwrapped_wrap_filetypes, ',') . ' call scrollwrapped#toggle(1, 1)'
augroup END
if !g:scrollwrapped_nomap
  noremap <C-f> <Cmd>call scrollwrapped#scroll(winheight(0), 0)<CR>
  noremap <C-b> <Cmd>call scrollwrapped#scroll(winheight(0), 1)<CR>
  noremap <C-d> <Cmd>call scrollwrapped#scroll(winheight(0) / 2, 0)<CR>
  noremap <C-u> <Cmd>call scrollwrapped#scroll(winheight(0) / 2, 1)<CR>
  noremap <C-j> <Cmd>call scrollwrapped#scroll(winheight(0) / 4, 0)<CR>
  noremap <C-k> <Cmd>call scrollwrapped#scroll(winheight(0) / 4, 1)<CR>
endif
