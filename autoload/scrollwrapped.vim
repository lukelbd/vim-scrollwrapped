"-----------------------------------------------------------------------------
" Functions for scrolling in presence of wrapped lines
"-----------------------------------------------------------------------------
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

" Get number of folded lines between cursor and window top or bottom
" Note: Include fold underneath cursor if scrolling down, because vim reads the
" line number as the first line in the fold. Do *not* include this if scrolling up.
function! s:foldlines(backward) abort
  let count_folded = 0
  if a:backward  " between here and top
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
  return count_folded  " fold line offset
endfunction

" Iteratively determine the top line. Then optionally *backtrack* by single line
" if using the previous topline option would have been a bit closer to 'n' lines.
" Note: Folded lines should not affect this algorithm.
function! s:topline(backward, nlines) abort
  let topline_init = line('w0')  " window top line
  let stopline = a:backward ? 1 : line('$')
  let motion = a:backward ? -1 : 1
  let counter = 0
  let scrolled = 0
  let topline = s:nextline(a:backward ? 0 : -1, topline_init)
  let lineheight = scrollwrapped#props(0, topline)
  while scrolled <= a:nlines && topline != stopline
    let topline = s:nextline(motion, topline)
    let lineheight = scrollwrapped#props(0, topline)
    let scrolled += lineheight
    if lineheight == -1  " indicates error
      return
    endif
    let counter += 1
    if counter == g:scrollwrapped_tolerance
      echohl WarningMsg
      echom 'Warning: Failed to determine the new top window line.'
      echohl None | break
    endif
  endwhile
  let topline = a:backward ? topline : topline + 1
  if topline == stopline  " move at least one line
    let scrolled = a:nlines
  endif
  let scrollback = abs(scrolled - lineheight - a:nlines) < abs(scrolled - a:nlines)
  let topline_back = s:nextline(-motion, topline)
  if scrollback && topline_init != topline_back
    let topline = topline_back
    let scrolled -= lineheight
  endif
  return [topline, scrolled]
endfunction

" Position the cursor after scrolling input lines, accounting for input window
" columns. Determines which wrapped line we are on, and therefore the number of
" window columns required to traverse before scrolling.
function! s:position(nlines, backward, wincols) abort
  " Initial stuff and line properties
  " Todo: Revisit this, try to keep cursor on same line
  let curline = line('.')
  let curcol = col('.')
  let colstarts = scrollwrapped#props(1, curline)
  let curline_height = len(colstarts)
  let idx = index(map(copy(colstarts), curcol . ' >= v:val'), 0)
  if idx == -1  " cursor is sitting on the last virtual line of 'curline'
    let curline_offset = curline_height - 1  " offset from first virtual line
  elseif idx > 0
    let curline_offset = idx - 1
  endif
  " Determine new cursorline, and offset down that line. Possible that line at top
  " of screen moves while the current much bigger line does not, so account for that
  " below. Gives *required* visual lines scrolled if we move cursor line up or down.
  if a:backward
    let scroll_init = curline_offset  " virtual lines to the first one
  else
    let scroll_init = curline_height - curline_offset  " virtual lines to start of next
  endif
  " If going up, scroll_init is distance to first virtual line of this line, so
  " a:nlines == scroll_init satisfies this (the + a:backward). If If going down,
  " scroll_init is distance to next line, so needs to be less than for same line.
  if a:nlines < scroll_init + a:backward  " stay on same line
    let curline_offset += a:nlines * (a:backward ? -1 : 1)
  else  " going to different line
    let [curline, curline_offset] = s:adjust(a:nlines, a:backward, scroll_init)
  endif
  " Get the column number for winrestview. The min() call avoids errors that crop up
  " due to the brute-force while-loop breaks above when tolerance is exceeded.
  let curline += s:foldlines(a:backward) * (a:backward ? -1 : 1)
  let colstarts = scrollwrapped#props(1, curline)
  let idx = max([min([curline_offset, len(colstarts) - 1]), 0])
  let curcol = a:wincols + colstarts[idx] - 1
  return [curline, curcol]
endfunction

" Scroll first across the current partial line, then across line heights of
" other wrapped lines. Example: If we are on 2nd out of 4 visual lines, want to go
" to next one. This represents virtual scrolling of 2 lines at start.
function! s:adjust(nlines, backward, scroll) abort
  " Determine line height. Note the init scroll brought us to (up) start of this
  " line, so query text above it, or (down) start of next line, so query enxt line
  let qline = line('.')
  let scrolled_cur = a:scroll
  let counter = 0
  while scrolled_cur <= a:nlines
    let qline += a:backward ? -1 : 1
    let counter += 1
    let lineheight = scrollwrapped#props(0, qline)
    let scrolled_cur += lineheight  " get to next/previous first line
    if counter == g:scrollwrapped_tolerance
      break
    endif
  endwhile
  " Figure our remaining virtual lines to be scrolled. The scrolled - scrolled_cur
  " just gives scrolling past *cursor line* virtual lines, plus the lineheights.
  let scrolled_cur -= lineheight  " result from moving to first/last virtual line
  let remainder = a:nlines - scrolled_cur  " number left
  if a:backward
    if remainder == 0  " don't have to move to previous line at all
      let curline = qline + 1
      let curline_offset = 0
    else  " e.g. if remainder == 1, lineheight == 3, 'offset' should be 2
      let curline = qline
      let curline_offset = lineheight - remainder
    endif
  else
    let curline = qline
    let curline_offset = remainder  " minimum remainder is 1
  endif
  return [curline, curline_offset]
endfunction

" Helper functions
" Warning: The numberwidth will *lie* if you have more line numbers
" than it permits, so must instead test the number of lines directly.
function! scrollwrapped#reverse(string) abort  " reverse the lines
  let result = reverse(split(a:string, '.\zs'))
  return join(result, '')
endfunction
function! scrollwrapped#numberwidth() abort
  let width = max([len(string(line('$'))) + 1, &l:numberwidth])
  return &l:number || &l:relativenumber ? width : 0
endfunction
function! scrollwrapped#signwidth() abort
  return &l:signcolumn ==# 'yes' || &l:signcolumn ==# 'auto'
    \ && !empty(sign_getplaced(bufnr(), {'group': '*'})[0]['signs']) ? 2 : 0
endfunction

" Helper function to return wrapped line height or columns where line is broken
" Note: This will not be be perfect. Consecutive non-whitespace characters
" in breakat seem to *prevent* breaking, for example. But close enough.
function! scrollwrapped#props(cols, line) abort
  let string = getline(a:line)
  let width = winwidth(0) - scrollwrapped#numberwidth() - scrollwrapped#signwidth()
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
      let test = scrollwrapped#reverse(string[0:width-1])
      let offset = match(test, '[' . escape(&l:breakat, '-') . ']')
    endif
    let colnum += width - offset - n_indent  " column number at first position
    let colstarts += [colnum]  " add column to list
    let lineheight += 1  " increment line
    " vint: -ProhibitUsingUndeclaredVariable
    let string = repeat(' ', n_indent) . substitute(string[width - offset:], '^ \+', '', '')
    if counter == g:scrollwrapped_tolerance
      break
    endif
  endwhile
  return a:cols ? colstarts : lineheight
endfunction

" Primary scrolling function. Calls winrestview with a new topline
" and line number, with topline adjusted 'topline' based on wrapping.
" Todo: Get this to work with folds better. Sometimes have moving
" up-and-down issues when position algorithm selects is under fold.
function! scrollwrapped#scroll(nlines, backward) abort
  let scrolloff = &l:scrolloff
  let &l:scrolloff = 0
  let motion = a:backward ? -1 : 1
  if &l:wrap  " figure out new *top* line
    let [topline, scrolled] = s:topline(a:backward, a:nlines)
  else  " wrapping disabled
    let [topline, scrolled] = [s:nextline(motion * a:nlines, line('w0')), a:nlines]
  endif
  let wincols = wincol() - scrollwrapped#numberwidth() - scrollwrapped#signwidth() - 1
  if &l:wrap  " figure out where to put cursor to match lines scrolled
    let [curline, curcol] = s:position(scrolled, a:backward, wincols)
  else  " wrapping disabled
    let [curline, curcol] = [s:nextline(motion * a:nlines, line('.')), wincols]
  endif
  let view = {
    \ 'topline': max([topline, 0]),
    \ 'lnum': curline,
    \ 'leftcol': 0,
    \ 'col': curcol
    \ }
  call winrestview(view)
  let &l:scrolloff = scrolloff
endfunction

" Helper function to toggle 'line wrapping' with associated settings
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
    let &l:scrolloff = 0
    for [key, val] in items(scrollwrapped_maps)
      exe 'noremap <buffer> ' . key . ' ' . val
    endfor
    if !suppress
      echom 'Line wrapping enabled.'
    endif
  else
    let &l:wrap = 0
    let &l:colorcolumn = &g:colorcolumn
    let &l:scrolloff = &g:scrolloff
    for key in keys(scrollwrapped_maps)
      exe 'silent! unmap <buffer> ' . key
    endfor
    if !suppress
      echom 'Line wrapping disabled.'
    endif
  endif
endfunction
