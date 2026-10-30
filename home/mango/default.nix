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
    # Mango ne relit pas sa config après un switch : on la recharge. L'activation HM tourne dans
    # un service système sans MANGO_INSTANCE_SIGNATURE, donc on retrouve le socket du compositeur.
    home.activation.reloadMango = lib.hm.dag.entryAfter ["writeBoundary"] ''
      sock=$(ls /run/user/$(id -u)/mango-*.sock 2>/dev/null | head -n 1 || true)
      if [ -n "$sock" ]; then
        MANGO_INSTANCE_SIGNATURE="$sock" ${(import ../../pkgs/osyx/lib.nix {inherit pkgs inputs;}).mmsgReload} || true
      fi
    '';

    xdg.configFile."xkb/symbols/us_qwerty-fr".source = "${inputs.qwerty-fr}/linux/us_qwerty-fr";

    osyx.apps = {
      term = lib.mkDefault "kitty";
      menu = lib.mkDefault "vicinae toggle";
      editor = lib.mkDefault "zeditor";
      files = lib.mkDefault "nemo";
      browser = lib.mkDefault "zen-beta";
      lock = lib.mkDefault "hyprlock";
      power = lib.mkDefault "vicinae deeplink vicinae://launch/power";
      control = lib.mkDefault "ctrlyx-lite";
      asryx = lib.mkDefault "asryx";
    };

    wayland.windowManager.mango = {
      enable = true;
      systemd.enable = true;
      autostart_sh = import ./autostart.nix;
      settings =
        {
          gap_inner_horizontal = 8;
          gap_inner_vertical = 8;
          gap_outer_horizontal = 6;
          gap_outer_vertical = 6;
          border_px = 2;
          border_radius = 12;
          blur = 1;
          # flou aussi sur les surfaces layer-shell (Vicinae), identique à celui de kitty
          blur_layer = 1;
          # pas d'« xray » : le flou porte aussi sur les fenêtres derrière, pas seulement sur le fond d'écran
          blur_optimized = 0;
          # flou plus marqué derrière les fenêtres translucides (défauts : 2 passes, rayon 5)
          blur_params_num_passes = 3;
          blur_params_radius = 8;
          unfocused_opacity = 0.9;
          focused_opacity = 1.0;
          # animations rapides et élastiques : les courbes bezier dépassent 1 (overshoot) puis se calent
          animations = 1;
          layer_animations = 1;
          animation_type_open = "zoom";
          animation_type_close = "zoom";
          layer_animation_type_open = "zoom";
          layer_animation_type_close = "zoom";
          zoom_initial_ratio = 0.8;
          fade_in_begin_opacity = 0.0;
          fade_out_begin_opacity = 1.0;
          animation_duration_open = 220;
          animation_duration_close = 160;
          animation_duration_move = 260;
          animation_duration_tag = 240;
          animation_duration_focus = 140;
          animation_curve_open = "0.25,1.2,0.35,1.0";
          animation_curve_move = "0.25,1.15,0.35,1.0";
          animation_curve_tag = "0.2,1.15,0.3,1.0";
          animation_curve_close = "0.5,0.0,0.9,0.4";
          animation_curve_focus = "0.25,1.1,0.35,1.0";
          animation_curve_opacity_fade_in = "0.1,0.9,0.2,1.0";
          animation_curve_opacity_fade_out = "0.5,0.0,0.9,0.5";
          repeat_rate = 40;
          repeat_delay = 250;
          xkb_rules_layout = "us_qwerty-fr";
          xkb_rules_variant = "qwerty-fr";
          tap_to_click = 1;
          trackpad_natural_scrolling = 1;
          # seule : 100 % de l'écran ; avec une voisine : 90 %
          scroller_default_proportion = 0.9;
          scroller_default_proportion_single = 1.0;
          scroller_ignore_proportion_single = 0;
          scroller_proportion_preset = "0.5,0.8,1.0";
          source_optional = "~/.local/state/osyx/mango-colors.conf";
        }
        // binds
        // rules;
    };
  };
}
