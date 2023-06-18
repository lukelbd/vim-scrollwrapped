"-----------------------------------------------------------------------------
" Functions for scrolling in presence of wrapped lines
"-----------------------------------------------------------------------------
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
  if a:nlines < 0  " jump to start of fold if scrolling up (one line puts us on new fold)
    for _ in range(-a:nlines)
      let line = line - 1
      let fline = foldclosed(line)  " text *previous* line
      if fline != -1
        let line = fline
      endif
    endfor
  else  " jump to one line after end of fold if we are on start of fold.
    for _ in range(a:nlines)
      let fline = foldclosedend(line)  " test *current* line
      let line = line + 1
      if fline != -1
        let line = fline + 1
      endif
    endfor
  endif
  return line
endfunction

" Determine number of folded lines between cursor and window top or bottom
" Todo: This is so far unused, but could be useful in future.
" Note: Include fold underneath cursor if scrolling down, because vim reads the
" line number as the first line in the fold. Do *not* include this if scrolling up.
function! s:foldlines(updown) abort
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
" Note: This overrides user local mappings if present. Could work
" around this but probably not worth it.
function! scrollwrapped#toggle(...) abort
  let state = &l:wrap
  let toggle = a:0 ? a:1 : 1 - state
  let suppress = a:0 > 1 ? a:2 : 0
  let scrollwrapped_maps = {
    \  'k': 'gk', 'j': 'gj', '^': 'g^', '$': 'g$', '0': 'g0',
    \  'gj': 'j', 'gk': 'k', 'g^': '^', 'g$': '$', 'g0': '0',
    \  'A': 'g$a', 'I': 'g^i', 'gA': 'A', 'gI': 'I'
    \ }
  if state == toggle
    return
  elseif toggle == 1
    let &l:wrap = 1
    let &l:colorcolumn = 0
    let &g:scrolloff = 0  "  this setting is global! need an autocmd!
    for [key, val] in items(scrollwrapped_maps)
      exe 'noremap <buffer> ' . key . ' ' . val
    endfor
    if !suppress
      echom 'Line wrapping enabled.'
    endif
  else
    let &l:wrap = 0
    let &l:colorcolumn = &g:colorcolumn
    let &g:scrolloff = g:scrollwrapped_scrolloff
    for key in keys(scrollwrapped_maps)
      exe 'silent! unmap <buffer> ' . key
    endfor
    if !suppress
      echom 'Line wrapping disabled.'
    endif
  endif
endfunction

" Helper function that returns one of two values: the wrapped line height of given
" line, or a list of *actual* column numbers where *virtual* line breaks placed by vim.
" Note: This won't be perfect! Consecutive non-whitespace characters
" in breakat seem to *prevent* breaking, for example. But close enough.
" Note: Since vim uses 0-indexing, position <width> is 1 character after
" the end. Also make sure we trim leading spaces.
" Note: Older versions of Vim require math expressions within index
" brackets surrounded by parentheses, or get weird error
function! scrollwrapped#props(linecol, line) abort
  if a:linecol !~# '^[lc]$'
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
  let offset = 0
  let colnum = 1
  let colstarts = [1]
  let lineheight = 1
  let counter = 0
  while len(string) + 1 >= width  " must include newline character
    let counter += 1
    if &l:linebreak
      let test = s:reverse(string[0:width-1])
      let offset = match(test, '[' . escape(&l:breakat, '-') . ']')  " dash is special inside brackets
    endif
    let colnum += width - offset - n_indent  " the *actual* column number at first position
    let colstarts += [colnum]  " add column to list
    let lineheight += 1  " increment line
    let string = repeat(' ', n_indent) . substitute(string[(width - offset):], '^ \+', '', '')
    if counter == g:scrollwrapped_tolerance
      break
    endif
  endwhile
  return a:linecol ==# 'l' ? lineheight : colstarts
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
  let nfolded_init = s:foldlines(a:updown)
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
    " Note: Folded lines should not affect this algorithm.
    let counter = 0
    let scrolled = 0
    let topline = s:nextline((a:updown ==# 'u' ? 0 : -1), topline_init)
    let lineheight = scrollwrapped#props('l', topline)
    while scrolled <= a:nlines && topline != stopline
      let topline = s:nextline(motion, topline)
      let lineheight = scrollwrapped#props('l', topline)
      let scrolled += lineheight
      if lineheight == -1  " indicates error
        return
      endif
      let counter += 1
      if counter == g:scrollwrapped_tolerance
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
    " Optionally *backtrack* by single line if using the previous topline option would
    " have been a bit closer to 'n' lines. Re-enforces moving by at least one line.
    let scrollback = abs(scrolled - lineheight - a:nlines) < abs(scrolled - a:nlines)
    let topline_back = s:nextline(-motion, topline)
    if scrollback && topline_init != topline_back
      let topline = topline_back
      let scrolled -= lineheight
    endif
  endif

  " Figure out how to correspondingly move *cursor* to match the
  " actual virtual lines scrolls, i.e. the 'scrolled'.
  let curline = line('.')
  let nfolded = s:foldlines(a:updown)
  let wincol = wincol() - s:numberwidth() - s:signwidth() - 1
  if !&l:wrap
    " Line wrapping is not toggled. Just get the
    " cursor column and the current line.
    let curcol = wincol
    let curline = s:nextline(motion * a:nlines, curline)
  else
    " Determine which wrapped line we are on, and therefore,
    " the number of window columns we *have* to traverse
    let curcol = col('.')
    let colstarts = scrollwrapped#props('c', curline)
    let curline_height = len(colstarts)
    let idx = index(map(copy(colstarts), curcol . ' >= v:val'), 0)
    if idx == -1  " cursor is sitting on the last virtual line of 'curline'
      let curline_offset = curline_height - 1  " offset from first virtual line of current line
    elseif idx > 0
      let curline_offset = idx - 1
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
      " Do not move lines. If going up, scroll_init is distance to first virtual line of
      " *this line*, so scroll_init *equal* to scrolled is acceptable (hence, increment
      " RHS by 1). If going down, scroll_init is distance to first virtual line of *next
      " line*, so need scroll_init to be 1 *more* than scrolled to stay on current line.
      let curline_offset += motion * scrolled
    else
      " Case where we do move lines. Idea is e.g. if we are on 2nd out of 4 visual lines,
      " want to go to next one, that represents a virtual scrolling of 2 lines at the
      " start. Then scroll by line heights until enough.
      let qline = curline
      let scroll = scroll_init
      let scrolled_cur = scroll_init  " virtual to reach (up) first one on this line or (down) first one on next line
      while scrolled_cur <= scrolled
        let counter += 1
       " Determine line height. Note the init scroll brought us to (up) start of this
       " line, so we want to query text above it, or to (down) start of next line, so
       " we want to query text on that next line.
        let qline += motion  " corresponds to (up) previous line or (down) this line.
        let lineheight = scrollwrapped#props('l', qline)  " necessary scroll to get to next/previous first line
        let scrolled_cur += lineheight  " add, then test
        if counter == g:scrollwrapped_tolerance
          break
        endif
      endwhile
      " Figure our remaining virtual lines to be scrolled The scrolled-scrolled_cur
      " just gives scrolling past *cursor line* virtual lines, plus the lineheights.
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
    endif
    " Get the column number for winrestview. The min() call avoids errors that crop up
    " due to the brute-force while-loop breaks above when tolerance is exceeded.
    let colstarts = scrollwrapped#props('c', curline)
    let idx = max([min([curline_offset, len(colstarts) - 1]), 0])
    let curcol = wincol + colstarts[idx] - 1
  endif

  " Finally restore to the new column
  " Todo: Also account for folds using nfolded and nfolded_init.
  let view = {
    \ 'topline': max([topline, 0]),
    \ 'lnum': curline,
    \ 'leftcol': 0,
    \ 'col': curcol
    \ }
  call winrestview(view)
  let &g:scrolloff = scrolloff
  return
endfunction
