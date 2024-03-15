Scrolling wrapped lines
=======================

After enabling vim line wrapping with `:set wrap`, the default scrolling commands
`<C-f>`, `<C-b>`, `<C-d>`, and `<C-u>` can cause the cursor position relative to the
window to jump around erratically. This is very disorienting when navigating documents.

The problem is that vim always tries to scroll by exact line counts, but since the
first line of the window must be the start of a wrapped line (i.e. not a line
continuation fragment), scrolling often changes the window-relative cursor line.

This plugin corrects this annoying behavior (see the below gif). Even with a tiny
window, the cursor does not move up and down during scrolling. It only moves when
explicitly adjusting the cursor line with `j` and `k`. Although the cursor sometimes
jumps horizontally, owing to vim trying to preserve the relative column position, this
is a vast improvement on the default vim scrolling behavior.

<img src="rec.gif" width="600">

Documentation
=============

This plugin overrides the default full-page scrolling maps `<C-f>` and `<C-b>`,
half-page scrolling maps `<C-d>` and `<C-u>`, and introduces new quarter-page scrolling
maps `<C-j>` and `<C-k>` (use `let g:scrollwrapped_nomap = 0` to disable these maps).
The mappings scroll by as close as possible to one, one half, or one quarter of the
window height without changing the window-relative cursor position.

The `:WrapToggle` command toggles the `&wrap` setting along with the `&colorcolumn` and
`&scrolloff` settings for the current buffer. Use without arguments to toggle on and
off or with `0` or `1` to set the state. This command also applies a series of buffer
local normal mode mappings so that motion keys follow *wrapped lines* (that is, `j`, `k`,
`^`, `$`, `0`, `A`, and `I` are swapped with `gj`, `gk`, `g^`, `g$`, `g0`, `gA`, and `gI`).

The `g:scrollwrapped_wrap_filetypes` option specifies the filetypes that should
have wrapping enabled by default. This will call `:WrapToggle 1` whenever the file
is opened. By default, this is `['bib', 'liquid', 'markdown', 'rst', 'tex']`.

Installation
============

Install with your favorite [plugin manager](https://vi.stackexchange.com/q/388/8084).
I highly recommend the [vim-plug](https://github.com/junegunn/vim-plug) manager.
To install with vim-plug, add
```
Plug 'lukelbd/vim-scrollwrapped'
```
to your `~/.vimrc`.
