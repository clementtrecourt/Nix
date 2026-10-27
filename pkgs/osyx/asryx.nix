{
  stdenv,
  cmake,
  ninja,
  pkg-config,
  llvmPackages,
  whisper-cpp,
  src,
}:
stdenv.mkDerivation {
  pname = "asryx";
  version = "0-osyx";
  inherit src;

  nativeBuildInputs = [cmake ninja pkg-config];
  buildInputs = [llvmPackages.openmp];

  # whisper.cpp est normalement cloné dans $HOME par package/install : on utilise
  # les sources de nixpkgs, copiées pour être inscriptibles. -march=native est retiré
  # (build reproductible, indépendant du CPU de la machine de build).
  postPatch = ''
    cp -r ${whisper-cpp.src} whisper.cpp
    chmod -R u+w whisper.cpp
    substituteInPlace CMakeLists.txt \
      --replace-fail '"$ENV{HOME}/.local/share/asryx/deps/whisper.cpp"' '"''${CMAKE_SOURCE_DIR}/whisper.cpp"' \
      --replace-fail '-march=native' '-mtune=generic'
  '';

  cmakeFlags = ["-DBACKEND=cpu" "-DCMAKE_BUILD_TYPE=Release"];

  installPhase = ''
    runHook preInstall
    install -Dm755 asryx $out/bin/asryx
    runHook postInstall
  '';

  meta.mainProgram = "asryx";
}
