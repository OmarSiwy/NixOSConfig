{ pkgs, ... }:
let
  # MCP server that fetches paywalled papers through institutional SSO.
  # Upstream's README says `uv sync` + `playwright install chromium`; neither
  # works here — pip's playwright ships an unpatched node driver and downloads
  # browsers that can't run on NixOS. nixpkgs already has every dependency
  # (mcp 1.x with fastmcp, playwright matching playwright-driver's browsers),
  # so build it declaratively instead.
  src = pkgs.fetchFromGitHub {
    owner = "CoderrOne";
    repo = "claude-research-gateway";
    rev = "659fd00a121a0a1f3e6ccae87a54a31899a06d30";
    hash = "sha256-FSbVu8aSr4DJt+qyvAYZsTqMRP2Mk4aQdHdqiB3922M=";
  };

  pythonEnv = pkgs.python3.withPackages (
    ps: with ps; [
      mcp # must stay 1.x — server.py imports mcp.server.fastmcp, dropped in 2.0
      playwright
      httpx
      beautifulsoup4
      pdfplumber
      cryptography
      pydantic
      lxml
    ]
  );

  # ponytail: pinned rev, bump by hand. `nix-prefetch-url --unpack
  # https://github.com/CoderrOne/claude-research-gateway/archive/<rev>.tar.gz`
  # then `nix hash to-sri --type sha256 <out>`.
  research-gateway = pkgs.writeShellScriptBin "research-gateway" ''
    export PLAYWRIGHT_BROWSERS_PATH=${pkgs.playwright-driver.browsers}
    exec ${pythonEnv}/bin/python ${src}/server.py "$@"
  '';
in
{
  environment.systemPackages = [ research-gateway ];
}
