#!@bash@/bin/bash
# powyx : menu power en QML. Un seul processus à la fois (verrou), actions lues dans powyx.toml.
set -euo pipefail

lock="${XDG_RUNTIME_DIR:-/tmp}/powyx-${UID}.lock"
exec 9>"$lock"
flock -n 9 || exit 0

config="${XDG_CONFIG_HOME:-$HOME/.config}/powyx/powyx.toml"
if [[ ! -f $config ]]; then
  echo "powyx: config absente ($config) : lance 'themes apply-default'" >&2
  exit 1
fi

toml_string() {
  awk -v section="$1" -v key="$2" '
    /^[[:space:]]*(#|$)/ { next }
    $0 ~ "^[[:space:]]*\\[" section "\\][[:space:]]*$" { in_section = 1; next }
    /^[[:space:]]*\[/ { in_section = 0; next }
    in_section && $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      value = $0
      sub("^[[:space:]]*" key "[[:space:]]*=[[:space:]]*\"", "", value)
      sub("\"[[:space:]]*$", "", value)
      print value
      exit
    }
  ' "$config"
}

confirm=$(toml_string theme confirm)
[[ $confirm =~ ^#[0-9A-Fa-f]{6}$ ]] || { echo "powyx: theme.confirm doit être #RRGGBB" >&2; exit 1; }

runner="${POWYX_QML_RUNNER:-@qml@}"
rc=0
"$runner" --apptype gui @share@/src/Main.qml -- --confirm="$confirm" || rc=$?

# L'interface a disparu : libérer le verrou avant l'action (ex. swaylock).
flock -u 9 || true
exec 9>&-

run_action() {
  local cmd
  cmd=$(toml_string actions "$1")
  [[ -n $cmd ]] || { echo "powyx: action '$1' vide" >&2; exit 1; }
  bash -lc -- "$cmd"
}

case "$rc" in
  0) ;;
  10) run_action lock ;;
  11) run_action suspend ;;
  12) run_action reboot ;;
  13) run_action shutdown ;;
  *) echo "powyx: qml a quitté avec le code $rc" >&2; exit "$rc" ;;
esac
