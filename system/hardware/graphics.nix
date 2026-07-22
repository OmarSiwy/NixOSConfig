{ ... }:
{
  hardware = {
    enableRedistributableFirmware = true;
    graphics.enable = true;
  };

  services.pulseaudio.enable = false;
}
