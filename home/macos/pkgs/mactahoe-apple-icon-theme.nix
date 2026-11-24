# Thème d'icônes « MacTahoe-Apple-dark / -light » : les vraies icônes d'apps de
# macOS 26 Tahoe (PNG 1024 de l'input de flake `macos-icons`, jamais copiées dans le
# dépôt) renommées vers les noms d'icônes Linux équivalents, redimensionnées en
# plusieurs tailles fixes pour la netteté. Petites tailles des dossiers et documents
# (16/22/24 px : listes du sélecteur de fichiers, Nemo…) : les versions couleur de
# MacTahoe (dossier bleu plein, documents illustrés, comme dans les listes du Finder)
# au lieu de ses pictos au trait, presque invisibles sur fond sombre. Tout le reste
# (symboliques, apps tierces) est hérité de MacTahoe-dark / MacTahoe-light.
{
  lib,
  stdenvNoCC,
  imagemagick,
  gtk3,
  mactahoe-icon-theme,
  src, # inputs.macos-icons
}: let
  # Fichier source (relatif à la racine du dépôt d'icônes) -> noms d'icônes Linux
  mapping = {
    "Finder.png" = ["nemo" "system-file-manager" "org.gnome.Nautilus" "org.gnome.nautilus" "nautilus" "thunar" "org.kde.dolphin"];
    "Utilities/Terminal.png" = ["kitty" "foot" "footclient" "utilities-terminal" "Alacritty" "org.gnome.Console" "org.gnome.Terminal" "com.mitchellh.ghostty" "org.wezfurlong.wezterm" "terminal"];
    "System Settings.png" = ["org.gnome.Settings" "preferences-system" "gnome-control-center" "systemsettings" "preferences-desktop" "nwg-look" "macos-settings"];
    "Utilities/Activity Monitor.png" = ["btop" "htop" "org.gnome.SystemMonitor" "gnome-system-monitor" "utilities-system-monitor" "io.missioncenter.MissionCenter"];
    "Preview.png" = ["imv" "org.gnome.Loupe" "eog" "org.gnome.eog" "org.pwmt.zathura" "zathura" "org.gnome.Evince" "evince" "org.gnome.Papers" "multimedia-photo-viewer"];
    "QuickTime Player.png" = ["mpv" "io.mpv.Mpv" "vlc" "org.gnome.Totem" "totem" "org.gnome.Showtime"];
    "Calculator.png" = ["org.gnome.Calculator" "gnome-calculator" "accessories-calculator" "org.kde.kcalc"];
    "Calendar.png" = ["org.gnome.Calendar" "x-office-calendar"];
    "Clock.png" = ["org.gnome.clocks"];
    "Contacts.png" = ["org.gnome.Contacts"];
    "Weather.png" = ["org.gnome.Weather"];
    "Maps.png" = ["org.gnome.Maps"];
    "TextEdit.png" = ["org.gnome.TextEditor" "gedit" "org.gnome.gedit" "accessories-text-editor"];
    "Utilities/Disk Utility.png" = ["org.gnome.DiskUtility" "gnome-disks" "gparted"];
    "Font Book.png" = ["org.gnome.font-viewer" "font-viewer"];
    "Utilities/Screenshot.png" = ["org.gnome.Screenshot" "macos-screenshot" "applets-screenshooter"];
    "CoreServices/Applications/Archive Utility.png" = ["org.gnome.FileRoller" "file-roller" "ark"];
    "CoreServices/Applications/Keychain Access.png" = ["org.gnome.seahorse.Application" "seahorse"];
    "Passwords.png" = ["org.gnome.World.Secrets" "keepassxc" "org.keepassxc.KeePassXC"];
    "Utilities/Audio MIDI Setup.png" = ["pwvucontrol" "pavucontrol" "org.pulseaudio.pavucontrol" "com.saivert.pwvucontrol" "easyeffects" "com.github.wwmm.easyeffects"];
    "Utilities/Console.png" = ["org.gnome.Logs" "gnome-logs"];
    "Utilities/System Information.png" = ["hardinfo" "hardinfo2"];
    "Music.png" = ["org.gnome.Music"];
    "Photos.png" = ["shotwell" "org.gnome.Shotwell" "org.gnome.Photos"];
    "Photo Booth.png" = ["org.gnome.Snapshot" "cheese"];
    "Books.png" = ["com.github.johnfactotum.Foliate"];
    "Time Machine.png" = ["org.gnome.DejaDup" "deja-dup"];
    "App Store.png" = ["org.gnome.Software" "macos-appstore"];
    "Reminders.png" = ["org.gnome.Todo" "io.github.alainm23.planify"];
    "Notes.png" = ["org.gnome.Notes"];
    "Utilities/Bluetooth File Exchange.png" = ["blueman" "blueman-manager"];
    # Icônes propres au shell
    "Apps.png" = ["macos-apps" "macos-launchpad"];
    "Mission Control.png" = ["macos-missioncontrol"];
    "CoreServices/Spotlight.png" = ["macos-spotlight"];
    "CoreServices/Control Center.png" = ["macos-controlcenter"];
    "CoreServices/Applications/About This Mac.png" = ["macos-about"];
    "CoreServices/Dock.png" = ["macos-dock"];
    "CoreServices/Wallpaper.png" = ["macos-wallpaper"];
    "CoreServices/Batteries.png" = ["macos-batteries"];
    "Siri.png" = ["macos-siri"];
    "Safari.png" = ["macos-safari"];
  };
  sizes = [16 22 24 32 48 64 128 256 512 1024];
  # Petites tailles « couleur » : dossier de contexte -> tailles
  smallColor = {
    places = {
      context = "Places";
      sizes = [16 22 24];
    };
    mimes = {
      context = "MimeTypes";
      sizes = [16 22];
    };
  };
  smallDirs = lib.concatLists (lib.mapAttrsToList (dir: v:
    map (s: {
      name = "${dir}/${toString s}";
      size = s;
      inherit (v) context;
    })
    v.sizes)
  smallColor);
  dirsOf = lib.concatStringsSep "," (map (s: "${toString s}x${toString s}/apps") sizes ++ map (d: d.name) smallDirs);
  sections =
    lib.concatMapStrings (s: ''

      [${toString s}x${toString s}/apps]
      Context=Applications
      Size=${toString s}
      Type=Fixed
    '')
    sizes
    + lib.concatMapStrings (d: ''

      [${d.name}]
      Context=${d.context}
      Size=${toString d.size}
      Type=Fixed
    '')
    smallDirs;
  # Liens <dossier>/<taille>/<nom>.svg -> version couleur (scalable) de MacTahoe du
  # même nom, ou de l'icône vers laquelle pointe le lien de petite taille
  smallLinks =
    lib.concatMapStrings (d: let
      dir = builtins.head (lib.splitString "/" d.name);
    in ''
      mkdir -p "$dark/${d.name}"
      for f in "$base/${d.name}"/*.svg; do
        n=$(basename "$f")
        # nom cible du lien (ex. mimes/16/inode-directory -> places/16/folder)
        t=$(basename "$(readlink "$f" || echo "$f")")
        for c in "$base/${dir}/scalable/$n" "$base/places/scalable/$t" "$base/mimes/scalable/$t"; do
          if [ -e "$c" ]; then
            ln -s "$c" "$dark/${d.name}/$n"
            break
          fi
        done
      done
    '')
    smallDirs;
  indexFor = variant: inherits: ''
    [Icon Theme]
    Name=MacTahoe-Apple-${variant}
    Comment=Icônes d'apps de macOS 26 Tahoe sur MacTahoe-${variant}
    Inherits=${inherits},hicolor
    Directories=${dirsOf}
    ${sections}
  '';
  # Script bash : une conversion par fichier source et par taille, puis liens
  commands = lib.concatStrings (lib.mapAttrsToList (file: names: ''
      render ${lib.escapeShellArg file} ${lib.escapeShellArgs names}
    '')
    mapping);
in
  stdenvNoCC.mkDerivation {
    pname = "mactahoe-apple-icon-theme";
    version = "0-unstable-2026-07-08";
    inherit src;

    nativeBuildInputs = [imagemagick gtk3];
    propagatedBuildInputs = [mactahoe-icon-theme];

    dontConfigure = true;
    dontBuild = true;
    dontDropIconThemeCache = true;

    installPhase = ''
      runHook preInstall
      dark=$out/share/icons/MacTahoe-Apple-dark
      light=$out/share/icons/MacTahoe-Apple-light
      mkdir -p $dark $light

      render() {
        local file="$1"; shift
        for s in ${toString sizes}; do
          mkdir -p "$dark/''${s}x''${s}/apps"
          local out="$dark/''${s}x''${s}/apps/$1.png"
          if [ "$s" = 1024 ]; then
            cp "$src/$file" "$out"
          else
            # Lanczos + léger accent : rendu net aux petites tailles (Dock, menus)
            magick "$src/$file" -filter Lanczos -resize "''${s}x''${s}" -unsharp 0x0.6+0.4+0.02 \
              -define png:compression-level=9 "$out"
          fi
          for n in "''${@:2}"; do
            ln -s "$1.png" "$dark/''${s}x''${s}/apps/$n.png"
          done
        done
      }
      ${commands}

      # Dossiers et documents en couleur aux petites tailles
      base=${mactahoe-icon-theme}/share/icons/MacTahoe
      ${smallLinks}

      # Variante claire : mêmes icônes d'apps, héritage MacTahoe-light
      for d in $dark/*x* $dark/places $dark/mimes; do ln -s "../MacTahoe-Apple-dark/$(basename "$d")" "$light/$(basename "$d")"; done
      cat > $dark/index.theme <<'EOF'
      ${indexFor "dark" "MacTahoe-dark"}
      EOF
      cat > $light/index.theme <<'EOF'
      ${indexFor "light" "MacTahoe-light"}
      EOF
      sed -i 's/^ *//' $dark/index.theme $light/index.theme
      gtk-update-icon-cache -f -t $dark
      gtk-update-icon-cache -f -t $light
      # Les thèmes hérités doivent être dans le même XDG_DATA_DIRS : liens vers MacTahoe
      for t in MacTahoe MacTahoe-dark MacTahoe-light; do
        ln -s ${mactahoe-icon-theme}/share/icons/$t $out/share/icons/$t
      done
      runHook postInstall
    '';

    meta = {
      description = "Icônes d'apps macOS 26 Tahoe superposées au thème MacTahoe";
      platforms = lib.platforms.linux;
    };
  }
