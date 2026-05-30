{ pkgs, ... }:

let
  chromiumRevision =
    (builtins.head (
      builtins.filter (b: b.name == "chromium")
        (builtins.fromJSON (builtins.readFile "${pkgs.playwright-driver}/browsers.json")).browsers
    )).revision;
  playwrightChromium = "${pkgs.playwright-driver.browsers}/chromium-${chromiumRevision}/chrome-linux/chrome";
in

{
  environment.systemPackages = with pkgs; [
    bun
    nodejs
    playwright-driver.browsers
    chromium

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

    PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
    PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
    PLAYWRIGHT_LAUNCH_OPTIONS_EXECUTABLE_PATH = playwrightChromium;
  };
}
