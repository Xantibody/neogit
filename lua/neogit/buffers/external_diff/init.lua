local Buffer = require("neogit.lib.buffer")
local config = require("neogit.config")

---@class ExternalDiffBuffer
---@field cmd_string string Shell command to execute
---@field env table Environment variables for the process
---@field cwd string Working directory
---@field kind string Buffer display kind
---@field buffer Buffer|nil
local M = {}
M.__index = M

---@param cmd_string string
---@param env table
---@param cwd string
---@return ExternalDiffBuffer
function M:new(cmd_string, env, cwd)
  local instance = {
    cmd_string = cmd_string,
    env = env,
    cwd = cwd,
    kind = config.values.external_diff.layout,
    buffer = nil,
  }

  setmetatable(instance, self)
  return instance
end

function M:close()
  if self.buffer then
    self.buffer:close()
    self.buffer = nil
  end
end

function M:open()
  local close = function()
    self:close()
  end

  local status_maps = config.get_reversed_status_maps()

  self.buffer = Buffer.create {
    name = "NeogitExternalDiff",
    filetype = "NeogitExternalDiff",
    kind = self.kind,
    buftype = false,
    after = function(buffer)
      vim.fn.termopen(self.cmd_string, {
        env = self.env,
        cwd = self.cwd,
        on_exit = function(_, _)
          vim.schedule(function()
            if buffer:is_valid() then
              vim.api.nvim_buf_set_keymap(buffer.handle, "n", "q", "", {
                noremap = true,
                silent = true,
                callback = close,
              })
              vim.api.nvim_buf_set_keymap(buffer.handle, "n", "<esc>", "", {
                noremap = true,
                silent = true,
                callback = close,
              })

              local close_keys = status_maps["Close"]
              if close_keys then
                for _, key in ipairs(type(close_keys) == "table" and close_keys or { close_keys }) do
                  if key ~= "q" then
                    vim.api.nvim_buf_set_keymap(buffer.handle, "n", key, "", {
                      noremap = true,
                      silent = true,
                      callback = close,
                    })
                  end
                end
              end

              vim.cmd("stopinsert")
            end
          end)
        end,
      })
    end,
  }

  return self
end

return M
