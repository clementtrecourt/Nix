{
  pkgs,
  inputs,
}: let
  osyxLib = import ./lib.nix {inherit pkgs inputs;};
  osyx-themes = pkgs.callPackage ./osyx-themes.nix {};
in {
  inherit osyx-themes;
  powyx = pkgs.callPackage ./powyx.nix {};
  lookas = pkgs.callPackage ./lookas.nix {src = inputs.lookas;};
  asryx = pkgs.callPackage ./asryx.nix {src = inputs.asryx;};
  ctrlyx-lite = pkgs.callPackage ./ctrlyx-lite.nix {};
  themes = pkgs.callPackage ./themes.nix {
    inherit osyx-themes;
    inherit (osyxLib) mmsgReload;
  };
}
