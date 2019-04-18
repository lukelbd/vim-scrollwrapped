"------------------------------------------------------------------------------"
" Name:   scrollwrapped.vim
" Author: Luke Davis (lukelbd@gmail.com)
" Date:   2018-09-03
"------------------------------------------------------------------------------"
"Distustingly over-engineered solution to scrolling wrapped lines in vim
"Note: vim forces us to always start at beginning of wrapped line, but don't
"necessarily have to end on one. So, scrolling is ***always controlled***
"by the lines near the top of the screen!
"Warning: Function may misbehave in special circumstances -- i.e. vim always
"coerces current topline to the next one if we try to put cursor on the bottom
"line when it runs off-screen. Not sure of robust way to fix this. Probably
"best to just let cursor get 'pushed' up the screen when this happens.
"Note: If cursor moves down screen instead of up the screen, some shit is wrong yo.
"------------------------------------------------------------------------------"
"Bindings
"------------------------------------------------------------------------------"
"Normal mode maps
"Arrow keys are for macbook Karabiner mapping
nnoremap <silent> <C-d>  :call <sid>scroll(winheight(0)/3,'d',1)<CR>
nnoremap <silent> <C-u>  :call <sid>scroll(winheight(0)/3,'u',1)<CR>
nnoremap <silent> <C-j>  :call <sid>scroll(winheight(0)/5,'d',1)<CR>
nnoremap <silent> <C-k>  :call <sid>scroll(winheight(0)/5,'u',1)<CR>
nnoremap <silent> <Down> :call <sid>scroll(winheight(0)/5,'d',1)<CR>
nnoremap <silent> <Up>   :call <sid>scroll(winheight(0)/5,'u',1)<CR>
"Closest reasonable thing for visual mode
vnoremap <silent> <expr> <C-d>  eval(winheight(0)/3).'<C-e>'.eval(winheight(0)/3).'gj'
vnoremap <silent> <expr> <C-u>  eval(winheight(0)/3).'<C-y>'.eval(winheight(0)/3).'gk'
vnoremap <silent> <expr> <C-j>  eval(winheight(0)/5).'<C-e>'.eval(winheight(0)/5).'gj'
vnoremap <silent> <expr> <C-k>  eval(winheight(0)/5).'<C-y>'.eval(winheight(0)/5).'gk'
vnoremap <silent> <expr> <Down> eval(winheight(0)/5).'<C-e>'.eval(winheight(0)/5).'gj'
vnoremap <silent> <expr> <Up>   eval(winheight(0)/5).'<C-y>'.eval(winheight(0)/5).'gk'

"------------------------------------------------------------------------------"
"Helper functions first
"------------------------------------------------------------------------------"
"Reverse a string
let s:tolerance=100
function! s:reverse(string)
  return join(reverse(split(a:string, '.\zs')), '')
endfunction
"This function has two purposes
" 1. Get the wrapped line height of given line.
" 2. Get a list of *actual* column numbers where *virtual* line breaks have
"    been placed by vim; numbers correspond to first char of each *virtual* col.
function! s:wrapped_line_props(mode,line)
  let verb=0
  if 'lc'!~a:mode
    echom "Error: Mode string must be either [l]ine or [c]ol."
    return -1
  endif
  "First figure out indents
  let string=getline(a:line)
  let width=winwidth(0)-(&l:nu || &l:rnu)*&l:numberwidth "exclude region for numbers
  if exists('&breakindent') && &l:breakindent
    let n_indent=max([0,match(string,'^ \+\zs')])
  else
    let n_indent=0
  endif
  "Iterate through pieces of string
  let offset=0
  let colnum=1
  let colstarts=[1]
  let lineheight=1
  let counter=0
  while len(string)+1>=width "must include newline character
    let counter+=1
    "Determine offset due to 'linebreak' feature
    "Note: This won't be perfect! Consecutive non-whitespace characters
    "in breakat seem to *prevent* breaking, for example. But close enough.
    "Note: Need to escape the dash or won't work sometimes (try searching [*-+])
    if &l:linebreak
      let test=s:reverse(string[0:width-1])
      let offset=match(test, '['.escape(&l:breakat,'-').']')
      " let offset=match(test, '['.&l:breakat.']\(\w\|\s\)') "breaks shit
    endif
    let colnum+=(width-offset-n_indent) "the *actual* column number at first position
    let colstarts+=[colnum] "add column to list
    let lineheight+=1 "increment line
    "Note since vim uses 0-indexing, position <width> is 1 char after end
    "Also make sure we trim leading spaces
    "NOTE: Older versions of Vim require math expressions within index
    "brackets surrounded by parentheses, or get weird error
    if verb
      echom 'width: '.width.' indent: '.n_indent.' string: '.(width-offset).' '.len(string)
    endif
    let string=repeat(' ',n_indent).substitute(string[(width-offset):],'^ \+','','')
    if counter==s:tolerance
      " echom "Warning: Could not determine line height."
      break
    endif
  endwhile
  return (a:mode=='l' ? lineheight : colstarts)
  " echom 'lineheight: '.lineheight
endfunction
command! LineHeight echom <sid>wrapped_line_props('l','.')
command! ColStarts echom join(<sid>wrapped_line_props('c','.'),', ')

"------------------------------------------------------------------------------"
"Next the driver function:
" * target is the number of lines
" * mode is whether to scroll down or up
" * move is whether to move cursor across lines when there is nothing
"   left to scroll, as with normal/builtin vim scrolling.
"------------------------------------------------------------------------------"
function! s:scroll(target,mode,move)
  "Initial stuff
  let verb=0
  let winline=winline()
  if 'ud'!~a:mode
    echom "Error: Mode string must be either [u]p or [d]own."
    return ''
  endif
  let scrolloff=&l:scrolloff
  let &l:scrolloff=0
  if a:mode=='u'
    let stopline=1
    let motion=-1
  else
    let stopline=line('$')
    let motion=+1
  endif
  "----------------------------------------------------------------------------"
  "Figure out the new *top* line
  "Will set this with winrestview
  "----------------------------------------------------------------------------"
  if &l:wrap
    "Determine new line iteratively
    let scrolled=0
    let topline_init=line('w0')
    let topline=(a:mode=='u' ? topline_init : topline_init-1) "initial
    let lineheight=s:wrapped_line_props('l',topline)
    let counter=0
    while scrolled<=a:target && topline!=stopline
      let counter+=1
      let topline+=motion
      let lineheight=s:wrapped_line_props('l',topline)
      let scrolled+=lineheight
      if lineheight==-1 "indicates error
        return ''
      endif
      if counter==s:tolerance
        " echom "Warning: Failed determining new line!"
        break
      endif
    endwhile
    let topline=(a:mode=='u' ? topline : topline+1)
    " if a:mode=='u' && line('w0')==1
    if topline==stopline
      let scrolled=a:target
    endif
    if verb
      echom 'old topline: '.line('w0').' new topline: '.topline.' visual motion: '.scrolled.' target: '.a:target
    endif
    "Optionally *backtrack*, if using the previous topline option would
    "have been a bit closer to 'n' lines. Re-enforces moving by at least one line.
    let options=[abs(scrolled-a:target),abs(scrolled-lineheight-a:target)]
    if index(options,min(options))==1 && topline_init!=(topline-motion)
      let scrolled-=lineheight
      let topline-=motion
      if verb
        echom 'backtracked; new topline: '.topline.' visual motion: '.scrolled
      endif
    endif
  else
    "If wrap not toggled, much simpler
    let topline=line('w0')
    let topline+=(motion*a:target)
    let scrolled=a:target "a:target is read-only variable, so re-assign
  endif
  "----------------------------------------------------------------------------"
  "Figure out how to correspondingly move *cursor* to match
  "the actual virtual lines scrolls, i.e. 'scrolled'
  "----------------------------------------------------------------------------"
  "Note numberwidth can be variable unless you set it manually to
  "something pretty big, possible bug there
  "WARNING: numberwidth will *lie* if you have more line numbers than it permits,
  "so you should instead test the number of lines directly
  let curline=line('.')
  let numberwidth=max([len(string(line('$')))+1, &l:numberwidth])
  let wincol=wincol()-numberwidth-1
  " let wincol=wincol()-&l:numberwidth-1
  if &l:wrap
    "Determine which wrapped line we are on, and therefore,
    "the number of window columns we *have* to traverse
    let curcol=col('.')
    let colstarts=s:wrapped_line_props('c',curline)
    let index=index(map(copy(colstarts), curcol.'>=v:val'), 0)
    let curline_height=len(colstarts)
    if index==-1 "cursor is sitting on the last virtual line of 'curline'
      let curline_offset=curline_height-1 "offset from first virtual line of current line
    elseif index==0 "should never happen -- would mean cursor is in column '0' because colstarts always starts with 1
      echom "Error: What the fudge." | return ''
    else
      let curline_offset=index-1
    endif
    if verb
      echom 'current line: '.curline.' virtual num: '.curline_offset.' colstarts: '.join(colstarts,', ')
    endif
    "--------------------------------------------------------------------------"
    "Determine the new cursorline, and offset down that line
    "Possible that the line at top of screen moves while the current much
    "bigger line does not, so account for that (if statement below)
    "The scroll_init will be the *required* visual lines scrolled if
    "we move the cursor line up or down
    if a:mode=='u'
      let scroll_init=curline_offset "how many virtual lines to the first one
    else
      let scroll_init=curline_height-curline_offset "how many virtual lines to start of next line (e.g. if height is 2, offset is 1, we're at the bottom; just scroll one more)
    endif
    if scrolled<(scroll_init+(a:mode=='u')) "see below for explanation
      "Case where we do not move lines
      " * If going up, scroll_init is distance to first virtual line of *this line*, so scroll_init
      "   *equal* to scrolled is acceptable (hence, increment RHS of inequality by 1)
      " * If going down, scroll_init is distance to first virtual line of *next line*, so need
      "   scroll_init to be 1 *more* than scrolled for us to be able to stay on current line.
      let curline_offset+=motion*scrolled
      if verb
        echom 'Not changing line.'
      endif
    else
      "Case where we do move lines
      "Idea is e.g. if we are on 2nd out of 4 visual lines, want to go to next one,
      "that represents a virtual scrolling of 2 lines at the start. Then scroll
      "by line heights until enough.
      let qline=curline
      let scroll=scroll_init
      let scrolled_cur=scroll_init "virtual to reach (up) first one on this line or (down) first one on next line
      while scrolled_cur<=scrolled
        let counter+=1
       "Determine line height
       "Note the init scroll brought us to (up) start of this line, so we want to query text above it,
       "or to (down) start of next line, so we want to query text on that next line
        if verb
          echom 'lineheight: '.lineheight.' scroll: '.scrolled_cur.' target: '.scrolled
        endif
        let qline+=motion "corresponds to (up) previous line or (down) this line.
        let lineheight=s:wrapped_line_props('l',qline) "necessary scroll to get to next/previous first line
        let scrolled_cur+=lineheight "add, then test
        if counter==s:tolerance
          " echom "Warning: Failed determining line height."
          break
        endif
      endwhile
      "Figure our remaining virtual lines to be scrolled
      "The scrolled-scrolled_cur just gives scrolling past *cursor line* virtual lines,
      "plus the lineheights
      let scrolled_cur-=lineheight "number of lines scrolled if we move up to first/last virtual line of curline
      let remainder=scrolled-scrolled_cur "number left
      if a:mode=='u'
        if remainder==0 "don't have to move to previous line at all
          let curline=qline+1
          let curline_offset=0
        else
          let curline=qline
          let curline_offset=lineheight-remainder "e.g. if remainder is 1, lineheight is 3, want curline 'offset' to be 2
        endif
      else
        let curline=qline
        let curline_offset=remainder "minimum remainder is 1
      endif
      if verb
        let lineheight=s:wrapped_line_props('l',curline)
        echom 'destination line: '.curline.' remainder: '.remainder.' destination height: '.lineheight.' offset: '.curline_offset
      endif
    endif
    "--------------------------------------------------------------------------"
    "Get the column number for winrestview
    "The min() call is to avoid errors that crop up due to those brute-force
    "while-loop breaks above when tolerance is exceeded
    let colstarts=s:wrapped_line_props('c',curline)
    if verb
      echom 'Length of colstarts vs. requested offset: '.len(colstarts).' '.curline_offset
    endif
    let idx=max([min([curline_offset,len(colstarts)-1]),0])
    let curcol=wincol+colstarts[idx]-1
    if verb
      echom 'destination colnum: '.curcol.' colstarts: '.join(colstarts, ', ')
    endif
  else
    "If wrap not toggled, much simpler
    if a:mode=='u'
      let curline-=a:target
    else
      let curline+=a:target
    endif
    let curcol=wincol
  endif
  "----------------------------------------------------------------------------"
  "Finally restore to the new column
  "----------------------------------------------------------------------------"
  call winrestview({'topline':max([topline,0]), 'lnum':curline, 'leftcol':0, 'col':curcol})
  let &l:scrolloff=scrolloff
  if verb
    echom 'WinLine: '.winline.' to '.winline()
  endif
  return ''
endfunction

