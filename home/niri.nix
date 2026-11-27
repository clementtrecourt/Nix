# Niri + DMS : config de base (inspirée du niri.kdl de référence DMS).
# Niri lui-même est installé côté système (programs.niri dans modules/common.nix).
#
# Ordre de chargement de ~/.config/niri/config.kdl :
#   1. ce fichier (input, layout, règles)
#   2. binds-dms.kdl     : raccourcis du modèle DMS (versionné avec l'input `dms`)
#   3. binds-island.kdl  : raccourcis "dynamic island" (surchargent les précédents)
#   4. dms/*.kdl         : fichiers générés par DMS (couleurs, layout, animations...),
#                          modifiables depuis Réglages DMS, donc jamais gérés par Nix.
{
  config,
  inputs,
  lib,
  osConfig,
  pkgs,
  ...
}: let
  # Écrans de la machine : même KDL que le greeter (modules/display.nix)
  outputsKdl = osConfig.my.display.niriOutputsKdl;

  # Affiche les écrans actuels au format my.display.outputs, à coller dans la config de l'hôte
  displaySnippet = pkgs.writeShellApplication {
    name = "display-snippet";
    runtimeInputs = [pkgs.jq];
    text = ''
      niri msg --json outputs | jq -r '
        def tr: {"Normal":"normal","_90":"90","_180":"180","_270":"270","Flipped":"flipped",
                 "Flipped90":"flipped-90","Flipped180":"flipped-180","Flipped270":"flipped-270"}[.] // "normal";
        def fmt: tostring | if test("\\.") then . else . + ".0" end;
        "  my.display.outputs = {",
        (to_entries[] | .value as $o
          | ($o.modes[$o.current_mode // 0]) as $m
          | (if $o.serial != null and $o.make != "Unknown"
             then "\($o.make) \($o.model) \($o.serial)" else $o.name end) as $id
          | "    # \($o.name) : \($o.make) \($o.model)",
            "    \"\($id)\" = {",
            (if $o.logical == null then "      enable = false;" else
              "      mode = \"\($m.width)x\($m.height)@\(($m.refresh_rate / 1000 * 1000 | round) / 1000)\";",
              "      scale = \($o.logical.scale | fmt);",
              "      position = { x = \($o.logical.x); y = \($o.logical.y); };",
              (if ($o.logical.transform | tr) != "normal" then "      transform = \"\($o.logical.transform | tr)\";" else empty end),
              (if $o.vrr_enabled then "      vrr = true;" else empty end)
            end),
            "    };"),
        "  };"'
    '';
  };

  dmsEmbedded = "${inputs.dms}/core/internal/config/embedded";

  # Raccourcis officiels DMS, terminal remplacé par kitty
  dmsBinds = pkgs.runCommand "niri-binds-dms.kdl" {} ''
    substitute ${dmsEmbedded}/niri-binds.kdl $out \
      --replace-fail '{{TERMINAL_COMMAND}}' 'kitty'
  '';

  # Bordure "verre" : mêmes couleurs que le thème DMS, mais translucides avec un
  # reflet en dégradé. Template matugen à nous, que DMS rend à chaque changement
  # de thème (il fusionne ~/.config/matugen/dms/configs/*.toml) vers
  # niri/glass-colors.kdl, inclus APRÈS dms/colors.kdl pour le surcharger.
  # Opacité en hex sur 2 chiffres : ff = 100 %, b3 = 70 %, 80 = 50 %, 4d = 30 %, 26 = 15 %.
  glassTemplate = pkgs.writeText "niri-glass-colors.kdl" ''
    // Généré par DMS depuis home/niri.nix (glassTemplate), ne pas éditer.
    layout {
        focus-ring {
            active-gradient   from="{{colors.primary.default.hex}}b3" to="{{colors.primary.default.hex}}26" angle=135 in="oklch"
            inactive-gradient from="{{colors.outline.default.hex}}4d" to="{{colors.outline.default.hex}}10" angle=135 in="oklch"
            urgent-color      "{{colors.error.default.hex}}b3"
        }
        border {
            active-gradient   from="{{colors.primary.default.hex}}b3" to="{{colors.primary.default.hex}}26" angle=135 in="oklch"
            inactive-gradient from="{{colors.outline.default.hex}}4d" to="{{colors.outline.default.hex}}10" angle=135 in="oklch"
            urgent-color      "{{colors.error.default.hex}}b3"
        }
    }
  '';

  island = activity: ''spawn "dms" "ipc" "call" "island" "toggle" "${activity}";'';
in {
  xdg.configFile."xkb/symbols/us_qwerty-fr".source = "${inputs.qwerty-fr}/linux/us_qwerty-fr";

  xdg.configFile."niri/binds-dms.kdl".source = dmsBinds;
  xdg.configFile."matugen/dms/configs/niri-glass.toml".text = ''
    [templates.niriglass]
    input_path = '${glassTemplate}'
    output_path = '${config.xdg.configHome}/niri/glass-colors.kdl'
  '';
  xdg.configFile."niri/outputs.kdl".text = outputsKdl;
  home.packages = [displaySnippet];

  # Un raccourci par activité de l'île, comme sur la vidéo de référence
  xdg.configFile."niri/binds-island.kdl".text = ''
    binds {
        Mod+Space hotkey-overlay-title="Island: Spotlight" { ${island "launcher"} }
        Mod+M     hotkey-overlay-title="Island: Média" { ${island "media"} }
        Mod+D     hotkey-overlay-title="Island: Dashboard" { spawn "dms" "ipc" "call" "dash" "toggle" ""; }
        Mod+Y     hotkey-overlay-title="Island: Fonds d'écran" { ${island "wallpaper"} }
        Mod+A     hotkey-overlay-title="Island: Spotlight" { ${island "launcher"} }
        Mod+Shift+A hotkey-overlay-title="Island: Centre de contrôle" { ${island "controlcenter"} }
        Mod+Ctrl+N hotkey-overlay-title="Island: Notifications" { ${island "notificationcenter"} }
        Mod+B     hotkey-overlay-title="Island: Météo" { ${island "weather"} }
        Mod+V     hotkey-overlay-title="Island: Presse-papiers" { ${island "clipboard"} }
        Mod+Escape hotkey-overlay-title="Island: Fermer" { spawn "dms" "ipc" "call" "island" "close"; }

        // Habitudes conservées de l'ancienne config
        Mod+E hotkey-overlay-title="Yazi" { spawn "kitty" "-e" "yazi"; }
        Print { screenshot; }
        Mod+P { screenshot; }
        Mod+Shift+P { screenshot-window; }
    }
  '';

  xdg.configFile."niri/config.kdl".text = ''
    config-notification {
        disable-failed
    }

    input {
        keyboard {
            xkb {
                layout "us_qwerty-fr"
                variant "qwerty-fr"
            }
            repeat-delay 400
            repeat-rate 25
            numlock
        }
        touchpad {
            tap
            dwt
            drag true
            drag-lock
        }
        focus-follows-mouse
        warp-mouse-to-focus
    }

    gestures {
        hot-corners {
            off
        }
    }

    layout {
        background-color "transparent"
        gaps 10
        center-focused-column "never"
        preset-column-widths {
            proportion 0.5
            proportion 0.66667
            proportion 1.0
        }
        default-column-width { proportion 0.66667; }
        // Liseré "menthe" fin autour de la fenêtre active (couleur fournie par dms/colors.kdl)
        focus-ring {
            width 2
        }
        border {
            off
        }
        shadow {
            on
            softness 30
            spread 5
            offset x=0 y=5
            color "#0007"
        }
    }

    // Le fond d'écran DMS reste visible derrière l'overview (fond flouté)
    layer-rule {
        match namespace="^quickshell$"
        place-within-backdrop true
    }
    layer-rule {
        match namespace="dms:blurwallpaper"
        place-within-backdrop true
    }

    overview {
        workspace-shadow {
            off
        }
    }

    environment {
        XDG_CURRENT_DESKTOP "niri"
        QT_QPA_PLATFORMTHEME "qt6ct"
        ELECTRON_OZONE_PLATFORM_HINT "auto"
        MOZ_ENABLE_WAYLAND "1"
    }

    cursor {
        xcursor-theme "capitaine-cursors"
        xcursor-size 24
    }

    hotkey-overlay {
        skip-at-startup
    }

    prefer-no-csd
    screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"

    spawn-at-startup "zen"

    window-rule {
        geometry-corner-radius 14
        clip-to-geometry true
        // Toujours un espace autour des fenêtres : une appli qui s'ouvre
        // "maximisée" (Zen, Chrome, Electron...) devient une colonne pleine
        // largeur avec les gaps, au lieu d'occuper l'écran bord à bord.
        open-maximized-to-edges false
    }
    window-rule {
        match app-id=r#"^org\.gnome\.Calculator$"#
        match app-id=r#"^blueman-manager$"#
        match app-id=r#"^xdg-desktop-portal$"#
        match app-id=r#"^pavucontrol$"#
        open-floating true
    }
    window-rule {
        match app-id=r#"firefox$"# title="^Picture-in-Picture$"
        match app-id=r#"^zen"# title="^Picture-in-Picture$"
        open-floating true
    }
    window-rule {
        match app-id=r#"^steam$"# title=r#"^notificationtoasts_\d+_desktop$"#
        default-floating-position x=10 y=10 relative-to="bottom-right"
        open-focused false
    }
    window-rule {
        match app-id="kitty"
        match app-id=r#"^zen"#
        draw-border-with-background false
    }

    // Flou d'arrière-plan (natif niri) derrière les fenêtres transparentes
    blur {
        passes 4
        offset 5
        noise 0
        saturation 0.8
    }
    window-rule {
        match app-id="kitty"
        match app-id=r#"^zen"#
        background-effect {
            blur true
        }
    }

    debug {
        honor-xdg-activation-with-invalid-serial
    }

    recent-windows {
        binds {
            Alt+Tab         { next-window scope="output"; }
            Alt+Shift+Tab   { previous-window scope="output"; }
            Alt+grave       { next-window filter="app-id"; }
            Alt+Shift+grave { previous-window filter="app-id"; }
        }
    }

    // Écrans : Nix d'abord (niri retient le PREMIER bloc qui correspond à un écran),
    // donc la config de l'hôte fait foi ; dms/outputs.kdl (Réglages DMS > Écrans)
    // ne sert que pour les écrans non déclarés (projecteur, écran de passage...).
    include "outputs.kdl"

    include "binds-dms.kdl"
    include "binds-island.kdl"

    // Fichiers générés par DMS (Réglages > Compositeur / Thème)
    include optional=true "dms/colors.kdl"
    include optional=true "glass-colors.kdl"
    include optional=true "dms/layout.kdl"
    include optional=true "dms/alttab.kdl"
    include optional=true "dms/animations.kdl"
    include optional=true "dms/binds.kdl"
    include optional=true "dms/outputs.kdl"
    include optional=true "dms/cursor.kdl"
    include optional=true "dms/input.kdl"
    include optional=true "dms/wpblur.kdl"
    include optional=true "dms/windowrules.kdl"
  '';
}
