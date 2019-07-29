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

let s:typename = {
      \ 0: 'number',
      \ 1: 'string',
      \ 2: 'func',
      \ 3: 'list',
      \ 4: 'dict',
      \ 5: 'float',
      \ 6: 'boolean',
      \ 7: 'null',
      \ }

fun! s:check(config, default)
  let errors = []
  for [key, val] in items(a:config)
    if has_key(a:default, key)
      let found = type(val)
      let expected = type(a:default[key])
      if found != expected
        let errors += ['Type mismatch for key '.string(key)
              \ .', found '.string(s:typename[found])
              \ .', expected '.string(s:typename[expected])]
      en
    el
      let errors += ['Unexpected key '.string(key)]
    en
  endfor
  return errors
endfun

fun! s:configure(name, default)
  if empty(exists(a:name))
    let {a:name} = a:default
  el
    let config = {a:name}
    let errors = s:check(config, a:default)
    if !empty(errors)
      echohl ErrorMsg
      echo "[Silicon Error]: \n  - ".join(errors, "\n  - ")
      echo "\n... Rolling back to default config."
      echohl None
      let {a:name} = a:default
    el
      " Defaults
      for [key, val] in items(a:default)
        if empty(has_key(config, key))
          let config[key] = val
        en
      endfor
    en
  en
endfun

" Definitions

call s:configure('g:silicon', {
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
\   'line-number':             v:true,
\   'round-corner':            v:true,
\   'window-controls':         v:true,
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
