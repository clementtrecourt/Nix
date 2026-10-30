{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  state = "${config.home.homeDirectory}/.local/state/osyx";
  ln = name: config.lib.file.mkOutOfStoreSymlink "${state}/${name}";
in {
  home.packages = [inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.themes];

  # Les fichiers générés vivent dans l'état runtime (écrit par `themes`)
  xdg.configFile = {
    "mako/config".source = ln "mako.conf";
    "lookas.toml".source = ln "lookas.toml";
    "powyx/powyx.toml".source = ln "powyx.toml";
    "gtk-3.0/gtk.css".source = ln "gtk.css";
    "gtk-4.0/gtk.css".source = ln "gtk.css";
    "zed/themes/osyx.json".source = ln "zed.json";
    "swaylock/config".source = ln "swaylock.conf";
    "hypr/hyprlock-colors.conf".source = ln "hyprlock-colors.conf";
    # écran de verrouillage : même esprit que l'écran de connexion SDDM (fond, heure à gauche, champ arrondi)
    "hypr/hyprlock.conf".text = ''
      source = ${state}/hyprlock-colors.conf

      general {
        hide_cursor = true
        ignore_empty_input = true
        # affiche tout de suite (fond de couleur du thème) sans attendre le décodage de l'image ni le flou :
        # c'est cette attente qui laissait l'écran noir un instant à l'activation
        immediate_render = true
      }

      # pas de fondu depuis le noir de la surface de verrouillage
      animations {
        enabled = false
      }

      background {
        monitor =
        path = ${state}/lock-wallpaper.jpg
        color = $bg
        # léger flou, comme le fond de SDDM
        blur_passes = 2
        blur_size = 4
      }

      label {
        monitor =
        text = cmd[update:1000] date +%H:%M
        color = $fg
        font_size = 120
        font_family = Plus Jakarta Sans
        position = 150, 130
        halign = left
        valign = center
      }

      label {
        monitor =
        text = cmd[update:60000] date "+%A %d %B"
        color = $muted
        font_size = 22
        font_family = Plus Jakarta Sans
        position = 156, 40
        halign = left
        valign = center
      }

      input-field {
        monitor =
        size = 320, 54
        outline_thickness = 2
        rounding = 16
        dots_size = 0.25
        dots_spacing = 0.35
        dots_center = true
        outer_color = $border
        inner_color = $bg_soft
        font_color = $fg
        check_color = $warn
        fail_color = $fail
        capslock_color = $warn
        fade_on_empty = false
        placeholder_text = <i>Mot de passe</i>
        fail_text = <i>$FAIL ($ATTEMPTS)</i>
        font_family = Plus Jakarta Sans
        position = 150, -60
        halign = left
        valign = center
      }
    '';
  };

  # Vicinae ne lit les thèmes que dans ~/.local/share/vicinae/themes
  xdg.dataFile."vicinae/themes/osyx.toml".source = ln "vicinae.toml";

  # Qt (qt6ct) : palette générée, style Fusion pour qu'elle s'applique partout
  qt.style.name = lib.mkForce "Fusion";
  qt.qt6ctSettings.Appearance = {
    style = "Fusion";
    custom_palette = true;
    color_scheme_path = "${state}/qt6ct.conf";
  };

  # nvim (LazyVim) : applique la palette au démarrage ; `themes` la recharge à chaud
  programs.lazyvim.config.autocmds = ''
    vim.api.nvim_create_autocmd("User", {
      pattern = "VeryLazy",
      callback = function()
        pcall(dofile, vim.fn.expand("${state}/nvim-theme.lua"))
      end,
    })
  '';

  programs.kitty.extraConfig = lib.mkAfter ''
    include ${state}/kitty.conf
  '';

  programs.zed-editor.userSettings.theme = lib.mkForce "Osyx";

  programs.tmux.extraConfig = lib.mkAfter ''
    source-file -q ${state}/tmux.conf
  '';

  programs.fish.interactiveShellInit = lib.mkAfter ''
    # réappliqué à chaque prompt : une fenêtre ouverte avant le dernier `themes` suit aussi le nouveau style
    function __osyx_starship --on-event fish_prompt
      test -e ${state}/starship.toml; and set -gx STARSHIP_CONFIG ${state}/starship.toml
    end
    test -r ${state}/dircolors; and eval (dircolors -c ${state}/dircolors)
  '';
}
