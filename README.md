# Scroll wrapped lines
This plugin was designed to help me
edit LaTeX, markdown, and other such non-programmatic
documents with heavily wrapped lines.

In the presence of wrapped lines, the default scrolling maps `<C-d>` and
`<C-u>` can cause
the cursor to jump around erratically. This is extremely disorienting
when navigating documents.
The fundamental problem is that VIM tries to
jump by a number of lines equaling exactly one-half page height
-- but because the first line in the viewer
is constrained to always be the start of a line, not a line continuation
fragment, this often causes the line on which the **cursor** is positioned
to get yanked up-and-down the screen.

This plugin corrects this annoying behavior.

## Normal mode maps
This plugin overrides the half-page scrolling maps `<C-d>` and `<C-u>` and
introduces new quarter-page scrolling maps `<C-j>` and `<C-k>`.

For each of these maps, instead of scrolling by exactly
one-half or one-quarter the window height, the plugin scrolls
by as close as possible to one-half or one-quarter
the window height **without messing up the relative cursor line position**.

# Installation
Install with your favorite [plugin manager](https://vi.stackexchange.com/questions/388/what-is-the-difference-between-the-vim-plugin-managers).
I highly recommend the [`vim-plug`](https://github.com/junegunn/vim-plug) manager,
in which case you can install this plugin by adding
```
Plug 'lukelbd/vim-scrollwrapped'
```
to your `.vimrc`.

