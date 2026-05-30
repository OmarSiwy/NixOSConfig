{
  config,
  pkgs,
  lib,
  ...
}:

{
  boot = {
    # CachyOS kernel: BORE scheduler, LTO, x86-64-v3 optimizations
    kernelPackages = pkgs.linuxPackages_cachyos;
    kernelParams = [
      "systemd.mask=systemd-vconsole-setup.service"
      "systemd.mask=dev-tpmrm0.device"
      "iommu=on"
      "nowatchdog"
      "modprobe.blacklist=sp5100_tco"
      "snd_hda_intel.power_save=1"
      "intel_idle.max_cstate=7"
      "cpuidle.governor=menu"
    ];

    extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
    kernelModules = [
      "v4l2loopback"
      "tcp_bbr"
    ];

    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "ahci"
        "nvme"
        "usb_storage"
        "usbhid"
        "sd_mod"
      ];
      kernelModules = [ ];
    };

    kernel.sysctl = {
      # Memory
      "vm.max_map_count" = 2147483642;
      "vm.dirty_writeback_centisecs" = 1500;
      "vm.swappiness" = 10;          # prefer RAM, use zram as last resort
      "vm.vfs_cache_pressure" = 50;  # keep dentries/inodes in cache longer

      # Network — BBR + CAKE
      "net.core.default_qdisc" = "cake";
      "net.ipv4.tcp_congestion_control" = "bbr";
      "net.core.rmem_max" = 16777216;
      "net.core.wmem_max" = 16777216;
      "net.ipv4.tcp_fastopen" = 3;
    };

    loader.systemd-boot.enable = true;

    tmp = {
      useTmpfs = false;
      tmpfsSize = "30%";
    };

    binfmt.registrations.appimage = {
      wrapInterpreterInShell = false;
      interpreter = "${pkgs.appimage-run}/bin/appimage-run";
      recognitionType = "magic";
      offset = 0;
      mask = ''\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff'';
      magicOrExtension = ''\x7fELF....AI\x02'';
    };
    plymouth.enable = true;
  };

  # I/O scheduler: none for NVMe (has own queue), mq-deadline for SATA SSD
  services.udev.extraRules = ''
    ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
    ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
  '';
}
