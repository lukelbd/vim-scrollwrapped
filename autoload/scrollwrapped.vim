"-----------------------------------------------------------------------------
" Functions for scrolling in presence of wrapped lines
"-----------------------------------------------------------------------------
" Get next line accounting for closed folds
" Note: Could include this as part of 'lineheight' but then folded lines would
" count toward the number of scrolled lines, which we do not want.
scriptencoding utf-8
function! s:nextline(line, nlines) abort
  let line = a:line
  if a:nlines < 0  " jump to start of fold if scrolling up (one line puts us on new fold)
    for _ in range(-a:nlines)
      let line = line - 1
      let fline = foldclosed(line)  " test *previous* line
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

" Iteratively determine the top line. Then optionally *backtrack* by single line
" if using the previous topline option would have been a bit closer to 'n' lines.
" Note: Folded lines should not affect this algorithm.
function! s:topline(nlines, backward) abort
  let topline_init = line('w0')  " window top line
  let stopline = a:backward ? 1 : line('$')
  let counter = 0
  let scrolled = 0
  let topline = s:nextline(topline_init, a:backward ? 0 : -1)
  let lineheight = scrollwrapped#props(topline, 0)
  while scrolled <= a:nlines && topline != stopline
    let topline = s:nextline(topline, a:backward ? -1 : 1)
    let lineheight = scrollwrapped#props(topline, 0)
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
  let topline_back = s:nextline(topline, a:backward ? 1 : -1)
  if topline_init != topline_back && abs(scrolled - lineheight - a:nlines) < abs(scrolled - a:nlines)
    let topline = topline_back
    let scrolled -= lineheight
  endif
  return [topline, scrolled]
endfunction

" Position the cursor after scrolling input lines, accounting for input window columns.
" Determines which number of window columns required to traverse before scrolling.
function! s:position(nlines, wincol, backward) abort
  " Initial stuff and line properties
  let curline = line('.')
  let curcol = col('.')
  let colstarts = scrollwrapped#props(curline, 1)
  let curline_height = len(colstarts)
  let idx = index(map(copy(colstarts), curcol . ' >= v:val'), 0)
  if idx == -1  " cursor is sitting on the last virtual line of 'curline'
    let curline_offset = curline_height - 1  " offset from first virtual line
  elseif idx > 0
    let curline_offset = idx - 1
  endif
  " Determine new cursorline, and offset down that line. Possible that line at top
  " of screen moves while the current much bigger line does not so account for that.
  if a:backward
    let scroll_line = curline_offset  " virtual lines to the first one
  else
    let scroll_line = curline_height - curline_offset  " virtual lines to start of next
  endif
  " Going up, scroll_line is distance to first virtual line of this line, so a:nlines
  " == scroll_line satisfies this. Going down this is distance to next line.
  if a:nlines < scroll_line + a:backward  " stay on same line
    let [newline, newline_offset] = [curline, a:nlines * (a:backward ? -1 : 1)]
  else  " going to different line
    let [newline, newline_offset] = s:scroll(a:nlines, a:backward, scroll_line)
  endif
  " Get the column number for winrestview. The min() call avoids errors that crop up
  " due to the brute-force while-loop breaks above when tolerance is exceeded.
  let starts = scrollwrapped#props(newline, 1)
  let index = max([min([newline_offset, len(starts) - 1]), 0])
  let newcol = starts[index] + a:wincol - 1  " a:wincol starts at one
  return [newline, newcol]
endfunction

" Scroll first across the current partial line, then across line heights of
" other wrapped lines. Example: If we are on 2nd out of 4 visual lines, want to go
" to next one. This represents virtual scrolling of 2 lines at start.
function! s:scroll(nlines, backward, scroll) abort
  " Determine line height. Note the init scroll brought us to (up) start of this
  " line, so query text above it, or (down) start of next line, so query enxt line
  let curline = line('.')
  let scrolled = a:scroll
  let counter = 0
  while scrolled <= a:nlines
    let curline = s:nextline(curline, a:backward ? -1 : 1)
    let counter += 1
    let lineheight = scrollwrapped#props(curline, 0)
    let scrolled += lineheight  " get to next/previous first line
    if counter == g:scrollwrapped_tolerance
      break
    endif
  endwhile
  " Figure our remaining virtual lines to be scrolled. The a:nlines - scrolled
  " just gives scrolling past *cursor line* virtual lines, plus the lineheights.
  let scrolled -= lineheight  " result from moving to first/last virtual line
  let remainder = a:nlines - scrolled  " number left
  if a:backward
    if remainder == 0  " don't have to move to previous line at all
      let curline = curline + 1
      let curline_offset = 0
    else  " e.g. if remainder == 1, lineheight == 3, 'offset' should be 2
      let curline = curline
      let curline_offset = lineheight - remainder
    endif
  else
    let curline = curline
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
" Todo: Consider using screenpos(winnr, line, col) and iterating over all
" columns in the line? Could be too expensive maybe.
" Note: Vim will never start a wrapped line with a break character, but will start
" lines with an end-of-line character for lines exactly matching window width.
function! scrollwrapped#props(line, cols) abort
  let string = getline(a:line) . "\n"  " include end-of-line newline
  let breaks = '[' . escape(&l:breakat, '-') . ']\+'
  let width = winwidth(0) - scrollwrapped#numberwidth() - scrollwrapped#signwidth()
  if exists('&breakindent') && &l:breakindent
    let spaces = substitute(matchstr(string, '^\s*'), '\t', repeat(' ', &l:tabstop), 'g')
  else  " empty leading space
    let spaces = ''
  endif
  let counter = 0
  let colstart = 1
  let colstarts = [1]
  let lineheight = 1
  while len(string) > width
    if counter == g:scrollwrapped_tolerance
      break
    endif
    if !&l:linebreak || string[width] ==# "\n"  " break at end-of-line character
      let offset = 0
    else  " break on &breakat characters
      let part = string[:width]  " endpoint inclusive i.e. length width + 1
      let part = scrollwrapped#reverse(part)  " search in reverse
      let break = part[0] =~# breaks  " never start line with &breakat
      let offset = match(part, breaks, 0, 1 + break)  " 1st or 2nd match
      let offset = offset == -1 ? 0 : offset  " ignore if not found
    endif
    " vint: -ProhibitUsingUndeclaredVariable ·
    let string = spaces . string[width - offset + 1:]  " e.g. width 5 -> start char 6
    let exclude = counter ? len(spaces) : 0  " exclude previous indent
    let colstart += width - offset - exclude + 1
    let colstarts += [colstart]  " add column number to list
    let lineheight += 1  " increment line
    let counter += 1
    " echom 'String ' . counter . ': ' . substitute(string[:width], ' ', '·', 'g')
  endwhile
  return a:cols ? colstarts : lineheight
endfunction

" Primary scrolling function. Calls winrestview with a new topline
" and line number, with topline adjusted 'topline' based on wrapping.
" Todo: Get this to work with folds better. Sometimes have moving
" up-and-down issues when position algorithm selects is under fold.
function! scrollwrapped#scroll(nlines, backward) abort
  let motion = a:backward ? -1 : 1
  let leftcol = winsaveview()['leftcol']
  let scrolloff = &l:scrolloff
  call winrestview({'leftcol': 0})  " needed for algorithm
  let &l:scrolloff = 0
  if &l:wrap  " figure out new *top* line
    let [topline, scroll] = s:topline(a:nlines, a:backward)
  else  " wrapping disabled
    let [topline, scroll] = [s:nextline(line('w0'), motion * a:nlines), a:nlines]
  endif
  let wincol = wincol() - scrollwrapped#numberwidth() - scrollwrapped#signwidth()
  if &l:wrap  " figure out where to put cursor to match lines scrolled
    let [newline, newcol] = s:position(scroll, wincol, a:backward)
  else  " wrapping disabled
    let [newline, newcol] = [s:nextline(line('.'), motion * a:nlines), wincol]
  endif
  let view = {
    \ 'col': newcol - 1,
    \ 'lnum': newline,
    \ 'leftcol': leftcol,
    \ 'topline': max([topline, 0]),
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
