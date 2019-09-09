" vim: et sw=2 sts=2

" Plugin:      https://github.com/segeljakt/vim-silicon
" Description: Create beautiful images of your source code.
" Maintainer:  Klas Segeljakt <http://github.com/segeljakt>

if exists('s:autoloaded') | finish | el | let s:autoloaded = v:true | en

" ====================== Plugin-Independent Functions ========================

" Info: Mapping from type-number to type-name
const s:typename = [
      \ 'number',
      \ 'string',
      \ 'func',
      \ 'list',
      \ 'dict',
      \ 'float',
      \ 'boolean',
      \ 'null',
      \ ]

" ------------------------- Vim/Neovim Compatibility -------------------------

" Info: Starts a:cmd as a job and passes a:data as input to it
if has('nvim')
  fun! s:run(cmd, data)
    let id = jobstart(a:cmd, s:job_options)
    call chansend(id, a:data)
    call chanclose(id)
  endfun
el
  fun! s:run(cmd, data)
    let id = job_start(a:cmd, s:job_options)
    call ch_sendraw(id, a:data)
    call ch_close(id)
  endfun
en

" Info: Callback for job
fun! s:handler(channel_id, data, name)
"   if a:name == 'stdout'
"     call s:print_info('stdout: '.join(a:data))
"   elseif a:name == 'stderr'
"     call s:print_info('stderr: '.join(a:data))
"   elseif a:name == 'exit'
"     call s:print_info('exited')
"   elseif a:name == 'data'
"     call s:print_info('???')
"   en
endfun

const s:job_options = {}
"       \   'on_stdout': function('s:handler'),
"       \   'on_stderr': function('s:handler'),
"       \   'on_exit':   function('s:handler'),
"       \   'on_data':   function('s:handler'),
"       \ }

" ------------------------------ Error handling ------------------------------

" Info: Prints a warning message
fun! s:print_warning(msg)
	echoh WarningMsg | echom '[Silicon - Warning]: '.a:msg | echoh None
endfun

" Info: Prints an error message
fun! s:print_error(msg)
  let v:errmsg = '[Silicon - Error]: '.v:exception
  echoh ErrorMsg | echom v:errmsg | echoh None
endfun

" Info: Prints a silent info message
fun! s:print_info(msg)
	echom '[Silicon - Info]: '.a:msg
endfun

" Info: Formats a list of errors
fun! s:format_errors(errors)
  return "\n  - " . join(a:errors, "\n  - ")
endfun

" ----------------------------- Configuration ------------------------------

" Info: Either creates or derives a configuration based on a specification
fun! s:configure(name, spec)
  if !exists(a:name)
    let {a:name} = map(copy(a:spec), "v:val[s:default]")
  el
    let config = {a:name}
    for [key, val] in items(a:spec)
      if !has_key(config, key) && val[s:default] != v:null
        let config[key] = val[s:default]
      en
    endfor
  en
endfun

" Info: Identifies and warns about deprecated features
fun! s:deprecate(config)
  if has_key(a:config, 'default-file-pattern')
    call s:print_warning('"default-file-pattern" is deprecated, '
          \ .'please use "output" instead')
    let a:config.output = remove(a:config, 'default-file-pattern')
  en
endfun

" Info: Overrides user a:config with command-line a:flags
fun! s:override(config, flags)
  for [key, val] in items(a:flags)
    let a:config[key] = val
  endfor
endfun

" Info: Expands values in the user a:config
fun! s:expand(config)
  call map(a:config, "type(v:val) == v:t_func? call(v:val, []) : v:val")
  let a:config.output = simplify(s:expand_path(a:config.output))
endfun

" Info: Expands a a:path variable
" e.g. ~/images/silicon-{time:%Y-%m-%d-%H%M%S}.png
" into ~/images/silicon-2019-08-10-164233.png
fun! s:expand_path(path)
  let path = substitute(a:path,
        \ '\v\{time:(.{-})\}', '\=strftime(submatch(1))', 'g')
  let path = substitute(path,
        \ '\v\{file:(.{-})\}', '\=expand(submatch(1))', 'g')
  let path = fnamemodify(path, ':p')
  if isdirectory(path)
    return path.'/'.s:new_filename()
  elseif empty(fnamemodify(a:path, ':e'))
    return path.'.png'
  el
    return path
  en
endfun

" Info: Generates a filename
fun! s:new_filename()
  let file = expand('%:t:r')
  let date = strftime('%Y-%m-%d_%H:%M:%S')
  return (empty(file)? 'silicon' : file).'_'.date.'.png'
endfun

" Info: Checks for binary installation, and inconsistencies between the user
" a:config and internal a:spec
fun! s:validate(binary, spec, config)
  let errors = []
  if executable(a:binary) != 1
    let errors += ['vim-'.a:binary.' requires `'.a:binary.'` to be '
          \ .'installed and added to the $PATH. Please refer to the '
          \ .'installation instructions in the README.md.']
  en
  for [key, val] in items(a:config)
    if !has_key(a:spec, key)
      let errors += ['Unexpected key in g:'.a:binary.': '.string(key)]
    el
      let [found, expected] = [type(val), a:spec[key][s:type]]
      if found != expected && found != v:t_func
        let errors += ['Type mismatch in g:'.a:binary.' for key "'.key.'"'
              \ .': found `'.s:typename[found].'`'
              \ .', expected `'.s:typename[expected].'`'
              \ .', e.g. '.string(a:spec[key][s:default])]
      en
    en
  endfor
  return errors
endfun

" -------------------------- Infer values for flags --------------------------

" Info: Infer the --output flag
fun! s:infer_output()
  return getcwd().'/'.s:new_filename()
endfun

" Info: Infer the --language flag
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

fun! s:os()
  return 'Darwin'
endfun

" Info: Infer the --to-clipboard flag
fun! s:infer_clipboard()
  return !empty(executable('xclip')) || s:os() ==# 'Darwin'? v:true : v:false
endfun

" ----------------------------- Command builder ------------------------------

" Info: Build a command
fun! s:cmd(binary, args, config, spec)
  let [path, flags, errors] = s:entered_flags(a:args, a:spec)
  if !empty(errors)
    throw s:format_errors(errors)
  en
  let flags.output = path
  let config = copy(a:config)
  call s:override(config, flags)
  call s:expand(config)
  let errors = s:validate(a:binary, a:spec, config)
  if !empty(errors)
    throw s:format_errors(errors)
  en
  return [[a:binary] + s:args(a:spec, config), config.output]
endfun

" Info: Converts a:config parameters into arguments
fun! s:args(spec, config)
  let args = []
  for [key, val] in items(a:config)
    let type = type(val)
    if type == v:t_bool
      let Default = a:spec[key][s:default]
      if (Default == v:false || type(Default) == v:t_func) && val == v:true
        let args += ['--'.key] " Enable, e.g. --to-clipboard
      elseif Default == v:true && val == v:false
        let args += ['--no-'.key] " Disable, e.g. --no-window-controls
      en
    el
      let args += ['--'.key, val] " Set, e.g. --line-pad 2
    en
  endfor
  return args
endfun

" ======================== Plugin specific functions =========================

" --------------------------- Completion functions ---------------------------

" Info: Theme completions
fun! s:complete_themes(key, val)
	return filter(systemlist('silicon --list-themes'), "v:val =~? '^'.a:val")
endfun

" Info: Font completions
fun! s:complete_fonts(key, val)
  return map(filter(systemlist('fc-list : family'), "v:val =~? '^'.a:val"),
        \ 'escape(v:val, " ")')
endfun

" Info: Bool completions
fun! s:complete_bools(key, val)
  return filter([v:true, v:false], "v:val =~? '^'.a:val")
endfun

" Info: Language completions
fun! s:complete_languages(key, val)
  return getcompletion(a:val, 'filetype')
endfun

" Info: Output path completions
fun! s:complete_outputs(key, val)
  return getcompletion(a:val, 'dir')
endfun

" Info: Default completion function
fun! s:complete_defaults(key, val)
  let current = get(g:silicon, a:key, '')
  let default = s:silicon[a:key][s:default]
  let completions = current is default? [current] : [current, default]
  return filter(completions, "v:val =~? '^'.a:val")
endfun

const s:themes    = function('s:complete_themes')
const s:fonts     = function('s:complete_fonts')
const s:bools     = function('s:complete_bools')
const s:languages = function('s:complete_languages')
const s:defaults  = function('s:complete_defaults')
const s:outputs   = function('s:complete_outputs')

" ---------------------- Internal config specification -----------------------

const [s:type, s:default, s:compfun] = range(0, 2) " Column labels
const s:silicon = {
      \   'theme':              [ v:t_string,                     'Dracula',    s:themes ],
      \   'font':               [ v:t_string,                        'Hack',     s:fonts ],
      \   'background':         [ v:t_string,                     '#AAAAFF',  s:defaults ],
      \   'shadow-color':       [ v:t_string,                     '#555555',  s:defaults ],
      \   'line-pad':           [ v:t_number,                             2,  s:defaults ],
      \   'pad-horiz':          [ v:t_number,                            80,  s:defaults ],
      \   'pad-vert':           [ v:t_number,                           100,  s:defaults ],
      \   'shadow-blur-radius': [ v:t_number,                             0,  s:defaults ],
      \   'shadow-offset-x':    [ v:t_number,                             0,  s:defaults ],
      \   'shadow-offset-y':    [ v:t_number,                             0,  s:defaults ],
      \   'line-number':        [   v:t_bool,                        v:true,     s:bools ],
      \   'round-corner':       [   v:t_bool,                        v:true,     s:bools ],
      \   'window-controls':    [   v:t_bool,                        v:true,     s:bools ],
      \   'to-clipboard':       [   v:t_bool, function('s:infer_clipboard'),     s:bools ],
      \   'language':           [ v:t_string,  function('s:infer_language'), s:languages ],
      \   'output':             [ v:t_string,    function('s:infer_output'),   s:outputs ],
      \ }

call s:configure('g:silicon', s:silicon)
call s:deprecate(g:silicon)

" =============================== External API ===============================

" Info: Generates an image of code which represents lines a:line1 to a:line2
" of the current buffer
fun! silicon#generate(line1, line2, ...)
"   try
    if mode() != 'n' && visualmode() != 'V'
      throw 'Command can only be called from Normal or Visual Line mode.'
    en
    let [cmd, path] = s:cmd('silicon', a:000, g:silicon, s:silicon)
    let lines = join(getline(a:line1, a:line2), "\n")
    let @+ = 'echo '.string(lines).' | '.join(cmd)
    call s:run(cmd, lines)
    echom '[Silicon - Success]: Image Generated to '.path
"   catch
"     call s:print_error(v:exception)
"   endtry
endfun

" Info: Generates an image of code which represents the current buffer with
" a:line1 to a:line2 highlighted
fun! silicon#generate_highlighted(line1, line2, ...)
  try
    if visualmode() != 'V'
      throw 'Command can only be called from Visual Line mode.'
    en
    let [cmd, path] = s:cmd('silicon', a:000, g:silicon, s:silicon)
    let cmd += ['--highlight-lines', a:line1.'-'.a:line2]
    let lines = join(getline('1', '$'), "\n")
    call s:run(cmd, lines)
    echom '[Silicon - Success]: Image Generated to '.path
  catch
    call s:print_error(v:exception)
  endtry
endfun

" =============================== Completions ================================

" Info: Returns all flags that can be completed
fun s:all_flags(spec)
  let all_flags = map(copy(a:spec), "v:val[s:default]")
  call remove(all_flags, 'output') " Output is treated differently
  return all_flags
endfun

fun! s:parse_val(val)
  return  a:val == 'true'? v:true :
        \ a:val == 'false'? v:false :
        \ a:val =~ '\v^[[:digit:]]+$'? str2nr(a:val) :
        \ a:val
endfun

" Info: Returns current path and flags that have been completed, and any
" kind of errors that might have occurred
fun! s:entered_flags(args, spec)
  let [entered_path, entered_flags, errors] = ['', {}, []]
  for arg in a:args
    let matches = matchlist(arg, '\v^--([[:lower:]\-]+)\=(.+)$')
    if !empty(matches)
      let [key, val] = matches[1:2]
      if has_key(a:spec, key)
        let entered_flags[key] = s:parse_val(val)
      el
        let errors += ['Undefined command-line flag: '.string('--'.key)]
      en
    elseif arg !~ '^-'
      if empty(entered_path)
        let entered_path = arg
      el
        let errors += ['Multiple output paths specified on command-line: '
              \ .string(entered_path).' and '.string(arg)]
      en
    el
      let errors += ['Failed to parse command-line argument: '.string(arg)]
    en
  endfor
  return [entered_path, entered_flags, errors]
endfun

" Info: Returns remaining flags to-be completed
fun! s:remaining_flags(all_flags, entered_flags)
  let remaining_flags = copy(a:all_flags)
  for entered_flag in keys(a:entered_flags)
    if has_key(remaining_flags, entered_flag)
      call remove(remaining_flags, entered_flag)
    en
  endfor
  return remaining_flags
endfun

" Info: Completion function for :Silicon and :SiliconHighlight that completes:
" 1. Output paths e.g. :Silicon foo/bar/baz
" 2. Flag keys    e.g. :Silicon foo/bar/baz --flag
" 3. Flag =       e.g. :Silicon foo/bar/baz --flag=
" 4. Flag values  e.g. :Silicon foo/bar/baz --flag=123
" Only remaining, i.e. un-entered, output paths/flags are completed
fun! silicon#complete(arglead, cmdline, cursorpos)
  let args = split(a:cmdline)[1:]
  let all_flags = s:all_flags(s:silicon)
  let [entered_path, entered_flags, _] = s:entered_flags(args, s:silicon)
  let remaining_flags = s:remaining_flags(all_flags, entered_flags)
  let matches = matchlist(a:arglead, '\v^--([[:lower:]\-]+)(\=(.+)?)?$')
  if !empty(matches)
    let [key, eq, val] = matches[1:3]
    if !empty(eq)
      if has_key(s:silicon, key)
        " Complete value
        return map(s:silicon[key][s:compfun](key, val), "'--'.key.'='.v:val")
      el
        return []
      en
    el
      " Complete key
      let completions = values(map(filter(remaining_flags,
            \ "v:key =~? '^'.key"), "'--'.v:key"))
      return len(completions) == 1? [completions[0].'='] : sort(completions)
    en
  elseif a:arglead == entered_path
    " Complete path
    return s:silicon.output[s:compfun]('output', entered_path)
  el
    " Complete remaining flags
    let completions = values(map(remaining_flags, "'--'.v:key"))
    return len(completions) == 1? [completions[0].'='] : sort(completions)
  en
endfun
