{ config, lib, pkgs, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
  ];
  boot.kernelPackages = pkgs.linuxPackages;
  networking.hostName = "work";
  system.stateVersion = "26.05";
}
