"-----------------------------------------------------------------------------"
" Functions for scrolling in presence of wrapped lines
"-----------------------------------------------------------------------------"
" Global settings
let s:debug = 0
let s:tolerance = 100

" Helper functions
" Warning: The numberwidth will *lie* if you have more line numbers
" than it permits, so must instead test the number of lines directly.
function! s:reverse(string) abort  " reverse the lines
  return join(reverse(split(a:string, '.\zs')), '')
endfunction
function! s:numberwidth() abort
  return (&l:nu || &l:rnu) * max([len(string(line('$'))) + 1, &l:numberwidth])
endfunction
function! s:signwidth() abort
  return 2 * (&l:signcolumn ==# 'yes' || &l:signcolumn ==# 'auto'
    \ && !empty(sign_getplaced(bufnr(), {'group': '*'})[0]['signs']))
endfunction

" Get next line accounting for closed folds
" Note: Could include this as part of 'lineheight' but then folded lines would
" count toward the number of scrolled lines, which we do not want.
function! s:nextline(nlines, line) abort
  let line = a:line
  if a:nlines < 0
    " Jump to start of fold if scrolling up one line puts us on new fold
    for _ in range(-a:nlines)
      let line = line - 1
      let fline = foldclosed(line)  " text *previous* line
      if fline != -1
        let line = fline
      endif
    endfor

  else
    " Jump to one line after end of fold if we are on start of fold and
    " scrolling down one line should move us off of it.
    for _ in range(a:nlines)
      let fline = foldclosedend(line)  " test *current* line
      let line = line + 1
      if fline != -1
        let line = fline + 1
      endif
    endfor
  endif
  if s:debug
    echom 'Scroll ' . a:nlines . ' lines: ' . a:line . ' to ' . line
  endif
  return line
endfunction

" Determine number of folded lines between cursor and window top or bottom
" Note: This is so far unused, but may be useful in future.
" Note: Include fold *underneath cursor* if scrolling down, because vim reads the
" line number as the first line in the fold. Do *not* include this if scrolling up.
function! s:nfolded(updown) abort
  let count_folded = 0
  if 'ud' !~# a:updown
    echom 'Error: Mode string must be either [u]p or [d]own.'
    return
  endif
  if a:updown ==# 'u'  " between here and top
    let cline = line('.')  " exclude fold under cursor
    let topline = line('w0')
    while cline >= topline
      let cline -= 1
      let fline = foldclosed(cline)
      if fline != -1
        let count_folded += (cline - fline)  " if 1-line fold, this is zero
        let cline = fline
      endif
    endwhile
  else  " between here and bottom
    let botline = line('w$')
    let cline = line('.') - 1  " include fold under cursor
    while cline <= botline
      let cline += 1
      let fline = foldclosedend(cline)
      if fline != -1
        let count_folded += (fline - cline)
        let cline = fline
      endif
    endwhile
  endif
  return count_folded  " number of extra lines
endfunction

" Toggle 'line wrapping' with associated settings
function! scrollwrapped#wraptoggle(...) abort
  if a:0  " if non-zero number of args
    let toggle = a:1
  else
    let toggle = 1 - &l:wrap
  endif
  if toggle == 1
    let &l:colorcolumn = 0
    let &g:scrolloff = 0  "  this setting is global! need an autocmd!
    let &l:wrap = 1
    noremap  <buffer> k  gk
    noremap  <buffer> j  gj
    noremap  <buffer> ^  g^
    noremap  <buffer> $  g$
    noremap  <buffer> 0  g0
    noremap  <buffer> gj j
    noremap  <buffer> gk k
    noremap  <buffer> g^ ^
    noremap  <buffer> g$ $
    noremap  <buffer> g0 0
    nnoremap <buffer> A  g$a
    nnoremap <buffer> I  g^i
    nnoremap <buffer> gA A
    nnoremap <buffer> gI I
  else
    let &l:wrap = 0
    let &l:colorcolumn = (has('gui_running') ? '0' : &g:colorcolumn)
    let &g:scrolloff = g:scrollwrapped_scrolloff
    silent! unmap  <buffer> k
    silent! unmap  <buffer> j
    silent! unmap  <buffer> ^
    silent! unmap  <buffer> $
    silent! unmap  <buffer> 0
    silent! unmap  <buffer> gj
    silent! unmap  <buffer> gk
    silent! unmap  <buffer> g^
    silent! unmap  <buffer> g$
    silent! unmap  <buffer> g0
    silent! nunmap <buffer> A
    silent! nunmap <buffer> I
    silent! nunmap <buffer> gA
    silent! nunmap <buffer> gI
  endif
endfunction

" Helper function that returns one of two values: the wrapped line height of given
" line, or a list of *actual* column numbers where *virtual* line breaks have been
" placed by vim. Numbers correspond to first char of each *virtual* col.
function! scrollwrapped#wrapped_line_props(linecol, line) abort
  " First figure out indents
  if 'lc' !~# a:linecol
    echom 'Error: Mode string must be either [l]ine or [c]ol.'
    return -1
  endif
  let string = getline(a:line)
  let width = winwidth(0) - s:numberwidth() - s:signwidth()
  if exists('&breakindent') && &l:breakindent
    let n_indent = max([0, match(string, '^ \+\zs')])
  else
    let n_indent = 0
  endif
  " Iterate through pieces of string
  let offset = 0
  let colnum = 1
  let colstarts = [1]
  let lineheight = 1
  let counter = 0
  while len(string) + 1 >= width  " must include newline character
    " Determine offset due to 'linebreak' feature
    " Note: This won't be perfect! Consecutive non-whitespace characters
    " in breakat seem to *prevent* breaking, for example. But close enough.
    " Note: Need to escape the dash or won't work sometimes (try searching [*-+])
    let counter += 1
    if &l:linebreak
      let test = s:reverse(string[0:width-1])
      let offset = match(test, '[' . escape(&l:breakat, '-') . ']')
    endif
    let colnum += width - offset - n_indent  " the *actual* column number at first position
    let colstarts += [colnum]  " add column to list
    let lineheight += 1  " increment line
    " Note since vim uses 0-indexing, position <width> is 1 char after end
    " Also make sure we trim leading spaces
    " Note: Older versions of Vim require math expressions within index
    " brackets surrounded by parentheses, or get weird error
    if s:debug
      echom 'width: ' . width . ' indent: ' . n_indent . ' string: ' . (width-offset) . ' ' . len(string)
    endif
    let string = repeat(' ', n_indent) . substitute(string[(width - offset):], '^ \+', '', '')
    if counter == s:tolerance
      break
    endif
  endwhile
  return (a:linecol ==# 'l' ? lineheight : colstarts)
endfunction

" Primary scrolling function. Works by calling winrestview with a
" new topline and lnum. We adjust 'topline' based on wrapping.
" * a:nlines is the number of lines
" * a:updown is whether to scroll down or up
" * a:move is whether to move cursor across lines when there is nothing
"   left to scroll, as with normal/builtin vim scrolling.
function! scrollwrapped#scroll(nlines, updown, move) abort
  let winline = winline()
  if 'ud' !~# a:updown
    echom 'Error: Mode string must be either [u]p or [d]own.'
    return
  endif
  let scrolloff = &g:scrolloff  " global only!
  let topline_init = line('w0')
  let nfolded_init = s:nfolded(a:updown)
  let &g:scrolloff = 0
  if a:updown ==# 'u'
    let stopline = 1
    let motion = -1
  else
    let stopline = line('$')
    let motion = +1
  endif

  " Figure out the new *top* line
  " Will set this with winrestview
  if !&l:wrap
    " Wrap not toggled
    let topline = s:nextline(motion * a:nlines, topline_init)
    let scrolled = a:nlines  " a:nlines is read-only variable, so re-assign
  else
    " Figure out the top line iteratively
    " NOTE: Folded lines should not affect this algorithm.
    let counter = 0
    let scrolled = 0
    let topline = s:nextline((a:updown ==# 'u' ? 0 : -1), topline_init)
    let lineheight = scrollwrapped#wrapped_line_props('l', topline)
    while scrolled <= a:nlines && topline != stopline
      let topline = s:nextline(motion, topline)
      let lineheight = scrollwrapped#wrapped_line_props('l', topline)
      let scrolled += lineheight
      if lineheight == -1  " indicates error
        return
      endif
      let counter += 1
      if counter == s:tolerance  " bail out
        echohl WarningMsg
        echom 'Warning: Failed to determine the new top window line.'
        echohl None
        break
      endif
    endwhile
    let topline = (a:updown ==# 'u' ? topline : topline + 1)
    if topline == stopline
      let scrolled = a:nlines
    endif
    if s:debug
      echom 'Old topline: ' . line('w0') . ' New topline: ' . topline . ' Visual motion: ' . scrolled . ' Target: ' . a:nlines
    endif
    " Optionally *backtrack* by single line if using the previous topline option would
    " have been a bit closer to 'n' lines. Re-enforces moving by at least one line.
    let scrollback = abs(scrolled - lineheight - a:nlines) < abs(scrolled - a:nlines)
    let topline_back = s:nextline(-motion, topline)
    if scrollback && topline_init != topline_back
      let topline = topline_back
      let scrolled -= lineheight
      if s:debug
        echom 'Backtracked new topline: ' . topline . ' Visual motion: ' . scrolled
      endif
    endif
  endif

  " Figure out how to correspondingly move *cursor* to match the
  " actual virtual lines scrolls, i.e. the 'scrolled'.
  let curline = line('.')
  let nfolded = s:nfolded(a:updown)
  let wincol = wincol() - s:numberwidth() - s:signwidth() - 1
  if !&l:wrap
    " Line wrapping is not toggled. Just get the cursor column
    " and the current line.
    let curcol = wincol
    let curline = s:nextline(motion * a:nlines, curline)
  else
    " Determine which wrapped line we are on, and therefore,
    " the number of window columns we *have* to traverse
    let curcol = col('.')
    let colstarts = scrollwrapped#wrapped_line_props('c', curline)
    let curline_height = len(colstarts)
    let idx = index(map(copy(colstarts), curcol . '>=v:val'), 0)
    if idx == -1  " cursor is sitting on the last virtual line of 'curline'
      let curline_offset = curline_height - 1  " offset from first virtual line of current line
    elseif idx > 0
      let curline_offset = idx - 1
    else  " should never happen -- would mean cursor is in column '0' because colstarts always starts with 1
      echom 'Error: This should never happen.'
      return
    endif
    if s:debug
      echom 'Current line: ' . curline . ' virtual num: ' . curline_offset . ' colstarts: ' . join(colstarts,', ')
    endif
    " Determine the new cursorline, and offset down that line. Possible that the line
    " at top of screen moves while the current much bigger line does not, so account
    " for that (if statement below). The scroll_init will be the *required* visual
    " lines scrolled if we move the cursor line up or down.
    if a:updown ==# 'u'
      let scroll_init = curline_offset  " how many virtual lines to the first one
    else
      let scroll_init = curline_height - curline_offset  " how many virtual lines to start of next line (e.g. if height is 2, offset is 1, we're at the bottom; just scroll one more)
    endif
    if scrolled < (scroll_init + (a:updown ==# 'u'))
      " Case where we do not move lines
      " * If going up, scroll_init is distance to first virtual line of *this line*, so
      "   scroll_init *equal* to scrolled is acceptable (hence, increment RHS by 1).
      " * If going down, scroll_init is distance to first virtual line of *next line*,
      "   so need scroll_init to be 1 *more* than scrolled to stay on the current line.
      let curline_offset += motion * scrolled
      if s:debug
        echom 'Not changing line.'
      endif
    else
      " Case where we do move lines
      " Idea is e.g. if we are on 2nd out of 4 visual lines, want to go to next one,
      " that represents a virtual scrolling of 2 lines at the start. Then scroll
      " by line heights until enough.
      let qline = curline
      let scroll = scroll_init
      let scrolled_cur = scroll_init  " virtual to reach (up) first one on this line or (down) first one on next line
      while scrolled_cur <= scrolled
        let counter += 1
       " Determine line height
       " Note the init scroll brought us to (up) start of this line, so we want to query text above it,
       " or to (down) start of next line, so we want to query text on that next line
        if s:debug
          echom 'Lineheight: ' . lineheight . ' Scroll: ' . scrolled_cur . ' Target: ' . scrolled
        endif
        let qline += motion  " corresponds to (up) previous line or (down) this line.
        let lineheight = scrollwrapped#wrapped_line_props('l', qline)  " necessary scroll to get to next/previous first line
        let scrolled_cur += lineheight  " add, then test
        if counter == s:tolerance
          break
        endif
      endwhile
      " Figure our remaining virtual lines to be scrolled
      " The scrolled-scrolled_cur just gives scrolling past *cursor line* virtual lines,
      " plus the lineheights
      let scrolled_cur -= lineheight  " number of lines scrolled if we move up to first/last virtual line of curline
      let remainder = scrolled-scrolled_cur  " number left
      if a:updown ==# 'u'
        if remainder == 0  " don't have to move to previous line at all
          let curline = qline+1
          let curline_offset = 0
        else
          let curline = qline
          let curline_offset = lineheight-remainder  " e.g. if remainder is 1, lineheight is 3, want curline 'offset' to be 2
        endif
      else
        let curline = qline
        let curline_offset = remainder  " minimum remainder is 1
      endif
      if s:debug
        let lineheight = scrollwrapped#wrapped_line_props('l', curline)
        echom 'Destination line: ' . curline . ' Remainder: ' . remainder . ' Destination height: ' . lineheight . ' Offset: ' . curline_offset
      endif
    endif
    " Get the column number for winrestview
    " The min() call is to avoid errors that crop up due to those brute-force
    " while-loop breaks above when tolerance is exceeded
    let colstarts = scrollwrapped#wrapped_line_props('c', curline)
    if s:debug
      echom 'Length of colstarts vs. requested offset: ' . len(colstarts) . ' ' . curline_offset
    endif
    let idx = max([min([curline_offset, len(colstarts) - 1]), 0])
    let curcol = wincol + colstarts[idx] - 1
    if s:debug
      echom 'Destination colnum: ' . curcol . ' Colstarts: ' . join(colstarts, ', ')
    endif
  endif

  " Finally restore to the new column
  " Todo: Also account for folds using nfolded and nfolded_init.
  call winrestview({
    \ 'topline': max([topline, 0]),
    \ 'lnum': curline,
    \ 'leftcol': 0,
    \ 'col': curcol
    \ })
  let &g:scrolloff = scrolloff
  if s:debug
    echom 'WinLine: ' . winline . ' to ' . winline()
  endif
  return
endfunction
