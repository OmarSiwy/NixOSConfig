local uv = vim.uv or vim.loop

local group = vim.api.nvim_create_augroup("RepoLspGuard", { clear = true })
local timers = {}

local specs = {
	rust = {
		label = "Rust",
		server = "rust_analyzer",
		exe = "rust-analyzer",
		project_root = { "Cargo.toml", "rust-project.json" },
		repo_root = { ".git", "Cargo.toml", "rust-project.json" },
	},
	zig = {
		label = "Zig",
		server = "zls",
		project_root = { "build.zig", "zls.json" },
		repo_root = { ".git", "build.zig", "zls.json" },
	},
	c = {
		label = "C/C++",
		server = "clangd",
		project_root = { ".clangd", "compile_commands.json", "compile_flags.txt" },
		repo_root = { ".git", ".clangd", "compile_commands.json", "compile_flags.txt", ".clang-tidy", ".clang-format", "configure.ac" },
		project_hint = ".clangd, compile_commands.json, or compile_flags.txt",
	},
	cpp = {
		label = "C/C++",
		server = "clangd",
		project_root = { ".clangd", "compile_commands.json", "compile_flags.txt" },
		repo_root = { ".git", ".clangd", "compile_commands.json", "compile_flags.txt", ".clang-tidy", ".clang-format", "configure.ac" },
		project_hint = ".clangd, compile_commands.json, or compile_flags.txt",
	},
	objc = {
		label = "C/C++",
		server = "clangd",
		project_root = { ".clangd", "compile_commands.json", "compile_flags.txt" },
		repo_root = { ".git", ".clangd", "compile_commands.json", "compile_flags.txt", ".clang-tidy", ".clang-format", "configure.ac" },
		project_hint = ".clangd, compile_commands.json, or compile_flags.txt",
	},
	objcpp = {
		label = "C/C++",
		server = "clangd",
		project_root = { ".clangd", "compile_commands.json", "compile_flags.txt" },
		repo_root = { ".git", ".clangd", "compile_commands.json", "compile_flags.txt", ".clang-tidy", ".clang-format", "configure.ac" },
		project_hint = ".clangd, compile_commands.json, or compile_flags.txt",
	},
}

local function stop_timer(bufnr)
	local timer = timers[bufnr]
	if timer then
		timer:stop()
		timer:close()
		timers[bufnr] = nil
	end
end

local function hard_fail(bufnr, message)
	if vim.b[bufnr].repo_lsp_guard_failed then
		return
	end

	vim.b[bufnr].repo_lsp_guard_failed = true
	stop_timer(bufnr)

	vim.schedule(function()
		if not vim.api.nvim_buf_is_valid(bufnr) then
			return
		end

		vim.api.nvim_err_writeln("LSP guard: " .. message)
		vim.cmd("cquit 1")
	end)
end

local function find_root(path, markers)
	return markers and vim.fs.root(path, markers) or nil
end

local function client_attached(bufnr, server)
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
		if client.name == server and not client:is_stopped() then
			return true
		end
	end
	return false
end

local function ensure_repo_lsp(bufnr)
	if vim.b[bufnr].repo_lsp_guard_checked then
		return
	end

	if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].buftype ~= "" then
		return
	end

	local spec = specs[vim.bo[bufnr].filetype]
	if not spec then
		return
	end

	local path = vim.api.nvim_buf_get_name(bufnr)
	if path == "" then
		return
	end

	local repo_root = find_root(path, spec.repo_root)
	local project_root = find_root(path, spec.project_root)

	if not repo_root and not project_root then
		return
	end

	if not project_root then
		local hint = spec.project_hint or table.concat(spec.project_root, ", ")
		hard_fail(bufnr, string.format("%s repo detected at %s, but required project marker is missing (%s)", spec.label, repo_root, hint))
		return
	end

	local exe = spec.exe or spec.server
	local server_path = vim.fn.exepath(exe)
	if server_path == "" then
		hard_fail(bufnr, string.format("%s project detected at %s, but `%s` is not on PATH", spec.label, project_root, exe))
		return
	end

	if client_attached(bufnr, spec.server) then
		vim.b[bufnr].repo_lsp_guard_checked = true
		return
	end

	stop_timer(bufnr)
	local deadline = uv.now() + 4000
	local timer = uv.new_timer()
	timers[bufnr] = timer

	timer:start(0, 100, vim.schedule_wrap(function()
		if not vim.api.nvim_buf_is_valid(bufnr) then
			stop_timer(bufnr)
			return
		end

		if client_attached(bufnr, spec.server) then
			vim.b[bufnr].repo_lsp_guard_checked = true
			stop_timer(bufnr)
			return
		end

		if uv.now() >= deadline then
			hard_fail(bufnr, string.format("%s project at %s did not get an attached `%s` client", spec.label, project_root, spec.server))
		end
	end))
end

vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile", "FileType" }, {
	group = group,
	callback = function(args)
		ensure_repo_lsp(args.buf)
	end,
})

vim.api.nvim_create_autocmd("BufWipeout", {
	group = group,
	callback = function(args)
		stop_timer(args.buf)
	end,
})

vim.api.nvim_create_user_command("LspGuardCheck", function()
	ensure_repo_lsp(vim.api.nvim_get_current_buf())
end, { desc = "Fail hard if the current repo buffer is missing its required LSP" })
