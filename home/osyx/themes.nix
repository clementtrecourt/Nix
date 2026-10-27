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
  };

  programs.tmux.extraConfig = lib.mkAfter ''
    source-file -q ${state}/tmux.conf
  '';

  programs.fish.interactiveShellInit = lib.mkAfter ''
    test -e ${state}/starship.toml; and set -gx STARSHIP_CONFIG ${state}/starship.toml
    test -r ${state}/dircolors; and eval (dircolors -c ${state}/dircolors)
  '';
}
