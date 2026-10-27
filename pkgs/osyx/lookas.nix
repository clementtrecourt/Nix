{
  rustPlatform,
  pkg-config,
  alsa-lib,
  src,
}:
rustPlatform.buildRustPackage {
  pname = "lookas";
  version = "1.10.0";
  inherit src;
  cargoLock.lockFile = "${src}/Cargo.lock";
  nativeBuildInputs = [pkg-config];
  buildInputs = [alsa-lib];
  meta.mainProgram = "lookas";
}
