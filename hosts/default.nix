{
  config,
  pkgs,
  lib,
  username,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix

    # System
    ./boot.nix
    ./networking.nix
    ./nix.nix
    ./security.nix
    ./virtualization.nix

    # Hardware
    ./hardware/graphics.nix
    ./hardware/bluetooth.nix
    ./hardware/amd.nix
    ./hardware/intel.nix
    ./hardware/nvidia.nix
    ./hardware/nvidia-prime.nix
    ./hardware/legion.nix

    # Desktop
    ./desktop/river.nix
    ./desktop/greetd.nix
    ./desktop/audio.nix

    # Services
    ./services.nix

    # Packages
    ./packages
  ];

  # Machine-specific settings
  networking.hostName = username;

  # Keep the base system lean: drop optional default packages and local docs.
  environment.defaultPackages = [ ];
  documentation = {
    enable = false;
    man.enable = false;
    info.enable = false;
    doc.enable = false;
    dev.enable = false;
    nixos.enable = false;
  };

  # Driver configuration
  drivers = {
    amdgpu.enable = false;
    intel.enable = true;
    nvidia.enable = true;
    nvidia-prime = {
      enable = true;
      intelBusID = "PCI:0:2:0";
      nvidiaBusID = "PCI:1:0:0";
    };
    legion = {
      enable = true;
    };
  };


  time.hardwareClockInLocalTime = true;

  # chaotic-nyx's cache-friendly.nix passes pkgs.config to chaotic's older nixpkgs.
  # Newer nixpkgs (Apr 2026+) declares replaceStdenv = null explicitly in pkgs.config.
  # Chaotic's nixpkgs (Dec 2025) sees the key present, enters custom stdenv stage, and
  # tries to call config.replaceStdenv { ... } — but it's null → crash.
  # Fix: pass a minimal config without replaceStdenv to chaotic's nixpkgs.
  chaotic.nyx.overlay.flakeNixpkgs.config = { allowUnfree = true; };

  # User configuration
  users = {
    users.${username} = {
      homeMode = "755";
      isNormalUser = true;
      description = username;
      extraGroups = [
        "networkmanager"
        "wheel"
        "libvirtd"
        "scanner"
        "lp"
        "video"
        "input"
        "audio"
        "docker"
        "seat"
        "i2c"
        "gamemode"
      ];
    };
    defaultUserShell = pkgs.zsh;
  };
  environment.shells = with pkgs; [ zsh ];
  programs.zsh.enable = true;

  system.stateVersion = "25.05";
}
