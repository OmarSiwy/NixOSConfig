-- Floating terminal (toggleterm) - Alt+t
kmap.set("n", "<A-t>", "<cmd>ToggleTerm<cr>", { desc = "Toggle floating terminal" })
kmap.set("t", "<A-t>", "<cmd>ToggleTerm<cr>", { desc = "Toggle floating terminal" })

-- Horizontal and vertical terminals (classic split)
kmap.set("n", "<leader>th", ":split | terminal<cr>", { desc = "Horizontal terminal" })
kmap.set("n", "<leader>tv", ":vsplit | terminal<cr>", { desc = "Vertical terminal" })

-- Exit terminal mode easily
kmap.set("t", "<C-h>", [[<C-\><C-n><C-w>h]])
kmap.set("t", "<C-j>", [[<C-\><C-n><C-w>j]])
kmap.set("t", "<C-k>", [[<C-\><C-n><C-w>k]])
kmap.set("t", "<C-l>", [[<C-\><C-n><C-w>l]])

-- Redo
kmap.set("n", "U", "<C-r>")

-- Split navigation using CTRL + {j, k, h, l}
kmap.set("n", "<c-k>", "<c-w>k")
kmap.set("n", "<c-j>", "<c-w>j")
kmap.set("n", "<c-l>", "<c-w>l")
kmap.set("n", "<c-h>", "<c-w>h")

-- Resize split windows using arrow keys
kmap.set("n", "<c-up>", "<c-w>-")
kmap.set("n", "<c-down>", "<c-w>+")
kmap.set("n", "<c-right>", "<c-w>>")
kmap.set("n", "<c-left>", "<c-w><")

-- NerdTree
kmap.set("n", "<c-n>", "<cmd>NvimTreeToggle<CR>", { noremap = true, silent = true })
kmap.set("n", "<leader>e", "<cmd>NvimTreeFocus<CR>", { noremap = true, silent = true })

-- Undo Tree
kmap.set("n", "<leader>ut", vim.cmd.UndotreeToggle)

-- Markdown Preview
kmap.set("n", "<leader>mp", vim.cmd.MarkdownPreview)

-- Telescope
local builtin = require("telescope.builtin")
local extensions = require("telescope").extensions

kmap.set("n", "<leader>ff", builtin.find_files, {})
kmap.set("n", "<leader>fg", builtin.live_grep, {})
kmap.set("n", "<leader>fw", builtin.current_buffer_fuzzy_find, {})
kmap.set("n", "<leader>fb", builtin.buffers, {})
kmap.set("n", "<leader>fh", builtin.help_tags, {})

kmap.set("n", "<leader>rf", extensions.recent_files.pick, {})
kmap.set("n", "<leader>fm", extensions.vim_bookmarks.all, {})
kmap.set("n", "<leader>fm-", extensions.vim_bookmarks.current_file, {})

-- Avante (AI - Cursor-like)
kmap.set({ "n", "v" }, "<leader>aa", "<cmd>AvanteAsk<cr>", { desc = "AI: Ask" })
kmap.set({ "n", "v" }, "<leader>ae", "<cmd>AvanteEdit<cr>", { desc = "AI: Edit selection" })
kmap.set("n", "<leader>ar", "<cmd>AvanteRefresh<cr>", { desc = "AI: Refresh" })
kmap.set("n", "<leader>at", "<cmd>AvanteToggle<cr>", { desc = "AI: Toggle sidebar" })

vim.g.copilot_no_tab_map = true
kmap.set("i", "<A-l>", 'copilot#Accept("")', {
	expr = true,
	replace_keycodes = false,
	desc = "Copilot: Accept suggestion",
})
