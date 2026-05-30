local languages = require("core.languages")

-- Build list of treesitter parsers from languages.lua
local parsers = {}
for _, lang in ipairs(languages) do
	if lang.treesitter then
		for _, parser in ipairs(lang.treesitter) do
			table.insert(parsers, parser)
		end
	end
end

require("nvim-treesitter.configs").setup({
	-- Auto-generated from languages.lua
	ensure_installed = parsers,

	sync_install = false,
	auto_install = false,
	ignore_install = {},

	highlight = {
		enable = true,
		-- Disable for large files (performance)
		disable = function(lang, buf)
			local max_filesize = 100 * 1024 -- 100 KB
			local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
			if ok and stats and stats.size > max_filesize then
				return true
			end
		end,
		additional_vim_regex_highlighting = false,
	},

	indent = {
		enable = true,
	},

	textobjects = {
		select = {
			enable = true,
			lookahead = true,
			keymaps = {
				["af"] = "@function.outer",
				["if"] = "@function.inner",
				["ac"] = "@class.outer",
				["ic"] = "@class.inner",
			},
		},
	},
})

-- Treesitter context (shows current function/class at top)
require("treesitter-context").setup({
	enable = true,
	max_lines = 0,
	min_window_height = 0,
	line_numbers = true,
	multiline_threshold = 20,
	trim_scope = "outer",
	mode = "cursor",
	separator = nil,
})
