local M = {}

local config = require("neogit.config")
local git = require("neogit.lib.git")

local presets = {
  difftastic = {
    cmd = "difft",
    mode = "external_diff",
    args = function(width)
      return { "--color=always", "--width=" .. width }
    end,
    git_flags = {
      show = { "--ext-diff" },
      log = { "--ext-diff", "-p" },
      diff = {},
    },
  },
  delta = {
    cmd = "delta",
    mode = "pager",
    args = function(width)
      return { "--width=" .. width }
    end,
    git_flags = {
      show = {},
      log = { "-p" },
      diff = {},
    },
  },
}

---@return boolean
function M.available()
  local ext_config = config.values.external_diff
  if not ext_config or not ext_config.enabled then
    return false
  end

  local tool = ext_config.tool
  local preset = type(tool) == "string" and presets[tool] or nil
  local cmd = preset and preset.cmd or (type(tool) == "table" and tool.cmd or nil)

  if not cmd then
    return false
  end

  return vim.fn.executable(cmd) == 1
end

---@return table|nil preset, table|nil tool_config
local function get_tool_config()
  local ext_config = config.values.external_diff
  local tool = ext_config.tool

  if type(tool) == "string" then
    return presets[tool], nil
  elseif type(tool) == "table" then
    return nil, tool
  end

  return nil, nil
end

---@param preset table
---@param git_subcmd string
---@param width number
---@return table env, string[] flags
local function build_cmd_parts(preset, git_subcmd, width)
  local env = {}
  local flags = {}
  local args = preset.args(width)
  local cmd_with_args = preset.cmd .. " " .. table.concat(args, " ")

  if preset.mode == "external_diff" then
    env.GIT_EXTERNAL_DIFF = cmd_with_args
  elseif preset.mode == "pager" then
    env.GIT_PAGER = cmd_with_args
  end

  local git_flags = preset.git_flags[git_subcmd] or {}
  for _, flag in ipairs(git_flags) do
    table.insert(flags, flag)
  end

  return env, flags
end

---@param section_name string|nil
---@param item_name string|nil
---@param opts table|nil
function M.open(section_name, item_name, opts)
  opts = opts or {}

  if not M.available() then
    vim.notify("External diff tool is not available", vim.log.levels.WARN)
    return
  end

  local ExternalDiffBuffer = require("neogit.buffers.external_diff")

  local preset, custom = get_tool_config()
  local tool = preset or custom
  if not tool then
    return
  end

  local width = vim.o.columns
  local git_subcmd = "diff"
  local extra_args = {}

  if section_name == "staged" then
    table.insert(extra_args, "--cached")
  elseif
    section_name == "recent"
    or section_name == "log"
    or (section_name and section_name:match("unmerged$"))
  then
    git_subcmd = "show"
    if item_name then
      local commit = type(item_name) == "string" and item_name:match("[a-f0-9]+") or item_name
      table.insert(extra_args, commit)
    end
  elseif section_name == "range" and item_name then
    table.insert(extra_args, item_name)
  elseif (section_name == "stashes" or section_name == "commit") and item_name then
    git_subcmd = "show"
    table.insert(extra_args, item_name)
  end

  local env, flags = build_cmd_parts(tool, git_subcmd, width)

  local git_executable = config.get_git_executable()
  local cmd_parts = { git_executable, git_subcmd }

  for _, flag in ipairs(flags) do
    table.insert(cmd_parts, flag)
  end

  for _, arg in ipairs(extra_args) do
    table.insert(cmd_parts, arg)
  end

  if item_name and (section_name == "unstaged" or section_name == "staged") then
    table.insert(cmd_parts, "--")
    table.insert(cmd_parts, item_name)
  end

  local cmd_string = table.concat(cmd_parts, " ")
  local cwd = git.repo.worktree_root

  ExternalDiffBuffer:new(cmd_string, env, cwd):open()
end

return M
