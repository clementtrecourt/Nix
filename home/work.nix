{
  config,
  pkgs,
  ...
}: {
  imports = [./common.nix];

  # Écrans du PC de travail : à adapter (`hyprctl monitors` pour les noms)
  xdg.configFile."caelestia/hypr-monitors.lua".text = ''
    hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
    return { primary = "eDP-1", secondary = "HDMI-A-1" }
  '';

  # Overrides spécifiques au PC de travail, si besoin :
  # programs.git.settings.user.email = "clement@axeesante.com";

  home.packages = with pkgs; [
    tigervnc
    teams-for-linux
    nettools
    sshuttle
    easyeffects
    heroic
  ];
}
