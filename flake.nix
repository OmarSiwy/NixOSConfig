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
    opencode = {
      url = "github:dan-online/opencode-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
  };
  outputs =
    inputs@{
      self,
      nixpkgs,
      nixpkgs-stable,
      home-manager,
      lanzaboote,
      claude-code,
      opencode,
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
          ./hosts
          { nixpkgs.config.allowUnfree = true; }
          {
            nixpkgs.overlays = [
              (import ./hosts/overlays/river.nix)
              # Suppress "xorg.lndir has been renamed to lndir" deprecation warning
              (final: prev: {
                xorg = prev.xorg // { lndir = prev.lndir; };
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
              extraSpecialArgs = { inherit inputs username; };
              users.${username} = import ./home;
            };
          }
          inputs.chaotic.nixosModules.nyx-overlay
          inputs.chaotic.nixosModules.nyx-cache
          { chaotic.nyx.cache.enable = false; } # nyx.chaotic.cx is down (HTTP 525)
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
                opencode.packages.${system}.default
              ];
            }
          )
        ];
      };
    };
}
