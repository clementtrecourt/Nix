# iNiR : ce que son module Home Manager laisse au système (cf. home/inir.nix).
# niri, PipeWire, UPower, power-profiles et le greeter sont déjà dans common.nix.
_: {
  # Groupes que l'installateur iNiR ajoute sur les autres distros
  # (luminosité, ydotool pour les raccourcis/collage, i2c pour les écrans externes)
  users.users.clem.extraGroups = ["video" "input" "i2c" "ydotool"];
  programs.ydotool.enable = true;
  hardware.i2c.enable = true;
  services.geoclue2.enable = true; # météo
  security.pam.services.swaylock = {}; # verrouillage
}
