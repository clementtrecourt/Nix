{
  pkgs,
  inputs,
  ...
}: let
  themeSrc = "${inputs.caelestia-sddm}/themes/locklike";
  # Le thème est copié dans un dossier inscriptible : le script de sync y écrit
  # couleurs, avatar et fond d'écran (impossible dans le store).
  themeRoot = "/var/lib/caelestia-sddm/themes";
  themeDir = "${themeRoot}/caelestia";

  syncScript = pkgs.runCommand "caelestia-sddm-sync-script" {} ''
    install -Dm755 ${inputs.caelestia-sddm}/scripts/sync.sh $out
    substituteInPlace $out \
      --replace-fail '/usr/share/sddm/themes/caelestia' '${themeDir}' \
      --replace-fail '#!/usr/bin/env bash' '#!${pkgs.bash}/bin/bash'
  '';

  # À lancer après un changement de wallpaper/scheme (ou en posthook Caelestia).
  syncCmd = pkgs.writeShellScriptBin "caelestia-sddm-sync" ''
    export PATH=${pkgs.lib.makeBinPath (with pkgs; [coreutils gnused gnugrep file util-linux])}:/run/wrappers/bin:/run/current-system/sw/bin:$PATH
    exec sudo "$(command -v env)" PATH="$PATH" ${syncScript} "$@"
  '';
in {
  # Greeter X11 (xcb) requis par le thème pour le flou MultiEffect
  services.xserver.enable = true;

  services.displayManager = {
    defaultSession = "hyprland";
    sddm = {
      enable = true;
      package = pkgs.kdePackages.sddm;
      extraPackages = with pkgs.kdePackages; [qt5compat qtsvg qtmultimedia qtdeclarative];
      settings = {
        Theme = {
          ThemeDir = pkgs.lib.mkForce themeRoot;
          Current = "caelestia";
        };
        General.GreeterEnvironment = "QML_XHR_ALLOW_FILE_READ=1,QT_QPA_PLATFORM=xcb";
      };
    };
  };

  system.activationScripts.caelestiaSddm = {
    deps = ["users"];
    text = ''
      mkdir -p ${themeDir}
      # Ne pas écraser ce que la sync a généré (couleurs, avatar, fond)
      ${pkgs.rsync}/bin/rsync -rt --chmod=D755,F644 \
        --exclude=/theme.conf --exclude='/assets/avatar.*' --exclude='/assets/background*' \
        ${themeSrc}/ ${themeDir}/
      [ -e ${themeDir}/theme.conf ] || install -m644 ${themeSrc}/theme.conf ${themeDir}/theme.conf
      mkdir -p ${themeDir}/scripts
    '';
  };

  fonts.packages = with pkgs; [
    rubik
    roboto
    nerd-fonts.caskaydia-cove
    material-symbols
  ];

  environment.systemPackages = [syncCmd];
}
