local M = {}

local session_files_set = {}
local session_files = {}
local edited_files_cache = nil
local project_root = vim.loop.cwd() -- luacheck: ignore 113/vim

-- Add a file to session_files
local function track_session_file()
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
		and filepath:find(project_root, 1, true) == 1
		and not session_files_set[filepath]
	then
		session_files_set[filepath] = true
		table.insert(session_files, 1, filepath)
		edited_files_cache = nil
	end
end

-- Invalidate cache on file write
local function invalidate_cache()
	edited_files_cache = nil
end

-- Helper function to get edited files with caching
local function get_edited_files()
	if edited_files_cache then
		return edited_files_cache
	end
	edited_files_cache = {}
	for _, filepath in ipairs(session_files) do
		local buf = vim.fn.bufnr(filepath)
		if buf ~= -1 then
			if vim.bo[buf].modified then
				table.insert(edited_files_cache, filepath)
			else
				local stat = vim.loop.fs_stat(filepath) -- luacheck: ignore 113/vim
				if stat and stat.mtime.sec > vim.g.session_start_time then
					table.insert(edited_files_cache, filepath)
				end
			end
		end
	end
	return edited_files_cache
end

-- Set session start time for mtime comparison
vim.g.session_start_time = vim.g.session_start_time or os.time()

-- Helper function to get filename relative to project root
local function get_relative_filename(filepath)
	if filepath:find(project_root, 1, true) == 1 then
		return filepath:sub(#project_root + 2)
	end
	return filepath
end

-- Custom picker for session files
local function recent_files_picker(opts)
	opts = opts or {}
	local action_state = require("telescope.actions.state")
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values

	local show_edited_only = vim.g.recent_files_show_edited_only or false
	local prefer_current_buffer = vim.g.recent_files_prefer_current_buffer or false

	local function get_entries()
		return show_edited_only and get_edited_files() or session_files
	end

	local function refresh_picker(prompt_bufnr)
		local current_picker = action_state.get_current_picker(prompt_bufnr)
		current_picker:refresh(
			finders.new_table({
				results = get_entries(),
				entry_maker = function(entry)
					local is_edited = vim.tbl_contains(get_edited_files(), entry)
					local relative_name = get_relative_filename(entry)
					return {
						value = entry,
						display = (is_edited and "[*] " or "") .. relative_name,
						ordinal = entry,
					}
				end,
			}),
			{ reset_prompt = false }
		)
	end

	local picker = pickers.new(opts, {
		prompt_title = "Recent Files (Session)",
		finder = finders.new_table({
			results = get_entries(),
			entry_maker = function(entry)
				local is_edited = vim.tbl_contains(get_edited_files(), entry)
				local relative_name = get_relative_filename(entry)
				return {
					value = entry,
					display = (is_edited and "[*] " or "") .. relative_name,
					ordinal = entry,
				}
			end,
		}),
		sorter = conf.generic_sorter(opts),
		layout_config = {
			width = 0.4,
			height = 0.5,
			prompt_position = "bottom",
			preview_cutoff = 1,
		},
		layout_strategy = "vertical",
		display_stat = false,
		initial_mode = "normal",
		attach_mappings = function(prompt_bufnr, map)
			local toggle_edited = function()
				show_edited_only = not show_edited_only
				vim.g.recent_files_show_edited_only = show_edited_only
				refresh_picker(prompt_bufnr)
			end

			local delete_entry = function()
				local entry = action_state.get_selected_entry()
				if entry and entry.value then
					local filepath = entry.value
					session_files_set[filepath] = nil
					for i, v in ipairs(session_files) do
						if v == filepath then
							table.remove(session_files, i)
							break
						end
					end
					edited_files_cache = nil
					vim.notify("Deleted: " .. get_relative_filename(filepath), vim.log.levels.INFO)
					refresh_picker(prompt_bufnr)
				end
			end

			local toggle_prefer_current_buffer = function()
				prefer_current_buffer = not prefer_current_buffer
				vim.g.recent_files_prefer_current_buffer = prefer_current_buffer
				local current_picker = action_state.get_current_picker(prompt_bufnr)
				local current_file = vim.api.nvim_buf_get_name(0)
				if prefer_current_buffer and current_file and session_files_set[current_file] then
					for i, entry in ipairs(current_picker.finder.results) do
						if entry == current_file then
							current_picker:set_selection(i - 1)
							break
						end
					end
				end
			end

			local copy_relative_path = function()
				local entry = action_state.get_selected_entry()
				if entry and entry.value then
					local relative_path = get_relative_filename(entry.value)
					vim.fn.setreg("+", relative_path)
					vim.notify("Copied relative path: " .. relative_path, vim.log.levels.INFO)
				end
			end

			local copy_absolute_path = function()
				local entry = action_state.get_selected_entry()
				if entry and entry.value then
					vim.fn.setreg("+", entry.value)
					vim.notify("Copied absolute path: " .. entry.value, vim.log.levels.INFO)
				end
			end

			map("n", "e", toggle_edited)
			map("n", "D", delete_entry)
			map("n", "P", toggle_prefer_current_buffer)
			map("n", "c", copy_relative_path)
			map("n", "<S-C>", copy_absolute_path)

			return true
		end,
	})

	if prefer_current_buffer then
		local current_file = vim.api.nvim_buf_get_name(0)
		if current_file and session_files_set[current_file] then
			for i, entry in ipairs(picker.finder.results) do
				if entry == current_file then
					picker:set_selection(i - 1)
					break
				end
			end
		end
	end

	picker:find()
end

-- Setup function to initialize the plugin
local function setup()
	-- Track all currently loaded buffers
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) then
			vim.api.nvim_buf_call(buf, track_session_file)
		end
	end

	-- Register autocommands
	vim.api.nvim_create_autocmd({ "BufEnter" }, {
		callback = track_session_file,
		desc = "Track files opened in the current session",
	})
	vim.api.nvim_create_autocmd({ "BufWritePost" }, {
		callback = invalidate_cache,
		desc = "Invalidate edited files cache on write",
	})

	-- Register Telescope extension
	pcall(function()
		require("telescope").register_extension({
			exports = {
				recent_files = recent_files_picker,
			},
		})
	end)

	-- Default keymap
	vim.keymap.set(
		"n",
		"<leader>fr",
		"<cmd>Telescope recent_files recent_files<CR>",
		{ desc = "Recent Files (Session)" }
	)

	-- Debug command
	vim.api.nvim_create_user_command("PrintSessionFilesCount", function()
		print("Number of session files: " .. #session_files)
	end, { desc = "Print the number of tracked session files" })
end

-- Automatically call setup when the module is loaded
setup()

-- Export the picker function for manual use if desired
M.recent_files = recent_files_picker

return M
