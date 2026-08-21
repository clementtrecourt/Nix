{ config, lib, pkgs, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/gaming.nix
  ];
  boot.kernelPackages = pkgs.linuxPackages_zen;
  networking.hostName = "home";
  system.stateVersion = "26.05";
}
