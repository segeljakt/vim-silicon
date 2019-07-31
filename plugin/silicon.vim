" vim: et sw=2 sts=2

" Plugin:      https://github.com/segeljakt/vim-silicon
" Description: Create beautiful images of your source code.
" Maintainer:  Klas Segeljakt <http://github.com/segeljakt>

if empty(executable('silicon'))
  echoerr 'vim-silicon requires `silicon` to be installed.'
        \ 'Please refer to the installation instructions in the README.md.'
  finish
en

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

