{ pkgs, ... }:

let
  cleanerScript = pkgs.writeShellScriptBin "clean-user-cache" ''
    set -euo pipefail

    # Corbeille : fichiers de plus de 14 jours
    TRASH="$HOME/.local/share/Trash/files"
    [ -d "$TRASH" ] && find "$TRASH" -mindepth 1 -mtime +14 -delete 2>/dev/null || true

    # Miniatures : fichiers de plus de 30 jours
    THUMBS="$HOME/.cache/thumbnails"
    [ -d "$THUMBS" ] && find "$THUMBS" -type f -atime +30 -delete 2>/dev/null || true
  '';
in
{
  environment.systemPackages = [ cleanerScript ];

  systemd.user.services.auto-clean-cache = {
    description = "Nettoyage automatique de la corbeille et des caches";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${cleanerScript}/bin/clean-user-cache";
    };
  };

  systemd.user.timers.auto-clean-cache = {
    description = "Timer quotidien de nettoyage des caches";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };
}
