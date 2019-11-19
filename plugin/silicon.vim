" vim: et sw=2 sts=2

" Plugin:      https://github.com/segeljakt/vim-silicon
" Description: Create beautiful images of source code.
" Maintainer:  Klas Segeljakt <http://github.com/segeljakt>

com!
  \ -bang
  \ -range=%
  \ -nargs=*
  \ -complete=customlist,silicon#complete
  \ Silicon
  \ call silicon#generate(<bang>0, <line1>, <line2>, <f-args>)

com!
  \ -range
  \ -nargs=*
  \ SiliconHighlight
  \ echoerr ':SiliconHighlight is deprecated, use :Silicon! instead'

