{ pkgs, ... }:

{
  # Organized parent -> children: each language is the parent; its language
  # server, formatter, linter and runtime/build tools nest beneath it.
  environment.systemPackages = with pkgs; [
    # ── Rust ──
    rust-analyzer # LSP
    rustfmt # formatter
    cargo # build / runtime

    # ── Python ──
    basedpyright # LSP
    black # formatter
    ruff # linter

    # ── Lua ──
    lua-language-server # LSP
    stylua # formatter
    lua53Packages.luacheck # linter
    lua # runtime

    # ── Nix ──
    nixd # LSP
    nixfmt # formatter
    statix # linter

    # ── JavaScript / TypeScript ──
    typescript-language-server # LSP
    vscode-langservers-extracted # html, css, json, eslint LSPs
    prettier # formatter (JS/TS/HTML/CSS/JSON/YAML/Markdown)
    eslint_d # linter
    nodejs # runtime
    bun # runtime / toolkit

    # ── C / C++ ──
    clang-tools # clangd + clang-format
    cmake-language-server # LSP
    gnumake # build

    # ── Zig ──
    zls # LSP
    zig_0_16 # compiler / build

    # ── TOML ──
    taplo # LSP + formatter

    # ── Shell ──
    shfmt # formatter
    shellcheck # linter

    # ── Hardware / HDL ──
    veridian # SystemVerilog LSP
    verible # Verilog format / lint
    sv-lang # SystemVerilog frontend

    # ── Debuggers (shared across Rust / C / C++) ──
    lldb
    gdb
    valgrind

    # ── General CLI & Neovim deps ──
    gh
    jq
    tmux
    codespell # cross-language spell checker
    tree-sitter
    lazygit
    bat
    eza
    ripgrep
    fd
  ];

  environment.variables = {
    NODE_PATH = "${pkgs.nodejs}/lib/node_modules";
    PYTHON3_HOST_PROG = "${pkgs.python3}/bin/python3";
  };
}
