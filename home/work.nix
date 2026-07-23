{ config, pkgs, ... }:

{
  imports = [ ./common.nix ];

  # Overrides spécifiques au PC de travail, si besoin :
  # programs.git.settings.user.email = "clement@axeesante.com";

  home.packages = with pkgs; [
    # paquets propres au taf, ex:
    # awscli2
    # kubectl
  ];
}