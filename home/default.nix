{
  pkgs,
  username,
  ...
}:

{
  imports = [
    ./programs/zsh.nix
    ./programs/git.nix
    ./programs/qutebrowser.nix
    ./programs/spicetify.nix
  ];

  home = {
    username = username;
    homeDirectory = "/home/${username}";
    stateVersion = "25.05";
    enableNixpkgsReleaseCheck = false;
  };

  programs.home-manager.enable = true;

  # Icon theme for GTK apps (fixes blueman's missing audio-* icons — without
  # this, GTK falls back to hicolor which lacks them).
  gtk = {
    enable = true;
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
  };
}
