{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  apps = config.osyx.apps;
  binds = import ./binds.nix {inherit lib apps;};
  rules = import ./rules.nix;
in {
  options.osyx.apps = lib.mkOption {
    type = lib.types.attrsOf (lib.types.nullOr lib.types.str);
    default = {};
    description = "Commandes des applications référencées par les keybinds Mango.";
  };

  config = {
    xdg.configFile."xkb/symbols/us_qwerty-fr".source = "${inputs.qwerty-fr}/linux/us_qwerty-fr";

    osyx.apps = {
      term = lib.mkDefault "kitty";
      menu = lib.mkDefault "wofi --show drun";
      editor = lib.mkDefault "zeditor";
      files = lib.mkDefault "nemo";
      browser = lib.mkDefault "zen";
      lock = lib.mkDefault "swaylock";
      power = lib.mkDefault "powyx";
      control = lib.mkDefault "ctrlyx-lite";
      asryx = lib.mkDefault null;
    };

    wayland.windowManager.mango = {
      enable = true;
      systemd.enable = true;
      autostart_sh = import ./autostart.nix;
      settings =
        {
          gap_inner_horizontal = 6;
          gap_inner_vertical = 6;
          gap_outer_horizontal = 18;
          gap_outer_vertical = 18;
          border_px = 2;
          border_radius = 12;
          blur = 1;
          unfocused_opacity = 0.9;
          focused_opacity = 1.0;
          repeat_rate = 40;
          repeat_delay = 250;
          xkb_rules_layout = "us_qwerty-fr";
          xkb_rules_variant = "qwerty-fr";
          tap_to_click = 1;
          trackpad_natural_scrolling = 1;
          scroller_default_proportion = 0.9;
          scroller_proportion_preset = "0.5,0.8,1.0";
          source_optional = "~/.local/state/osyx/mango-colors.conf";
        }
        // binds
        // rules;
    };
  };
}
