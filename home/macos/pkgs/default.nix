# Paquets locaux du bureau macOS Tahoe.
# Usage : macosPkgs = import ./pkgs {inherit pkgs inputs;};
{
  pkgs,
  inputs,
}: let
  mactahoe-icon-theme = pkgs.callPackage ./mactahoe-icon-theme.nix {};
  mactahoe-gtk-theme = pkgs.callPackage ./mactahoe-gtk-theme.nix {};
  scripts = pkgs.callPackage ./macos-scripts.nix {inherit mactahoe-gtk-theme;};
in {
  inherit mactahoe-icon-theme;
  # Vraies icônes d'apps de macOS 26 (input de flake macos-icons) sur MacTahoe
  mactahoe-apple-icon-theme = pkgs.callPackage ./mactahoe-apple-icon-theme.nix {
    inherit mactahoe-icon-theme;
    src = inputs.macos-icons;
  };
  inherit mactahoe-gtk-theme;
  mactahoe-kde = pkgs.callPackage ./mactahoe-kde.nix {};
  macos-wm = scripts.wm;
  macos-screenshot = scripts.screenshot;
  macos-appearance = scripts.appearance;
  macos-settings = scripts.settings;
}
