<h1 align="center">vim-silicon</h1>

This plugin provides a command which, given a visual selection or buffer, will generate a neat looking image of the source code using https://github.com/Aloxaf/silicon. The image generator is similar to https://carbon.now.sh, but does not require an internet connection.

# Installation

First, you need to install [cargo](https://doc.rust-lang.org/cargo/getting-started/installation.html) and [silicon](https://github.com/Aloxaf/silicon):

```
# Install cargo
curl https://sh.rustup.rs -sSf | sh

# Install silicon
cargo install silicon
```

Then, if using [vim-plug](https://github.com/junegunn/vim-plug), add this to your `~/.vimrc`:

```
Plug 'segeljakt/vim-silicon'
```

# Commands

These are the available commands:

```
" Generate a code image from a buffer or visual line selection
:Silicon [/path/to/output.png]

" Generate a code image from a buffer and highlight the lines
" of the current visual line selection
:SiliconHighlight [/path/to/output.png]
```

If no ` /path/to/output.png` is specified, then the generated image is copied to clipboard.

# Options

This is the default configuration:

```
let g:silicon = {
      \ 'theme':              'Dracula',
      \ 'font':                  'Hack',
      \ 'background':         '#aaaaff',
      \ 'shadow-color':       '#555555',
      \ 'line-pad':                   2,
      \ 'pad-horiz':                 80,
      \ 'pad-vert':                 100,
      \ 'shadow-blur-radius':         0,
      \ 'shadow-offset-x':            0,
      \ 'shadow-offset-y':            0,
      \ 'no-line-number':       v:false,
      \ 'no-round-corner':      v:false,
      \ 'no-window-controls':   v:false,
      \ }
```

To get the list of available themes, you can run this in the terminal:

```
silicon --list-themes
```

For more details about options, please see https://github.com/Aloxaf/silicon.
