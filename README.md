# trap

lightweight neovim plugin for quick note-taking with floating window.

## features

- zero configuration - it just works
- persistent notes that auto-clear after 7 days
- floating window UI that doesn't disrupt your workspace
- simple commands: `:TrapOpen` and `:TrapClear`
- cross-platform compatibility

## dependencies

- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) - required for floating window functionality

## installation

use your preferred plugin manager.

### with paq

```lua
require "paq" {
    "nvim-lua/plenary.nvim",  -- dependency
    "ratmav/trap",            -- this plugin
}
```

### local development

to work on trap locally:

```lua
-- Add your local trap checkout to the runtime path
vim.opt.runtimepath:append("/path/to/your/trap")

-- Ensure dependency is installed
require "paq" {
    "nvim-lua/plenary.nvim",  -- dependency
}
```

## usage

- `:TrapToggle` - toggle the trap window (open if closed, close if open)
  - perfect for mapping to a single key
  - automatically saves content when closing
- `:TrapClear` - manually clear the trap file contents

notes are stored in `stdpath("data")/trap/trap.md` and auto-clear after 7 days.

## theming

trap directly integrates with your active colorscheme:

- Window background matches your editor background
- Border colors adapt to your theme colors
- Highlight groups refresh automatically when colorscheme changes

no configuration needed - it just works with your current theme.