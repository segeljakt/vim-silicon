" vim: et sw=2 sts=2

" Plugin:      https://github.com/segeljakt/vim-silicon
" Description: Create beautiful images of your source code.
" Maintainer:  Klas Segeljakt <http://github.com/segeljakt>

if exists('s:autoloaded') | finish | el | let s:autoloaded = v:true | en

" Plugin-independent Helpers

" Mapping from type-number to type-name
let s:typename = [
      \ 'number',
      \ 'string',
      \ 'func',
      \ 'list',
      \ 'dict',
      \ 'float',
      \ 'boolean',
      \ 'null',
      \ ]

" Job-dispatch
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
    let sep = "\n  - "
    throw sep + join(errors, sep)
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
let s:default_cmd = {
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

let s:default_vim = {
      \   'default-file-pattern':        '',
      \ }

let s:default = extend(copy(s:default_cmd), s:default_vim)

call s:configure('g:silicon', s:default)

" Silicon bindings
fun! s:cmd(argc, argv)
  return ['silicon']
        \ + s:cmd_output(a:argc, a:argv)
        \ + s:cmd_language(a:argc, a:argv)
        \ + s:cmd_config(a:argc, a:argv)
endfun

fun! s:cmd_output(argc, argv)
  if a:argc > 0
    return ['--output', s:cmd_output_path(a:argc, a:argv)]
  elseif !empty(g:silicon['default-file-pattern'])
    return ['--output', s:cmd_output_pattern(a:argc, a:argv)]
  elseif !empty(executable('xclip'))
    return ['--to-clipboard']
  el
    throw 'Copying to clipboard is only supported on Linux with xclip installed. '
          \ .'Please specify a path instead.'
  en
endfun

fun! s:set_extension(path)
  if !empty(fnamemodify(a:path, ':e'))
    return a:path
  el
    return a:path.'.png'
  en
endfun

fun! s:cmd_output_pattern(argc, argv)
  let path = g:silicon['default-file-pattern']
  let path = substitute(path, '{time:\(.\{-}\)}', {match -> strftime(match[1])}, 'g')
  let path = substitute(path, '{file:\(.\{-}\)}', {match -> expand(match[1])}, 'g')
  let path = fnamemodify(path, ':p')
  return s:set_extension(path)
endfun

fun! s:cmd_output_path(argc, argv)
  let path = expand(a:argv[0])
  if isdirectory(path)                         " /path/to/
    let filename = expand('%:t:r')
    if !empty(filename)                        " Named source file
      return path.'/'.filename.'.png'
    el                                         " Unnamed source file
      let date = strftime('%Y-%m-%d_%H-%M-%S')
      return path.'/silicon_'.date.'.png'
    en
  el
    return s:set_extension(path)               " /path/to/img.png
  en
endfun

fun! s:cmd_language(argc, argv)
  if !empty(&ft)
    return ['--language', &ft]
  el
    let ext = expand('%:e')
    if !empty(ext)
      return ['--language', ext]
    el
      return ['--language', 'txt']
    en
  en
endfun

fun! s:cmd_config(argc, argv)
  let flags = []
  for [key, val] in items(g:silicon)
    if has_key(s:default_cmd, key)
      if type(val) == type(v:false)
        if val == v:false
          let flags += ['--no-'.key]
        en
      el
        let flags += ['--'.key, val]
      en
    en
  endfor
  return flags
endfun

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
    let v:errmsg = '[Silicon - Error]: '.v:exception
    echohl ErrorMsg | echo v:errmsg | echohl None
  endtry
endfun

fun! silicon#generate_highlighted(line1, line2, ...)
  try
    if visualmode() != 'V'
      throw 'Command can only be called from Visual Line mode.'
    en
    call s:validate(g:silicon, s:default)
    let cmd = s:cmd(a:0, a:000)
          \ + ['--highlight-lines', a:line1.'-'.a:line2]
    let lines = join(getline('1', '$'), "\n")
    call s:dispatch(cmd, lines)
    echo '[Silicon - Success]: Highlighted Image Generated'
  catch
    let v:errmsg = '[Silicon - Error]: '.v:exception
    echohl ErrorMsg | echo v:errmsg | echohl None
  endtry
endfun

" Completions

" All possible flags that can be completed
fun s:all_flags()
  let s:all_flags = {}
  for [key, val] in items(s:default)
    let s:all_flags['--'.key] = val
  endfor
  return s:all_flags
endfun

" Current flags that have been completed
fun! s:entered_flags(cmdline)
  let entered_flags = {}
  let entered_path = ''
  for arg in split(a:cmdline)[1:]
    let flag = matchstr(arg, '^--[a-z\-]\+')
    if !empty(flag)
      let entered_flags[flag] = v:null
    elseif arg !~ '^-'
      let entered_path = arg
    en
  endfor
  return [entered_flags, entered_path]
endfun

" Remaining flags to-be completed
fun! s:remaining_flags(all_flags, entered_flags)
  let remaining_flags = copy(a:all_flags)
  for entered_flag in keys(a:entered_flags)
    if has_key(remaining_flags, entered_flag)
      call remove(remaining_flags, entered_flag)
    en
  endfor
  return remaining_flags
endfun

fun! silicon#complete(arglead, cmdline, cursorpos)
  let all_flags = s:all_flags()
  let [entered_flags, entered_path] = s:entered_flags(a:cmdline)
  let remaining_flags = s:remaining_flags(all_flags, entered_flags)
  " Completely-entered config flag, e.g. --theme=GitHub, do nothing
  if a:arglead =~ '^--[a-z\-]\+='
    return [a:arglead]
  en
  " Partially-entered config flag, e.g. --th, complete it
  let partial_flag = matchstr(a:arglead, '^--[a-z\-]\+$')
  if !empty(partial_flag)
    return values(map(filter(remaining_flags, {flag, type -> flag =~ partial_flag}),
          \ {flag, val -> flag.'='.string(val)}))
  en
  " File path, complete either when
  "   A) No flags have been entered, or
  "   B) When the path is the current arg
  if a:arglead == entered_path
    return getcompletion(a:arglead, 'dir')
  en
  " Default case, complete remaining flags
  return values(map(remaining_flags, {flag, val -> flag.'='.string(val)}))
endfun
