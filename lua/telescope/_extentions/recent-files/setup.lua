--- @class RecentFilesSetup
local RF = {}

local core = require("telescope._extensions.recent_files.core")

-- Setup function to initialize the plugin
--- @return nil
function RF.setup()
	-- Track all currently loaded buffers
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) then
			vim.api.nvim_buf_call(buf, core.track_session_file)
		end
	end

	-- Register autocommands
	vim.api.nvim_create_autocmd({ "BufEnter" }, {
		callback = core.track_session_file,
		desc = "Track files opened in the current session",
	})
	vim.api.nvim_create_autocmd({ "BufWritePost" }, {
		callback = core.invalidate_cache,
		desc = "Invalidate edited files cache on write",
	})

	-- Default keymap
	vim.keymap.set(
		"n",
		"<leader>fr",
		"<cmd>Telescope recent_files recent_files<CR>",
		{ desc = "Recent Files (Session)" }
	)

	-- Debug command
	vim.api.nvim_create_user_command("PrintSessionFilesCount", function()
		print("Number of session files: " .. #core.session_files)
	end, { desc = "Print the number of tracked session files" })
end

return RF
