{ pkgs, lib, username, ... }:
let
  # Root helper to flip the CPU governor (performance <-> powersave) from the
  # eww panel. NOTE: TLP may re-apply its own governor on an AC/battery change.
  setPowerprofile = pkgs.writeShellScriptBin "set-powerprofile" ''
    g="$1"
    case "$g" in
      performance|powersave) ;;
      *) echo "usage: set-powerprofile performance|powersave" >&2; exit 1 ;;
    esac
    for c in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
      echo "$g" > "$c"
    done
  '';
in
{
  environment.systemPackages = [ setPowerprofile ];

  # Let the eww panel run just this one helper without a password prompt.
  security.sudo.extraRules = [
    {
      users = [ username ];
      commands = [
        {
          command = "/run/current-system/sw/bin/set-powerprofile";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  services = {
    seatd.enable = false; # broken Type=notify -> systemd kills it every 90s -> river loses seat0 -> crash. logind handles seats.

    speechd.enable = lib.mkForce false; # ponytail: graphical-desktop default pulls speech-dispatcher -> 645MB mbrola-voices we don't use

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
    settings.Login = {
      HandleLidSwitch = "ignore";
      HandleLidSwitchExternalPower = "ignore";
      HandleLidSwitchDocked = "ignore";
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
