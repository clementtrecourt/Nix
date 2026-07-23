{ pkgs, inputs, ... }:
{
  home-manager.users.clem = {
    imports = [
      inputs.caelestia-shell.homeManagerModules.default
    ];

    programs.caelestia = {
      enable = true;
      cli.enable = true;
    };
  };
}
