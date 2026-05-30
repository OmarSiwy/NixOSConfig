# Overlay: river 0.4.5 compositor + rill 0.6.0 window manager
# river-classic in nixpkgs is used as the base to build river 0.4.5.
# River 0.4.x is a non-monolithic compositor — it requires a separate WM (rill).
final: prev: {
  # rill: minimalist scrolling WM implementing river-window-management-v1
  # Windows open in horizontal columns you scroll through (PaperWM-style).
  # Config: ~/.config/rill/config.zon
  # Source: https://codeberg.org/lzj15/rill
  rill = prev.stdenv.mkDerivation (finalAttrs: {
    pname = "rill";
    version = "0.6.0";

    src = prev.lib.cleanSource ./rill;

    deps = prev.linkFarm "zig-packages" [
      {
        name = "wayland-0.6.0-lQa1kqz8AQADQmdNJsNhLoNHcnEGEUjrOaPV-dtEnEmX";
        path = prev.fetchzip {
          url = "https://codeberg.org/ifreund/zig-wayland/archive/v0.6.0.tar.gz";
          hash = "sha256-3m/ITNhZUJ/5uD/Tqm+0uZSktGoYgWF5oldOqOCUkIE=";
        };
      }
      {
        name = "xkbcommon-0.4.0-VDqIe0i2AgDRsok2GpMFYJ8SVhQS10_PI2M_CnHXsJJZ";
        path = prev.fetchzip {
          url = "https://codeberg.org/ifreund/zig-xkbcommon/archive/v0.4.0.tar.gz";
          hash = "sha256-zQkmP/cuhAtjOLqYS5D15khKzpqyhbyZ0TD6/8jOkqE=";
        };
      }
    ];

    nativeBuildInputs = [ final.zig_0_16.hook prev.pkg-config prev.wayland-scanner ];
    buildInputs = [
      prev.wayland
      prev.wayland-protocols
      prev.libxkbcommon
    ];

    dontConfigure = true;

    preBuild = ''
      export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-global-cache"
      mkdir -p "$ZIG_GLOBAL_CACHE_DIR"
    '';

    zigBuildFlags = [
      "--system" "${finalAttrs.deps}"
      "--release=safe"
    ];

    meta = {
      description = "Minimalist scrolling window manager for the river compositor";
      homepage = "https://codeberg.org/lzj15/rill";
      license = prev.lib.licenses.mit;
      platforms = prev.lib.platforms.linux;
      mainProgram = "rill";
    };
  });

  river-classic = prev.river-classic.overrideAttrs (old: {
    pname = "river";
    version = "0.4.5";

    src = prev.fetchFromGitea {
      domain = "codeberg.org";
      owner = "river";
      repo = "river";
      tag = "v0.4.5";
      hash = "sha256-q4JAlr9/ex+BEgktBmFwOvZzQEAGvxXPD1QyKqyha4g=";
    };

    # river 0.4.x removed example/init; the base postInstall tries to install it.
    postInstall = ''
      install contrib/river.desktop -Dt $out/share/wayland-sessions
    '';

    # Replace wlroots_0_18 (used by river-classic 0.3.x) with wlroots_0_20.
    buildInputs =
      (builtins.filter
        (p: builtins.match "wlroots.*" (p.name or "") == null)
        (old.buildInputs or []))
      ++ [ final.wlroots_0_20 ];

    # River 0.4.5 needs zig 0.16.
    nativeBuildInputs =
      (builtins.filter
        (p: builtins.match "zig.*" (p.name or "") == null)
        (old.nativeBuildInputs or []))
      ++ [ final.zig_0_16.hook ];

    deps = prev.linkFarm "zig-packages" [
      {
        name = "pixman-0.3.0-LClMnz2VAAAs7QSCGwLimV5VUYx0JFnX5xWU6HwtMuDX";
        path = prev.fetchzip {
          url = "https://codeberg.org/ifreund/zig-pixman/archive/v0.3.0.tar.gz";
          hash = "sha256-8tA4auo5FEI4IPnomV6bkpQHUe302tQtorFQZ1l14NU=";
        };
      }
      {
        name = "wayland-0.6.0-lQa1kqz8AQADQmdNJsNhLoNHcnEGEUjrOaPV-dtEnEmX";
        path = prev.fetchzip {
          url = "https://codeberg.org/ifreund/zig-wayland/archive/v0.6.0.tar.gz";
          hash = "sha256-3m/ITNhZUJ/5uD/Tqm+0uZSktGoYgWF5oldOqOCUkIE=";
        };
      }
      {
        name = "wlroots-0.20.1-jmOlcqNVBAB3uB5oqBTzpRlwu-FmMyyZMVAWCe5kmcSt";
        path = prev.fetchzip {
          url = "https://codeberg.org/ifreund/zig-wlroots/archive/v0.20.1.tar.gz";
          hash = "sha256-cfzHJ2ziiCkMyNlIo6I9o/NjaZGrsv22hq41WYwCnpk=";
        };
      }
      {
        name = "xkbcommon-0.4.0-VDqIe0i2AgDRsok2GpMFYJ8SVhQS10_PI2M_CnHXsJJZ";
        path = prev.fetchzip {
          url = "https://codeberg.org/ifreund/zig-xkbcommon/archive/v0.4.0.tar.gz";
          hash = "sha256-zQkmP/cuhAtjOLqYS5D15khKzpqyhbyZ0TD6/8jOkqE=";
        };
      }
      {
        name = "translate_c-0.0.0-Q_BUWlX1BgCD1wo6uo97prlp9VJ4gxAjwN_vZ7nsSjGN";
        path = prev.fetchzip {
          url = "https://codeberg.org/ziglang/translate-c/archive/57c559cf581b1fcad90494eda219f98abeb155ce.tar.gz";
          hash = "sha256-7OlW2f5tRc1UZySDcEQERsLGChSxIcJAiVWdvuFUvvY=";
        };
      }
      {
        name = "aro-0.0.0-JSD1Qi7QNgDnfcrdEJf82v3o6MhZySjYVrtdfEf3E4Se";
        path = prev.fetchzip {
          url = "https://github.com/Vexu/arocc/archive/5f5a050569a95ecc40a426f0c3666ae7ef987ede.tar.gz";
          hash = "sha256-f8Z0SXWx5Uia2TCMB5SUpcO8+xUnaWk32Oknva7xcxw=";
        };
      }
    ];
  });
}
