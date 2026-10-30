{
  writeShellApplication,
  vicinae,
  networkmanagerapplet,
  networkmanager,
  bluez,
  pamixer,
  brightnessctl,
  gawk,
  coreutils,
  swaylock,
  hyprlock,
}:
writeShellApplication {
  name = "ctrlyx-lite";
  runtimeInputs = [vicinae networkmanager networkmanagerapplet bluez pamixer brightnessctl gawk coreutils swaylock hyprlock];
  text = ''
    menu() { vicinae dmenu --placeholder "$1" --no-section --no-footer; }

    choice=$(printf '%s\n' "Wi-Fi" "Bluetooth" "Volume" "Luminosité" "Night shift" "Verrouiller" "Alimentation" | menu control) || exit 0

    case "$choice" in
      Wi-Fi)
        ssid=$(nmcli -t -f SSID dev wifi list | awk 'NF' | sort -u | menu wifi) || exit 0
        if nmcli -t -f NAME connection show | grep -qxF "$ssid"; then
          nmcli connection up id "$ssid"
        else
          # nouveau réseau : le mot de passe se saisit dans l'éditeur de connexions
          nm-connection-editor
        fi ;;
      Bluetooth)
        entry=$( { echo "power on"; echo "power off"; bluetoothctl devices; } | menu bluetooth) || exit 0
        case "$entry" in
          power*) bluetoothctl "$entry" ;;
          Device*) bluetoothctl connect "$(echo "$entry" | awk '{print $2}')" ;;
        esac ;;
      Volume)
        v=$(printf '%s\n' "muet" "+10" "-10" "25" "50" "75" "100" | menu volume) || exit 0
        case "$v" in
          muet) pamixer -t ;;
          +10) pamixer -i 10 ;;
          -10) pamixer -d 10 ;;
          *) pamixer --set-volume "$v" ;;
        esac ;;
      Luminosité)
        b=$(printf '%s\n' 10 25 50 75 100 | menu luminosité) || exit 0
        brightnessctl set "$b%" ;;
      "Night shift") nightshift ;;
      Verrouiller) hyprlock ;;
      Alimentation) vicinae deeplink vicinae://launch/power ;;
    esac
  '';
}
