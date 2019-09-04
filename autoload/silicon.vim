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

fun! s:on_stdout(chan_id, data, name)
"   echomsg 'stdout: '.string([a:chan_id, a:data, a:name])
endfun

fun! s:on_stderr(chan_id, data, name)
"   echomsg 'stderr: '.string([a:chan_id, a:data, a:name])
endfun

fun! s:on_exit(chan_id, data, name)
"   echomsg 'exit: '.string([a:chan_id, a:data, a:name])
endfun

fun! s:on_data(chan_id, data, name)
"   echomsg 'data: '.string([a:chan_id, a:data, a:name])
endfun

let s:job_options = {
          \ "on_stdout": function("s:on_stdout"),
          \ "on_stderr": function("s:on_stderr"),
          \ "on_exit":   function("s:on_exit"),
          \ "on_data":   function("s:on_data"),
          \ }

" Job-dispatch
if has('nvim')
  fun! s:dispatch(cmd, lines)
    let id = jobstart(a:cmd, s:job_options)
    call chansend(id, a:lines)
    call chanclose(id)
  endfun
el
  fun! s:dispatch(cmd, lines)
    let id = job_start(a:cmd, s:job_options)
    call ch_sendraw(id, a:lines)
    call ch_close(id)
  endfun
en

" First, check that silicon is installed. Then, check for unexpected keys and
" type mismatches in a:config, using a:default as reference. If any are found,
" an exception is thrown.
fun! s:validate(config, spec)
  if empty(executable('silicon'))
    throw 'vim-silicon requires `silicon` to be installed. '
          \ .'Please refer to the installation instructions in the README.md.'
  en
  let errors = []
  for [key, val] in items(a:config)
    if !has_key(a:spec, key)
      let errors += ['Unexpected key '.string(key)]
    el
      let default_val = a:spec[key][s:default]
      let [found, expected] = [type(val), type(default_val)]
      if found != expected
        let errors += [
              \ 'Type mismatch for key '.string(key)
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

" Creates/derives a configuration based on the internal config specification
fun! s:configure(name, spec)
  if !exists(a:name)
    let {a:name} = map(a:spec, "v:val[s:default]")
  el
    let config = {a:name}
    for [key, val] in items(a:spec)
      if !has_key(config, key) && val[s:default] != v:null
        let config[key] = val[s:default]
      en
    endfor
  en
endfun

" Possible completions for themes
fun! s:themes(key, val)
	return filter(systemlist('silicon --list-themes'), "v:val =~ a:val")
endfun

" Possible completions for bools
fun! s:bools(key, val)
  return filter([v:true, v:false], "v:val =~ a:val")
endfun

fun! s:langs(key, val)
  return getcompletion(a:val, 'filetype')
endfun

" Possible completions for other types
fun! s:others(key, val)
  let current = g:silicon[a:key]
  let default = s:silicon[a:key][s:default]
  return filter(current == default || empty(default)? [current] : [current, default],
        \ "v:val =~ a:val")
endfun

fun! s:fonts(key, val)
  return filter(systemlist('fc-list : family'), "v:val =~ a:val")
endfun

" Config specification
let [s:default, s:is_flag, s:completions] = range(0, 2) " Column labels
let s:silicon = {
      \   'theme':                [ 'Dracula',  v:true,  function('s:themes') ],
      \   'font':                 [    'Hack',  v:true,  function('s:fonts')  ],
      \   'background':           [ '#aaaaff',  v:true,  function('s:others') ],
      \   'shadow-color':         [ '#555555',  v:true,  function('s:others') ],
      \   'line-pad':             [         2,  v:true,  function('s:others') ],
      \   'pad-horiz':            [        80,  v:true,  function('s:others') ],
      \   'pad-vert':             [       100,  v:true,  function('s:others') ],
      \   'shadow-blur-radius':   [         0,  v:true,  function('s:others') ],
      \   'shadow-offset-x':      [         0,  v:true,  function('s:others') ],
      \   'shadow-offset-y':      [         0,  v:true,  function('s:others') ],
      \   'line-number':          [    v:true,  v:true,  function('s:bools')  ],
      \   'round-corner':         [    v:true,  v:true,  function('s:bools')  ],
      \   'window-controls':      [    v:true,  v:true,  function('s:bools')  ],
      \   'language':             [    v:null,  v:true,  function('s:langs')  ],
      \   'default-file-pattern': [        '',  v:false, function('s:others') ],
      \ }

call s:configure('g:silicon', s:silicon)

" Silicon bindings
fun! s:cmd(path, flags)
  return ['silicon']
        \ + s:cmd_output(a:path, a:flags)
        \ + s:cmd_language(a:path, a:flags)
        \ + s:cmd_config(a:path, a:flags)
endfun

fun! s:cmd_output(path, flags)
  if !empty(a:path)
    return ['--output', s:set_extension(s:cmd_output_path(a:path, a:flags))]
  elseif !empty(g:silicon['default-file-pattern'])
    return ['--output', s:set_extension(s:cmd_file_pattern(a:path, a:flags))]
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

fun! s:cmd_file_pattern(path, flags)
  let path = g:silicon['default-file-pattern']
  let path = substitute(path, '{time:\(.\{-}\)}', {match -> strftime(match[1])}, 'g')
  let path = substitute(path, '{file:\(.\{-}\)}', {match -> expand(match[1])}, 'g')
  let path = fnamemodify(path, ':p')
  return path
endfun

fun! s:cmd_output_path(path, flags)
  let realpath = expand(a:path)
  if isdirectory(realpath)                     " /path/to/
    let filename = expand('%:t:r')
    let date = strftime('%Y-%m-%d_%H:%M:%S')
    if !empty(filename)                        " Named source file
      return realpath.'/'.filename.'_'.date
    el                                         " Unnamed source file
      return realpath.'/silicon_'.date
    en
  el
    return realpath                            " /path/to/img.png
  en
endfun

fun! s:infer_language()
  if !empty(&ft)
    return &ft
  el
    let ext = expand('%:e')
    if !empty(ext)
      return ext
    el
      return 'txt'
    en
  en
endfun

fun! s:cmd_language(path, flags)
  return ['--language', get(a:flags, 'language', s:infer_language())]
endfun

fun! s:cmd_config(path, flags)
  let flags = []
  for [key, val] in items(g:silicon)
    let val = get(a:flags, key, val) " Override
    if s:silicon[key][s:is_flag]
      if type(val) == v:t_bool
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
    call s:validate(g:silicon, s:silicon)
    let [path, flags] = s:entered_flags(a:000)
    let cmd = s:cmd(path, flags)
    let lines = join(getline(a:line1, a:line2), "\n")
    echomsg string(cmd)
    call s:dispatch(cmd, lines)
    echomsg '[Silicon - Success]: Image Generated'
  catch
    let v:errmsg = '[Silicon - Error]: '.v:exception
    echohl ErrorMsg | echomsg v:errmsg | echohl None
  endtry
endfun

fun! silicon#generate_highlighted(line1, line2, ...)
  try
    if visualmode() != 'V'
      throw 'Command can only be called from Visual Line mode.'
    en
    call s:validate(g:silicon, s:silicon)
    let [path, flags] = s:entered_flags(a:000)
    let cmd = s:cmd(path, flags) + ['--highlight-lines', a:line1.'-'.a:line2]
    let lines = join(getline('1', '$'), "\n")
    call s:dispatch(cmd, lines)
    echomsg '[Silicon - Success]: Highlighted Image Generated'
  catch
    let v:errmsg = '[Silicon - Error]: '.v:exception
    echohl ErrorMsg | echomsg v:errmsg | echohl None
  endtry
endfun

" Completions

" All possible flags that can be completed
fun s:all_flags()
  let all_flags = {}
  for [key, val] in items(s:silicon)
    let all_flags[key] = val['default']
  endfor
  let all_flags.language = s:infer_language()
  return all_flags
endfun

" Current flags that have been completed
fun! s:entered_flags(args)
  let entered_flags = {}
  let entered_path = ''
  for arg in a:args
    let matches = matchlist(arg, '\v^--([a-z\-]+)\=(.+)$')
    if !empty(matches)
      let [flag, val] = matches[1:2]
      let entered_flags[flag] = val
    elseif arg !~ '^-'
      let entered_path = arg
    en
  endfor
  return [entered_path, entered_flags]
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
  let [entered_path, entered_flags] = s:entered_flags(split(a:cmdline)[1:])
  let remaining_flags = s:remaining_flags(all_flags, entered_flags)
  let matches = matchlist(a:arglead, '\v^--([a-z\-]+)(\=(.+)?)?$')
  if !empty(matches)
    let [key, eq, val] = matches[1:3]
    if !empty(eq)
      if has_key(s:silicon, key)
        " Complete value
        return map(s:silicon[key][s:completions](key, val), "'--'.key.'='.v:val")
      el
        return []
      en
    el
      " Complete key
      return sort(values(map(filter(remaining_flags, "v:key =~ key"), "'--'.v:key")))
    en
  elseif a:arglead == entered_path
    " Complete path
    return getcompletion(a:arglead, 'dir')
  el
    " Complete remaining flags
    return sort(values(map(remaining_flags, "'--'.v:key")))
  en
endfun
