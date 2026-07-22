{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.drivers.legion;
in
{
  options.drivers.legion = {
    enable = mkEnableOption "Lenovo Legion laptop drivers and RGB control";
  };

  config = mkIf cfg.enable {
    # Legion kernel module and driver support
    boot = {
      extraModulePackages = with config.boot.kernelPackages; [
        lenovo-legion-module
      ];
      # The package is named `lenovo-legion-module` but the actual kernel
      # module it installs is `legion-laptop`. Using the wrong name here
      # caused systemd-modules-load to fail every boot.
      kernelModules = [ "legion-laptop" ];
      kernelParams = [ "acpi_backlight=native" ];
    };

    # Legion hardware control packages
    environment.systemPackages = with pkgs; [
      lenovo-legion
    ];
  };
}
