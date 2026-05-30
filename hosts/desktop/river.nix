{ pkgs, ... }:
let
  wowup-cf-fixed = pkgs.symlinkJoin {
    name = "wowup-cf";
    paths = [ pkgs.wowup-cf ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/wowup-cf \
        --add-flags "--no-sandbox" \
        --unset WAYLAND_DISPLAY
    '';
  };
in
{
  programs.river-classic.enable = true;
  programs.xwayland.enable = true;

  services.xserver = {
    enable = true;
    xkb = {
      layout = "us";
      variant = "";
    };
  };

  xdg.mime = {
    enable = true;
    defaultApplications = {
      "text/html" = "org.qutebrowser.qutebrowser.desktop";
      "x-scheme-handler/http" = "org.qutebrowser.qutebrowser.desktop";
      "x-scheme-handler/https" = "org.qutebrowser.qutebrowser.desktop";
      "x-scheme-handler/about" = "org.qutebrowser.qutebrowser.desktop";
      "x-scheme-handler/unknown" = "org.qutebrowser.qutebrowser.desktop";
      "x-scheme-handler/slack" = "slack.desktop";
    };
  };

  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
    config = {
      common = {
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
      };
    };
  };

  environment.sessionVariables = {
    XDG_CURRENT_DESKTOP = "river";
    XDG_SESSION_TYPE = "wayland";
    QT_QPA_PLATFORM = "wayland";
    QT_STYLE_OVERRIDE = "qt6ct";

    XCURSOR_THEME = "Volantes";
    XCURSOR_SIZE = "24";

    NIXOS_OZONE_WL = "1";
  };

  environment.systemPackages = with pkgs; [
    # Wow addons
    wowup-cf-fixed

    # Anime!
    ani-cli

    # ── Wayland / WM core ─────────────────────────────
    river-classic
    rill
    wlr-randr
    kanshi
    wdisplays
    xwayland
    awww
    waybar

    # ── Notifications / Portals / Auth ───────────────
    mako
    libnotify

    # ── Browsers ─────────────────────────────────────
    qutebrowser

    # ── App launcher / UI tools ──────────────────────
    rofi
    nwg-look
    volantes-cursors

    # ── Power / Idle / Lock ──────────────────────────
    swayidle
    swaylock
    wlopm
    brightnessctl
    ddcutil

    # ── Terminal / Utilities ─────────────────────────
    ghostty
    btop
    gnome-system-monitor

    # ── Screenshots / Clipboard ──────────────────────
    grim
    slurp
    wl-clipboard
    imagemagick

    # ── Audio / Media ────────────────────────────────
    pamixer
    pavucontrol
    playerctl

    # ── Networking ─────────────────────────────────
    networkmanagerapplet

    # ── GPU / Monitoring ─────────────────────────────
    nvtopPackages.full

    # ── Qt / GTK theming & deps ──────────────────────
    gtk-engine-murrine
    glib
    kdePackages.qt6ct
    kdePackages.qtwayland
    qt6.qtdeclarative
    qt6.qtwebengine
    python3Packages.pyqt6
  ];

  fonts.packages = with pkgs; [
    noto-fonts
    fira-code
    jetbrains-mono
    font-awesome
    nerd-fonts.jetbrains-mono
  ];

  programs = {
    dconf.enable = true;
    nm-applet.indicator = true;
  };

  hardware.i2c.enable = true;
}
