{
  pkgs,
  inputs,
  username,
  ...
}:

let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.system};
in
{
  imports = [
    inputs.spicetify-nix.homeManagerModules.spicetify
    ./programs/zsh.nix
    ./programs/git.nix
  ];

  home = {
    username = username;
    homeDirectory = "/home/${username}";
    stateVersion = "25.05";
    enableNixpkgsReleaseCheck = false;
  };

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    widevine-cdm
  ];

  # Slack's sign-in page does a JS-initiated redirect to slack://, not a
  # direct user click, so allow-from-user-interaction blocks it. allow-all
  # lets Qt WebEngine pass the URI through to xdg-open.
  programs.qutebrowser = {
    enable = true;
    settings = {
      content.unknown_url_scheme_policy = "allow-all";
      content.plugins = true;
    };
    extraConfig = ''
      c.qt.args += ["widevine-path=${pkgs.widevine-cdm}/share/google/chrome/WidevineCdm/_platform_specific/linux_x64/libwidevinecdm.so"]
    '';
  };

  # User-level mimeapps.list — GIO and Qt check this before the system-level
  # /etc/xdg/mimeapps.list, so this ensures xdg-open resolves slack:// reliably.
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "x-scheme-handler/slack" = "slack.desktop";
    };
  };

  programs.spicetify = {
    enable = true;
    theme = spicePkgs.themes.tokyoNight;
    enabledExtensions = with spicePkgs.extensions; [
      adblockify
      hidePodcasts
      shuffle
    ];
  };
}
