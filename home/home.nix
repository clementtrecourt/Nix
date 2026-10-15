{
  config,
  pkgs,
  ...
}: {
  imports = [./common.nix];

  # Écrans du PC home : à adapter (`hyprctl monitors` pour les noms)
  xdg.configFile."caelestia/hypr-monitors.lua".text = ''
    hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
    return { primary = "eDP-1", secondary = "HDMI-A-1" }
  '';
  # ========================================================
  # Sauvegarde automatique des jeux (Ludusavi) - Gaming PC
  # ========================================================
  services.ludusavi = {
    enable = true;
    frequency = "daily";
    backupNotification = true;

    settings = {
      language = "fr-FR";
      theme = "dark";

      backup = {
        path = "${config.home.homeDirectory}/Documents/Ludusavi_Backups";
      };

      restore = {
        path = "${config.home.homeDirectory}/Documents/Ludusavi_Backups";
      };

      roots = [
        {
          path = "${config.home.homeDirectory}/.local/share/Steam";
          store = "steam";
        }
        {
          path = "${config.home.homeDirectory}/.config/heroic";
          store = "heroic";
        }
        {
          path = "${config.home.homeDirectory}/Games/Heroic";
          store = "heroic";
        }
      ];
    };
  };
}
