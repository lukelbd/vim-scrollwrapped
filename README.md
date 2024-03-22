Scrolling wrapped lines
=======================

When vim line wrapping is enabled with `:set wrap`, the default scrolling maps `<C-f>`,
`<C-b>`, `<C-d>`, and `<C-u>` may cause the cursor position relative to the window
to jump around erratically. This can be very disorienting when navigating documents.

The problem is that vim always scrolls by exact line counts. If line wrapping is
enabled, this requires changing the cursor position, since the first line shown in
the window must be the start of a wrapped line (i.e. not a line continuation fragment).

This plugin corrects this annoying behavior (see the below gif). Even with a tiny
window, the cursor line does not change during scrolling -- it only changes with
explicit motions (e.g. `j`, `k`). The new scrolling maps also work when line wrapping
is off and account for closed folds, tab widths, and multi-byte characters.

<img src="rec.gif" width="600">

Documentation
=============

By default, this plugin overwrites the full-page scrolling maps `<C-f>` and `<C-b>`,
the half-page scrolling maps `<C-d>` and `<C-u>`, and introduces new quarter-page
scrolling maps `<C-j>` and `<C-k>`. These scroll by as close as possible to the given
window height without changing the window-relative cursor line or cursor column. The
maps can be disabled with `let g:scrollwrapped_nomap = 0`, then applied
manually with `scrollwrapped#scroll` (see `plugin/scrollwrapped.vim`).

Use the `:WrapToggle` command to call `:set wrap scrolloff=0 colorcolumn=0` for the
current buffer. Using this command without arguments toggles the state, and using with `0`
arguments `1` or `0` turns wrapping on or off. This command also makes various motions
follow wrapped lines using buffer-local maps that swap `j`, `k`, `^`, `$`, `0`, `A`, and
`I` with `gj`, `gk`, `g^`, `g$`, `g0`, `gA`, and `gI` (respectively).

Use the `g:scrollwrapped_wrap_filetypes` variable to specify file types that should
have wrapping enabled by default (i.e., `:WrapToggle 1` is called when a corresponding
file is opened; default is `['bib', 'liquid', 'markdown', 'rst', 'tex']`). Use the
`:WrapHeights` and `:WrapStarts` commands to debug the scrolling behavior by printing
the wrapped line count and column starts detected by the scrolling algorithm (should
account for tab widths, fold/sign/number column widths, and multi-byte characters).

Installation
============

Install with your favorite [plugin manager](https://vi.stackexchange.com/q/388/8084).
I highly recommend the [vim-plug](https://github.com/junegunn/vim-plug) manager.
To install with vim-plug, add
```
Plug 'lukelbd/vim-scrollwrapped'
```
to your `~/.vimrc`.
