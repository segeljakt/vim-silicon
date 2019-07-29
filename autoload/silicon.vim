" vim: et sw=2 sts=2

" Plugin:      https://github.com/segeljakt/vim-silicon
" Description: Create beautiful images of your source code.
" Maintainer:  Klas Segeljakt <http://github.com/segeljakt>

fun! s:cmd(argc, argv)
  let cmd = 'silicon '
  if a:argc == 0
    if empty(has('linux'))
      echoerr 'Copying to clipboard with Silicon is only supported on Linux'
    el
      let cmd .= ' --to-clipboard'
    en
  el
    let path = a:argv[0]
    if empty(fnamemodify(path, ':e'))
      let cmd .= ' --output '.path.'.png'
    el
      let cmd .= ' --output '.path
    en
  en
  let cmd .= ' --language '.&ft
  let cmd .= ' '.join(values(map(copy(g:silicon), {key, val ->
        \    type(val) == type(v:false) ? (
        \      val == v:false ?
        \        '--no-'.key :
        \        ''
        \      ) :
        \      '--'.key.' '.string(val)
        \ })), ' ')
  return cmd
endfun

fun! silicon#generate(line1, line2, ...)
  let lines = join(getline(a:line1, a:line2), "\n")
  let cmd = s:cmd(a:0, a:000)
  call system('echo '.shellescape(lines).'|'.cmd)
endfun

fun! silicon#generate_highlighted(line1, line2, ...)
  let lines = join(getline('1', '$'), "\n")
  let cmd = s:cmd(a:0, a:000)
  let cmd .= ' --highlight-lines '.a:line1.'-'.(a:line2+1)
  call system('echo '.shellescape(lines).'|'.cmd)
endfun
