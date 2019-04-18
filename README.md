# Plugin for scrolling wrapped lines
This plugin was designed to help me
edit LaTeX, markdown, and other such non-programmatic
documents with heavily wrapped lines.

In the presence of wrapped lines, default VIM scrolling with `<C-d>` and
`<C-u>` causes the cursor to jump around erratically, which is extremely disorienting
when navigating documents. The fundamental problem is that VIM tries to
jump by a number of lines equaling **exactly** one-half page height
-- but because the first line in the viewer
is constrained to always be the **start** of a line, not a line continuation
fragment, this is often causes the line on which the **cursor** is positioned
to get yanked up-and-down the screen as you scroll.

With this plugin, the half-page scrolling commands `<C-d>` and `<C-u>`
are overridden so that, instead of scrolling by **exactly**
one-half page height, we scroll by **as close as possible** to one page height
without messing up the relative cursor line position.
This plugin also introduces new quarter-page scrolling commands
`<C-j>` and `<C-k>` are also introduced.