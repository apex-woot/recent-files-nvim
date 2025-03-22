--- @class RecentFilesPicker
local RF = {}

local core = require("telescope._extensions.recent_files.core")

-- Custom picker for session files
--- @param opts table|nil Options for the picker
--- @return nil
function RF.recent_files_picker(opts)
	opts = opts or {}
	local action_state = require("telescope.actions.state")
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values

	--- @type boolean
	local show_edited_only = vim.g.recent_files_show_edited_only or false
	--- @type boolean
	local prefer_current_buffer = vim.g.recent_files_prefer_current_buffer or false

	--- @return string[]
	local function get_entries()
		return show_edited_only and core.get_edited_files() or core.session_files
	end

	--- @param prompt_bufnr number
	--- @return nil
	local function refresh_picker(prompt_bufnr)
		--- @type TelescopePicker
		local current_picker = action_state.get_current_picker(prompt_bufnr)
		current_picker:refresh(
			finders.new_table({
				results = get_entries(),
				--- @param entry string
				--- @return table
				entry_maker = function(entry)
					local is_edited = vim.tbl_contains(core.get_edited_files(), entry)
					local relative_name = core.get_relative_filename(entry)
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

	--- @type TelescopePicker
	local picker = pickers.new(opts, {
		prompt_title = "Recent Files (Session)",
		finder = finders.new_table({
			results = get_entries(),
			--- @param entry string
			--- @return table
			entry_maker = function(entry)
				local is_edited = vim.tbl_contains(core.get_edited_files(), entry)
				local relative_name = core.get_relative_filename(entry)
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
		--- @param prompt_bufnr number
		--- @param map fun(mode: string, key: string, fn: function): nil
		--- @return boolean
		attach_mappings = function(prompt_bufnr, map)
			--- @return nil
			local toggle_edited = function()
				show_edited_only = not show_edited_only
				vim.g.recent_files_show_edited_only = show_edited_only
				refresh_picker(prompt_bufnr)
			end

			--- @return nil
			local delete_entry = function()
				--- @type { value: string }|nil
				local entry = action_state.get_selected_entry()
				if entry and entry.value then
					local filepath = entry.value
					core.session_files_set[filepath] = nil
					for i, v in ipairs(core.session_files) do
						if v == filepath then
							table.remove(core.session_files, i)
							break
						end
					end
					core.invalidate_cache()
					vim.notify("Deleted: " .. core.get_relative_filename(filepath), vim.log.levels.INFO)
					refresh_picker(prompt_bufnr)
				end
			end

			--- @return nil
			local toggle_prefer_current_buffer = function()
				prefer_current_buffer = not prefer_current_buffer
				vim.g.recent_files_prefer_current_buffer = prefer_current_buffer
				--- @type TelescopePicker
				local current_picker = action_state.get_current_picker(prompt_bufnr)
				local current_file = vim.api.nvim_buf_get_name(0)
				if prefer_current_buffer and current_file and core.session_files_set[current_file] then
					for i, entry in ipairs(current_picker.finder.results) do
						if entry == current_file then
							current_picker:set_selection(i - 1)
							break
						end
					end
				end
			end

			--- @return nil
			local copy_relative_path = function()
				--- @type { value: string }|nil
				local entry = action_state.get_selected_entry()
				if entry and entry.value then
					local relative_path = core.get_relative_filename(entry.value)
					vim.fn.setreg("+", relative_path)
					vim.notify("Copied relative path: " .. relative_path, vim.log.levels.INFO)
				end
			end

			--- @return nil
			local copy_absolute_path = function()
				--- @type { value: string }|nil
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
		if current_file and core.session_files_set[current_file] then
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

return RF
