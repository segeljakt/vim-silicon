" vim: et sw=2 sts=2

" Plugin:      https://github.com/segeljakt/vim-silicon
" Description: Create beautiful images of your source code.
" Maintainer:  Klas Segeljakt <http://github.com/segeljakt>

com!
  \ -range=%
  \ -nargs=*
  \ -complete=customlist,silicon#complete
  \ Silicon
  \ call silicon#generate(<line1>, <line2>, <f-args>)

com!
  \ -range
  \ -nargs=*
  \ -complete=customlist,silicon#complete
  \ SiliconHighlight
  \ call silicon#generate_highlighted(<line1>, <line2>, <f-args>)

