local M = {}

local config = require("neogit.config")
local popup = require("neogit.lib.popup")
local actions = require("neogit.popups.diff.actions")

function M.create(env)
  local diffview = config.check_integration("diffview")
  local commit_selected = (env.section and env.section.name == "log") and type(env.item.name) == "string"

  local ext_diff = require("neogit.integrations.external_diff")
  local ext_available = ext_diff.available()

  local p = popup
    .builder()
    :name("NeogitDiffPopup")
    :group_heading("Diff")
    :action_if(diffview and env.item, "d", "this", actions.this)
    :action_if(diffview and commit_selected, "h", "this..HEAD", actions.this_to_HEAD)
    :action_if(diffview, "r", "range", actions.range)
    :action("p", "paths")
    :new_action_group()
    :action_if(diffview, "u", "unstaged", actions.unstaged)
    :action_if(diffview, "s", "staged", actions.staged)
    :action_if(diffview, "w", "worktree", actions.worktree)
    :new_action_group("Show")
    :action_if(diffview, "c", "Commit", actions.commit)
    :action_if(diffview, "t", "Stash", actions.stash)
    :new_action_group_if(ext_available, "External")
    :action_if(ext_available and env.item, "D", "ext this", actions.ext_this)
    :action_if(ext_available, "U", "ext unstaged", actions.ext_unstaged)
    :action_if(ext_available, "S", "ext staged", actions.ext_staged)
    :env(env)
    :build()

  p:show()

  return p
end

return M
