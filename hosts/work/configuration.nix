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

    kernelParams = [
      "quiet"
      "rd.udev.log_level=3"
      "rd.systemd.show_status=auto"
    ];

    loader.timeout = 8;
  };

  networking.hostName = "work";

  system.stateVersion = "26.05";
}
