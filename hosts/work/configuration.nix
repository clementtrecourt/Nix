{ config, lib, pkgs, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
  ];
  boot.kernelPackages = pkgs.linuxPackages;
  boot = {
      plymouth = {
        enable = true;
        theme = "lone"; # ou un autre nom de thème du pack, ex: "angular", "lone", etc.
        themePackages = with pkgs; [
          (adi1090x-plymouth-themes.override { selected_themes = [ "lone" ]; })
        ];
      };

      consoleLogLevel = 3;
      initrd ={
          verbose = false;
          kernelModules = [ "i915" ];
        };

      kernelParams = [
        "quiet"
        "rd.udev.log_level=3"
        "rd.systemd.show_status=auto"
      ];

      loader.timeout = 0;
  };
  networking.hostName = "work";
  system.stateVersion = "26.05";
}
