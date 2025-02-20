local M = {}
M.buffers = {}

local scnvim = require"scnvim"
local send2sc = scnvim.send
local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event
local utils = require"sc-scratchpad/utils"
local settings = {}

-- Default settings
settings.keymaps = {
	toggle = "<space>",
	send = "<C-E>",
}

settings.open_insertmode = true

settings.border = "double"
settings.position = "50%"
settings.width = "50%"
settings.height = "50%"

settings.firstline = "// Scratchpad"

local function register_commands()
	vim.cmd[[
	command! SCratch lua require('sc-scratchpad').open()
	]]
end

local function copybuffer(fromBuffer, toBuffer)
	local numlines = vim.api.nvim_buf_line_count(fromBuffer)
	local fromlines = vim.api.nvim_buf_get_lines(fromBuffer, 0, numlines, false)
	vim.api.nvim_buf_set_lines(toBuffer, 0, numlines, false, fromlines)
end

local function set_keymaps()

	local mappings = {
		["<cmd>SCratch<CR>"] = settings.keymaps["toggle"]
	}

	-- Toggle scratchpad
	vim.cmd[[augroup scratchpad]]
	vim.cmd[[au!]]
	for command, keymap in pairs(mappings) do
		vim.cmd(
			string.format("au! BufEnter *.scd,*.sc,*.schelp,*.scdoc lua vim.api.nvim_buf_set_keymap(0, 'n', '%s', '%s', {})",
				keymap, command
			)
		)
		vim.cmd(
			string.format("au! BufEnter FileType supercollider lua vim.api.nvim_buf_set_keymap(0, 'n', '%s', '%s', {})",
				keymap, command
			)
		)
	end
	vim.cmd[[augroup END]]
end

local function set_popup_maps(popup)

	local sendfunc = function()
		local bufnr = popup.bufnr
		-- Get text from buffer
		local numLines = vim.api.nvim_buf_line_count(bufnr)
		local buffer_contents = vim.api.nvim_buf_get_lines(bufnr, 0, numLines, false)
		local text = utils.flatten_lines(buffer_contents, true)

		-- Send it off
		send2sc(text)
	end

	local closefunc = function()
		local bufnr = popup.bufnr
		local window = vim.api.nvim_get_current_win()
		vim.api.nvim_win_close(window, true)

	end

	local sendandclosefunc = function()
		local bufnr = popup.bufnr
		sendfunc()
		closefunc()
	end

	-- local previous_buf = function(bufnr)
	-- 	load_old(bufnr)
	-- end

	popup:map("n", settings.keymaps.send, sendandclosefunc, { noremap = true })
	popup:map("i", settings.keymaps.send, sendandclosefunc, { noremap = true })
	popup:map("n", settings.keymaps.toggle, closefunc, { noremap = true })

	-- popup:map("n", settings.keymaps.previous, previous_buf, { noremap = true })

end
-- 	return left_hand_sides
-- end
function M.open()
	local popup = Popup({
		enter = true,
		focusable = true,
		border = {
			style = settings.border,
			highlight = "FloatBorder",
				text = {
				top = "SuperCollider",
				top_align = "center",
				bottom = "scratchpad",
				bottom_align = "center",
				}
		},
		-- border = {
		-- 	style = "rounded",
		-- 	highlight = "FloatBorder",
		-- },
		position = settings.position,
		size = {
			width = settings.width,
			height = settings.height,
		},
		buf_options = {
			modifiable = true,
			readonly = false,
			filetype = "supercollider",
		},
		win_options = {
			winblend = 5,
			winhighlight = "Normal:Normal",
		},
	})

	-- mount/open the component
	popup:mount()

	-- Set keymaps
	set_popup_maps(popup)

	-- Set buffer from saved
	copybuffer(settings.buffer, popup.bufnr)

	-- Set cursor and insert mode
	local numlines = vim.api.nvim_buf_line_count(popup.bufnr)
	vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), {numlines,0})

	if settings.open_insertmode then
		vim.cmd[[startinsert]]
	end

	-- unmount component when cursor leaves buffer
	popup:on(event.WinLeave, function()

		-- Copy buffer
		copybuffer(popup.bufnr, settings.buffer)

		-- Close buffer
		popup:unmount()

		-- Stop insertmode
		vim.cmd[[stopinsert]]
	end)

end

local function apply_user_settings(user_settings)
	for key, value in pairs(user_settings) do
		if key ~= nil then
			settings[key] = value
		end
	end
end

function M.print_settings()
	for settingName, settingVal in pairs(settings) do
		print(settingName .. ": " .. tostring(settingVal))
	end
end

function M.setup(user_settings)

	if user_settings then
		apply_user_settings(user_settings)
	end

	register_commands()
	set_keymaps()

	-- Create scratchpad buffer
	settings.buffer = vim.api.nvim_create_buf(false, true);
	vim.api.nvim_buf_set_lines(settings.buffer, 0, 1, false, {settings.firstline, ""});

end

return M
