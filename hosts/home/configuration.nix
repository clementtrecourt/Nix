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
    ../../modules/gaming.nix
  ];
  networking.hostName = "home";

  # Écrans : détection automatique par niri tant que rien n'est déclaré.
  # Sous niri, régler les écrans (réglages iNiR) puis lancer
  # `display-snippet` et coller le résultat ici (cf. modules/display.nix).
  my.display.outputs = {};
  system.stateVersion = "26.05";
}
