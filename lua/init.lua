--- @class RecentFilesNvim
local RF = {}

-- Load the Telescope extension module
local extension = require("telescope._extensions.recent_files")

-- Export a setup function (optional public API)
--- @return nil
function RF.setup()
	-- Delegate to the extension's setup (already called automatically, but exposed here for clarity)
	require("telescope._extensions.recent_files.setup").setup()
end

-- Export the picker function for direct use
--- @param opts table|nil Options for the picker
--- @return nil
function RF.recent_files(opts)
	extension.recent_files(opts)
end

return RF
