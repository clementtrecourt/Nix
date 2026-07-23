{ config, lib, pkgs, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
    ../../modules/gaming.nix
    ../../zen.nix
  ];

  networking.hostName = "nixos";
  system.stateVersion = "26.05";
}