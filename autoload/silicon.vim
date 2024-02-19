" vim: et sw=2 sts=2

" Plugin:      https://github.com/segeljakt/vim-silicon
" Description: Create beautiful images of source code.
" Maintainer:  Klas Segeljakt <http://github.com/segeljakt>

if exists('s:autoloaded') | finish | el | let s:autoloaded = v:true | en

" ====================== Plugin-Independent Functions ========================

" Info: Mapping from type-number to type-name
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

" Info: Converts a number into a boolean
fun! s:nr2bool(number)
  return  a:number == 0 ? v:false :
        \ a:number == 1 ? v:true :
        \ a:number
endfun

" Info: Parses a string into a vim-expression
fun! s:parse_expr(str)
  return  a:str == 'true' ? v:true :
        \ a:str == 'false' ? v:false :
        \ a:str =~ '\v^[[:digit:]]+$' ? str2nr(a:str) :
        \ a:str
endfun

" ------------------------- Vim/Neovim Compatibility -------------------------

" Info: Callback for job
fun! s:handler(channel_id, data, name)
  if s:debug_mode_enabled()
    if a:name == 'stdout'
      call s:print_debug('stdout: '.join(a:data))
    if a:name == 'stderr'
      call s:print_debug('stderr: '.join(a:data))
    elseif a:name == 'exit'
      call s:print_debug('exited')
    elseif a:name == 'data'
      call s:print_debug('data')
    en
  en
endfun

" Info: Starts a:cmd as a job and passes a:data as input to it
if has('nvim')
  let s:job_options = {
        \   'on_stderr': function('s:handler'),
        \   'stderr_buffered': 1,
        \ }
  fun! s:run(cmd, data)
    let id = jobstart(a:cmd, s:job_options)
    call chansend(id, a:data)
    call chanclose(id)
  endfun
el
  let s:job_options = { }
  fun! s:run(cmd, data)
    let id = job_start(a:cmd, s:job_options)
    call ch_sendraw(id, a:data)
    call ch_close(id)
  endfun
en

" ------------------------------ Error handling ------------------------------

" Info: Prints a warning message
fun! s:print_success(msg)
  echom '[Silicon - Success]: '.a:msg
endfun

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
fun! s:print_debug(msg)
	echom '[Silicon - Debug]: '.a:msg
endfun

" Info: Formats a list of errors
fun! s:format_errors(errors)
  return "\n  - " . join(a:errors, "\n  - ")
endfun

" Info: Returns true if debug mode is enabled
fun! s:debug_mode_enabled()
  return get(g:, 'silicon#debug', v:false)
endfun

fun! s:throw_if_nonempty(errors)
  if !empty(a:errors)
    throw s:format_errors(a:errors)
  en
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
    if s:debug_mode_enabled()
      call s:print_warning('"default-file-pattern" is deprecated, '
            \ .'please use "output" instead')
    en
    let a:config['output'] = remove(a:config, 'default-file-pattern')
  en
endfun

" Info: Overrides user a:config with command-line a:flags
fun! s:override(config, flags)
  for [key, val] in items(a:flags)
    let a:config[key] = val
  endfor
endfun

" Info: Expands values in the user a:config by calling functions and expanding paths
" if functions return numbers (0 and 1) where booleans are expected, make a conversion
fun! s:expand(config, spec)
  call map(a:config, "type(v:val) == v:t_func ? call(v:val, []) : v:val")
  call map(a:config, "a:spec[v:key][s:type] == v:t_bool && type(v:val) == v:t_number ?"
        \ ."s:nr2bool(v:val) : v:val")
  let a:config['output'] = simplify(s:expand_path(a:config['output']))
endfun

" Info: Expands a a:path variable
" e.g. ~/images/silicon-{time:%Y-%m-%d-%H%M%S}.png
" into ~/images/silicon-2019-08-10-164233.png
fun! s:expand_path(path)
  let path = substitute(a:path, '\v\{time:(.{-})\}', '\=strftime(submatch(1))', 'g')
  let path = substitute(path, '\v\{file:(.{-})\}', '\=expand(submatch(1))', 'g')
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
  return (empty(file) ? 'silicon' : file).'_'.date.'.png'
endfun

" Info: Checks for binary installation, and inconsistencies between the user
" a:config and internal a:spec
fun! s:validate(binary, config, spec)
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

let s:os = has('win64') || has('win32') || has('win16') ? 'Windows' :
      \ has('mac') || has('macunix') || has('gui_mac') ? 'Darwin' :
      \ substitute(system('uname'), '\n', '', '')

" Info: Infer the --to-clipboard flag
fun! s:infer_to_clipboard()
  return !empty(executable('xclip')) || s:os ==# 'Darwin' || s:os ==# 'Windows'
endfun

" ----------------------------- Command builder ------------------------------

" Info: Converts a:config parameters into arguments
fun! s:args(config, spec)
  let args = []
  for [key, val] in items(a:config)
    let type = type(val)
    if type == v:t_bool
      let Default = a:spec[key][s:default]
      if val == v:true && (Default == v:false || type(Default) == v:t_func)
        let args += ['--'.key] " Enable, e.g. --to-clipboard
      elseif val == v:false && Default == v:true
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
	return filter(systemlist('silicon --list-themes'), 'v:val =~? "^".a:val')
endfun

" Info: Font completions
fun! s:complete_fonts(key, val)
  return map(filter(systemlist('fc-list : family'), 'v:val =~? "^".a:val'),
        \ 'escape(v:val, " ")')
endfun

" Info: Bool completions
fun! s:complete_bools(key, val)
  return filter([v:true, v:false], 'v:val =~? "^".a:val')
endfun

" Info: Language completions
fun! s:complete_filetypes(key, val)
  return getcompletion(a:val, 'filetype')
endfun

" Info: Path completions
fun! s:complete_paths(key, val)
  return getcompletion(a:val, 'dir') + ['./', '../']
endfun

" Info: Default completion function
fun! s:complete_defaults(key, val)
  let current = get(g:silicon, a:key, '')
  let default = s:silicon[a:key][s:default]
  let completions = (current == default) ? [default] : [current, default]
  return filter(completions, 'v:val =~? "^".a:val')
endfun

let s:themes       = function('s:complete_themes')
let s:fonts        = function(executable('fc-list') ?
      \ 's:complete_fonts':'s:complete_defaults')
let s:bools        = function('s:complete_bools')
let s:filetypes    = function('s:complete_filetypes')
let s:defaults     = function('s:complete_defaults')
let s:paths        = function('s:complete_paths')

let s:to_clipboard = function('s:infer_to_clipboard')
let s:language     = function('s:infer_language')
let s:output       = function('s:infer_output')

" ---------------------- Internal config specification -----------------------

let [s:type, s:default, s:compfun] = range(0, 2) " Column labels
let s:silicon = {
      \   'theme':              [ v:t_string,      'Dracula',    s:themes ],
      \   'font':               [ v:t_string,         'Hack',     s:fonts ],
      \   'background':         [ v:t_string,      '#AAAAFF',  s:defaults ],
      \   'shadow-color':       [ v:t_string,      '#555555',  s:defaults ],
      \   'line-offset':        [ v:t_number,              1,  s:defaults ],
      \   'line-pad':           [ v:t_number,              2,  s:defaults ],
      \   'pad-horiz':          [ v:t_number,             80,  s:defaults ],
      \   'pad-vert':           [ v:t_number,            100,  s:defaults ],
      \   'shadow-blur-radius': [ v:t_number,              0,  s:defaults ],
      \   'shadow-offset-x':    [ v:t_number,              0,  s:defaults ],
      \   'shadow-offset-y':    [ v:t_number,              0,  s:defaults ],
      \   'line-number':        [   v:t_bool,         v:true,     s:bools ],
      \   'round-corner':       [   v:t_bool,         v:true,     s:bools ],
      \   'window-controls':    [   v:t_bool,         v:true,     s:bools ],
      \   'to-clipboard':       [   v:t_bool, s:to_clipboard,     s:bools ],
      \   'language':           [ v:t_string,     s:language, s:filetypes ],
      \   'output':             [ v:t_string,       s:output,     s:paths ],
      \ }

call s:configure('g:silicon', s:silicon)
call s:deprecate(g:silicon)

fun! s:read_attributes(bang, line1, line2)
    let errors = []
    if !a:bang 
      let lines = join(getline(a:line1, a:line2), "\n")
      let suffix = []
    el
      if a:line1 == 1 && a:line2 == line('$')
        let errors += [
              \ 'Specify a sub-range to highlight using Visual Line mode.'
              \ ]
      en
      let [line1, line2] = [a:line1, a:line2]
      if line2 == line('$')
        let line2 -= 1
        if line1 == line('$')
          let line1 -= 1
        en
      en
      let lines = join(getline(0, '$'), "\n")
      let suffix = ['--highlight-lines', line1.'-'.line2]
    en
    return [lines, suffix, errors]
endfun

" =============================== External API ===============================

" Info: Generates an image of code which represents lines a:line1 to a:line2
" of the current buffer. If <bang> is supplied, then the generated image will
" instead represent the current buffer with a:line1 to a:line2 highlighted.
fun! silicon#generate(bang, line1, line2, ...)
  try
    let [lines, suffix, errors] = s:read_attributes(a:bang, a:line1, a:line2)
    call s:throw_if_nonempty(errors)

    let [path, flags, errors] = s:entered_flags(a:000, s:silicon)
    call s:throw_if_nonempty(errors)

    if !empty(path)
      let flags['output'] = path
    en

    let silicon = copy(g:silicon)
    call s:override(silicon, flags)
    call s:expand(silicon, s:silicon)

    let errors = s:validate('silicon', silicon, s:silicon)
    call s:throw_if_nonempty(errors)

    let messages = []

    if !empty(silicon['to-clipboard'])
      let tmp = remove(silicon, 'output')
      call s:run(['silicon'] + s:args(silicon, s:silicon) + suffix, lines)
      let silicon['output'] = tmp
      let messages += ['copied to clipboard']
    en

    if !empty(silicon['output'])
      let tmp = remove(silicon, 'to-clipboard')
      call s:run(['silicon'] + s:args(silicon, s:silicon) + suffix, lines)
      let silicon['to-clipboard'] = tmp
      let messages += ['written to '.silicon['output']]
    en

    call s:print_success('Generated image '.join(messages, ' and '))

    if s:debug_mode_enabled()
      let @+ = join(cmd + suffix)
      call s:print_debug('Command executed: '.string(cmd + suffix))
      call s:print_debug('With piped input: '.string(lines))
      call s:print_debug('Copied command to clipboard: '.@+)
    en
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

" Info: Returns current path and flags that have been completed, and any
" kind of errors that might have occurred
fun! s:entered_flags(args, spec)
  let [entered_path, entered_flags, errors] = ['', {}, []]
  for arg in a:args
    let matches = matchlist(arg, '\v^--([[:lower:]\-]+)\=(.+)$')
    if !empty(matches)
      let [key, val] = matches[1:2]
      if has_key(a:spec, key)
        let entered_flags[key] = (key == 'theme' || key == 'font') ?
              \ val : s:parse_expr(val)
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

" Info: Completion function for :Silicon that completes:
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
      return len(completions) == 1 ? [completions[0].'='] : sort(completions)
    en
  elseif a:arglead == entered_path
    " Complete path
    return s:silicon['output'][s:compfun]('output', entered_path)
  el
    " Complete remaining flags
    let completions = values(map(remaining_flags, "'--'.v:key"))
    return len(completions) == 1 ? [completions[0].'='] : sort(completions)
  en
endfun
