-- Variables
opt = vim.opt
g = vim.g
cmd = vim.cmd

-- Leader key
g.mapleader = " "
g.maplocalleader = " "

-- Defined below leader key, variables:
kmap = vim.keymap

-- Imports
require("core.lazy") -- lazy.nvim plugin manager
require("core.plugins") -- Plugins

require("core.settings") -- Editor settings
require("core.setups") -- Setup of plugins
require("core.mappings") -- Mappings
require("core.scripts") -- Scripts
require("core.lsp_guard") -- Hard-fail on missing repo LSPs

require("plugins.lsp-config-setup") -- LSP configuration
require("plugins.nvim-cmp") -- Autocompletion
require("plugins.treesitter") -- Treesitter syntax highlighting
require("plugins.conform") -- Formatter
require("plugins.gitsigns-config") -- Gitsigns mappings
require("plugins.toggleterm") -- Toggleterm configuration
