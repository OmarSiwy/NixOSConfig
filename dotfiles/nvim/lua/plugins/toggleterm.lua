require("toggleterm").setup({
	size = 20,
	open_mapping = [[<c-\>]], -- Toggle with Ctrl+\
	hide_numbers = true,
	shade_terminals = true,
	shading_factor = 2,
	start_in_insert = true,
	insert_mappings = true,
	terminal_mappings = true,
	persist_size = true,
	persist_mode = true,
	direction = "float", -- 'vertical' | 'horizontal' | 'tab' | 'float'
	close_on_exit = true,
	shell = vim.o.shell,
	auto_scroll = true,
	float_opts = {
		border = "curved", -- 'single' | 'double' | 'shadow' | 'curved'
		winblend = 0,
		highlights = {
			border = "Normal",
			background = "Normal",
		},
	},
})

-- Custom terminal keymaps
function _G.set_terminal_keymaps()
	local opts = { buffer = 0 }
	vim.keymap.set("t", "<esc>", [[<C-\><C-n>]], opts)
	vim.keymap.set("t", "jk", [[<C-\><C-n>]], opts)
	vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], opts)
	vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], opts)
	vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], opts)
	vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], opts)
end

vim.cmd("autocmd! TermOpen term://* lua set_terminal_keymaps()")
