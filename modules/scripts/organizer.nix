{pkgs, ...}: let
  organizeScript = pkgs.writeShellScriptBin "organize-files" ''
    set -euo pipefail

    DOWNLOADS="$HOME/Downloads"
    PICTURES="$HOME/Pictures"
    DOCUMENTS="$HOME/Documents"
    VIDEOS="$HOME/Videos"
    MUSIC="$HOME/Music"

    [ -d "$DOWNLOADS" ] || exit 0

    mkdir -p \
      "$PICTURES/Downloads" \
      "$DOCUMENTS/PDFs" \
      "$DOCUMENTS/Office" \
      "$DOCUMENTS/Dev_Configs" \
      "$DOCUMENTS/Certs_Keys" \
      "$VIDEOS" \
      "$MUSIC" \
      "$DOWNLOADS/Archives" \
      "$DOWNLOADS/ISOs_Torrents"

    # Déplacement par extensions classiques
    move_ext() {
      local dest="$1"
      shift
      for ext in "$@"; do
        find "$DOWNLOADS" -maxdepth 1 -type f -iname "*.$ext" \
          ! -name "*.crdownload" \
          ! -name "*.part" \
          ! -name "*.aria2" \
          ! -name ".*" \
          -exec mv -n -t "$dest" {} + 2>/dev/null || true
      done
    }

    # 1. Images
    move_ext "$PICTURES/Downloads" png jpg jpeg webp gif svg avif bmp ico

    # 2. Documents & PDFs
    move_ext "$DOCUMENTS/PDFs" pdf epub mobi
    move_ext "$DOCUMENTS/Office" docx doc odt xlsx xls csv pptx ppt ods odp txt

    # 3. Code, Sysadmin & Configs
    move_ext "$DOCUMENTS/Dev_Configs" yml yaml json j2 service conf sh py sql html css ts js

    # 4. Certificats & Clés de sécurité
    move_ext "$DOCUMENTS/Certs_Keys" pem p12 crt key pfx ovpn kdbx

    # 5. Vidéos
    move_ext "$VIDEOS" mp4 mkv webm avi mov flv wmv

    # 6. Audio
    move_ext "$MUSIC" mp3 flac wav ogg m4a aac opus

    # 7. Archives & ISOs
    move_ext "$DOWNLOADS/Archives" zip tar gz bz2 xz zst 7z rar tgz
    move_ext "$DOWNLOADS/ISOs_Torrents" iso torrent img

    # 8. Détection magique des fichiers SANS EXTENSION (via MIME-type)
    find "$DOWNLOADS" -maxdepth 1 -type f ! -name "*.*" ! -name ".*" | while read -r file; do
      mime=$(${pkgs.file}/bin/file --brief --mime-type "$file" 2>/dev/null || true)
      case "$mime" in
        image/*)
          mv -n "$file" "$PICTURES/Downloads/" ;;
        video/*)
          mv -n "$file" "$VIDEOS/" ;;
        audio/*)
          mv -n "$file" "$MUSIC/" ;;
        application/pdf)
          mv -n "$file" "$DOCUMENTS/PDFs/" ;;
        application/zip|application/x-tar|application/x-7z-compressed)
          mv -n "$file" "$DOWNLOADS/Archives/" ;;
      esac
    done
  '';
in {
  environment.systemPackages = [organizeScript];

  systemd.user.services.organize-downloads = {
    description = "Rangement automatique du dossier Downloads";
    wantedBy = ["default.target"];
    after = ["default.target"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${organizeScript}/bin/organize-files";
    };
  };

  systemd.user.timers.organize-downloads = {
    description = "Timer pour ranger périodiquement le dossier Downloads";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
    };
  };
}
