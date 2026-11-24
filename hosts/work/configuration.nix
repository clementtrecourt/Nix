{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/work.nix
  ];

  boot = {
    consoleLogLevel = 3;

    initrd.verbose = false;

    kernelParams = [
      "quiet"
      "rd.udev.log_level=3"
      "rd.systemd.show_status=auto"
    ];

    loader.timeout = 0;
  };

  networking.hostName = "work";

  # Écrans du bureau : deux 24" 1080p côte à côte (cf. modules/display.nix)
  my.display.outputs = {
    # Samsung S24F350 (série H4ZK910475), à gauche
    "DP-3" = {
      mode = "1920x1080@60";
      position = {
        x = 0;
        y = 0;
      };
      focusAtStartup = true;
    };
    # Philips 247ELH (série AU51202005588), à droite
    "HDMI-A-3" = {
      mode = "1920x1080@60";
      position = {
        x = 1920;
        y = 0;
      };
    };
  };

  system.stateVersion = "26.05";
}
