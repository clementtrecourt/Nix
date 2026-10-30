{
  pkgs,
  config,
  inputs,
  ...
}: let
  osyxPkgs = inputs.self.packages.${pkgs.stdenv.hostPlatform.system};
in {
  home.packages =
    [osyxPkgs.powyx osyxPkgs.ctrlyx-lite osyxPkgs.lookas osyxPkgs.asryx osyxPkgs.wallpaper inputs.matuwall.packages.${pkgs.stdenv.hostPlatform.system}.matuwall]
    ++ (with pkgs; [
      mako
      awww
      wlsunset
      swaylock
      grim
      slurp
      swappy
      wl-clipboard
      pamixer
      brightnessctl
      pavucontrol
      blueman
      alsa-utils
      libnotify
      waypaper
      gnome-keyring
      trash-cli
      wl-color-picker
    ]);

  # Vicinae : lanceur, presse-papier, menu power, menus de listes (daemon en service systemd utilisateur).
  programs.vicinae = {
    enable = true;
    systemd.enable = true;
    # Vicinae réécrit settings.json (changement de thème dans l'interface) : les réglages du flake
    # vont dans home-manager.json, importé par settings.json.
    mutableSettings = true;
    # thème généré par `themes` (home/osyx/themes.nix)
    settings.theme = {
      dark.name = "osyx";
      light.name = "osyx";
    };
    # même translucidité que kitty (background_opacity) ; le flou vient de Mango (blur_layer)
    extensions = [
      # Bluetooth (bluetoothctl) : commandes Scan / Devices / Discoverable — MIT, 2 000 lignes de TS,
      # seul accès système : spawn("bluetoothctl")
      (config.lib.vicinae.mkExtension {
        name = "bluetooth";
        src = pkgs.fetchgit {
          url = "https://codeberg.org/gelei/vicinae-bluetooth";
          rev = "16204787e0ac3925e7e466df38f3a959294b440f";
          hash = "sha256-xOemsBLnXKfcCVOZew2vm0mlylfFvcX4s/AnpjF3kBo=";
        };
        npmDepsHash = "sha256-cpyuJTc3a7oLibKUY2EhD33w8/35frfwIaGFKFezvts=";
      })
    ];
    settings.search_files_in_root = true;
    settings.launcher_window = {
      opacity = 0.5;
      material = "none";
    };
  };
}
