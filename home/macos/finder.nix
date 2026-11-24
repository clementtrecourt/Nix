# Finder façon macOS Tahoe : dessiné par le shell Quickshell (shell/finder),
# ouvert par l'IPC « finder ». Ce module fournit l'entrée .desktop « Finder »
# (gestionnaire par défaut des dossiers, icône Finder de MacTahoe-Apple via
# system-file-manager) et les outils qu'il appelle.
{pkgs, ...}: let
  # Lanceur : chaque argument (chemin ou URL file://) ouvre une fenêtre du
  # Finder sur ce dossier, ou sur le dossier parent avec le fichier sélectionné ;
  # sans argument : nouvelle fenêtre sur le dossier de départ.
  macos-finder = pkgs.writeShellScriptBin "macos-finder" ''
    qs="${pkgs.quickshell}/bin/quickshell"
    if [ "$#" -eq 0 ]; then
      exec "$qs" -c macos ipc call finder newWindow
    fi
    for p in "$@"; do
      "$qs" -c macos ipc call finder open "$p"
    done
  '';
in {
  home.packages = with pkgs; [
    macos-finder
    glib # gio : corbeille, ouverture, applications associées (Open With)
    inotify-tools # surveillance des dossiers ouverts
    poppler-utils # pdftoppm : vignettes et Coup d'œil des PDF
    ffmpegthumbnailer # vignettes des vidéos
    zip # Compress
    unzip # ouverture des archives .zip (Archive Utility)
    xdg-utils
  ];

  xdg.desktopEntries.finder = {
    name = "Finder";
    genericName = "File Manager";
    comment = "Browse the file system";
    exec = "macos-finder %U";
    icon = "system-file-manager";
    terminal = false;
    categories = ["System" "FileTools" "FileManager"];
    mimeType = ["inode/directory"];
  };

  xdg.mimeApps.defaultApplications."inode/directory" = ["finder.desktop"];
}
