Scrolling wrapped lines
=======================

In the presence of wrapped lines, the default scrolling commands `<C-f>`, `<C-b>`,
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

<!-- ![](rec.gif) -->
<img src="rec.gif" width="600">

Documentation
=============

This plugin overrides the default scrolling commands and `<C-f>`, `<C-b>`, `<C-d>`, and
`<C-u>`, and introduces new quarter page scrolling commands `<C-j>` and `<C-k>`. For
each of these mappings, the plugin scrolls by as close as possible to one, one half, or
one quarter of the window height without messing up the relative cursor line position.

`:WrapToggle` toggles line wrapping for the current buffer. Call this without arguments
to toggle the wrapping mode on and off, or with `1` or `0` to set the wrapping mode to
the on or off states. This also applies a series of buffer local normal mode mappings so
that motion keys follow the *wrapped lines* instead of the actual lines. That is, the
`j`, `k`, `^`, `$`, `0`, `A`, and `I` commands are swapped with the `gj`, `gk`, `g^`,
`g$`, `g0`, `gA`, and `gI` commands.

`g:scrollwrapped_wrap_filetypes` specifies the filetypes for which `:WrapToggle` is
called automatically when the file is opened. By default, this is
`['bib', 'tex', 'markdown', 'rst', 'liquid']`.

Installation
============

Install with your favorite [plugin manager](https://vi.stackexchange.com/q/388/8084).
I highly recommend the [vim-plug](https://github.com/junegunn/vim-plug) manager.
To install with vim-plug, add
```
Plug 'lukelbd/vim-scrollwrapped'
```
to your `~/.vimrc`.
