{ pkgs, ... }:
let
  wlCopyRs = pkgs.writeShellScriptBin "wl-copy-rs" ''
    exec ${pkgs.wl-clipboard-rs}/bin/wl-copy "$@"
  '';

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
    wlr.settings = {
      screencast = {
        chooser_type = "simple";
        chooser_cmd = "${pkgs.slurp}/bin/slurp -f 'Monitor: %o' -or";
      };
    };
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
    eww

    # ── Notifications / Portals / Auth ───────────────
    mako
    libnotify

    # ── Browsers ─────────────────────────────────────
    qutebrowser

    # ── App launcher / UI tools ──────────────────────
    fuzzel
    papirus-icon-theme
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
    wl-clipboard-rs
    wlCopyRs
    wl-clip-persist
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

  fonts = {
    fontDir.enable = true;

    fontconfig.defaultFonts = {
      monospace = [
        "Iosevka"
        "Iosevka Nerd Font"
        "Liberation Mono"
        "DejaVu Sans Mono"
      ];
      sansSerif = [
        "Noto Sans"
        "Arial"
        "Liberation Sans"
        "DejaVu Sans"
      ];
      serif = [
        "Noto Serif"
        "Times New Roman"
        "Liberation Serif"
        "DejaVu Serif"
      ];
    };

    packages = with pkgs; [
      noto-fonts
      iosevka
      font-awesome
      nerd-fonts.iosevka

      # Wine apps such as LTSpice behave better with broader Windows-compatible
      # fallback families available through fontconfig.
      liberation_ttf
      dejavu_fonts
      corefonts
    ];
  };

  programs = {
    dconf.enable = true;
    nm-applet.indicator = true;
  };

  hardware.i2c.enable = true;
}
