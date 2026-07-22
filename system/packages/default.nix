{
  pkgs,
  pkgs-stable,
  ...
}:
let
  python-packages = pkgs.python3.withPackages (
    ps: with ps; [
      requests
      pyquery
    ]
  );

  # Lutris wrapped with Nvidia PRIME offload env vars so every game launched
  # from it (including the Battle.net Wine prefix -> WoW) runs on the dGPU.
  # The desktop entry (net.lutris.Lutris.desktop) uses `Exec=lutris` which
  # resolves via PATH, so this wrapper takes over transparently.
  #
  # We also force DISPLAY=:0 so Lutris' xrandr/glxinfo probes succeed under
  # the river (Wayland) session via XWayland — otherwise they fail at
  # startup with "Can't open display" and spam the log.
  # OrcaSlicer forced onto XWayland + iGPU rendering. Native Wayland breaks its
  # wxWidgets/GTK stack; the nvidia GLX path and webkitgtk dmabuf renderer both
  # misbehave under the river session, so pin GL to mesa and disable dmabuf.
  orca-slicer-wrapped = pkgs.symlinkJoin {
    name = "orca-slicer-wrapped";
    paths = [ pkgs.orca-slicer ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/orca-slicer \
        --set DRI_PRIME 0 \
        --set __GLX_VENDOR_LIBRARY_NAME mesa \
        --set GDK_BACKEND x11
    '';
  };

  lutris-nvidia = pkgs.symlinkJoin {
    name = "lutris-nvidia";
    paths = [ pkgs.lutris ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm -f $out/bin/lutris
      makeWrapper ${pkgs.lutris}/bin/lutris $out/bin/lutris \
        --set __NV_PRIME_RENDER_OFFLOAD 1 \
        --set __NV_PRIME_RENDER_OFFLOAD_PROVIDER NVIDIA-G0 \
        --set __VK_LAYER_NV_optimus NVIDIA_only \
        --set __GLX_VENDOR_LIBRARY_NAME nvidia \
        --set __GL_THREADED_OPTIMIZATION 1 \
        --set __GL_SHADER_DISK_CACHE 1 \
        --set __GL_SHADER_DISK_CACHE_PATH "$HOME/.cache/nvidia-shader-cache" \
        --set-default DISPLAY :0
        # NOTE: do NOT set VK_ICD_FILENAMES. Pinning it to the x86_64 json
        # excludes the i686 ICD, which breaks 32-bit Wine apps (Battle.net,
        # the WoW launcher, etc.). The Vulkan loader auto-discovers both
        # /run/opengl-driver{,-32}/share/vulkan/icd.d/nvidia_icd.*.json and
        # the __NV_PRIME_* vars above already steer it to the dGPU.
    '';
  };

in
{
  imports = [
    ./development.nix
  ];

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages =
    (with pkgs; [
      # ── Core system utilities ──
      baobab
      bc
      btrfs-progs
      clang
      curl
      cpufrequtils
      duf
      findutils
      ffmpeg
      git
      htop
      killall
      openssl
      pciutils
      pkgs-stable.neovim
      unzip
      wget
      xarchiver
      xdg-user-dirs
      xdg-utils
      yad
      zathura # PDF/document viewer (pdf-mupdf plugin bundled)
      orca-slicer-wrapped # 3D print slicer (X11/mesa-wrapped, see let-binding)

      # ── Wine ──  (runtime + companions)
      wineWow64Packages.staging
      winetricks # wine-prefix configuration helper
      dxvk # D3D9/10/11 → Vulkan

      # ── Gaming ──  (Lutris/Steam stack; Steam itself under programs.steam)
      lutris-nvidia
      mangohud # in-game perf overlay
      protonup-qt # manages GE-Proton versions
      mesa-demos # glxinfo — Lutris diagnostic shim (see services.nix envfs)
      vulkan-tools # vulkaninfo — Lutris diagnostic shim (see services.nix envfs)

      # ── Networking ──
      iw
      wirelesstools
      wireless-regdb
      openconnect # School VPN
      samba # NOT a Wine dep — keep only if you use SMB shares / NTLM auth

      # ── Media & entertainment ──
      fastfetch
      obs-studio
      yt-dlp
      (mpv.override { scripts = [ mpvScripts.mpris ]; })
      karere # WhatsApp

      # ── Communication ──
      slack
      teams-for-linux
      vesktop
      obsidian

      # ── Containerization ──
      podman-compose

      # ── Screenshare to iPad ──
      # uxplay self-bundles its GStreamer plugins (binary is wrapped with
      # GST_PLUGIN_SYSTEM_PATH_ → base/good/bad/ugly/libav are already in its
      # runtime closure), so they don't need to be listed here.
      uxplay
      gnome-network-displays # Miracast / Wi-Fi Display casting
    ])
    ++ [
      python-packages
    ];

  programs = {
    seahorse.enable = true;
    fuse.userAllowOther = true;
    mtr.enable = true;
    thunar = {
      enable = true;
      plugins = with pkgs; [
        xfce4-exo
        mousepad
        thunar-archive-plugin
        thunar-volman
        tumbler
      ];
    };
    noisetorch.enable = true;
    steam = {
      enable = true;
      gamescopeSession.enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
    };
    gamemode = {
      enable = true;
      settings = {
        gpu = {
          apply_gpu_optimisations = 0;
        };
      };
    };
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
  };

  # NOTE: The Lutris /usr/bin/vulkaninfo and /usr/bin/glxinfo shims are
  # provided via `services.envfs.extraFallbackPathCommands` in
  # ../services/services.nix, not via an activation script. An activation
  # script cannot write to /usr/bin because envfs mounts it read-only (FUSE),
  # and even if it could, envfs would mask the entries.
}
