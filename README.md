# Recent Files Telescope Extension for Neovim

A ZED/VSCode inspired Telescope extension to track
and display recently opened files within a Neovim session.

## Features

- Tracks files opened in the current session.
- Shows edited files with a [*] marker.
- Keybindings: toggle edited files (`e`), delete entries (`D`), toggle current buffer preference (`P`), copy paths (`c`, `<S-C>`).

## Installation

### Packer.nvim

```lua
use {
    "apex-woot/recent-files-nvim",
    requires = { "nvim-telescope/telescope.nvim", "nvim-lua/plenary.nvim" },
}
```

### Lazy.nvim

```lua
{
    "apex-woot/recent-files-nvim",
    dependencies = { "nvim-telescope/telescope.nvim", "nvim-lua/plenary.nvim" },
}

