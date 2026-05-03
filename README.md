# kitty-agent-picker.nvim

Pick an existing Claude, Codex, or custom agent CLI window from the current Kitty
tab and receive its Kitty window metadata in Lua.

This plugin is for workflows where agents already live in external Kitty splits.
It does not start Claude/Codex and it does not manage an embedded Neovim
terminal. It only finds matching windows in the current Kitty tab and gives your
configuration a stable target window id.

## Features

- Uses `kitty @ ls` to inspect the current Kitty tab.
- Detects targets by window title, last reported command line, or foreground
  process command line.
- Fast path for zero or one match.
- Uses Kitty's native `kitten @ select-window` UI when multiple targets match.
- Validates the selected Kitty window against the configured target before
  returning it.
- Configurable targets, so tools such as `aider` can be added.

## Requirements

- Neovim 0.8+
- Kitty with remote control available to Neovim.

Typical Kitty setup:

```conf
allow_remote_control yes
```

If you use a socket-based setup, configure Kitty and your environment so
`kitty @ ls` and `kitten @ select-window` work from inside Neovim.

## Installation

With lazy.nvim:

```lua
{
  "kang/kitty-agent-picker.nvim",
  opts = {},
}
```

For local development:

```lua
{
  dir = "/Users/kang/kang/kitty-agent-picker.nvim",
  opts = {},
}
```

## Usage

```lua
require("kitty-agent-picker").pick(function(win)
  if not win then
    return
  end

  vim.print(win.id, win.cwd, win.title, win.agent_name)
end)
```

Pick a specific target:

```lua
require("kitty-agent-picker").pick({ target = "codex" }, function(win)
  if win then
    vim.fn.system({ "kitty", "@", "send-text", "--match", "id:" .. win.id, "hello\n" })
  end
end)
```

Built-in targets:

- `claude`
- `codex`
- `agent` for either Claude or Codex

There is also a lightweight debug command:

```vim
:KittyAgentPick
:KittyAgentPick codex
:KittyAgentPick agent
```

## Configuration

```lua
require("kitty-agent-picker").setup({
  kitty_ls_cmd = { "kitty", "@", "ls" },
  kitty_select_window_cmd = { "kitten", "@", "select-window", "--self", "--exclude-active" },
  targets = {
    aider = {
      display_name = "Aider",
      patterns = { "aider" },
    },
  },
})
```

`targets` is merged with the defaults, so the snippet above adds `aider` without
removing `claude`, `codex`, or `agent`.

When multiple configured targets match, Kitty's native selector may display
other windows in the tab as well. The plugin returns `nil` if the selected
window is not one of the matching target windows.

## API

### `setup(opts)`

Configures the plugin.

### `pick([opts], callback)`

Finds matching windows in the current Kitty tab.

```lua
require("kitty-agent-picker").pick({ target = "agent" }, function(win)
  -- win is nil when no matching window is reachable or selection is cancelled.
  -- win = { id, cwd, title, agent_name }
end)
```

## Development

This repository follows the structure from
[ellisonleao/nvim-plugin-template](https://github.com/ellisonleao/nvim-plugin-template).

Run tests:

```sh
make test
```
