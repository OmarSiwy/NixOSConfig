{ pkgs, lib, username, ... }:

{
  virtualisation = {
    podman = {
      enable = lib.mkDefault true;
      dockerCompat = lib.mkDefault true;
      defaultNetwork.settings.dns_enabled = lib.mkDefault true;
    };
    libvirtd.enable = false; # ponytail: was pulling ~1GB qemu; flip to true if you need VMs
  };

  users.extraUsers.${username}.extraGroups = [ "libvirtd" ];
}
