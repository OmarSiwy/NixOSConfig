{
  pkgs,
  username,
  ...
}:

{
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
