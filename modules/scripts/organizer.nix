{ pkgs, config, lib, ... }:

let
  organizeScript = pkgs.writeShellScriptBin "organize-files" ''
    set -euo pipefail

    DOWNLOADS="${config.home.homeDirectory}/Downloads"
    PICTURES="${config.home.homeDirectory}/Pictures"
    DOCUMENTS="${config.home.homeDirectory}/Documents"
    VIDEOS="${config.home.homeDirectory}/Videos"
    MUSIC="${config.home.homeDirectory}/Music"

    # Ne rien faire si le dossier Downloads n'existe pas
    [ -d "$DOWNLOADS" ] || exit 0

    # Création de l'arborescence cible
    mkdir -p \
      "$PICTURES/Downloads" \
      "$DOCUMENTS/PDFs" \
      "$DOCUMENTS/Office" \
      "$VIDEOS" \
      "$MUSIC" \
      "$DOWNLOADS/Archives" \
      "$DOWNLOADS/ISOs_Torrents"

    # Déplacement sécurisé par extension (insensible à la casse, ignore les fichiers en cours)
    move_ext() {
      local dest="$1"
      shift
      for ext in "$@"; do
        find "$DOWNLOADS" -maxdepth 1 -type f -iname "*.$ext" \
          ! -name "*.crdownload" \
          ! -name "*.part" \
          ! -name ".*" \
          -exec mv -n -t "$dest" {} + 2>/dev/null || true
      done
    }

    # 1. Images -> ~/Pictures/Downloads
    move_ext "$PICTURES/Downloads" png jpg jpeg webp gif svg avif bmp ico

    # 2. Documents & PDFs -> ~/Documents/...
    move_ext "$DOCUMENTS/PDFs" pdf epub mobi
    move_ext "$DOCUMENTS/Office" docx doc odt xlsx xls csv pptx ppt ods odp txt

    # 3. Vidéos -> ~/Videos
    move_ext "$VIDEOS" mp4 mkv webm avi mov flv wmv

    # 4. Audio -> ~/Music
    move_ext "$MUSIC" mp3 flac wav ogg m4a aac opus

    # 5. Archives & Médias d'installation -> ~/Downloads/Archives & ISOs
    move_ext "$DOWNLOADS/Archives" zip tar gz bz2 xz zst 7z rar tgz
    move_ext "$DOWNLOADS/ISOs_Torrents" iso torrent img
  '';
in
{
  # Rendre la commande 'organize-files' utilisable manuellement dans le terminal
  home.packages = [ organizeScript ];

  # Service systemd lancé au démarrage / connexion
  systemd.user.services.organize-downloads = {
    Unit = {
      Description = "Rangement automatique du dossier Downloads";
      After = [ "default.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${organizeScript}/bin/organize-files";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # Timer systemd (toutes les heures en arrière-plan)
  systemd.user.timers.organize-downloads = {
    Unit = {
      Description = "Timer pour ranger périodiquement le dossier Downloads";
    };
    Timer = {
      OnCalendar = "hourly";
      Persistent = true;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
