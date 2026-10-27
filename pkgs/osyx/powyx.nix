{
  lib,
  stdenv,
  bash,
  gawk,
  coreutils,
  util-linux,
  qt6,
}:
stdenv.mkDerivation {
  pname = "powyx";
  version = "0-osyx";
  src = ../../home/osyx/assets/powyx;

  nativeBuildInputs = [qt6.wrapQtAppsHook];
  buildInputs = [qt6.qtdeclarative qt6.qt5compat qt6.qtwayland qt6.qtsvg];
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/powyx $out/bin
    cp -r src icons $out/share/powyx/
    install -Dm755 ${./powyx.sh} $out/bin/powyx
    substituteInPlace $out/bin/powyx \
      --replace-fail @bash@ ${bash} \
      --replace-fail @qml@ ${qt6.qtdeclarative}/bin/qml \
      --replace-fail @share@ $out/share/powyx
    runHook postInstall
  '';

  dontWrapQtApps = true;
  postFixup = ''
    wrapQtApp $out/bin/powyx --prefix PATH : ${lib.makeBinPath [gawk coreutils util-linux]}
  '';

  meta.mainProgram = "powyx";
}
