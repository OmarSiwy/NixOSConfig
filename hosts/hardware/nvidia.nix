{
  lib,
  pkgs,
  config,
  ...
}:
with lib;
let
  cfg = config.drivers.nvidia;
in
{
  options.drivers.nvidia = {
    enable = mkEnableOption "Enable Nvidia Drivers";
  };

  config = mkIf cfg.enable {
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        libva-vdpau-driver
        libvdpau
        libvdpau-va-gl
        nvidia-vaapi-driver
        vdpauinfo
        libva
        libva-utils
      ];
    };

    hardware.nvidia = {
      # Modesetting is required.
      modesetting.enable = true;

      # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
      powerManagement.enable = true;

      # Fine-grained power management. Turns off GPU when not in use.
      # Experimental and only works on modern Nvidia GPUs (Turing or newer).
      powerManagement.finegrained = false;

      #dynamicBoost.enable = true; # Dynamic Boost

      nvidiaPersistenced = false;

      # Use the NVidia open source kernel module (not to be confused with the
      # independent third-party "nouveau" open source driver).
      # Support is limited to the Turing and later architectures. Full list of
      # supported GPUs is at:
      # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
      # Only available from driver 515.43.04+
      # Currently alpha-quality/buggy, so false is currently the recommended setting.
      open = false; # open 580.x incompatible with kernel 6.18 (get_dev_pagemap API changed)

      # Enable the Nvidia settings menu,
      # accessible via `nvidia-settings`.

      nvidiaSettings = true;

      # Use stable (580.105.08 as of Apr 2026) from chaotic's kernel packages.
      # legacy_580 does not exist in chaotic-nyx's Dec 2025 nixpkgs kernel set.
      # stable now resolves to 580.x (not 595.x), so it avoids the old regressions:
      #   - 595.58.03 had Wine/Lutris/Battle.net/DXVK issues
      #   - 580.x is stable for RTX 4060 (Ada Lovelace) + Lutris + DXVK
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };
  };
}
