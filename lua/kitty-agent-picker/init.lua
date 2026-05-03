local M = {}

---@class KittyAgentPickerTarget
---@field display_name string
---@field patterns string[]

---@class KittyAgentPickerConfig
---@field kitty_ls_cmd string[]
---@field kitty_select_window_cmd string[]
---@field targets table<string, KittyAgentPickerTarget>

local defaults = {
  kitty_ls_cmd = { "kitty", "@", "ls" },
  kitty_select_window_cmd = { "kitten", "@", "select-window", "--self", "--exclude-active" },
  targets = {
    claude = {
      display_name = "Claude",
      patterns = { "claude" },
    },
    codex = {
      display_name = "Codex",
      patterns = { "codex" },
    },
    agent = {
      display_name = "Agent",
      patterns = { "claude", "codex" },
    },
  },
}

M.config = vim.deepcopy(defaults)

---@param opts KittyAgentPickerConfig?
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
end

local function normalize_target(target)
  target = target or "claude"
  return M.config.targets[target] and target or "claude"
end

local function has_target(s, target)
  if type(s) ~= "string" then
    return false
  end
  s = s:lower()
  for _, pattern in ipairs(M.config.targets[target].patterns or {}) do
    if s:find(pattern:lower(), 1, true) ~= nil then
      return true
    end
  end
  return false
end

local function detect_agent_name(s, target)
  if type(s) ~= "string" then
    return nil
  end
  s = s:lower()
  for key, spec in pairs(M.config.targets) do
    if key ~= "agent" then
      for _, pattern in ipairs(spec.patterns or {}) do
        if s:find(pattern:lower(), 1, true) ~= nil and has_target(spec.display_name, target) then
          return spec.display_name
        end
      end
    end
  end
  return nil
end

local function window_matches_target(window, target)
  local agent_name = detect_agent_name(window.last_reported_cmdline, target) or detect_agent_name(window.title, target)
  if agent_name then
    return true, agent_name
  end
  for _, proc in ipairs(window.foreground_processes or {}) do
    for _, arg in ipairs(proc.cmdline or {}) do
      agent_name = detect_agent_name(arg, target)
      if agent_name then
        return true, agent_name
      end
    end
  end
  return false, nil
end

local function selection_from_meta(meta, display_name)
  return {
    id = meta.window_id,
    cwd = meta.cwd,
    title = meta.title,
    agent_name = meta.agent_name or display_name,
  }
end

local function collect_target_windows(target)
  local output = vim.fn.system(M.config.kitty_ls_cmd)
  if vim.v.shell_error ~= 0 then
    return nil
  end
  local ok, data = pcall(vim.fn.json_decode, output)
  if not ok or not data then
    return nil
  end

  for _, os_window in ipairs(data) do
    for _, tab in ipairs(os_window.tabs or {}) do
      local self_window_id = nil
      for _, w in ipairs(tab.windows or {}) do
        if w.is_self then
          self_window_id = w.id
          break
        end
      end

      if self_window_id then
        local targets = {}
        local targets_by_id = {}
        for _, w in ipairs(tab.windows or {}) do
          if w.id ~= self_window_id then
            local matches_target, agent_name = window_matches_target(w, target)
            if matches_target then
              local meta = {
                window_id = w.id,
                cwd = w.cwd,
                title = w.title,
                agent_name = agent_name,
              }
              table.insert(targets, meta)
              targets_by_id[w.id] = meta
            end
          end
        end

        return {
          targets = targets,
          targets_by_id = targets_by_id,
        }
      end
    end
  end
  return nil
end

local function select_window_id(display_name)
  local cmd = vim.deepcopy(M.config.kitty_select_window_cmd)
  table.insert(cmd, "--title")
  table.insert(cmd, "Pick " .. display_name)

  local output = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    return nil
  end
  output = vim.trim(output)
  if output == "" then
    return nil
  end
  return tonumber(output)
end

---@class KittyAgentPickerSelection
---@field id integer
---@field cwd string
---@field title string
---@field agent_name string

---@class KittyAgentPickerPickOpts
---@field target string?

---@param opts KittyAgentPickerPickOpts|fun(selection: KittyAgentPickerSelection?)?
---@param callback fun(selection: KittyAgentPickerSelection?)?
function M.pick(opts, callback)
  if type(opts) == "function" then
    callback = opts
    opts = {}
  end
  opts = opts or {}
  callback = callback or function() end

  local target = normalize_target(opts.target)
  local display_name = M.config.targets[target].display_name

  local found = collect_target_windows(target)
  if not found or #found.targets == 0 then
    callback(nil)
    return
  end

  if #found.targets == 1 then
    callback(selection_from_meta(found.targets[1], display_name))
    return
  end

  local selected_id = select_window_id(display_name)
  local meta = selected_id and found.targets_by_id[selected_id] or nil
  callback(meta and selection_from_meta(meta, display_name) or nil)
end

M._private = {
  collect_target_windows = collect_target_windows,
  detect_agent_name = detect_agent_name,
  select_window_id = select_window_id,
  window_matches_target = window_matches_target,
}

return M
