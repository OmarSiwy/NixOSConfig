# 💫 https://github.com/JaKooLit 💫 #
{
  lib,
  pkgs,
  config,
  ...
}:
with lib;
let
  cfg = config.drivers.intel;
in
{
  options.drivers.intel = {
    enable = mkEnableOption "Enable Intel Graphics Drivers";
  };
  config = mkIf cfg.enable {
    # Load Intel kernel module
    boot.initrd.kernelModules = [ "i915" ];
    boot.kernelModules = [ "i915" ];

    # Note: `i915.modeset=1` is deprecated on modern kernels — modesetting is
    # on by default. Remove `nomodeset` instead if you ever need to disable it.

    # Override intel-vaapi-driver with hybrid codec support
    nixpkgs.config.packageOverrides = pkgs: {
      intel-vaapi-driver = pkgs.intel-vaapi-driver.override { enableHybridCodec = true; };
    };

    # OpenGL/Graphics
    hardware.graphics = {
      extraPackages = with pkgs; [
        intel-media-driver # For Raptor Lake (12th gen+) - MAIN DRIVER
        intel-vaapi-driver # Hardware acceleration (already overridden above)
        libvdpau-va-gl
        libva
        libva-utils
      ];

      # 32-bit support
      extraPackages32 = with pkgs.pkgsi686Linux; [
        intel-media-driver
        intel-vaapi-driver
      ];
    };
  };
}
