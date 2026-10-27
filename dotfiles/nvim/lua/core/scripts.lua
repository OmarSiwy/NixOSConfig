-- Colorscheme
cmd("colorscheme embark")

-- Transparent background: let ghostty's background-opacity show through
for _, group in ipairs({
	"Normal", "NormalNC", "NormalFloat", "FloatBorder", "SignColumn", "LineNr",
	"EndOfBuffer", "StatusLine", "StatusLineNC", "NvimTreeNormal", "NvimTreeNormalNC",
}) do
	local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
	hl.bg, hl.ctermbg = nil, nil
	vim.api.nvim_set_hl(0, group, hl)
end

-- Run ":so" after writing .zshrc
cmd("autocmd BufWritePost ~/.zshrc so %")

-- Run "xrdb" after writing .Xresources
cmd("autocmd BufWritePost ~/.Xresources !xrdb %")
