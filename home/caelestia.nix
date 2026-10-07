{
  config,
  pkgs,
  inputs,
  lib,
  ...
}: {
  # 1. Déploiement de votre disposition XKB personnalisée
  xdg.configFile."xkb/symbols/us_qwerty-fr".source = "${inputs.qwerty-fr}/linux/us_qwerty-fr";

  # 2. Déploiement de la configuration Hyprland officielle de Caelestia (Lua)
  xdg.configFile."hypr" = {
    source = "${inputs.caelestia-dots}/hypr";
    recursive = true;
  };

  # 3. Vos surcharges applicatives et variables (hypr-vars.lua)
  # Ce fichier surcharge les paramètres par défaut de Caelestia
  xdg.configFile."caelestia/hypr-vars.lua".text = ''
    return {
      -- Applications par défaut
      terminal = "kitty",
      browser = "zen-beta",
      editor = "zed",
      fileManager = "kitty -e yazi",

      -- Clavier & Disposition
      kbLayout = "us_qwerty-fr",
      kbVariant = "qwerty-fr",
      kbRepeatRate = 25,
      kbRepeatDelay = 400,
      numlockOn = true,

      -- Décorations de fenêtres & Effets
      windowGapsIn = 5,
      windowGapsOut = 5,
      windowBorderSize = 2,
      windowRounding = 10,
      blurEnabled = true,

      -- Raccourcis personnalisés (si vous souhaitez modifier le terminal par ex.)
      kbTerminal = "SUPER + T",
    }
  '';

  # 4. Vos règles de fenêtres et raccourcis additionnels (hypr-user.lua)
  # Ce fichier est chargé automatiquement à la fin par Caelestia
  xdg.configFile."caelestia/hypr-user.lua".text = ''
    -- Règles d'attribution de workspace
    hypr.windowrule("workspace 1", "match:class ^(zen.*)$")
    hypr.windowrule("workspace 2", "match:class ^(kitty)$")
    hypr.windowrule("workspace special:spotify", "match:class ^(spotify)$")
    hypr.windowrule("workspace special:spotify", "match:class ^(Spotify)$")
  '';

  # 5. Dépendances système requises par Caelestia pour tous les raccourcis
  home.packages = with pkgs; [
    # Paquets Caelestia (Shell Quickshell & CLI)
    inputs.caelestia-cli.packages.${pkgs.stdenv.hostPlatform.system}.default

    # Outils utilisés par les scripts Caelestia (capture, son, clipboard, pip, etc.)
    hyprpicker
    hyprshot
    cliphist
    wl-clipboard
    brightnessctl
    wireplumber
    inotify-tools
    trashy
    pwvucontrol
  ];
}
