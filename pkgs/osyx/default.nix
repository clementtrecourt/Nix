{
  pkgs,
  inputs,
}: let
  osyxLib = import ./lib.nix {inherit pkgs inputs;};
  osyx-themes = pkgs.callPackage ./osyx-themes.nix {};
in {
  inherit osyx-themes;
  themes = pkgs.callPackage ./themes.nix {
    inherit osyx-themes;
    inherit (osyxLib) mmsgReload;
  };
}
