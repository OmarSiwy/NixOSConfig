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
      # ========== SYSTEM UTILITIES ==========
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
      # ========== WINE ==========
      wineWow64Packages.staging
      winetricks
      samba
      mesa-demos # glxinfo - IMPORTANT for diagnostics
      vulkan-tools # vulkaninfo
      dxvk
      # ========== GAMING ==========
      lutris-nvidia
      mangohud
      protonup-qt
      # ========== NETWORKING ==========
      iw
      wirelesstools
      wireless-regdb
      openconnect # School VPN
      # ========== MEDIA & ENTERTAINMENT ==========
      fastfetch
      obs-studio
      yt-dlp
      (mpv.override { scripts = [ mpvScripts.mpris ]; })
      karere # Whatsapp
      # ========== COMMUNICATION ==========
      slack
      teams-for-linux
      zoom-us
      vesktop
      # ========== DEVELOPMENT TOOLS ==========
      ltspice # SPICE simulator (Wine-based, the standard nixpkgs package)
      obsidian
      zathura
      # ========== CONTAINERIZATION ==========
      podman-compose
      # ========== Screenshare on IPAD  =======
      uxplay
      # GStreamer runtime + common codecs/sinks
      gst_all_1.gstreamer
      gst_all_1.gst-plugins-base
      gst_all_1.gst-plugins-good
      gst_all_1.gst-plugins-bad
      gst_all_1.gst-plugins-ugly
      gst_all_1.gst-libav
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
