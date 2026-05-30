-- PLUGINS

return {
	-------- Appearance
	{
		"catppuccin/nvim",
		name = "catppuccin",
		priority = 1000,
		lazy = false,
	},

	"folke/tokyonight.nvim",

	"goolord/alpha-nvim", -- Startup screen
	"nvim-lualine/lualine.nvim", -- Status line

	-------- Neovim Tools
	"mbbill/undotree", -- Undo tree

	{
		"nvim-tree/nvim-tree.lua", -- Nvim Tree, NerdTree alternative
		dependencies = { "nvim-tree/nvim-web-devicons" },
	},
	{
		"nvim-treesitter/nvim-treesitter", -- Treesitter
		build = ":TSUpdate",
		dependencies = {
			"nvim-treesitter/nvim-treesitter-textobjects",
			"nvim-treesitter/nvim-treesitter-context",
		},
	},
	{
		"hrsh7th/nvim-cmp", -- Auto completion
		dependencies = {
			"hrsh7th/cmp-nvim-lsp",
			"hrsh7th/cmp-buffer",
			"hrsh7th/cmp-path",
			"hrsh7th/cmp-cmdline",

			"hrsh7th/cmp-vsnip",
			"hrsh7th/vim-vsnip",
		},
	},
	{
		"nvim-telescope/telescope.nvim", -- Telescope
		tag = "0.1.4",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"smartpde/telescope-recent-files",
			"tom-anders/telescope-vim-bookmarks.nvim",
		},
	},

	------- LSP
	"neovim/nvim-lspconfig", -- LSP configuration

	------- Formatter
	"stevearc/conform.nvim",

	------- Linter
	{
		"mfussenegger/nvim-lint",
		lazy = true, -- Load only when needed
		ft = { "v", "sv", "verilog", "systemverilog" }, -- File types that need linting
	},

	------- Terminal
	{
		"akinsho/toggleterm.nvim",
		version = "*",
		config = true,
	},

	------- Editing Tools
	"windwp/nvim-autopairs", -- Auto closing brackets, parenthesis etc.
	"alvan/vim-closetag", -- Auto closing HTML tags
	"lukas-reineke/indent-blankline.nvim", -- Line highlighting
	"norcalli/nvim-colorizer.lua", -- Hex color highlighting
	"MattesGroeger/vim-bookmarks", -- Bookmarks
	"lewis6991/gitsigns.nvim", -- Git signs
	"hiphish/rainbow-delimiters.nvim", -- Brackets, parenthesis colorizing

	{
		"iamcco/markdown-preview.nvim",
		cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
		ft = { "markdown" },
		build = function()
			vim.fn["mkdp#util#install"]()
		end,
	},
	"github/copilot.vim",
	"andweeb/presence.nvim",
	{
		"yetone/avante.nvim",
		event = "VeryLazy",
		version = false,
		build = "make",
		opts = {
			provider = "openai",
			windows = {
				position = "left",
			},
		},
		dependencies = {
			"nvim-lua/plenary.nvim",
			"MunifTanjim/nui.nvim",
			"nvim-tree/nvim-web-devicons",
			"nvim-treesitter/nvim-treesitter",
			{
				"HakonHarnes/img-clip.nvim",
				event = "VeryLazy",
				opts = {
					default = {
						embed_image_as_base64 = false,
						prompt_for_file_name = false,
						drag_and_drop = { insert_mode = true },
					},
				},
			},
			{
				"MeanderingProgrammer/render-markdown.nvim",
				opts = { file_types = { "markdown", "Avante" } },
				ft = { "markdown", "Avante" },
			},
		},
	},
}
