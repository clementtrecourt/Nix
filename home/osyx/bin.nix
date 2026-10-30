{pkgs, ...}: let
  mk = name: runtimeInputs: text:
    pkgs.writeShellApplication {inherit name runtimeInputs text;};
in {
  home.packages = [
    (mk "nightshift" [pkgs.procps pkgs.wlsunset] ''
      if pgrep -x wlsunset >/dev/null; then
        pkill -x wlsunset
      else
        # dégradé de 30 min à partir de maintenant, jusqu'au lever du jour (05:00)
        setsid wlsunset -S 05:00 -s "$(date +%H:%M)" -d 1800 -t 4500 -T 6500 >/dev/null 2>&1 &
      fi
    '')

    (mk "vocaster" [pkgs.alsa-utils pkgs.util-linux pkgs.gawk pkgs.coreutils] ''
      device="Vocaster One"
      control="name='Line In 1 Mute Capture Switch'"
      lock="''${XDG_RUNTIME_DIR:-/tmp}/vocaster-$UID.lock"

      fail() { printf 'vocaster: %s\n' "$*" >&2; exit 1; }

      exec 9>"$lock"
      flock -n 9 || exit 0   # ignore duplicate key events

      mapfile -t cards < <(awk -v d="$device" '$1 ~ /^[0-9]+$/ && index($0, d) {print $1}' /proc/asound/cards)
      case "''${#cards[@]}" in
        0) fail "$device is not connected" ;;
        1) card="''${cards[0]}" ;;
        *) fail "multiple $device devices are connected" ;;
      esac

      read_state() {
        amixer -c "$card" cget "$control" | awk -F= '/^[[:space:]]*: values=/ {gsub(/[[:space:]]/, "", $2); print $2; exit}'
      }
      set_state() { amixer -q -c "$card" cset "$control" "$1"; sleep 0.25; }

      amixer -c "$card" cget "$control" >/dev/null 2>&1 || fail "the Vocaster hardware mute control is unavailable"

      case "''${1:-toggle}" in
        toggle)
          case "$(read_state)" in
            on) set_state off ;;
            off) set_state on ;;
            *) fail "could not read the mute state" ;;
          esac ;;
        mute) set_state on ;;
        unmute) set_state off ;;
        state)
          case "$(read_state)" in
            on) echo muted ;;
            off) echo unmuted ;;
            *) fail "could not read the mute state" ;;
          esac ;;
        *) fail "usage: vocaster [toggle|mute|unmute|state]" ;;
      esac
    '')
  ];
}
