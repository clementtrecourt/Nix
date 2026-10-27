{
  config,
  pkgs,
  ...
}: {
  imports = [./common.nix];

  # Écrans de l'hôte home uniquement (jamais dans common.nix : work a d'autres sorties)
  wayland.windowManager.mango.extraConfig = ''
    monitor_rule=name:^DP-3$,width:1920,height:1080,refresh:60,x:0,y:0,scale:1,vrr:0,rr:0
    monitor_rule=name:^HDMI-A-3$,width:1920,height:1080,refresh:60,x:1920,y:0,scale:1,vrr:0,rr:0
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
