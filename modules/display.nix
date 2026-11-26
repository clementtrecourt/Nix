# Écrans de la machine : la seule chose qui diffère entre home et work.
#
# Chaque hôte décrit ses moniteurs dans hosts/<hôte>/configuration.nix :
#
#   my.display.outputs."DP-3" = {
#     mode = "1920x1080@60";
#     position = { x = 0; y = 0; };
#   };
#
# Tout ce qui dépend de l'écran en découle :
#   - ~/.config/niri/outputs.kdl            (home/niri.nix)
#   - écrans du greeter de connexion         (modules/greeter.nix)
#   - rendu des polices : sous-pixel RGB en basse densité, niveaux de gris en
#     HiDPI (le sous-pixel y est inutile et colore les bords) (modules/fonts.nix)
#   - taille de la police console / greeter
#
# Pour récupérer la config des écrans d'une machine : se connecter sous niri,
# régler les écrans dans Réglages DMS > Écrans, puis lancer `display-snippet`
# et coller le résultat dans la config de l'hôte.
{
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption types;
  cfg = config.my.display;

  kdlOutput = name: o:
    if !o.enable
    then ''
      output "${name}" {
          off
      }
    ''
    else ''
      output "${name}" {
      ${lib.concatStringsSep "\n" (lib.filter (l: l != "") [
        (lib.optionalString (o.mode != null) "    mode \"${o.mode}\"")
        (lib.optionalString (o.scale != null) "    scale ${toString o.scale}")
        (lib.optionalString (o.position != null) "    position x=${toString o.position.x} y=${toString o.position.y}")
        (lib.optionalString (o.transform != "normal") "    transform \"${o.transform}\"")
        (lib.optionalString o.vrr "    variable-refresh-rate on-demand=true")
        (lib.optionalString o.focusAtStartup "    focus-at-startup")
      ])}
      }
    '';

  outputType = types.submodule {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "false = écran éteint (ex. TV branchée en permanence)";
      };
      mode = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "2560x1440@165";
        description = "Résolution@fréquence ; null = mode préféré de l'écran";
      };
      scale = mkOption {
        type = types.nullOr types.float;
        default = null;
        example = 1.5;
        description = "Facteur d'échelle ; null = choix automatique de niri";
      };
      position = mkOption {
        type = types.nullOr (types.submodule {
          options = {
            x = mkOption {type = types.int;};
            y = mkOption {type = types.int;};
          };
        });
        default = null;
        description = "Position en pixels logiques ; null = placement automatique";
      };
      transform = mkOption {
        type = types.enum ["normal" "90" "180" "270" "flipped" "flipped-90" "flipped-180" "flipped-270"];
        default = "normal";
      };
      vrr = mkOption {
        type = types.bool;
        default = false;
        description = "Fréquence variable (FreeSync / G-Sync)";
      };
      focusAtStartup = mkOption {
        type = types.bool;
        default = false;
        description = "Écran principal (focus au démarrage)";
      };
    };
  };
in {
  options.my.display = {
    outputs = mkOption {
      type = types.attrsOf outputType;
      default = {};
      description = ''
        Écrans, indexés par nom niri : soit le connecteur ("DP-3", "HDMI-A-1",
        "eDP-1"), soit "Marque Modèle Numéro-de-série" tel qu'affiché par
        `niri msg outputs` (suit l'écran même s'il change de port).
        Vide = détection automatique par niri.
      '';
    };

    hidpi = mkOption {
      type = types.bool;
      default = lib.any (o: o.enable && o.scale != null && o.scale >= 1.5) (lib.attrValues cfg.outputs);
      defaultText = "vrai si un écran a une échelle >= 1.5";
      description = "Écran haute densité : polices en niveaux de gris, sans hinting.";
    };

    niriOutputsKdl = mkOption {
      type = types.str;
      readOnly = true;
      default =
        "// Généré depuis my.display.outputs (hosts/${config.networking.hostName}/configuration.nix)\n"
        + lib.concatStrings (lib.mapAttrsToList kdlOutput cfg.outputs);
      defaultText = "blocs output KDL générés depuis outputs";
      description = "Config niri des écrans, partagée par la session (home/niri.nix) et le greeter.";
    };

    subpixelOrder = mkOption {
      type = types.enum ["rgb" "bgr" "vrgb" "vbgr"];
      default = "rgb";
      description = "Ordre des sous-pixels de la dalle (rgb pour l'immense majorité)";
    };
  };
}
