{
  config,
  pkgs,
  inputs,
  lib,
  ...
}: {
  imports = [
    inputs.inir.homeModules.inir
  ];

  # 2. Configurer iNiR avec son lien symbolique
  programs.inir = {
    enable = true;
    service.compositor = "niri";
    configSymlink.enable = true;
    extraPackages = [pkgs.niri];
  };
  # 1. Clavier us_qwerty-fr
  xdg.configFile."xkb/symbols/us_qwerty-fr".source = "${inputs.qwerty-fr}/linux/us_qwerty-fr";

  # 2. Configuration déclarative de Niri (KDL)
  xdg.configFile."niri/config.kdl".text = ''
    input {
      keyboard {
        xkb {
          layout "us_qwerty-fr"
          variant "qwerty-fr"
        }
        repeat-delay 400
        repeat-rate 25
      }
      touchpad {
        tap
      }
    }

    output "eDP-1" {
      scale 1.0
    }

    layout {
      gaps 5
      center-focused-column "never"
      default-column-width { proportion 0.5; }
      focus-ring {
        width 2
        active-color "#7aa2f7"
        inactive-color "#24283b"
      }
    }

    prefer-no-csd

    // Règles de fenêtres
    window-rule {
      match app-id=r#"^zen"#
      open-on-workspace "1"
    }

    window-rule {
      match app-id="kitty"
      open-on-workspace "2"
    }

    binds {
      // Actions du Shell iNiR
      Mod+Space       { spawn "inir" "overview" "toggle"; }
      Mod+V           { spawn "inir" "clipboard" "toggle"; }
      Mod+Comma       { spawn "inir" "settings"; }
      Mod+Slash       { spawn "inir" "cheatsheet" "toggle"; }
      Mod+Shift+W     { spawn "inir" "panelFamily" "cycle"; }
      Mod+Alt+L       { spawn "inir" "lock" "activate"; }
      Mod+Shift+S     { spawn "inir" "region" "screenshot"; }
      Mod+Shift+X     { spawn "inir" "region" "ocr"; }

      // Applications & Terminal
      Mod+T           { spawn "kitty"; }
      Mod+E           { spawn "kitty" "-e" "yazi"; }
      Mod+Q           { close-window; }
      Mod+Shift+Ctrl+Q { quit; }

      // Navigation et fenêtres (layout Scroller Niri)
      Mod+Left        { focus-column-left; }
      Mod+Right       { focus-column-right; }
      Mod+Up          { focus-window-up; }
      Mod+Down        { focus-window-down; }

      Mod+Shift+Left  { move-column-left; }
      Mod+Shift+Right { move-column-right; }

      Mod+F           { maximize-column; }
      Mod+Shift+F     { fullscreen-window; }
      Mod+W           { toggle-window-floating; }

      // Workspaces
      Mod+1 { focus-workspace 1; }
      Mod+2 { focus-workspace 2; }
      Mod+3 { focus-workspace 3; }
      Mod+4 { focus-workspace 4; }
      Mod+5 { focus-workspace 5; }

      Mod+Shift+1 { move-column-to-workspace 1; }
      Mod+Shift+2 { move-column-to-workspace 2; }
      Mod+Shift+3 { move-column-to-workspace 3; }
      Mod+Shift+4 { move-column-to-workspace 4; }
      Mod+Shift+5 { move-column-to-workspace 5; }

      // Contrôles média et son
      XF86AudioRaiseVolume allow-when-locked=true { spawn "wpctl" "set-volume" "-l" "1.5" "@DEFAULT_AUDIO_SINK@" "5%+"; }
      XF86AudioLowerVolume allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
      XF86AudioMute        allow-when-locked=true { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
      XF86MonBrightnessUp   allow-when-locked=true { spawn "brightnessctl" "set" "5%+"; }
      XF86MonBrightnessDown allow-when-locked=true { spawn "brightnessctl" "set" "5%-"; }
    }
  '';
}
