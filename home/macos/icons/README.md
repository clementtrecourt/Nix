# Icônes macOSicons

Icônes d'apps tierces (et variantes sombres) téléchargées depuis
https://macosicons.com/, plus la Corbeille officielle de macOS 26 (export PNG
partagé sur Google Drive, absent du dépôt `macos-icons`). Le manifeste conserve les
auteurs, les liens source et les SHA-256. Les images restent hors du dépôt.

Installation (Python 3 et ImageMagick) :

```sh
python3 home/macos/icons/install.py
```

Les PNG sont extraits à leur résolution maximale dans
`~/.local/share/macos-shell/icons/{dark,light}/`. Une icône pleine page (sans marge)
est ramenée sur la grille Apple (squircle de 824 px dans une toile de 1024 px).
Les fichiers de ces deux dossiers qui ne sont plus dans le manifeste sont supprimés ;
les surcharges posées à la racine du dossier ne sont jamais touchées. Le Dock
recharge les icônes sous 20 secondes. Les fichiers ICNS/PNG source sont conservés
dans `~/.cache/macosicons/`.

## Choix des variantes (comme Tahoe)

Le mode sombre ne change pas les icônes : c'est le réglage
System Settings > Appearance > Icon & widget style qui le fait.

- **Default** : `light/`, puis le thème MacTahoe-Apple (vraies icônes Tahoe).
- **Dark** : `dark/`, puis comme Default. Une app sans variante sombre convenable
  garde donc son icône normale, comme une app non mise à jour sous Tahoe.

Règles de sélection :

- Apps Apple (Finder, Terminal, System Settings, Apps, Activity Monitor, Preview,
  QuickTime pour mpv) : aucune icône `light/`, les officielles du thème font foi.
  En `dark/`, uniquement des variantes « fond sombre, glyphe d'origine » au dessin
  Tahoe.
- Corbeille : l'officielle en verre dans les deux styles. Téléchargements : le
  dossier du thème.
- Écartées : icônes plates ou détournées (Finder noir et blanc pleine page,
  dossier bleu plat, corbeille « biohazard », fusée de Launchpad Big Sur), variantes
  « sombres » qui ne le sont pas (LibreWolf, NixOS). TigerVNC n'a pas d'icône au
  style Apple : son icône d'origine est posée dans le squircle gris, comme Tahoe.
- Aucune icône retenue pour T3 Code, Orca IDE, Yazi, Easy Effects, Kvantum et
  Gammastep : leurs icônes existantes sont conservées.
