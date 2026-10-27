{
  pkgs,
  config,
  inputs,
  ...
}: let
  osyxPkgs = inputs.self.packages.${pkgs.stdenv.hostPlatform.system};
in {
  home.packages =
    [osyxPkgs.powyx osyxPkgs.ctrlyx-lite osyxPkgs.lookas osyxPkgs.asryx]
    ++ (with pkgs; [
      wofi
      mako
      swww
      wlsunset
      swaylock
      grim
      slurp
      swappy
      cliphist
      wl-clipboard
      pamixer
      brightnessctl
      pavucontrol
      blueman
      alsa-utils
      libnotify
    ]);

  # Config wofi d'osyx (le style.css est généré par `themes`)
  xdg.configFile."wofi/config".text = ''
    show=drun
    prompt=Run
    matching=fuzzy
    insensitive=true
    allow_images=true
    allow_markup=true
    image_size=24
    columns=1
    width=760
    height=460
    location=center
    orientation=vertical
    halign=center
    hide_scroll=true
    term=kitty
    sparse_search=true
    no_actions=true
  '';

  # Wallpapers osyx
  home.file."Pictures/osyx".source = ./assets/wallpapers;
}
