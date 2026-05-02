if vim.g.loaded_kitty_agent_picker == 1 then
  return
end
vim.g.loaded_kitty_agent_picker = 1

vim.api.nvim_create_user_command("KittyAgentPick", function(opts)
  require("kitty-agent-picker").pick({ target = opts.args ~= "" and opts.args or nil }, function(selection)
    if not selection then
      vim.notify("No matching Kitty agent window", vim.log.levels.INFO)
      return
    end
    vim.notify(
      string.format(
        "Selected %s window %s: %s",
        selection.agent_name or "agent",
        selection.id,
        selection.cwd or selection.title or ""
      ),
      vim.log.levels.INFO
    )
  end)
end, {
  nargs = "?",
  complete = function()
    return vim.tbl_keys(require("kitty-agent-picker").config.targets)
  end,
  desc = "Pick a Claude/Codex agent window in the current Kitty tab",
})
