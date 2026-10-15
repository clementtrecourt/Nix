{
  inputs,
  pkgs,
  ...
}: let
  dots = "${inputs.caelestia-dots}/hypr";
in {
  xdg.configFile."xkb/symbols/us_qwerty-fr".source = "${inputs.qwerty-fr}/linux/us_qwerty-fr";

  # Shell Caelestia (lancé par hyprland.lua via `caelestia shell -d`, donc pas de service systemd)
  programs.caelestia = {
    enable = true;
    systemd.enable = false;
    cli.enable = true;
  };

  # Dots Caelestia : fichiers en lecture seule depuis le store.
  # ~/.config/hypr/scheme reste un vrai dossier (écrit par le shell).
  # Surcharges perso : ~/.config/caelestia/hypr-user.lua
  xdg.configFile = {
    "hypr/hyprland.lua".source = "${dots}/hyprland.lua";
    "hypr/variables.lua".source = "${dots}/variables.lua";
    "hypr/hyprland".source = "${dots}/hyprland";
    "hypr/utils".source = "${dots}/utils";
    "caelestia/hypr-user.lua".source = ./hypr-user.lua;
    "caelestia/hypr-vars.lua".text = ''
      return {
          terminal = "kitty",
          windowOpacity = 1,
          kbWindowCycleNext = "SUPER + TAB",
          kbWindowCyclePrev = "SUPER + SHIFT + TAB",
      }
    '';
    # Synchronise le thème SDDM (fond + couleurs) à chaque changement de wallpaper/scheme
    "caelestia/cli.json".text = builtins.toJSON {
      wallpaper.postHook = "caelestia-sddm-sync --posthook >/dev/null 2>&1 &";
      theme.postHook = "caelestia-sddm-sync --posthook >/dev/null 2>&1 &";
    };
    "hyprshade/config.toml".text = ''
      [[shades]]
      name = "blue-light-filter"
      start_time = 20:00:00
      end_time = 07:00:00
      config.temperature = 4500
    '';
  };

  # Dépendances utilisées par les dots (execs.lua / keybinds)
  home.packages = with pkgs; [
    gnome-keyring
    hyprpicker
    cliphist
    wl-clipboard
    trash-cli
    gammastep
    xdg-desktop-portal-hyprland
    grim
    swappy
    libqalculate
    app2unit
    kitty
    wtype
  ];
}
