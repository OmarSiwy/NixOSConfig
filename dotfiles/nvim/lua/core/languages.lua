-- Centralized language configuration
-- Define all languages with their LSP, formatter, and treesitter parsers
-- Add a new language here and it will auto-configure across all plugins

return {
	-- Systems Programming
	{
		name = "Lua",
		filetypes = { "lua" },
		lsp = "lua_ls",
		lsp_config = {
			settings = {
				Lua = {
					runtime = { version = "LuaJIT" },
					diagnostics = { globals = { "vim" } },
					workspace = { library = vim.api.nvim_get_runtime_file("", true), checkThirdParty = false },
					telemetry = { enable = false },
				},
			},
		},
		formatter = "stylua",
		treesitter = { "lua" },
	},

	{
		name = "Rust",
		filetypes = { "rust" },
		lsp = "rust_analyzer",
		lsp_config = {
			settings = {
				["rust-analyzer"] = {
					cargo = { allFeatures = true },
					check = { command = "clippy" },
				},
			},
		},
		formatter = "rustfmt",
		treesitter = { "rust" },
	},

	{
		name = "C/C++",
		filetypes = { "c", "cpp", "objc", "objcpp" },
		lsp = "clangd",
		lsp_config = {
			cmd = { "clangd", "--background-index", "--clang-tidy" },
		},
		formatter = "clang_format",
		formatter_config = {
			command = "clang-format",
		},
		treesitter = { "c", "cpp" },
	},

	{
		name = "Zig",
		filetypes = { "zig" },
		lsp = "zls",
		lsp_config = {
			settings = {
				zls = {
					enable_inlay_hints = true,
					enable_snippets = true,
					warn_style = true,
					enable_semantic_tokens = true,
				},
			},
		},
		formatter = "zig_fmt",
		formatter_config = {
			command = "zig",
			args = { "fmt", "--stdin" },
			stdin = true,
		},
		treesitter = { "zig" },
	},

	-- Functional Programming
	{
		name = "OCaml",
		filetypes = { "ocaml", "ocaml.menhir", "ocaml.interface", "ocaml.ocamllex", "reason", "dune" },
		lsp = "ocamllsp",
		formatter = "ocamlformat",
		treesitter = { "ocaml", "ocaml_interface" },
	},

	-- Web Development
	{
		name = "TypeScript",
		filetypes = { "typescript", "typescriptreact" },
		lsp = "ts_ls",
		formatter = "prettier",
		treesitter = { "typescript", "tsx" },
	},

	{
		name = "JavaScript",
		filetypes = { "javascript", "javascriptreact" },
		lsp = "ts_ls",
		formatter = "prettier",
		treesitter = { "javascript" },
	},

	{
		name = "HTML",
		filetypes = { "html" },
		lsp = "html",
		formatter = "prettier",
		treesitter = { "html" },
	},

	{
		name = "CSS",
		filetypes = { "css", "scss", "sass" },
		lsp = "cssls",
		formatter = "prettier",
		treesitter = { "css", "scss" },
	},

	-- Scripting
	{
		name = "Python",
		filetypes = { "python" },
		lsp = "basedpyright",
		lsp_config = {
			settings = {
				basedpyright = {
					analysis = {
						autoSearchPaths = true,
						useLibraryCodeForTypes = true,
						diagnosticMode = "workspace",
						typeCheckingMode = "basic",
					},
				},
			},
		},
		formatter = "black",
		treesitter = { "python" },
	},

	{
		name = "Shell",
		filetypes = { "sh", "bash" },
		formatter = "shfmt",
		treesitter = { "bash" },
	},

	-- Config & Data
	{
		name = "Nix",
		filetypes = { "nix" },
		lsp = "nixd",
		lsp_config = {
			settings = {
				nixd = {
					formatting = { command = { "nixfmt" } },
				},
			},
		},
		formatter = "nixfmt",
		formatter_config = {
			command = "nixfmt",
		},
	},

	{
		name = "JSON",
		filetypes = { "json" },
		lsp = "jsonls",
		formatter = "prettier",
		treesitter = { "json", "hjson" },
	},

	{
		name = "YAML",
		filetypes = { "yaml", "yml" },
		formatter = "prettier",
		treesitter = { "yaml" },
	},

	{
		name = "TOML",
		filetypes = { "toml" },
		treesitter = { "toml" },
	},

	{
		name = "Markdown",
		filetypes = { "markdown" },
		formatter = "prettier",
		treesitter = { "markdown", "markdown_inline" },
	},

	-- Hardware
	{
		name = "Verilog",
		filetypes = { "verilog", "systemverilog", "v", "sv" },
		lsp = "veridian",
		lsp_config = {
			cmd = { "veridian" },
			root_dir = function(fname)
				return require("lspconfig.util").root_pattern("veridian.yml", ".git")(fname)
			end,
		},
		formatter = "verible_verilog_format",
		formatter_config = {
			command = "verible-verilog-format",
			args = { "-" },
			stdin = true,
		},
		treesitter = { "verilog" },
	},

	-- Editor
	{
		name = "Vim",
		filetypes = { "vim" },
		treesitter = { "vim", "vimdoc", "query" },
	},

	-- Misc
	{
		name = "Dockerfile",
		filetypes = { "dockerfile" },
		treesitter = { "dockerfile" },
	},

	{
		name = "CMake",
		filetypes = { "cmake" },
		treesitter = { "cmake" },
	},

	{
		name = "Graphviz",
		filetypes = { "dot" },
		treesitter = { "dot" },
	},

	{
		name = "XML",
		filetypes = { "xml" },
		treesitter = { "xml" },
	},

	{
		name = "Diff",
		filetypes = { "diff" },
		treesitter = { "diff" },
	},

	{
		name = "Regex",
		treesitter = { "regex" },
	},

	{
		name = "LaTeX",
		filetypes = { "tex", "plaintex", "bib" },
		lsp = "texlab",
		lsp_config = {
			settings = {
				texlab = {
					build = {
						executable = "latexmk",
						args = {
							"-pdf",
							"-interaction=nonstopmode",
							"-synctex=1",
							"-outdir=build",
							"%f",
						},
						onSave = true,
					},
					forwardSearch = {
						executable = "zathura",
						args = {
							"--synctex-forward",
							"%l:1:%f",
							"build/%p",
						},
					},
					chktex = { onOpenAndSave = true, onEdit = false },
					diagnosticsDelay = 300,
					formatterLineLength = 120,
				},
			},
		},
		formatter = "latexindent",
		formatter_config = { command = "latexindent", args = { "-" }, stdin = true },
		treesitter = { "latex", "bibtex" },
	},
}
