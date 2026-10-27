{ pkgs, lib, username, ... }:
let
  # Root helper behind the eww panel's power-profile buttons.
  #
  # This CPU runs intel_pstate, which offers only performance/powersave as
  # governors — the governor alone barely moves package power. The knobs that
  # do are EPP (energy_performance_preference) and the Legion EC's ACPI
  # platform_profile, which sets the sustained power/fan envelope. Write all
  # three or the mode is cosmetic.
  #
  # NOTE: TLP re-applies its own governor/EPP on an AC<->battery transition, so
  # a mode picked here holds until you plug or unplug. platform_profile is
  # untouched by TLP (no PLATFORM_PROFILE_ON_* set), which is why the bar polls
  # that one as the source of truth.
  setPowerprofile = pkgs.writeShellScriptBin "set-powerprofile" ''
    case "$1" in
      performance) gov=performance; epp=performance; prof=performance ;;
      powersave)   gov=powersave;   epp=power;       prof=low-power   ;;
      *) echo "usage: set-powerprofile performance|powersave" >&2; exit 1 ;;
    esac

    for c in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
      echo "$gov" > "$c"
    done
    # EPP exists only while intel_pstate/amd-pstate runs in active mode.
    for c in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
      [ -w "$c" ] && echo "$epp" > "$c"
    done
    # legion-laptop; choices on this box: low-power balanced performance max-power custom
    [ -w /sys/firmware/acpi/platform_profile ] \
      && echo "$prof" > /sys/firmware/acpi/platform_profile
    exit 0
  '';
in
{
  environment.systemPackages = [ setPowerprofile ];

  # Appgate SDP VPN (university CAD access). NixOS module, not home-manager:
  # it needs the root appgatedriver service, system D-Bus policy and tun.
  programs.appgate-sdp.enable = true;

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
    # ponytail: illum removed — 18MB resident to handle XF86MonBrightness keys
    # that rill already binds (config.zon). Both running meant every keypress
    # stepped brightness twice.
    libinput.enable = true;
    openssh.enable = true;
    # ponytail: avahi removed (3MB + open mDNS port). Costs .local discovery —
    # re-add if a network printer or Miracast cast stops being found.
    fwupd.enable = true;
    upower.enable = true;
    gnome.gnome-keyring.enable = true;
    thermald.enable = true;
  };
  systemd = {
    packages = [ pkgs.pritunl-client ];
    services = {
      # ponytail: on-demand, not wantedBy multi-user.target — 21MB standing for
      # a school VPN used occasionally. `systemctl start pritunl-client`.
      pritunl-client.after = [ "network.target" ];
      # No WWAN modem in this laptop (mmcli -L finds none); NetworkManager pulls
      # ModemManager in regardless. 9MB for hardware that isn't here.
      ModemManager.enable = false;
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
