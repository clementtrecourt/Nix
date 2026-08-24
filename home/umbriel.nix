{ pkgs, inputs, ... }:

{
  # Import du module Home-Manager d'Umbriel
  imports = [
    inputs.umbriel.homeModules.default
  ];

  # Configuration d'Umbriel
  programs.umbriel = {
    enable = true;
    settings = {
      # Clavier en français AZERTY
      input.keyboard.layout = "qwerty-fr";

      # Aspect et disposition
      layout = {
        gap = 6;
      };

      # Autostart d'applications (ex: barre de statut / noctalia si installée)
      general = {
        autostart = [ "noctalia" ];
      };

      # Raccourcis clavier (Mod = touche Super/Windows)
      keybinds = {
        # Lancement d'applications
        "Mod+Return" = "spawn:kitty";
        "Mod+Q"      = "window-close";
        "Mod+Escape" = "quit";

        # Fenêtrage
        "Mod+F" = "toggle-fullscreen";
        "Mod+T" = "toggle-floating";
        "Mod+P" = "toggle-pin";
        "Mod+O" = "toggle-overview";

        # Navigation (Flèches ou HJKL)
        "Mod+Left"  = "focus-left";
        "Mod+Right" = "focus-right";
        "Mod+Up"    = "focus-up";
        "Mod+Down"  = "focus-down";

        # Workspaces (Chiffres 1 à 5 en AZERTY / direct)
        "Mod+ampersand" = "workspace:1";
        "Mod+eacute"    = "workspace:2";
        "Mod+quotedbl"  = "workspace:3";
        "Mod+apostrophe"= "workspace:4";
        "Mod+parenleft" = "workspace:5";

        # Déplacer vers un workspace
        "Mod+Shift+ampersand"  = "move-to-workspace:1";
        "Mod+Shift+eacute"     = "move-to-workspace:2";
        "Mod+Shift+quotedbl"   = "move-to-workspace:3";
        "Mod+Shift+apostrophe" = "move-to-workspace:4";
        "Mod+Shift+parenleft"  = "move-to-workspace:5";
      };
    };
  };

  home.stateVersion = "24.11";
}
