#!/usr/bin/env bash
# Banc de test : lance un Hyprland imbriqué (fenêtre dans la session courante)
# avec le rendu de la prod (home/macos/hyprland-look.nix), puis le shell Quickshell dedans.
#
#   nested.sh start [WxH]   -> démarre Hyprland imbriqué
#   nested.sh shell         -> (re)lance quickshell -p home/macos/shell dans l'instance
#   nested.sh shot out.png  -> capture l'écran imbriqué (grim)
#   nested.sh run <cmd...>  -> exécute une commande dans l'instance (env positionné)
#   nested.sh log           -> log quickshell
#   nested.sh stop
#
# NESTED_ID=<nom> permet de faire tourner plusieurs instances en parallèle.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_DIR="${SHELL_DIR:-$HERE/../shell}"
ID="${NESTED_ID:-0}"
STATE="${STATE:-${XDG_RUNTIME_DIR:-/tmp}/macos-nested-$ID}"
mkdir -p "$STATE"
P() { nix build --no-link --print-out-paths --inputs-from "$HERE/../../.." "nixpkgs#$1^out" 2>/dev/null | head -1; }
HYPR="${HYPR:-$(P hyprland)}"
QS="${QS:-$(P quickshell)}"
GRIM="${GRIM:-$(P grim)}"
JQ="${JQ:-$(command -v jq)}"
# Pilotes GL du même nixpkgs que Hyprland/Quickshell (façon nixGL) : le Mesa de
# /run/opengl-driver peut venir d'un nixpkgs plus récent (glibc incompatible).
MESA="${MESA:-$(P mesa)}"
export LIBGL_DRIVERS_PATH="$MESA/lib/dri" GBM_BACKENDS_PATH="$MESA/lib/gbm" \
  __EGL_VENDOR_LIBRARY_FILENAMES="$MESA/share/glvnd/egl_vendor.d/50_mesa.json" \
  LD_LIBRARY_PATH="$MESA/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
# Thème d'icônes MacTahoe (paquet local home/macos/pkgs), construit à la demande :
# aucun chemin du store figé dans le dépôt, le banc marche sur toutes les machines.
icon_pkg() {
  nix build --no-link --print-out-paths --impure --expr "
    let f = builtins.getFlake \"path:$(cd "$HERE/../../.." && pwd)\";
        pkgs = import f.inputs.nixpkgs {system = builtins.currentSystem;};
    in (import $HERE/../pkgs {inherit pkgs; inputs = f.inputs;}).mactahoe-apple-icon-theme" 2>/dev/null | head -1
}

envload() {
  [ -f "$STATE/env" ] || { echo "pas d'instance (nested.sh start)" >&2; exit 1; }
  # shellcheck disable=SC1091
  . "$STATE/env"
  export HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY
  export XDG_CURRENT_DESKTOP=Hyprland
}

case "${1:-}" in
start)
  SIZE="${2:-1920x1080}"
  CONF="$STATE/hyprland.conf"
  # Réglages écrits par l'app Réglages Système (créé vide s'il manque, jamais réécrit)
  SETTINGS_CONF="${MACOS_SETTINGS_CONF:-${XDG_CONFIG_HOME:-$HOME/.config}/hypr/macos-settings.conf}"
  [ -e "$SETTINGS_CONF" ] || { mkdir -p "$(dirname "$SETTINGS_CONF")"; touch "$SETTINGS_CONF"; }
  # Même rendu que la session réelle : le bloc « look » est évalué depuis la même
  # expression Nix que home/macos/hyprland.nix (pure, instantané)
  if ! nix eval --raw -f "$HERE/../hyprland-look.nix" > "$STATE/look.conf"; then
    echo "évaluation de home/macos/hyprland-look.nix impossible" >&2
    exit 1
  fi
  {
    echo "monitor = , ${SIZE}@60, 0x0, 1"
    # Plugin hyprbars de la même version que Hyprland (comme en prod)
    echo "plugin = $(P hyprlandPlugins.hyprbars)/lib/libhyprbars.so"
    # Bloc « look » de la prod (source unique : home/macos/hyprland-look.nix)
    echo "source = $STATE/look.conf"
    # Réglages propres au banc (aucun aujourd'hui)
    if [ -f "$HERE/hyprland-dev.conf" ]; then echo "source = $HERE/hyprland-dev.conf"; fi
    echo "misc {"
    echo "  disable_hyprland_logo = true"
    echo "  disable_splash_rendering = true"
    echo "}"
    # Comme en prod, en dernier : réglages de l'app Réglages Système du shell
    echo "source = $SETTINGS_CONF"
  } > "$CONF"
  before=$(ls "$XDG_RUNTIME_DIR/hypr" 2>/dev/null || true)
  nohup "$HYPR/bin/Hyprland" -c "$CONF" > "$STATE/hyprland.log" 2>&1 &
  echo $! > "$STATE/hypr.pid"
  for _ in $(seq 1 150); do
    sleep 0.1
    for sig in $(ls "$XDG_RUNTIME_DIR/hypr" 2>/dev/null); do
      if ! grep -qx "$sig" <<<"$before" && [ -S "$XDG_RUNTIME_DIR/hypr/$sig/.socket.sock" ]; then
        wl=$(HYPRLAND_INSTANCE_SIGNATURE=$sig "$HYPR/bin/hyprctl" -j instances 2>/dev/null | "$JQ" -r --arg s "$sig" '.[]|select(.instance==$s)|.wl_socket' 2>/dev/null || true)
        [ -n "$wl" ] || continue
        printf 'HYPRLAND_INSTANCE_SIGNATURE=%s\nWAYLAND_DISPLAY=%s\n' "$sig" "$wl" > "$STATE/env"
        # La fenêtre imbriquée n'est pas forcément visible (pas de frame callbacks) :
        # on rend sur une sortie headless "MAC" et on coupe la sortie WAYLAND-1.
        H() { HYPRLAND_INSTANCE_SIGNATURE=$sig WAYLAND_DISPLAY=$wl "$HYPR/bin/hyprctl" "$@" >/dev/null; }
        H output create headless MAC
        H keyword monitor "MAC,${SIZE}@60,0x0,1"
        sleep 0.3
        H keyword monitor "WAYLAND-1,disable"
        # Avertissements de Hyprland imbriqué (XDG_CURRENT_DESKTOP, start-hyprland…) :
        # sans objet dans le banc, ils masqueraient le coin haut-droit des captures
        H dismissnotify || true
        cat "$STATE/env"
        exit 0
      fi
    done
  done
  echo "Hyprland n'a pas démarré, voir $STATE/hyprland.log" >&2
  tail -20 "$STATE/hyprland.log" >&2
  exit 1
  ;;
shell)
  envload
  if [ -f "$STATE/qs.pid" ]; then kill "$(cat "$STATE/qs.pid")" 2>/dev/null || true; fi
  # Thème d'icônes MacTahoe (mis en cache par instance ; ICON_PKG=<store path> pour forcer)
  if [ -z "${ICON_PKG:-}" ]; then
    [ -d "$(cat "$STATE/icon-pkg" 2>/dev/null)" ] || icon_pkg > "$STATE/icon-pkg"
    ICON_PKG="$(cat "$STATE/icon-pkg")"
  fi
  export XDG_DATA_DIRS="$ICON_PKG/share:${XDG_DATA_DIRS:-/run/current-system/sw/share}"
  export QS_ICON_THEME="${QS_ICON_THEME:-$(cat "$HERE/icon-theme" 2>/dev/null || echo MacTahoe-Apple-dark)}"
  # Comme le service de prod : texte hinté et net
  QT_QUICK_DEFAULT_TEXT_RENDER_TYPE="${QT_QUICK_DEFAULT_TEXT_RENDER_TYPE:-NativeRendering}" \
  MACOS_SHELL_DEV=1 \
  nohup "$QS/bin/quickshell" -p "$SHELL_DIR" > "$STATE/qs.log" 2>&1 &
  echo $! > "$STATE/qs.pid"
  sleep "${WAIT:-3}"
  tail -40 "$STATE/qs.log"
  ;;
shot)
  envload
  out="${2:-$STATE/shot.png}"
  timeout 15 "$GRIM/bin/grim" -o MAC "$out"
  echo "$out"
  ;;
run)
  envload
  shift
  PATH="$HYPR/bin:$QS/bin:$PATH" exec "$@"
  ;;
log) cat "$STATE/qs.log" ;;
stop)
  for f in qs hypr; do
    if [ -f "$STATE/$f.pid" ]; then kill "$(cat "$STATE/$f.pid")" 2>/dev/null || true; fi
    rm -f "$STATE/$f.pid"
  done
  rm -f "$STATE/env"
  ;;
*)
  sed -n 2,12p "$0"
  exit 1
  ;;
esac
