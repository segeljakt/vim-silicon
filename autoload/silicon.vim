" vim: et sw=2 sts=2

" Plugin:      https://github.com/segeljakt/vim-silicon
" Description: Create beautiful images of your source code.
" Maintainer:  Klas Segeljakt <http://github.com/segeljakt>

if exists('s:autoloaded')
  finish
el
  let s:autoloaded = v:true
en

" Plugin-independent Helpers

" Mapping from type-number to type-name
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

" First, check that silicon is installed. Then, check for unexpected keys and
" type mismatches in a:config, using a:default as reference. If any are found,
" an exception is thrown.
fun! s:validate(config, default)
  if empty(executable('silicon'))
    throw 'vim-silicon requires `silicon` to be installed. '
          \ .'Please refer to the installation instructions in the README.md.'
  en
  let errors = []
  for [key, val] in items(a:config)
    if !has_key(a:default, key)
      let errors += ['Unexpected key '.string(key)]
    el
      let default_val = a:default[key]
      let found = type(val)
      let expected = type(default_val)
      if found != expected
        let errors += [
              \ 'Type mismatch in key '.string(key)
              \ .', found '.string(s:typename[found])
              \ .', expected '.string(s:typename[expected])
              \ .', e.g. '.string(default_val)
              \ ]
      en
    en
  endfor
  if !empty(errors)
    throw join(errors, "\n  - ")
  en
endfun

" Creates/derives a configuration based on a default configuration
fun! s:configure(name, default)
  if !exists(a:name)
    let {a:name} = a:default
  el
    let config = {a:name}
    for [key, val] in items(a:default)
      if !has_key(config, key)
        let config[key] = val
      en
    endfor
  en
endfun

" Default configuration
let s:default = {
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
      \ }

call s:configure('g:silicon', s:default)

" Silicon bindings
fun! s:cmd(argc, argv)
  let cmd = ['silicon']
  " Output method
  if a:argc == 0
    if empty(executable('xclip'))
      throw 'Copying to clipboard is only supported on Linux with xclip installed. '
            \ .'Please specify a path instead.'
    el
      let cmd += ['--to-clipboard']
    en
  el
    let path = a:argv[0]
    if !empty(fnamemodify(path, ':e'))
      let cmd += ['--output', path]
    el
      let cmd += ['--output', path.'.png']
    en
  en
  " Language
  if !empty(&ft)
    let cmd += ['--language', &ft]
  el
    let ext = expand('%:e')
    if !empty(ext)
      let cmd += ['--language', ext]
    el
      let cmd += ['--language', 'txt']
    en
  en
  " Configuration
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

" Exposed API
fun! silicon#generate(line1, line2, ...)
  try
    if mode() != 'n' && visualmode() != 'V'
      throw 'Command can only be called from Normal or Visual Line mode.'
    en
    call s:validate(g:silicon, s:default)
    let cmd = s:cmd(a:0, a:000)
    let lines = join(getline(a:line1, a:line2), "\n")
    call s:dispatch(cmd, lines)
    echo '[Silicon - Success]: Image Generated'
  catch
    echohl ErrorMsg | echo "[Silicon - Error]:\n  - ".v:exception | echohl None
  endtry
endfun

fun! silicon#generate_highlighted(line1, line2, ...)
  try
    if visualmode() != 'V'
      throw 'Command can only be called from Visual Line mode.'
    en
    call s:validate(g:silicon, s:default)
    let cmd = s:cmd(a:0, a:000)
    let cmd += ['--highlight-lines', a:line1.'-'.a:line2]
    let lines = join(getline('1', '$'), "\n")
    call s:dispatch(cmd, lines)
    echo '[Silicon - Success]: Highlighted Image Generated'
  catch
    echohl ErrorMsg | echo "[Silicon - Error]:\n  - ".v:exception | echohl None
  endtry
endfun

