local plugin = require("kitty-agent-picker")

local function reset(opts)
  plugin.setup(vim.tbl_deep_extend("force", {
    state_file = vim.fn.tempname(),
  }, opts or {}))
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

describe("layout helpers", function()
  it("assigns direction keys by recency", function()
    local keymap, group_keys = plugin._private.assign_direction_keys({ 2, 3 }, {
      [1] = { col = 0, row = 0 },
      [2] = { col = 1, row = 0, dir = "right" },
      [3] = { col = 2, row = 0, dir = "right" },
    }, {
      [2] = { window_id = 20 },
      [3] = { window_id = 30 },
    }, {
      [30] = 1,
      [20] = 2,
    })

    assert.are.equal(3, keymap.l)
    assert.are.equal(2, keymap.L)
    assert.are.equal("l", group_keys[3])
    assert.are.equal("L", group_keys[2])
  end)

  it("assigns extra letters after two targets in the same direction", function()
    local keymap, group_keys, available_keys = plugin._private.assign_direction_keys({ 2, 3, 4 }, {
      [1] = { col = 0, row = 0 },
      [2] = { col = 1, row = 0, dir = "right" },
      [3] = { col = 2, row = 0, dir = "right" },
      [4] = { col = 3, row = 0, dir = "right" },
    }, {
      [2] = { window_id = 20 },
      [3] = { window_id = 30 },
      [4] = { window_id = 40 },
    }, {
      [40] = 1,
      [30] = 2,
      [20] = 3,
    })

    assert.are.equal(4, keymap.l)
    assert.are.equal(3, keymap.L)
    assert.are.equal(2, keymap.f)
    assert.are.equal("f", group_keys[2])
    assert.are.same({ "l", "L", "f" }, available_keys)
  end)

  it("centers and truncates by display width", function()
    assert.are.equal(" hi ", plugin._private.center_text("hi", 4))
    assert.are.equal("abcd", plugin._private.center_text("abcde", 4))
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

  it("selects the only matching target without opening UI", function()
    local payload = vim.fn.json_encode({
      {
        tabs = {
          {
            active_window_history = { 101, 102 },
            groups = {
              { id = 1, windows = { 101 } },
              { id = 2, windows = { 102 } },
            },
            windows = {
              {
                id = 101,
                is_self = true,
                cwd = "/repo",
                title = "nvim",
                neighbors = { right = { 2 } },
              },
              {
                id = 102,
                cwd = "/repo",
                title = "claude",
                last_reported_cmdline = "claude",
                foreground_processes = {},
                neighbors = { left = { 1 } },
              },
            },
          },
        },
      },
    })
    reset({ kitty_ls_cmd = { "printf", "%s", payload } })
    local actual

    plugin.pick(function(selection)
      actual = selection
    end)

    assert.are.equal(102, actual.id)
    assert.are.equal("/repo", actual.cwd)
    assert.are.equal("Claude", actual.agent_name)
  end)
end)
