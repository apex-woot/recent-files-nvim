--- @class RecentFilesExtension
local RF = {}

-- Load submodules
local core = require("telescope._extensions.recent_files.core")
local picker = require("telescope._extensions.recent_files.picker")
local setup = require("telescope._extensions.recent_files.setup")

-- Export the picker function as required by Telescope
--- @param opts table|nil Options for the picker
RF.recent_files = function(opts)
	picker.recent_files_picker(opts)
end

-- Automatically run setup when the module is loaded
setup.setup()

return RF
