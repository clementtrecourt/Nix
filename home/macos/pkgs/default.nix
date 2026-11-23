# Paquets locaux du bureau macOS Tahoe.
# Usage : macosPkgs = import ./pkgs {inherit pkgs inputs;};
{
  pkgs,
  inputs,
}: let
  scripts = pkgs.callPackage ./macos-scripts.nix {};
  mactahoe-icon-theme = pkgs.callPackage ./mactahoe-icon-theme.nix {};
in {
  inherit mactahoe-icon-theme;
  # Vraies icônes d'apps de macOS 26 (input de flake macos-icons) sur MacTahoe
  mactahoe-apple-icon-theme = pkgs.callPackage ./mactahoe-apple-icon-theme.nix {
    inherit mactahoe-icon-theme;
    src = inputs.macos-icons;
  };
  mactahoe-gtk-theme = pkgs.callPackage ./mactahoe-gtk-theme.nix {};
  mactahoe-kde = pkgs.callPackage ./mactahoe-kde.nix {};
  macos-wm = scripts.wm;
  macos-screenshot = scripts.screenshot;
}
