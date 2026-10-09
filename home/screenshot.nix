{pkgs, ...}: let
  screenshot = pkgs.writeShellApplication {
    name = "screenshot";
    runtimeInputs = with pkgs; [grim slurp satty wl-clipboard libnotify coreutils];
    text = ''
      mode=region
      if [ $# -gt 0 ]; then mode=$1; fi

      dir="$HOME/Pictures/Screenshots"
      mkdir -p "$dir"
      file="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"

      case "$mode" in
        region|edit)
          geo=$(slurp -d) || exit 0      # Échap = annule
          grim -g "$geo" "$file"
          ;;
        screen)
          geo=$(slurp -o -d) || exit 0   # clic sur un écran = capture de cet écran
          grim -g "$geo" "$file"
          ;;
        *)
          echo "usage: screenshot region|screen|edit" >&2
          exit 1
          ;;
      esac

      if [ "$mode" = edit ]; then
        satty --filename "$file" --output-filename "$file" \
          --early-exit --copy-command wl-copy \
          --actions-on-enter save-to-clipboard
      else
        wl-copy < "$file"
        notify-send -i "$file" "Capture enregistrée" "$file"
      fi
    '';
  };
in {
  home.packages = [screenshot];
}
