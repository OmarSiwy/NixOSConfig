{ pkgs, lib, username, ... }:

{
  virtualisation = {
    podman = {
      enable = lib.mkDefault true;
      dockerCompat = lib.mkDefault true;
      defaultNetwork.settings.dns_enabled = lib.mkDefault true;
    };
    libvirtd.enable = true;
  };

  users.extraUsers.${username}.extraGroups = [ "libvirtd" ];
}
