{
  pkgs,
  inputs,
  ...
}: {
  imports = ["${inputs.thyx}/module.nix"];

  # Greeter X11 : le greeter Wayland (weston kiosk) a gelé clavier, souris et changement de TTY
  # au premier essai sur cette machine (voir l'historique git), l'ancien greeter X11 fonctionnait.
  services.xserver.enable = true;

  services.displayManager = {
    # Mango est la session par défaut
    defaultSession = "mango";
    sddm = {
      enable = true;
      package = pkgs.kdePackages.sddm;
      wayland.enable = false;
      thyx = {
        enable = true;
        # le fond du greeter est la copie du wallpaper courant, posée par `wallpaper` (voir backdrops)
        package = (pkgs.callPackage "${inputs.thyx}/default.nix" {}).overrideAttrs (old: {
          postInstall =
            (old.postInstall or "")
            + ''
              theme="$out/share/sddm/themes/thyx"
              ln -s /var/lib/sddm-wallpaper/wallpaper.jpg "$theme/backgrounds/current.jpg"
              sed -i 's|^Background=.*|Background="backgrounds/current.jpg"|' "$theme/theme.conf"
              # léger flou sur le fond (0 à 1 ; rayon = valeur × 64 px)
              sed -i 's|^Blur=.*|Blur="0.25"|' "$theme/theme.conf"
            '';
        });
      };
    };
  };

  # dossier du fond de l'écran de connexion, écrit par l'utilisateur (wallpaper), lu par sddm
  systemd.tmpfiles.rules = ["d /var/lib/sddm-wallpaper 0755 clem users -"];

  fonts.packages = with pkgs; [
    rubik
    roboto
    nerd-fonts.caskaydia-cove
    material-symbols
  ];
}
