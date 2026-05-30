{ config, options, ... }:

{
  networking = {
    timeServers = options.networking.timeServers.default ++ [ "pool.ntp.org" ];
    networkmanager.enable = true;
    firewall.allowedUDPPorts = [
      6000
      6001
      7011
    ];
    firewall.allowedTCPPorts = [
      7000
      7001
      7100
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
