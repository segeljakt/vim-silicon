<h1 align="center">vim-silicon</h1>

<p align="center">
  <img width="800px" src="https://github.com/segeljakt/assets/blob/master/Silicon.gif?raw=true">
</p>

This plugin provides a command which, given a visual selection or buffer, will generate a neat looking and highly customizable image of the source code. The image generator is https://github.com/Aloxaf/silicon, which is similar to https://carbon.now.sh, but does not require an internet connection.

# Installation

First, you need to install [cargo](https://doc.rust-lang.org/cargo/getting-started/installation.html) and [silicon](https://github.com/Aloxaf/silicon):

```sh
# Install cargo
curl https://sh.rustup.rs -sSf | sh

# Install silicon
cargo install silicon

# Add cargo-installed binaries to the path
export PATH="$PATH:$CARGO_HOME/bin"
```

Then, if using [vim-plug](https://github.com/junegunn/vim-plug), add this to your `~/.vimrc`:

```vim
Plug 'segeljakt/vim-silicon'
```

# Commands

The available commands are `Silicon`, and `SiliconHighlight`:

```vim
" Generate an image of the current buffer and write it to /path/to/output.png
:Silicon /path/to/output.png

" Generate an image of the current buffer and write it to /path/to/<filename>.png
:Silicon /path/to/

" Generate an image of the current visual line selection and write it to /path/to/output.png
:'<,'>Silicon /path/to/output.png

" Generate an image of the current buffer, with the current visual line selection highlighted.
:'<,'>SiliconHighlight /path/to/output.png
```

If no `/path/to/output.png` is specified, then the generated image is copied to clipboard. However, this feature is only supported on macOS and Linux at the moment.

# Options

This is the default configuration:

```vim
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
      \ 'line-number':           v:true,
      \ 'round-corner':          v:true,
      \ 'window-controls':       v:true,
      \ }
```

To get the list of available themes, you can run this in the terminal:

```sh
silicon --list-themes
```

For more details about options, see https://github.com/Aloxaf/silicon.

# Credits

Credits goes to:

* https://github.com/Aloxaf for Silicon
* Bethesda for the awesome Doom wallpaper
