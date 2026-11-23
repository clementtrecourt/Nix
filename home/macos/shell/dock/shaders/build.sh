#!/usr/bin/env bash
# Recompile les shaders du Dock (.vert/.frag -> .qsb). Les .qsb sont versionnés :
# ce script n'est nécessaire qu'après modification.
set -euo pipefail
cd "$(dirname "$0")"
QSB="${QSB:-$(nix build --no-link --print-out-paths 'nixpkgs#qt6.qtshadertools' 2>/dev/null | head -1)/bin/qsb}"
for f in *.vert *.frag; do
  "$QSB" --glsl "100 es,120,150" --hlsl 50 --msl 12 -o "$f.qsb" "$f"
done
