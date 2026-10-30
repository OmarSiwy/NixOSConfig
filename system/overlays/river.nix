# Overlay: river 0.4.8 compositor.
# river-classic in nixpkgs is used as the base to build river 0.4.8.
# River 0.4.x is a non-monolithic compositor — it requires a separate WM.
# That WM is `rill`, built from pkgs/brill (our fork) by an overlay in flake.nix.
final: prev: {
  river-classic = prev.river-classic.overrideAttrs (old: {
    pname = "river";
    version = "0.4.8";

    src = prev.fetchFromGitea {
      domain = "codeberg.org";
      owner = "river";
      repo = "river";
      tag = "v0.4.8";
      hash = "sha256-vqOGyd0sddjYZ47xPMFmfzDIg8mHfIBzAJQ2CcsMQ3Y=";
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
