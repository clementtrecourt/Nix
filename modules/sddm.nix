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
      thyx.enable = true;
    };
  };

  fonts.packages = with pkgs; [
    rubik
    roboto
    nerd-fonts.caskaydia-cove
    material-symbols
  ];
}
