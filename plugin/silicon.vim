" vim: et sw=2 sts=2

" Plugin:      https://github.com/segeljakt/vim-silicon
" Description: Create beautiful images of your source code.
" Maintainer:  Klas Segeljakt <http://github.com/segeljakt>

if empty(executable('silicon'))
  echoe 'vim-silicon requires `silicon` to be installed.'
      \ 'Please refer to the installation instructions in the README.md.'
  finish
en

" Helpers

fun! s:conf(name, dict)
  if empty(exists(name))
    let {name} = a:dict
  el
    for [key, val] in items(a:dict)
      if empty(has_key({name}, key))
        let {name}[key] = val
      en
    endfor
  en
endfun

" Definitions

call s:conf('g:silicon', {
\   'theme':                'Dracula',
\   'font':                    'Hack',
\   'background':           '#aaaaff',
\   'shadow-color':         '#555555',
\   'line-pad':                     2,
\   'pad-horiz':                   80,
\   'pad-vert':                   100,
\   'shadow-blur-radius':           0,
\   'shadow-offset-x':              0,
\   'shadow-offset-y':              0,
\   'no-line-number':         v:false,
\   'no-round-corner':        v:false,
\   'no-window-controls':     v:false,
\ })

com!
  \ -range=%
  \ -nargs=?
  \ -complete=dir
  \ Silicon call silicon#generate(<line1>, <line2>, <f-args>)

com!
  \ -range
  \ -nargs=?
  \ -complete=dir
  \ SiliconHighlight call silicon#generate_highlighted(<line1>, <line2>, <f-args>)
