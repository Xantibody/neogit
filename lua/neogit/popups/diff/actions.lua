local M = {}
local diffview = require("neogit.integrations.diffview")
local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")
local util = require("neogit.lib.util")
local git = require("neogit.lib.git")
local input = require("neogit.lib.input")

-- aka "dwim" = do what I mean
function M.this(popup)
  popup:close()

  local item = popup:get_env("item")
  local section = popup:get_env("section")

  if section and section.name and item and item.name then
    diffview.open(section.name, item.name, { only = true })
  elseif section.name then
    diffview.open(section.name, nil, { only = true })
  elseif item.name then
    diffview.open("range", item.name .. "..HEAD")
  end
end

function M.this_to_HEAD(popup)
  popup:close()

  local item = popup:get_env("item")
  if item then
    if item.name then
      diffview.open("range", item.name .. "..HEAD")
    end
  end
end

function M.range(popup)
  local commit
  local item = popup:get_env("item")
  local section = popup:get_env("section")
  if section and (section.name == "log" or section.name == "recent") then
    commit = item and item.name
  end

  local options = util.deduplicate(
    util.merge(
      { commit, git.branch.current() or "HEAD" },
      git.branch.get_all_branches(false),
      git.tag.list(),
      git.refs.heads()
    )
  )

  local range_from = FuzzyFinderBuffer.new(options):open_async {
    prompt_prefix = "Diff for range from",
    refocus_status = false,
  }

  if not range_from then
    return
  end

  local range_to = FuzzyFinderBuffer.new(options)
    :open_async { prompt_prefix = "Diff from " .. range_from .. " to", refocus_status = false }
  if not range_to then
    return
  end

  local choices = {
    "&1. Range (a..b)",
    "&2. Symmetric Difference (a...b)",
    "&3. Cancel",
  }
  local choice = input.get_choice("Select type", { values = choices, default = #choices })

  popup:close()
  if choice == "1" then
    diffview.open("range", range_from .. ".." .. range_to)
  elseif choice == "2" then
    diffview.open("range", range_from .. "..." .. range_to)
  end
end

function M.worktree(popup)
  popup:close()
  diffview.open("worktree")
end

function M.staged(popup)
  popup:close()
  diffview.open("staged", nil, { only = true })
end

function M.unstaged(popup)
  popup:close()
  diffview.open("unstaged", nil, { only = true })
end

function M.stash(popup)
  popup:close()

  local selected = FuzzyFinderBuffer.new(git.stash.list()):open_async { refocus_status = false }
  if selected then
    diffview.open("stashes", selected)
  end
end

function M.commit(popup)
  popup:close()

  local options = util.merge(git.refs.list_branches(), git.refs.list_tags(), git.refs.heads())

  local selected = FuzzyFinderBuffer.new(options):open_async { refocus_status = false }
  if selected then
    diffview.open("commit", selected)
  end
end

-- External diff actions

function M.ext_this(popup)
  popup:close()

  local external_diff = require("neogit.integrations.external_diff")
  local section = popup:get_env("section")
  local item = popup:get_env("item")

  if section and section.name and item and item.name then
    external_diff.open(section.name, item.name)
  elseif section and section.name then
    external_diff.open(section.name)
  end
end

function M.ext_unstaged(popup)
  popup:close()

  local external_diff = require("neogit.integrations.external_diff")
  external_diff.open("unstaged")
end

function M.ext_staged(popup)
  popup:close()

  local external_diff = require("neogit.integrations.external_diff")
  external_diff.open("staged")
end

return M
