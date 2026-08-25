# ~/Dot/home-manager/noctalia.nix
{ inputs, ... }:
{
  imports = [ inputs.noctalia.homeModules.default ];

  programs.noctalia = {
    enable = true;
    systemd.enable = true;

    settings = {
      bar.default = {
        background_opacity = 0.4;
        contact_shadow = true;
        end = [
          "media" "tray" "notifications" "clipboard" "network"
          "bluetooth" "volume" "brightness" "battery"
          "control-center" "session" "now-playing"
        ];
        font_family = "Readex Pro";
        margin_ends = 0;
        radius = 0;
        shadow = false;
        start = [ "launcher" "wallpaper" "workspaces" "screenshot" "btn" "wallhaven" ];
        dead_zone.actions = {
          scroll_down = "volume-down";
          scroll_up = "volume-up";
        };
      };

      control_center.calendar.show_events_card = false;

      hot_corners = {
        enabled = true;
        bottom_right = {
          action = "command";
          command = "noctalia msg panel-toggle control-center media";
        };
      };


      plugins.enabled = [
        "kenn/keybind-cheatsheet"
        "ezequiel/mango_layouts"
        "noctalia/wallpaper_depth"
        "noctalia/wallhaven"
      ];

      shell = {
        font_family = "Readex Pro";
        panel = {
          control_center_placement = "floating";
          list_item_background = true;
          shadow = false;
          transparency_mode = "glass";
        };
      };

      theme = {
        builtin = "Ayu";
        community_palette = "Oxocarbon";
        mode = "dark";
        source = "wallpaper";
        wallpaper_scheme = "m3-content";
        templates = {
          builtin_ids = [
            "alacritty" "foot" "gtk3" "gtk4" "hyprland"
            "kcolorscheme" "kitty" "mango" "qt" "starship" "umbriel"
          ];
          community_ids = [
            "libreoffice" "obsidian" "zed" "heroiclauncher"
            "vicinae" "fastfetch" "papirus-icons" "bat" "lazygit" "yazi"
          ];
        };
      };

      widget = {
        btn.type = "ezequiel/mango_layouts:btn";
        "now-playing".type = "dragged/cider:now-playing";
        wallhaven.type = "noctalia/wallhaven:wallhaven";
      };
    };
  };
}
