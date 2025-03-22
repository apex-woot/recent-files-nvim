--- @class RecentFilesCore
local RF = {}

-- State
--- @type table<string, boolean> Hash set for O(1) lookups
RF.session_files_set = {}
--- @type string[] Ordered list of session file paths
RF.session_files = {}
--- @type string[]|nil Cached list of edited files
RF.edited_files_cache = nil
--- @type string Project root directory
RF.project_root = vim.loop.cwd() -- luacheck: ignore 113/vim

-- Helper function to get edited files with caching
--- @return string[] Edited files
function RF.get_edited_files()
	if RF.edited_files_cache then
		return RF.edited_files_cache
	end
	--- @type string[]
	RF.edited_files_cache = {}
	for _, filepath in ipairs(RF.session_files) do
		local buf = vim.fn.bufnr(filepath)
		if buf ~= -1 then
			if vim.bo[buf].modified then
				table.insert(RF.edited_files_cache, filepath)
			else
				--- @type uv.fs_stat_t|nil
				local stat = vim.loop.fs_stat(filepath) -- luacheck: ignore 113/vim
				if stat and stat.mtime.sec > vim.g.session_start_time then
					table.insert(RF.edited_files_cache, filepath)
				end
			end
		end
	end
	return RF.edited_files_cache
end

-- Helper function to get filename relative to project root
--- @param filepath string Absolute file path
--- @return string Relative file path
function RF.get_relative_filename(filepath)
	if filepath:find(RF.project_root, 1, true) == 1 then
		return filepath:sub(#RF.project_root + 2)
	end
	return filepath
end

-- Function to add a file to session_files
--- @return nil
function RF.track_session_file()
	local filepath = vim.api.nvim_buf_get_name(0)
	local buf = vim.api.nvim_get_current_buf()
	local buftype = vim.bo[buf].buftype
	local filetype = vim.bo[buf].filetype
	if filepath == "" or vim.fn.isdirectory(filepath) ~= 0 then
		return -- Early exit for empty or directory buffers
	end
	if
		buftype == ""
		and filetype ~= "neo-tree"
		and not filepath:match("neo%-tree filesystem")
		and filepath:find(RF.project_root, 1, true) == 1
		and not RF.session_files_set[filepath]
	then
		RF.session_files_set[filepath] = true
		table.insert(RF.session_files, 1, filepath)
		RF.edited_files_cache = nil
	end
end

-- Invalidate cache on file write
--- @return nil
function RF.invalidate_cache()
	RF.edited_files_cache = nil
end

-- Set session start time for mtime comparison
vim.g.session_start_time = vim.g.session_start_time or os.time()

return RF
