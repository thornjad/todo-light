# todo-light - highlight TODO and similar keywords

_Author:_ Jade Michael Thornton<br>
_Version:_ 1.2.0<br>

Highlight TODO and similar keywords in comments and strings.

You can either turn on `todo-light-mode` in individual buffers or use the the
global variant `global-todo-light-mode`. Note that the option
`todo-light-activate-in-modes` controls in what buffers the local mode will be
activated if you do the latter. By default it will only be activated in
buffers whose major-mode derives from `prog-mode`.

This package also provides commands for moving to the next or previous
keyword, to invoke `occur` with a regexp that matches all known keywords, and
to insert a keyword. If you want to use these commands, then you should bind
them in `todo-light-mode-map`

todo-light is forked from hl-todo by Jonas Bernoulli to make some needed
improvements.


---
Converted from `todo-light.el` by [_el2md_](https://gitlab.com/thornjad/el2md).
