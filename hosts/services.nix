{ pkgs, username, ... }:
{
  services = {
    seatd.enable = true;

    # Tailscale
    tailscale.enable = true;

    # TLP - Advanced power management
    tlp = {
      enable = true;
      settings = {
        START_CHARGE_THRESH_BAT0 = 60;
        STOP_CHARGE_THRESH_BAT0 = 80;
      };
    };

    resolved.enable = true;

    power-profiles-daemon.enable = false; # Conflicts with TLP
    gvfs.enable = true;
    tumbler.enable = true;
    udev.enable = true;
    envfs = {
      enable = true;
      extraFallbackPathCommands = ''
        ln -s ${pkgs.vulkan-tools}/bin/vulkaninfo $out/vulkaninfo
        ln -s ${pkgs.mesa-demos}/bin/glxinfo $out/glxinfo
      '';
    };
    dbus.enable = true;
    fstrim = {
      enable = true;
      interval = "weekly";
    };
    illum.enable = true;
    libinput.enable = true;
    openssh.enable = true;
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
      publish = {
        enable = true;
        userServices = true;
      };
    };
    fwupd.enable = true;
    upower.enable = true;
    gnome.gnome-keyring.enable = true;
    thermald.enable = true;
  };
  systemd = {
    packages = [ pkgs.pritunl-client ];
    services = {
      pritunl-client = {
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
      };
      nvidia-powerd.enable = false;
      NetworkManager-wait-online.enable = false;
    };
  };

  services.logind = {
    lidSwitch = "ignore";
    lidSwitchExternalPower = "ignore";
    lidSwitchDocked = "ignore";
    settings.Login = {
      HandleSuspendKey = "ignore";
      HandleHibernateKey = "ignore";
      IdleAction = "ignore";
    };
  };

  powerManagement.enable = true;

  zramSwap = {
    enable = true;
    priority = 100;
    memoryPercent = 100;
    swapDevices = 1;
    algorithm = "zstd";
  };

  environment.etc."libinput/local-overrides.quirks".text = ''
    [USB Mouse No Debounce]
    MatchUdevType=mouse
    MatchBus=usb
    ModelBouncingKeys=1
  '';
}
