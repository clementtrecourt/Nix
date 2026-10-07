{
  config,
  pkgs,
  inputs,
  lib,
  ...
}: {
  # 1. Clavier us_qwerty-fr
  xdg.configFile."xkb/symbols/us_qwerty-fr".source = "${inputs.qwerty-fr}/linux/us_qwerty-fr";

  # 2. Configuration Hyprland Caelestia officielle (Lua)
  xdg.configFile."hypr" = {
    source = "${inputs.caelestia-dots}/hypr";
    recursive = true;
  };

  # 3. Variables Caelestia personnalisées (hypr-vars.lua)
  xdg.configFile."caelestia/hypr-vars.lua".text = ''
    return {
      terminal = "kitty",
      browser = "zen-beta",
      editor = "zed",
      fileManager = "kitty -e yazi",

      kbLayout = "us_qwerty-fr",
      kbVariant = "qwerty-fr",
      kbRepeatRate = 25,
      kbRepeatDelay = 400,
      numlockOn = true,

      windowGapsIn = 5,
      windowGapsOut = 5,
      windowBorderSize = 2,
      windowRounding = 10,
      blurEnabled = true,

      kbTerminal = "SUPER + T",
    }
  '';

  # 4. Règles de fenêtres Hyprland (hypr-user.lua)
  xdg.configFile."caelestia/hypr-user.lua".text = ''
    hypr.windowrule("workspace 1", "match:class ^(zen.*)$")
    hypr.windowrule("workspace 2", "match:class ^(kitty)$")
    hypr.windowrule("workspace special:spotify", "match:class ^(spotify)$")
    hypr.windowrule("workspace special:spotify", "match:class ^(Spotify)$")
  '';

  # 5. Paquets : Caelestia Shell + CLI combinés (with-cli) et dépendances
  home.packages = with pkgs; [
    inputs.caelestia-shell.packages.${pkgs.stdenv.hostPlatform.system}.with-cli
    pkgs.caelestia-cli

    hyprpicker
    hyprshot
    cliphist
    wl-clipboard
    brightnessctl
    wireplumber
    inotify-tools
    pwvucontrol
  ];
}
