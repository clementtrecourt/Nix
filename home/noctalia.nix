# ~/Dot/home-manager/noctalia.nix
{
  inputs,
  lib,
  config,
  ...
}: {
  imports = [inputs.noctalia.homeModules.default];

  # Le lien direct avec la parenthèse ); bien fermée :
  xdg.configFile."noctalia/config.toml".source = lib.mkForce (
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Nix/home/noctalia.toml"
  );

  programs.noctalia = {
    enable = true;
    systemd.enable = true;
  };
}
