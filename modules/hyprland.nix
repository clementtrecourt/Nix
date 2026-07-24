{ inputs, pkgs, ... }:

{
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;

    package =
      inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;

    portalPackage =
      inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}
        .xdg-desktop-portal-hyprland;
  };

  environment.sessionVariables = {
    # Force Wayland for Qt apps
    QT_QPA_PLATFORM = "wayland;xcb";
    QT_AUTO_SCREEN_SCALE_FACTOR = "1";

    # Force Wayland for GTK apps
    GDK_BACKEND = "wayland,x11,*";

    # Force Wayland for Mozilla/Firefox
    MOZ_ENABLE_WAYLAND = "1";

    # Force Wayland for Electron apps (VSCode, Discord, Slack, etc.)
    NIXOS_OZONE_WL = "1";
  };
  nix.settings = {
    substituters = [
      "https://cache.nixos.org"
      "https://hyprland.cachix.org"
    ];

    trusted-substituters = [
      "https://hyprland.cachix.org"
    ];

    trusted-public-keys = [
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    ];

    trusted-users = [
      "root"
      "@wheel"
    ];
  };
}
