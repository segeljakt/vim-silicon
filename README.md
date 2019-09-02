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

This plugin provides a single command `Silicon`:

```vim
" Generate an image of the current buffer and write it to /path/to/output.png
:Silicon /path/to/output.png

" Generate an image of the current buffer and write it to /path/to/output.png and clipboard.
:Silicon /path/to/output.png --to-clipboard

" Generate an image of the current buffer and write it to /path/to/<filename>.png
:Silicon /path/to/

" Generate an image of the current visual line selection and write it to /path/to/output.png
:'<,'>Silicon /path/to/output.png

" Generate an image of the current buffer, with the current visual line selection highlighted.
:'<,'>Silicon! /path/to/output.png
```

# Options

This is the default configuration:

```vim
let g:silicon = {
      \   'theme':              'Dracula',
      \   'font':                  'Hack',
      \   'background':         '#AAAAFF',
      \   'shadow-color':       '#555555',
      \   'line-pad':                   2,
      \   'pad-horiz':                 80,
      \   'pad-vert':                 100,
      \   'shadow-blur-radius':         0,
      \   'shadow-offset-x':            0,
      \   'shadow-offset-y':            0,
      \   'line-number':           v:true,
      \   'round-corner':          v:true,
      \   'window-controls':       v:true,
      \ }
```

Images are by default saved to the working directory with a unique filename,
you can change this filepath by setting:

```vim
let g:silicon['output'] = '~/images/silicon-{time:%Y-%m-%d-%H%M%S}.png'
```

To get the list of available themes, you can run this in the terminal:

```sh
silicon --list-themes
```

Silicon internally uses [`bat`'s](https://github.com/sharkdp/bat) themes and syntaxes. To get the list of supported languages, you could:

```sh
cargo install bat
bat --list-languages
```

For more details about options, see https://github.com/Aloxaf/silicon.

## Advanced Configuration

Instead of assigning values to flags in g:silicon, you can assign functions which expand into values right before generating the images.

For example, to save images into different directories depending on whether you are at work or not:

```vim
let s:workhours = {
      \ 'Monday':    [8, 16],
      \ 'Tuesday':   [9, 17],
      \ 'Wednesday': [9, 17],
      \ 'Thursday':  [9, 17],
      \ 'Friday':    [9, 15],
      \ }

function! s:working()
    let day = strftime('%u')
    if has_key(s:workhours, day)
      let hour = strftime('%H')
      let [start_hour, stop_hour] = s:workhours[day]
      if start_hour <= hour && hour <= stop_hour
        return "~/Work-Snippets/"
      endif
    endif
    return "~/Personal-Snippets/"
endfunction

let g:silicon['output'] = function('s:working')
```

# Credits

Credits goes to:

* https://github.com/Aloxaf for Silicon
* Bethesda for the awesome Doom wallpaper
