#!/usr/bin/env bash
# Passe Orca (canal RC = bêta) à la plus récente version publiée sur
# stablyai/orca, RC ou stable (comme le canal RC de l'app), réécrit source.json.
# Jamais bloquant : en cas d'échec (hors ligne, limite de l'API GitHub…), on
# garde la version épinglée et on continue le rebuild.
set -uo pipefail
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
json="$dir/source.json"
asset="orca-linux.AppImage"

# Tags vX.Y.Z ou vX.Y.Z-rc.N (pas les builds -rc.N.perf ni mobile) ayant
# l'AppImage Linux. "-rc." devient "~rc." pour que sort -V classe la RC avant
# la stable du même numéro.
latest="$(curl -fsSL "https://api.github.com/repos/stablyai/orca/releases?per_page=50" |
  jq -r --arg a "$asset" '.[] | select(.draft | not)
          | select(.tag_name | test("^v[0-9]+\\.[0-9]+\\.[0-9]+(-rc\\.[0-9]+)?$"))
          | select(any(.assets[]; .name == $a)) | .tag_name' |
  sed 's/^v//; s/-rc\./~rc./' | sort -V | tail -n1 | sed 's/~rc\./-rc./')" || latest=""
if [ -z "$latest" ]; then
  echo "orca-rc : impossible de lire les releases, version conservée" >&2
  exit 0
fi

current="$(jq -r .version "$json" 2>/dev/null || echo none)"
if [ "$latest" = "$current" ]; then
  echo "orca-rc : déjà à jour ($current)"
  exit 0
fi

url="https://github.com/stablyai/orca/releases/download/v$latest/$asset"
if ! hash="$(nix store prefetch-file --json "$url" | jq -r .hash)" || [ -z "$hash" ]; then
  echo "orca-rc : téléchargement de $latest échoué, version conservée" >&2
  exit 0
fi

jq -n --arg v "$latest" --arg h "$hash" '{version: $v, hash: $h}' >"$json.tmp" && mv "$json.tmp" "$json"
echo "orca-rc : $current -> $latest"
