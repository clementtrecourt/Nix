{
  config,
  pkgs,
  ...
}: {
  imports = [./common.nix];

  # Écrans de l'hôte home uniquement (DP-3 BenQ à gauche, DP-2 Samsung à droite) — jamais dans common.nix : work a d'autres sorties
  wayland.windowManager.mango.extraConfig = ''
    monitor_rule=name:^DP-3$,width:1920,height:1080,refresh:60,x:0,y:0,scale:1
    monitor_rule=name:^DP-2$,width:2560,height:1440,refresh:143.998,x:1920,y:0,scale:1,primary:1
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
