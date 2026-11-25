# Niri + iNiR : la config de niri vient d'iNiR, Nix n'y ajoute que l'essentiel.
# Niri lui-même est installé côté système (programs.niri dans modules/common.nix).
#
# ~/.config/niri/config.kdl n'est PAS géré par Nix : à l'activation, s'il n'existe
# pas, iNiR y copie sa config (config.kdl + config.d/), modifiable depuis ses
# réglages. On y ajoute à la fin `include "nix.kdl"` (géré ici) :
#   - clavier qwerty-fr, numlock
#   - écrans déclarés dans l'hôte (outputs.kdl, même KDL que le greeter)
#   - curseur capitaine-cursors-white (celui d'iNiR n'existe pas dans nixpkgs)
#   - Zen au démarrage
# Retouches perso : ~/.config/niri/config.d/90-user-extra.kdl (jamais écrasé par iNiR).
# Repartir de la config iNiR d'origine : supprimer config.kdl + config.d, puis rebuild.
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
in {
  xdg.configFile."xkb/symbols/us_qwerty-fr".source = "${inputs.qwerty-fr}/linux/us_qwerty-fr";
  xdg.configFile."niri/outputs.kdl".text = outputsKdl;
  home.packages = [displaySnippet];

  # Inclus en DERNIER dans la config d'iNiR : ces valeurs l'emportent sur ses défauts
  xdg.configFile."niri/nix.kdl".text = ''
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
    }

    // Curseur : iNiR demande "capitaine-cursors-light", qui n'existe pas dans
    // nixpkgs (seulement capitaine-cursors / -white) -> gros curseur X par défaut.
    // Même thème que home.pointerCursor (home/common.nix).
    cursor {
        xcursor-theme "capitaine-cursors-white"
        xcursor-size 30
    }

    spawn-at-startup "zen"

    include "outputs.kdl"
  '';

  # Après la copie de la config iNiR (inirNiriSeed) : y ajouter l'include, une seule fois
  home.activation.inirNixInclude = lib.hm.dag.entryAfter ["inirNiriSeed"] ''
    f="${config.xdg.configHome}/niri/config.kdl"
    if [ -f "$f" ] && [ ! -L "$f" ] && ! grep -q 'include "nix.kdl"' "$f"; then
      if [ -v DRY_RUN ]; then
        echo "ajouterait include \"nix.kdl\" à $f"
      else
        printf '\n// Ajouté par ~/Nix/home/niri.nix (clavier, écrans, Zen)\ninclude "nix.kdl"\n' >> "$f"
      fi
    fi
  '';
}
