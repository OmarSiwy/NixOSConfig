{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    bun
    gh
    jq
    nodejs
    tmux

    # ========== LANGUAGE SERVERS ==========
    lua-language-server
    gnumake
    rust-analyzer
    basedpyright
    nixd
    typescript-language-server
    vscode-langservers-extracted # html, css, json, eslint
    clang-tools # clangd + clang-format
    ocamlPackages.ocaml-lsp
    dune_3
    taplo
    zig_0_16
    zls
    veridian
    verible
    cmake-language-server

    # ========== FORMATTERS ==========
    prettier # JS/TS/HTML/CSS/JSON/YAML/Markdown
    stylua
    nixfmt
    rustfmt
    black
    ocamlformat
    shfmt

    # ========== LINTERS ==========
    codespell
    statix
    lua53Packages.luacheck
    shellcheck
    eslint_d
    ruff

    # ========== DEBUGGING TOOLS ==========
    lldb
    gdb
    valgrind

    # ========== PROGRAMMING LANGUAGES & TOOLS ==========
    cargo
    lua

    # ========== HARDWARE DESIGN ==========
    kicad
    sv-lang

    # ========== NEOVIM DEPENDENCIES ==========
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
