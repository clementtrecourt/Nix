#!/usr/bin/env bash
# Passe T3 Code Nightly à la dernière nightly publiée (réécrit source.json).
# Jamais bloquant : en cas d'échec (hors ligne, limite de l'API GitHub…), on
# garde la version épinglée et on continue le rebuild.
set -uo pipefail
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
json="$dir/source.json"

latest="$(curl -fsSL "https://api.github.com/repos/pingdotgg/t3code/releases?per_page=20" |
  jq -r '[.[] | select(.prerelease and (.tag_name | test("-nightly\\.")))
           | select(any(.assets[]; .name == "T3-Code-Nightly-x86_64.AppImage"))][0].tag_name // empty' |
  sed 's/^v//')" || latest=""
if [ -z "$latest" ]; then
  echo "t3code-nightly : impossible de lire les releases, version conservée" >&2
  exit 0
fi

current="$(jq -r .version "$json")"
if [ "$latest" = "$current" ]; then
  echo "t3code-nightly : déjà à jour ($current)"
  exit 0
fi

url="https://github.com/pingdotgg/t3code/releases/download/v$latest/T3-Code-Nightly-x86_64.AppImage"
if ! hash="$(nix store prefetch-file --json "$url" | jq -r .hash)" || [ -z "$hash" ]; then
  echo "t3code-nightly : téléchargement de $latest échoué, version conservée" >&2
  exit 0
fi

jq -n --arg v "$latest" --arg h "$hash" '{version: $v, hash: $h}' >"$json.tmp" && mv "$json.tmp" "$json"
echo "t3code-nightly : $current -> $latest"
