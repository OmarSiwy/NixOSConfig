{
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./machine.nix

    # System
    ./boot.nix
    ./networking.nix
    ./nix.nix
    ./security.nix
    ./virtualization.nix

    # Hardware
    ./hardware/graphics.nix
    ./hardware/bluetooth.nix
    ./hardware/amd.nix
    ./hardware/intel.nix
    ./hardware/nvidia.nix
    ./hardware/nvidia-prime.nix
    ./hardware/legion.nix

    # Desktop
    ./desktop/river.nix
    ./desktop/greetd.nix
    ./desktop/audio.nix

    # Services
    ./services.nix

    # Packages
    ./packages
  ];
}
