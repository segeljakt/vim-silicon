" vim: et sw=2 sts=2

" Plugin:      https://github.com/segeljakt/vim-silicon
" Description: Create beautiful images of your source code.
" Maintainer:  Klas Segeljakt <http://github.com/segeljakt>

if exists('s:autoloaded')
  finish
el
  let s:autoloaded = v:true
en

" Configure

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

" Defaults

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

" Logic

fun! s:cmd(argc, argv)
  let cmd = ['silicon']
  if a:argc == 0
    if empty(has('linux'))
      echoerr 'Copying to clipboard with Silicon is only supported on Linux'
    el
      let cmd += ['--to-clipboard']
    en
  el
    let path = a:argv[0]
    if empty(fnamemodify(path, ':e'))
      let cmd += ['--output', path.'.png']
    el
      let cmd += ['--output', path]
    en
  en
  let cmd += ['--language', &ft]
  for [key, val] in items(g:silicon)
    if type(val) == type(v:false)
      if val == v:false
        let cmd += ['--no-'.key]
      en
    el
      let cmd += ['--'.key, val]
    en
  endfor
  return cmd
endfun

if has('nvim')
  fun! s:dispatch(cmd, lines)
    let id = jobstart(a:cmd)
    call chansend(id, a:lines)
    call chanclose(id)
  endfun
el
  fun! s:dispatch(cmd, lines)
    let id = job_start(a:cmd)
    call ch_sendraw(id, a:lines)
    call ch_close(id)
  endfun
en

fun! silicon#generate(line1, line2, ...)
  let lines = join(getline(a:line1, a:line2), "\n")
  let cmd = s:cmd(a:0, a:000)
  call s:dispatch(cmd, lines)
endfun

fun! silicon#generate_highlighted(line1, line2, ...)
  let lines = join(getline('1', '$'), "\n")
  let cmd = s:cmd(a:0, a:000)
  let cmd += ['--highlight-lines', a:line1.'-'.(a:line2+1)]
  call s:dispatch(cmd, lines)
endfun
