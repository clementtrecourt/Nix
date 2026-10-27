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
    "wofi/style.css".source = ln "wofi.css";
    "lookas.toml".source = ln "lookas.toml";
    "powyx/powyx.toml".source = ln "powyx.toml";
    "gtk-3.0/gtk.css".source = ln "gtk.css";
    "gtk-4.0/gtk.css".source = ln "gtk.css";
    "zed/themes/osyx.json".source = ln "zed.json";
    "swaylock/config".source = ln "swaylock.conf";
  };

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
    test -e ${state}/starship.toml; and set -gx STARSHIP_CONFIG ${state}/starship.toml
    test -r ${state}/dircolors; and eval (dircolors -c ${state}/dircolors)
  '';
}
