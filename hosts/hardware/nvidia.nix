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

      # Pin legacy_580 (580.142). `stable` now resolves to 595.71.05, which is
      # broken on this setup:
      #   - 595.71.05 still uses the screen_info struct refactored in kernel 7.0
      #     -> can't map framebuffers -> black screens / VC corruption
      #   - 595 + Chromium/QtWebEngine on Wayland -> raster tile corruption
      #     (white/black garbage on YouTube thumbnails/video) — confirmed on CachyOS
      # 580.142 avoids both and is stable for RTX 4060 (Ada) + Lutris + DXVK.
      # legacy_580 now exists in chaotic-nyx's kernel set (was missing in Dec 2025).
      package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
    };
  };
}
