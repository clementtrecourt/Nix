{
  config,
  pkgs,
  ...
}: {
  imports = [./common.nix];
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
