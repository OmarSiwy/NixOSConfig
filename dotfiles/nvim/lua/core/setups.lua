-- NvimTree
require("nvim-tree").setup({
	view = {
		side = "right",
		width = 35,
	},
	renderer = {
		indent_markers = {
			enable = true,
		},
	},
	filters = {
		git_ignored = true,  -- Hide files ignored by git
		dotfiles = false,    -- Show dotfiles (including .gitignore)
		git_clean = false,   -- Show files with no git status
		no_buffer = false,
		custom = {},
		exclude = {}
	},
	git = {
		enable = true,       -- Required for git_ignored filter to work
		ignore = false,      -- Show git-ignored files with different styling
	},
})

-- Alpha startup screen / dashboard
require("alpha").setup(require("alpha.themes.startify").config)
require("alpha.themes.dashboard").section.footer.val = require("alpha.fortune")() -- Quotes

-- Lualine status bar
require("lualine").setup({
	options = {
		theme = "auto",
		component_separators = " ",
		section_separators = { left = "", right = "" },
	},
})

-- Nvim Autopairs
require("nvim-autopairs").setup()

-- Git signs
require("gitsigns").setup()

-- Line highlighting
require("ibl").setup({
	indent = { char = "┊" },
	scope = { enabled = false },
})

-- Hex color highlighting
require("colorizer").setup()

-- Rainbow delimiters (bracket colorizing)
local rainbow_delimiters = require("rainbow-delimiters")
vim.g.rainbow_delimiters = {
	strategy = {
		[""] = rainbow_delimiters.strategy["global"],
	},
	query = {
		[""] = "rainbow-delimiters",
	},
	blacklist = { "NvimTree" },
}
