{ inputs, pkgs, config, ... }:
{
  wayland.windowManager.hyprland.enable = false;

  home.file.".config/hypr/plugins-generated.lua".text = ''
    hl.plugin.load("${inputs.gloview.packages.${pkgs.stdenv.hostPlatform.system}.gloview}/lib/libgloview.so")
    hl.bind("SUPER, TAB, gloview:toggle")
  '';
}
