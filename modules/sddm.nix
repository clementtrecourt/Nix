{
  pkgs,
  inputs,
  ...
}: {
  imports = ["${inputs.thyx}/module.nix"];

  services.displayManager = {
    # Mango est la session par défaut ; Hyprland reste proposé jusqu'à son retrait
    defaultSession = "mango";
    sddm = {
      enable = true;
      package = pkgs.kdePackages.sddm;
      wayland.enable = true;
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
