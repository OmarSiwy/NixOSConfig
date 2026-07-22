{ pkgs, ... }:

{
  home.packages = [ pkgs.widevine-cdm ];

  # Slack's sign-in page does a JS-initiated redirect to slack://, not a
  # direct user click, so allow-from-user-interaction blocks it. allow-all
  # lets Qt WebEngine pass the URI through to xdg-open.
  programs.qutebrowser = {
    enable = true;
    package = pkgs.symlinkJoin {
      name = "qutebrowser-gpu";
      paths = [ pkgs.qutebrowser ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/qutebrowser \
          --set EGL_PLATFORM wayland \
          --set QT_OPENGL_NO_SANITY_CHECK 1 \
          --set QTWEBENGINE_CHROMIUM_FLAGS "--disable-accelerated-video-decode --disable-accelerated-video-encode"
      '';
    };
    settings = {
      content.unknown_url_scheme_policy = "allow-all";
      content.plugins = true;

      # Native ad blocker (nixpkgs qutebrowser bundles the python `adblock`
      # engine, so "both" = hosts list + ABP-syntax lists).
      content.blocking.enabled = true;
      content.blocking.method = "both";

      # Chromium forced dark mode.
      colors.webpage.darkmode.enabled = true;
      colors.webpage.preferred_color_scheme = "dark";
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
}
