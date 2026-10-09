{
  config,
  pkgs,
  ...
}: let
  nix = "${config.home.homeDirectory}/Nix";
  link = config.lib.file.mkOutOfStoreSymlink;

  setWallpaper = pkgs.writeShellApplication {
    name = "set-wallpaper";
    runtimeInputs = with pkgs; [awww matugen coreutils procps];
    text = ''
      state="$HOME/.local/state/wallpaper"
      mkdir -p "$(dirname "$state")" "$HOME/.local/state/quickshell"

      if [ "''${1:-}" = "--restore" ]; then
        [ -e "$state" ] || exit 0
        set -- "$(readlink -f "$state")"
      fi
      [ -f "''${1:-}" ] || { echo "usage: set-wallpaper <image>|--restore" >&2; exit 1; }
      wall="$(readlink -f -- "$1")"

      # attend que le daemon awww soit prêt (max 5 s)
      for _ in $(seq 1 50); do
        awww query >/dev/null 2>&1 && break
        sleep 0.1
      done

      awww img "$wall" --transition-type wave --transition-duration 1.4 --transition-fps 120 --transition-angle 20 --transition-wave 40,20
      ln -sf "$wall" "$state"
      matugen image "$wall" --mode dark --source-color-index 0
      pkill -USR1 -x kitty || true   # recharge la config kitty
    '';
  };
in {
  home.packages = [setWallpaper pkgs.libnotify];

  # Édition live, sans rebuild : ~/.config/... -> ~/Nix/...
  xdg.configFile."quickshell".source = link "${nix}/shell";
  xdg.configFile."matugen".source = link "${nix}/matugen";
}
