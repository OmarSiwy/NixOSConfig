local languages = require("core.languages")
local lspconfig = require("lspconfig")

-- ========== LSP UI SETUP ==========
local function setup_ui()
	-- Diagnostic configuration
	vim.diagnostic.config({
		virtual_text = true,
		signs = {
			text = {
				[vim.diagnostic.severity.ERROR] = "",
				[vim.diagnostic.severity.WARN] = "",
				[vim.diagnostic.severity.HINT] = "",
				[vim.diagnostic.severity.INFO] = "",
			},
		},
		underline = true,
		update_in_insert = true,
		severity_sort = true,
		float = {
			focusable = false,
			style = "minimal",
			border = "rounded",
			source = "always",
			header = "",
			prefix = "",
		},
	})

end

-- Global diagnostic keymaps
vim.keymap.set("n", "<space>`", vim.diagnostic.open_float)
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev)
vim.keymap.set("n", "]d", vim.diagnostic.goto_next)
vim.keymap.set("n", "<space>q", vim.diagnostic.setloclist)

-- ========== LSP ATTACH & CAPABILITIES ==========
local on_attach = function(client, bufnr)
	-- Disable formatting for certain servers (handled by conform)
	if client.name == "tsserver" or client.name == "ts_ls" or client.name == "rust_analyzer" then
		client.server_capabilities.documentFormattingProvider = false
	end

	-- Buffer keymaps
	local opts = { noremap = true, silent = true, buffer = bufnr }
	vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
	vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
	vim.keymap.set("n", "K", function()
		vim.lsp.buf.hover({ border = "rounded" })
	end, opts)
	vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
	vim.keymap.set("n", "<C-k>", function()
		vim.lsp.buf.signature_help({ border = "rounded" })
	end, opts)
	vim.keymap.set("n", "<space>D", vim.lsp.buf.type_definition, opts)
	vim.keymap.set("n", "<space>ih", function()
		vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }), { bufnr = bufnr })
	end, opts)
	vim.keymap.set("n", "<space>rn", vim.lsp.buf.rename, opts)
	vim.keymap.set({ "n", "v" }, "<space>ca", vim.lsp.buf.code_action, opts)
	vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
	vim.keymap.set("n", "<space>f", function()
		vim.lsp.buf.format({ async = true })
	end, opts)

	-- Document highlighting
	if client.server_capabilities.documentHighlightProvider then
		vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
			buffer = bufnr,
			callback = vim.lsp.buf.document_highlight,
		})
		vim.api.nvim_create_autocmd("CursorMoved", {
			buffer = bufnr,
			callback = vim.lsp.buf.clear_references,
		})
	end
end

-- Setup capabilities with cmp
local has_cmp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
local capabilities = has_cmp and cmp_nvim_lsp.default_capabilities() or vim.lsp.protocol.make_client_capabilities()

-- ========== INLAY HINTS ==========
vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(args)
		vim.lsp.inlay_hint.enable(true, { bufnr = args.buf })
	end,
})

-- ========== SETUP ==========
setup_ui()

-- Automatically setup LSP servers from languages.lua
for _, lang in ipairs(languages) do
	if lang.lsp then
		local config = lang.lsp_config or {}
		config.on_attach = on_attach
		config.capabilities = capabilities

		-- Use PATH lookup for the LSP binary (respects nix-shell)
		local server_config = lspconfig[lang.lsp]
		if server_config and server_config.document_config then
			local default_config = server_config.document_config.default_config
			if default_config and default_config.cmd and default_config.cmd[1] then
				local binary = default_config.cmd[1]
				local resolved = vim.fn.exepath(binary)
				if resolved ~= "" then
					config.cmd = vim.deepcopy(default_config.cmd)
					config.cmd[1] = resolved
				end
			end
		end

		lspconfig[lang.lsp].setup(config)
	end
end
