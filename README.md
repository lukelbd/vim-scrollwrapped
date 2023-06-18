Scrolling wrapped lines
=======================

In the presence of wrapped lines, the default vim scrolling commands `<C-f>`, `<C-b>`,
`<C-d>`, and `<C-u>` can cause the cursor position relative to the window to jump around
erratically. This is extremely disorienting when navigating documents.

The fundamental problem is that vim tries to jump by exact numbers of lines -- but
because the first line in the viewer is constrained to always be the start of a line,
not a line continuation fragment, this often causes the window relative cursor line to
change.

This plugin corrects this annoying behavior (see the below gif). Even with a tiny
window, the cursor does not move up and down during scrolling. It only moves when the
cursor line is adjusted `j` and `k`. Although the cursor sometimes jumps from left to
right, owing to vim trying to preserve the column position with scrolling, this is a
vast improvement on the default vim scrolling behavior.

<img src="rec.gif" width="600">

Documentation
=============

By default, this plugin overrides the default scrolling commands and `<C-f>`, `<C-b>`,
`<C-d>`, and `<C-u>`, and introduces new quarter page scrolling commands `<C-j>` and
`<C-k>` (use `let g:scrollwrapped_nomap = 0` to disable these default mappings). These
scroll by as close as possible to one, one half, or one quarter of the window
height without changing the cursor position relative to the window.

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
