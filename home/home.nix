{
  config,
  pkgs,
  ...
}: {
  imports = [./common.nix];

  # Écrans du PC fixe : Philips (HDMI-A-3) = workspaces 1-5, Samsung (DP-3) = 6-9
  xdg.configFile."caelestia/hypr-monitors.lua".text = ''
    hl.monitor({ output = "DP-3", mode = "preferred", position = "0x0", scale = 1 })
    hl.monitor({ output = "HDMI-A-3", mode = "preferred", position = "1920x0", scale = 1 })
    return { primary = "HDMI-A-3", secondary = "DP-3" }
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
