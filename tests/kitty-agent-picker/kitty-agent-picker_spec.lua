local plugin = require("kitty-agent-picker")

local function reset(opts)
  plugin.setup(opts or {})
end

local function payload_with_windows(windows)
  return vim.fn.json_encode({
    {
      tabs = {
        {
          windows = windows,
        },
      },
    },
  })
end

describe("setup", function()
  before_each(function()
    reset()
  end)

  it("keeps default targets", function()
    assert.is_not_nil(plugin.config.targets.claude)
    assert.is_not_nil(plugin.config.targets.codex)
    assert.is_not_nil(plugin.config.targets.agent)
  end)

  it("accepts custom targets", function()
    reset({
      targets = {
        aider = {
          display_name = "Aider",
          patterns = { "aider" },
        },
      },
    })

    assert.are.same({ "aider" }, plugin.config.targets.aider.patterns)
  end)
end)

describe("pick", function()
  before_each(function()
    reset()
  end)

  it("returns nil when kitty is unreachable", function()
    reset({ kitty_ls_cmd = { "false" } })
    local actual = "unset"

    plugin.pick(function(selection)
      actual = selection
    end)

    assert.is_nil(actual)
  end)

  it("selects the only matching target without opening native UI", function()
    local payload = payload_with_windows({
      {
        id = 101,
        is_self = true,
        cwd = "/repo",
        title = "nvim",
      },
      {
        id = 102,
        cwd = "/repo",
        title = "claude",
        last_reported_cmdline = "claude",
        foreground_processes = {},
      },
    })
    reset({ kitty_ls_cmd = { "printf", "%s", payload }, kitty_select_window_cmd = { "false" } })
    local actual

    plugin.pick(function(selection)
      actual = selection
    end)

    assert.are.equal(102, actual.id)
    assert.are.equal("/repo", actual.cwd)
    assert.are.equal("Claude", actual.agent_name)
  end)

  it("uses native selection when multiple targets match", function()
    local payload = payload_with_windows({
      {
        id = 101,
        is_self = true,
        cwd = "/repo",
        title = "nvim",
      },
      {
        id = 102,
        cwd = "/claude",
        title = "claude",
        last_reported_cmdline = "claude",
        foreground_processes = {},
      },
      {
        id = 103,
        cwd = "/codex",
        title = "codex",
        last_reported_cmdline = "codex",
        foreground_processes = {},
      },
    })
    reset({
      kitty_ls_cmd = { "printf", "%s", payload },
      kitty_select_window_cmd = { "sh", "-c", "printf '103\\n'" },
    })
    local actual

    plugin.pick({ target = "agent" }, function(selection)
      actual = selection
    end)

    assert.are.equal(103, actual.id)
    assert.are.equal("/codex", actual.cwd)
    assert.are.equal("Codex", actual.agent_name)
  end)

  it("returns nil when native selection chooses a non-target window", function()
    local payload = payload_with_windows({
      {
        id = 101,
        is_self = true,
        cwd = "/repo",
        title = "nvim",
      },
      {
        id = 102,
        cwd = "/claude",
        title = "claude",
        last_reported_cmdline = "claude",
        foreground_processes = {},
      },
      {
        id = 103,
        cwd = "/codex",
        title = "codex",
        last_reported_cmdline = "codex",
        foreground_processes = {},
      },
      {
        id = 104,
        cwd = "/shell",
        title = "zsh",
        foreground_processes = {},
      },
    })
    reset({
      kitty_ls_cmd = { "printf", "%s", payload },
      kitty_select_window_cmd = { "sh", "-c", "printf '104\\n'" },
    })
    local actual = "unset"

    plugin.pick({ target = "agent" }, function(selection)
      actual = selection
    end)

    assert.is_nil(actual)
  end)

  it("returns nil when native selection is cancelled", function()
    local payload = payload_with_windows({
      {
        id = 101,
        is_self = true,
        cwd = "/repo",
        title = "nvim",
      },
      {
        id = 102,
        cwd = "/claude",
        title = "claude",
        last_reported_cmdline = "claude",
        foreground_processes = {},
      },
      {
        id = 103,
        cwd = "/codex",
        title = "codex",
        last_reported_cmdline = "codex",
        foreground_processes = {},
      },
    })
    reset({
      kitty_ls_cmd = { "printf", "%s", payload },
      kitty_select_window_cmd = { "false" },
    })
    local actual = "unset"

    plugin.pick({ target = "agent" }, function(selection)
      actual = selection
    end)

    assert.is_nil(actual)
  end)

  it("supports custom targets", function()
    local payload = payload_with_windows({
      {
        id = 101,
        is_self = true,
        cwd = "/repo",
        title = "nvim",
      },
      {
        id = 102,
        cwd = "/aider",
        title = "aider",
        last_reported_cmdline = "aider",
        foreground_processes = {},
      },
    })
    reset({
      kitty_ls_cmd = { "printf", "%s", payload },
      targets = {
        aider = {
          display_name = "Aider",
          patterns = { "aider" },
        },
      },
    })
    local actual

    plugin.pick({ target = "aider" }, function(selection)
      actual = selection
    end)

    assert.are.equal(102, actual.id)
    assert.are.equal("Aider", actual.agent_name)
  end)
end)
