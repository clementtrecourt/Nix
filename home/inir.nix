{ inputs, pkgs, ... }:

let
  inir-python = pkgs.python3.withPackages (ps: with ps; [
    materialyoucolor
    numpy
    pillow
    requests
    jinja2
    pyyaml
    pygobject3
  ]);

  inir-tools = with pkgs; [
    inir-python
    awww
    swww
    bash
    glib
    imagemagick
    uv
    grim
    slurp
    swappy
    tesseract
    wf-recorder
    ffmpeg
    playerctl
    libnotify
    wlsunset
    cava
    libqalculate
    yt-dlp
    socat
    brightnessctl
    blueman
    ddcutil
    mpv
    translate-shell
    fuzzel
    hyprpicker
    kdePackages.plasma-integration
    kdePackages.kconfig
  ];

  quickshell-inir = pkgs.quickshell.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];
    buildInputs = (old.buildInputs or [ ]) ++ [
      pkgs.qt6.qt5compat
      pkgs.qt6.qtmultimedia
      pkgs.qt6.qtsvg
      pkgs.qt6.qtdeclarative
      pkgs.kdePackages.kirigami
      pkgs.kdePackages.kirigami-addons
      pkgs.kdePackages.qqc2-desktop-style
      pkgs.kdePackages.syntax-highlighting
      pkgs.kdePackages.kiconthemes
      pkgs.kdePackages.breeze-icons
    ];
    postFixup = (old.postFixup or "") + ''
      wrapProgram $out/bin/quickshell \
        --prefix PATH : "${pkgs.lib.makeBinPath inir-tools}"
    '';
  });
in
{
  imports = [
    inputs.inir.homeModules.inir
  ];

  programs.inir = {
    enable = true;
    service.compositor = "niri";
    configSymlink.enable = true;

    extraPackages = inir-tools;

    package = inputs.inir.packages.${pkgs.system}.default.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
        pkgs.makeWrapper
      ];
      buildInputs = (old.buildInputs or [ ]) ++ [
        quickshell-inir
      ];
      postPatch = (old.postPatch or "") + ''
        # 1. Remplace /bin/bash uniquement dans les fichiers QML
        find . -name "*.qml" -exec sed -i 's|"/bin/bash"|"${pkgs.bash}/bin/bash"|g' {} +
        find . -name "*.qml" -exec sed -i 's|"/usr/bin/bash"|"${pkgs.bash}/bin/bash"|g' {} +

        # 2. Remplace les shebangs bash UNIQUEMENT sur la ligne 1 au début du fichier (1s|^)
        find . -type f -exec sed -i '1s|^#!/usr/bin/env bash|#!${pkgs.bash}/bin/bash|' {} +
        find . -type f -exec sed -i '1s|^#!/usr/bin/bash|#!${pkgs.bash}/bin/bash|' {} +
        find . -type f -exec sed -i '1s|^#!/bin/bash|#!${pkgs.bash}/bin/bash|' {} +

        # 3. Remplace les shebangs python UNIQUEMENT sur la ligne 1
        find . -type f -exec sed -i '1s|^#!/usr/bin/env -S.*|#!${inir-python}/bin/python3|' {} +
        find . -type f -exec sed -i '1s|^#!/usr/bin/env python3|#!${inir-python}/bin/python3|' {} +

        sed -i 's/command -v qs/command -v quickshell/g' scripts/inir
        sed -i 's|/usr/bin/qs|${quickshell-inir}/bin/quickshell|g' scripts/inir

        sed -i '1a export PATH="${pkgs.lib.makeBinPath inir-tools}:$PATH"' scripts/inir
        sed -i 's|find_qs() {|find_qs() { qs_bin="${quickshell-inir}/bin/quickshell"; return 0; |g' scripts/inir
      '';
      postInstall = (old.postInstall or "") + ''
        cp -f *.qml $out/share/quickshell/inir/ 2>/dev/null || true
        sed -i 's|qs_bin=.*|qs_bin="${quickshell-inir}/bin/quickshell"|g' $out/share/quickshell/inir/scripts/inir
      '';
      postFixup = (old.postFixup or "") + ''
        wrapProgram $out/share/quickshell/inir/scripts/inir \
          --prefix PATH : "${pkgs.lib.makeBinPath inir-tools}"
      '';
    });
  };
}
