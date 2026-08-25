{ pkgs, lib, ... }:

{
  programs.zed-editor = {
    enable = true;
    installRemoteServer = true;

    # Extensions installées automatiquement
    extensions = [
      "nix"
      "toml"
      "rust"
      "elixir"
      "make"
    ];

    # Outils / LSP mis à disposition de Zed
    extraPackages = with pkgs; [
      nixd
      rust-analyzer
      nodejs
    ];

    # Paramètres Zed déclaratifs (~/.config/zed/settings.json)
    userSettings = {
      theme = {
        mode = "system";
        light = "One Light";
        dark = "One Dark";
      };
      ui_font_size = 16;
      buffer_font_size = 16;
      show_whitespaces = "all";
      hour_format = "hour24";
      auto_update = false;
      vim_mode = true;
      base_keymap = "VSCode";
      load_direnv = "shell_hook";

      # Assistant IA
      assistant = {
        enabled = true;
        version = "2";
        default_open_ai_model = null;
        default_model = {
          provider = "zed.dev";
          model = "claude-3-5-sonnet-latest";
        };
      };

      # Chemins vers Node.js
      node = {
        path = lib.getExe pkgs.nodejs;
        npm_path = lib.getExe' pkgs.nodejs "npm";
      };

      # Terminal intégré
      terminal = {
        alternate_scroll = "off";
        blinking = "off";
        copy_on_select = false;
        dock = "bottom";
        detect_venv = {
          on = {
            directories = [ ".env" "env" ".venv" "venv" ];
            activate_script = "default";
          };
        };
        env = {
          TERM = "alacritty";
        };
        font_family = "FiraCode Nerd Font";
        font_features = null;
        font_size = null;
        line_height = "comfortable";
        option_as_meta = false;
        button = false;
        shell = "system";
        toolbar = {
          title = true;
        };
        working_directory = "current_project_directory";
      };

      # Configuration des LSPs
      lsp = {
        rust-analyzer = {
          binary = {
            path_lookup = true;
          };
        };

        nix = {
          binary = {
            path_lookup = true;
          };
        };

        elixir-ls = {
          binary = {
            path_lookup = true;
          };
          settings = {
            dialyzerEnabled = true;
          };
        };
      };

      # Paramètres par langage
      languages = {
        "Elixir" = {
          language_servers = [ "!lexical" "elixir-ls" "!next-ls" ];
          format_on_save = {
            external = {
              command = "mix";
              arguments = [ "format" "--stdin-filename" "{buffer_path}" "-" ];
            };
          };
        };

        "HEEX" = {
          language_servers = [ "!lexical" "elixir-ls" "!next-ls" ];
          format_on_save = {
            external = {
              command = "mix";
              arguments = [ "format" "--stdin-filename" "{buffer_path}" "-" ];
            };
          };
        };
      };
    };
  };
}
