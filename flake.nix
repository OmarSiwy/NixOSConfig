{
  description = "NixOS config flake - Modular with Home Manager";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.2";
    };
    claude-code = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    codex-cli = {
      url = "github:sadjow/codex-cli-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    inputs@{
      self,
      nixpkgs,
      nixpkgs-stable,
      home-manager,
      lanzaboote,
      claude-code,
      codex-cli,
      ...
    }:
    let
      system = "x86_64-linux";
      username = "omare";
      pkgs-stable = import nixpkgs-stable {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      nixosConfigurations.${username} = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs username pkgs-stable; };
        modules = [
          ./system
          { nixpkgs.config.allowUnfree = true; }
          {
            nixpkgs.overlays = [
              (import ./system/overlays/river.nix)
              # ani-cli 5.0 (nixpkgs is on 4.14) — drop once nixpkgs catches up
              (final: prev: {
                ani-cli = prev.ani-cli.overrideAttrs (old: rec {
                  version = "5.0";
                  src = prev.fetchFromGitHub {
                    owner = "pystardust";
                    repo = "ani-cli";
                    tag = "v${version}";
                    hash = "sha256-rRQESi0Skoyf1jy/dRRK6ooKRPQhkak107kk5ulwZYI=";
                  };
                });
              })
              # Suppress "xorg.lndir has been renamed to lndir" deprecation warning
              (final: prev: {
                xorg = prev.xorg // {
                  lndir = prev.lndir;
                };
              })
              # openldap syncreplication test flaky in sandbox
              (final: prev: {
                openldap = prev.openldap.overrideAttrs (old: {
                  doCheck = false;
                });
              })
            ];
          }
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit inputs username pkgs-stable; };
              users.${username} = import ./home;
            };
          }
          lanzaboote.nixosModules.lanzaboote
          (
            { lib, pkgs, ... }:
            {
              environment.systemPackages = [ pkgs.sbctl ];
              boot = {
                loader.systemd-boot.enable = lib.mkForce false;
                lanzaboote = {
                  enable = true;
                  pkiBundle = "/var/lib/sbctl";
                };
              };
            }
          )
          (
            { pkgs, ... }:
            {
              environment.systemPackages = [
                claude-code.packages.${system}.claude-code
                codex-cli.packages.${system}.default
              ];
            }
          )
        ];
      };
    };
}
