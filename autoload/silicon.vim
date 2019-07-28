" vim: et sw=2 sts=2

" Plugin:      https://github.com/segeljakt/vim-silicon
" Description: Create beautiful images of your source code.
" Maintainer:  Klas Segeljakt <http://github.com/segeljakt>

fun! s:cmd(path)
  if empty(a:path) && empty(has('linux'))
    echoerr 'Copying to clipboard with Silicon is currently'
          \ 'only supported on Linux'
  en
  let cmd = 'silicon '.shellescape(expand('%:p'))
  let cmd .= empty(a:path) ?
        \ ' --to-clipboard' :
        \ ' --output '.a:path
  let cmd .= ' --language '.&ft
  let cmd .= ' '.join(map(g:silicon, {key, val ->
        \    type(val) == type(v:true) ? (
        \      val == v:true ?
        \        '--'.key :
        \        ''
        \      ) :
        \      '--'.key.' '.val
        \ }, ' '))
  return cmd
endfun

fun! silicon#generate(line1, line2, path)
  let lines = join(getline(a:line1, a:line2), "\n")
  let cmd = s:cmd(a:path)
  system('echo '.shellescape(lines).'|'.cmd)
endfun

fun! silicon#generate_highlighted(line1, line2, path)
  let lines = join(getline('1', '$'), "\n")
  let cmd = s:cmd(a:path)
  let cmd .= ' --highlight-lines '.a:line1.'-'.a:line2
  system('echo '.shellescape(lines).'|'.cmd)
endfun
