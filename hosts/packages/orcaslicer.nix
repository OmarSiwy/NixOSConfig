{ config, lib, pkgs, ... }:

let
  cfg = config.services.orcaslicer;

  # Wrapper script: start container → open browser → stop container on exit
  orcaslicer-launcher = pkgs.writeShellScriptBin "orcaslicer" ''
    SERVICE="podman-orcaslicer"
    URL="https://localhost:${toString cfg.port}"

    cleanup() {
      echo "Stopping OrcaSlicer container..."
      systemctl stop "$SERVICE" 2>/dev/null
    }
    trap cleanup EXIT

    echo "Starting OrcaSlicer container..."
    systemctl start "$SERVICE"

    # Wait for the web UI to become available
    for i in $(seq 1 30); do
      if ${pkgs.curl}/bin/curl -sSfk "$URL" >/dev/null 2>&1; then
        break
      fi
      sleep 1
    done

    echo "Opening OrcaSlicer in browser..."
    ${pkgs.xdg-utils}/bin/xdg-open "$URL"

    echo "OrcaSlicer is running. Press Ctrl+C or close this terminal to stop."
    # Keep alive until interrupted
    while systemctl is-active --quiet "$SERVICE"; do
      sleep 5
    done
  '';

  # Desktop entry — shows "OrcaSlicer" in your app launcher
  orcaslicer-desktop = pkgs.makeDesktopItem {
    name = "orcaslicer";
    desktopName = "OrcaSlicer";
    comment = "3D Printer Slicer (browser-based)";
    exec = "${orcaslicer-launcher}/bin/orcaslicer";
    icon = "orcaslicer";
    categories = [ "Graphics" "3DGraphics" "Engineering" ];
    terminal = true;
  };

  # Fetch the official OrcaSlicer icon from the repo
  orcaslicer-icon = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/OrcaSlicer/OrcaSlicer/main/resources/images/OrcaSlicer_128px.png";
    sha256 = "sha256-Y7kiAJnIPAyMiLiUgu1Yem35AcuDiDFFJ8nAV+l+nwU=";
  };

in
{
  options.services.orcaslicer = {
    enable = lib.mkEnableOption "OrcaSlicer web UI (LinuxServer container)";

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "HTTPS port for the OrcaSlicer web UI.";
    };

    httpPort = lib.mkOption {
      type = lib.types.port;
      default = 3001;
      description = "HTTP port for the OrcaSlicer web UI.";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/orcaslicer";
      description = "Persistent storage directory for OrcaSlicer config and prints.";
    };

    gpuType = lib.mkOption {
      type = lib.types.enum [ "none" "intel" "amd" "nvidia" ];
      default = "none";
      description = ''
        GPU type for hardware-accelerated 3D viewport rendering.
        - "none"   : Software rendering (slow but works everywhere)
        - "intel"  : Intel iGPU via /dev/dri
        - "amd"    : AMD GPU via /dev/dri
        - "nvidia" : NVIDIA GPU (requires nvidia-container-toolkit)
      '';
    };

    useWayland = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Use the Wayland/Selkies streaming stack (recommended).
        Provides zero-copy GPU encoding and lower latency.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "1000";
      description = "PUID to run the container as.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "1000";
      description = "PGID to run the container as.";
    };

    imageTag = lib.mkOption {
      type = lib.types.str;
      default = "latest";
      description = "LinuxServer OrcaSlicer image tag.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the configured ports in the firewall.";
    };

    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional environment variables to pass to the container.";
    };
  };

  config = lib.mkIf cfg.enable {

    # ── Desktop entry + launcher ───────────────────────────────────
    environment.systemPackages = [
      orcaslicer-desktop
      orcaslicer-launcher
    ];

    # Install the icon so the desktop entry can find it
    environment.etc."xdg/icons/hicolor/128x128/apps/orcaslicer.png".source =
      orcaslicer-icon;

    # ── Persistent data directory ──────────────────────────────────
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 ${cfg.user} ${cfg.group} -"
    ];

    # ── Container runtime (Podman) ─────────────────────────────────
    virtualisation.podman = {
      enable = lib.mkDefault true;
      defaultNetwork.settings.dns_enabled = lib.mkDefault true;
    };
    virtualisation.oci-containers.backend = lib.mkDefault "podman";

    # ── NVIDIA container toolkit (only if nvidia selected) ─────────
    hardware.nvidia-container-toolkit.enable =
      lib.mkIf (cfg.gpuType == "nvidia") true;

    # ── The container (does NOT autostart) ─────────────────────────
    virtualisation.oci-containers.containers.orcaslicer = {
      image = "lscr.io/linuxserver/orcaslicer:${cfg.imageTag}";
      autoStart = false;

      ports = [
        "127.0.0.1:${toString cfg.port}:3000"
        "127.0.0.1:${toString cfg.httpPort}:3001"
      ];

      volumes = [
        "${cfg.dataDir}:/config"
      ];

      environment = {
        PUID = cfg.user;
        PGID = cfg.group;
        TZ = if config.time.timeZone != null then config.time.timeZone else "UTC";
      }
      // lib.optionalAttrs cfg.useWayland {
        PIXELFLUX_WAYLAND = "true";
        DRINODE = "/dev/dri/renderD128";
        DRI_NODE = "/dev/dri/renderD128";
      }
      // cfg.extraEnvironment;

      extraOptions =
        lib.optionals (cfg.gpuType != "none") [
          "--device=/dev/dri:/dev/dri"
        ]
        ++ lib.optionals (cfg.gpuType == "nvidia") [
          "--device=nvidia.com/gpu=all"
          "--security-opt=label=disable"
        ];
    };

    # Allow the user to start/stop the container without sudo
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            action.lookup("unit") == "podman-orcaslicer.service" &&
            subject.isInGroup("users")) {
          return polkit.Result.YES;
        }
      });
    '';

    # ── Firewall ───────────────────────────────────────────────────
    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port cfg.httpPort ];
    };
  };
}
