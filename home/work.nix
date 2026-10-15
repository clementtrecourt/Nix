{
  config,
  pkgs,
  ...
}: {
  imports = [./common.nix];

  # Écrans du PC work (ici) : Philips (HDMI-A-3) = workspaces 1-5, Samsung (DP-3) = 6-9
  xdg.configFile."caelestia/hypr-monitors.lua".text = ''
    hl.monitor({ output = "DP-3", mode = "preferred", position = "0x0", scale = 1 })
    hl.monitor({ output = "HDMI-A-3", mode = "preferred", position = "1920x0", scale = 1 })
    return { primary = "HDMI-A-3", secondary = "DP-3" }
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
