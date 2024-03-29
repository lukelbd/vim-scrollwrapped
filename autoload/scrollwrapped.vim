"-----------------------------------------------------------------------------
" Functions for scrolling in presence of wrapped lines
"-----------------------------------------------------------------------------
" Return string parts accounting for display width
" Note: This includes both expanded tab characters and multi-byte characters. Would
" use e.g. strdisplaypart() function like strcharpart() but does not exist.
scriptencoding utf-8
function! s:getparts(str, start, width, ...) abort
  let size = a:width
  let part1 = strcharpart(a:str, a:start, a:width)
  let part2 = strcharpart(a:str, a:start + a:width)
  while size && strdisplaywidth(part1) > a:width  " e.g. tab characters
    let size = size - 1
    let [part1, part2] = [strcharpart(a:str, 0, size), strcharpart(a:str, size) . part2]
  endwhile
  return [part1, part2]
endfunction

" Return the next line accounting for closed folds
" Note: Could include this as part of 'lineheight' but then folded lines would
" count toward the number of scrolled lines, which we do not want.
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
  return max([min([line, line('$')]), 1])
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
  let lineheight = len(scrollwrapped#starts(topline))
  while scrolled <= a:nlines && topline != stopline
    let topline = s:nextline(topline, a:backward ? -1 : 1)
    let lineheight = len(scrollwrapped#starts(topline))
    let scrolled += lineheight
    let counter += 1
    if counter == g:scrollwrapped_tolerance
      echohl WarningMsg
      echom 'Warning: Failed to determine the new top window line.'
      echohl None | break
    endif
  endwhile
  let topline = a:backward ? topline : min([topline + 1, line('$')])
  let scrolled = topline == stopline ? a:nlines : scrolled  " move by at least one
  let topline_back = s:nextline(topline, a:backward ? 1 : -1)
  if topline_init != topline_back && abs(scrolled - lineheight - a:nlines) < abs(scrolled - a:nlines)
    let topline = topline_back
    let scrolled -= lineheight
  endif
  let topline = max([topline, 1])
  return [topline, scrolled]
endfunction

" Position the cursor after scrolling input lines, accounting for input window columns.
" Determines which number of window columns required to traverse before scrolling.
function! s:position(nlines, backward) abort
  " Initial stuff and line properties
  let curline = line('.')
  let curcol = col('.')
  let curstarts = scrollwrapped#starts(curline)
  let curline_height = len(curstarts)
  let curidx = index(map(copy(curstarts), curcol . ' >= v:val'), 0)
  if curidx == -1  " cursor is sitting on the last wrapped line of 'curline'
    let curline_offset = curline_height - 1  " offset from first wrapped line
  elseif curidx > 0
    let curline_offset = curidx - 1
  endif
  " Determine new cursorline, and offset down that line. Possible that line at top
  " of screen moves while the current much bigger line does not so account for that.
  if a:backward
    let scroll_line = curline_offset  " wrapped lines to the first one
  else
    let scroll_line = curline_height - curline_offset  " wrapped lines to start of next
  endif
  " Going up, scroll_line is distance to first wrapped line of this line, so a:nlines
  " == scroll_line satisfies this. Going down this is distance to next line.
  if a:nlines < scroll_line + a:backward  " stay on same line
    let [newline, newline_offset] = [curline, a:nlines * (a:backward ? -1 : 1)]
  else  " going to different line
    let [newline, newline_offset] = s:scroll(a:nlines, a:backward, scroll_line)
  endif
  " Get the column number for winrestview. The min() call avoids errors that crop up
  " due to the brute-force while-loop breaks above when tolerance is exceeded.
  let newstarts = scrollwrapped#starts(newline)
  let newidx = max([min([newline_offset, len(newstarts) - 1]), 0])
  return [newline, newstarts[newidx]]
endfunction

" Scroll first across the current partial line, then across line heights of
" other wrapped lines. Example: If we are on 2nd out of 4 visual lines, want to go
" to next one. This represents wrapped scrolling of 2 lines at start.
function! s:scroll(nlines, backward, scroll) abort
  " Determine line height. Note the init scroll brought us to (up) start of this
  " line, so query text above it, or (down) start of next line, so query enxt line
  let curline = line('.')
  let scrolled = a:scroll
  let counter = 0
  while scrolled <= a:nlines
    let curline = s:nextline(curline, a:backward ? -1 : 1)
    let counter += 1
    let lineheight = len(scrollwrapped#starts(curline))
    let scrolled += lineheight  " get to next/previous first line
    if counter == g:scrollwrapped_tolerance
      break
    endif
  endwhile
  " Figure our remaining wrapped lines to be scrolled. The a:nlines - scrolled
  " just gives scrolling past *cursor line* wrapped lines, plus the lineheights.
  let prevline = curline  " see below
  let scrolled -= lineheight  " after moving to first/last wrapped line
  let remainder = a:nlines - scrolled  " number left
  if a:backward  " e.g. if remainder == 1, lineheight == 3, 'offset' should be 2
    let curline = remainder ? curline : min([curline + 1, line('$')])
    let curline_offset = curline == prevline ? lineheight - remainder : 0
  else
    let curline = curline
    let curline_offset = remainder  " minimum remainder is 1
  endif
  return [curline, curline_offset]
endfunction

" Helper functions
" Note: The numberwidth will *lie* if you have more line numbers than
" it permits, so must instead test the number of lines directly.
function! scrollwrapped#reverse(string) abort  " reverse the lines
  let result = reverse(split(a:string, '\zs'))
  return join(result, '')
endfunction
function! scrollwrapped#numberwidth() abort
  let width = max([len(string(line('$'))) + 1, &l:numberwidth])
  return &l:number || &l:relativenumber ? width : 0
endfunction
function! scrollwrapped#signwidth() abort
  return &l:foldcolumn + (&l:signcolumn ==# 'yes' || &l:signcolumn ==# 'auto'
    \ && !empty(sign_getplaced(bufnr(), {'group': '*'})[0]['signs']) ? 2 : 0)
endfunction

" Helper function to return wrapped line height or columns where line is broken
" Todo: Consider using screenpos(winnr, line, col) and iterating over all columns.
" Note: Vim will never start a wrapped line with a break character, but will start
" lines with an end-of-line character for lines exactly matching window width.
function! scrollwrapped#starts(line) abort
  let width = winwidth(0) - scrollwrapped#numberwidth() - scrollwrapped#signwidth()
  let string = getline(a:line) . "\n"  " include end-of-line newline
  let indent = exists('&breakindent') && &l:breakindent ? matchstr(string, '^\s*') : ''
  let breaks = '[' . escape(&l:breakat, '-') . ']\+'
  let counter = 0
  let colstarts = [0]
  while strdisplaywidth(string) > width
    if counter == g:scrollwrapped_tolerance
      break
    endif
    let [part1, part2] = s:getparts(string, 0, width)
    if &l:linebreak && matchstr(part1, '.$') !=# "\n"
      let ipart = scrollwrapped#reverse(part1)
      let ibreak = strgetchar(ipart, 0) =~# breaks  " never start with &breakat
      let offset = match(ipart, breaks, 0, 1 + ibreak)  " first or second match
      let [part1, part2] = offset > 0 ? s:getparts(string, 0, width - offset) : [part1, part2]
    endif
    " vint: -ProhibitUsingUndeclaredVariable ·
    let nignore = counter ? strcharlen(indent) : 0  " exclude indent indent
    let nbreak = strcharlen(part1)  " use setcharpos() afterward
    let string = indent . part2  " next part to search
    let counter += 1  " increase counter
    let colstart = colstarts[-1] + nbreak - nignore + 1
    call add(colstarts, colstart)
    " echom 'Part ' . counter . ': ' . substitute(string[:width], ' ', '·', 'g')
  endwhile
  return colstarts
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
    let [topline, scroll] = [s:nextline(line('w0'), motion * a:nlines), motion * a:nlines]
  endif
  if &l:wrap  " figure out where to put cursor to match lines scrolled
    let [newline, newstart] = s:position(scroll, a:backward)
  else  " wrapping disabled
    let [newline, newstart] = [s:nextline(line('.'), scroll), 0]
  endif
  if foldclosed(line('.')) > 0
    let newcol = getcursorcharpos()[2]
  else  " infer column from getparts 
    let curcol = wincol() - scrollwrapped#numberwidth() - scrollwrapped#signwidth()
    let newstr = s:getparts(getline(newline), newstart, curcol)[0]
    let newcol = curcol - (curcol - strcharlen(newstr))
  endif
  call winrestview({'lnum': newline, 'leftcol': leftcol, 'topline': topline})
  call setcursorcharpos(newline, newstart + newcol)
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
      let map = key =~# '[AI]$' ? 'nnoremap' : 'noremap'
      exe map . ' <buffer> ' . key . ' ' . val
    endfor
    if !suppress
      echom 'Line wrapping enabled.'
    endif
  else
    let &l:wrap = 0
    let &l:colorcolumn = &g:colorcolumn
    let &l:scrolloff = &g:scrolloff
    for key in keys(scrollwrapped_maps)
      let unmap = key =~# '[AI]$' ? 'nunmap' : 'unmap'
      silent! exe unmap . ' <buffer> ' . key
    endfor
    if !suppress
      echom 'Line wrapping disabled.'
    endif
  endif
endfunction
