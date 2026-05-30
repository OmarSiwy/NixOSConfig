local languages = require("core.languages")

-- Auto-build formatters_by_ft from languages.lua
local formatters_by_ft = {}
for _, lang in ipairs(languages) do
	if lang.formatter and lang.filetypes then
		for _, ft in ipairs(lang.filetypes) do
			formatters_by_ft[ft] = { lang.formatter }
		end
	end
end

-- Fallback formatters
formatters_by_ft["*"] = { "codespell" }
formatters_by_ft["_"] = { "trim_whitespace" }

-- Auto-build custom formatters from languages.lua
local formatters = {}
for _, lang in ipairs(languages) do
	if lang.formatter_config then
		formatters[lang.formatter] = lang.formatter_config
	end
end

require("conform").setup({
	formatters_by_ft = formatters_by_ft,
	formatters = formatters,
	format_on_save = {
		lsp_fallback = true,
		timeout_ms = 500,
	},
})
