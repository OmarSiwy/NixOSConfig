{
  config,
  pkgs,
  options,
  ...
}:

{
  networking = {
    timeServers = options.networking.timeServers.default ++ [ "pool.ntp.org" ];
    networkmanager.enable = true;
    networkmanager.plugins = with pkgs; [
      networkmanager-openconnect
    ];
    firewall.allowedUDPPorts = [
      53 # GNOME Network Displays WFD zone: DNS
      6000
      6001
      7011
    ];
    firewall.allowedUDPPortRanges = [
      { from = 50000; to = 65535; } # Discord voice/WebRTC
    ];
    firewall.allowedTCPPorts = [
      53 # GNOME Network Displays WFD zone: DNS
      7000
      7001
      7100
      7236 # GNOME Network Displays RTSP
    ];
  };

  # Automatic timezone
  services.automatic-timezoned.enable = true;

  # Internationalization
  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };
  };

  console.keyMap = "us";
}
