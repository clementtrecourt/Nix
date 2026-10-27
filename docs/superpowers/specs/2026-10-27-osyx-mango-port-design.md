# Port d'osyx vers NixOS + MangoWM — design

Date : 2026-10-27 · Dépôt cible : `~/Nix` · Source : `~/Documents/osyx`

## Objectif

Utiliser osyx (stack UI : powyx, lookas, asryx, thyx, moteur de thèmes `flavors`,
keybinds, wofi/mako, wallpapers) sur le NixOS existant de `~/Nix`, avec **MangoWM**
à la place de Hyprland + Caelestia. Les keybinds osyx sont traduits vers Mango.

Succès :
- `nixos-rebuild`/`nrs` passe pour l'hôte `home` (et `work` n'est pas cassé).
- Connexion via SDDM (thème thyx) → session `mango` fonctionnelle, 2 écrans.
- Tous les keybinds du tableau ci-dessous fonctionnent.
- `themes <nom>` change les couleurs de kitty, tmux, starship, mako, wofi, bordures Mango.
- Plus aucune référence à Hyprland / Caelestia dans `~/Nix`.

## Contexte vérifié

- `~/Nix` tourne aujourd'hui sous Hyprland (Lua) + Caelestia. Le README annonce déjà
  Mango + Noctalia mais `home/mango.nix` n'existe pas (`build.log` : tentative Noctalia échouée).
- Écrans (`~/.config/mango/monitor.conf` existant) : `DP-3` 1920x1080@60 en (0,0),
  `HDMI-A-3` 1920x1080@60 en (1920,0). Clavier `us_qwerty-fr` (déjà géré par `inputs.qwerty-fr`).
- Shell : fish. Apps installées : zen-browser, Zed, nemo, brave, helium, spotify-spotx, kitty.
- Flake Mango : `github:DreamMaoMao/mango` (v0.15.0) expose `nixosModules.mango`
  (`programs.mango`, portals wlr+gtk, entrée SDDM) et `hmModules.mango`
  (`wayland.windowManager.mango` : `settings`, `extraConfig`, `autostart_sh`).
- Submodules osyx : `lookas` (Rust, crates simples → `buildRustPackage`), `thyx`
  (fournit déjà `default.nix` + `module.nix` NixOS), `asryx` (C++/CMake + whisper.cpp,
  plus lourd) sont publics. **`ctrlyx` et `jarvis` sont inaccessibles.**

## Décisions (validées)

1. Stack UI osyx complète (pas Noctalia).
2. `ctrlyx` remplacé par un petit centre de contrôle maison.
3. osyx copié/adapté dans `~/Nix` (pas d'input `osyx` complet) ; seuls `lookas`, `asryx`,
   `thyx` sont des inputs `flake = false`.
4. Fish conservé (pas de zsh). Apps : Zed, nemo, zen-browser.
5. `ALT+S` / `ALT+F` d'osyx déplacés en `SUPER+ALT+S` / `SUPER+ALT+F` pour ne pas
   écraser les hints Kitty (`Alt+s` flash motion, `Alt+f` path motion).

Hors périmètre : `provisioning/`, `bootstrap`, `hyprtryx`, CI GitHub, config zsh, `jarvis`.

## Architecture

```
flake.nix                 - retire caelestia-*, ajoute mango, lookas, asryx, thyx
modules/mango.nix         - NixOS : programs.mango, SDDM defaultSession, polkit/keyring
modules/sddm.nix          - réécrit : thème thyx (module.nix du dépôt thyx)
home/mango/default.nix    - wayland.windowManager.mango : settings + imports
home/mango/binds.nix      - keybinds (liste `bind`/`mousebind`/`axisbind`)
home/mango/rules.nix      - window_rule, tag_rule, monitorrule
home/mango/autostart.nix  - autostart_sh
home/osyx/default.nix     - imports des briques ci-dessous
home/osyx/flavors.nix     - générateur de thèmes (build) + script `themes`
home/osyx/powyx.nix       - package QML + wrapper `powyx`
home/osyx/lookas.nix      - buildRustPackage
home/osyx/asryx.nix       - package C++ (voir Risques)
home/osyx/control.nix     - centre de contrôle de remplacement (`ctrlyx-lite`)
home/osyx/ui.nix          - wofi, mako, swww, wlsunset, swaylock, grim/slurp/swappy, clipvault
home/osyx/bin/            - scripts osyx portés (battery, wifi, volume, … adaptés)
home/osyx/assets/         - wallpapers + palettes + templates flavors
```

À supprimer : `home/hyprland.nix`, `home/hypr-user.lua`, imports/inputs Caelestia,
`programs.hyprland`, `security.pam.services.hyprlock` (remplacé par `swaylock`),
paquets `hyprshade`, `hyprlock`, `hyprshot`, `hyprpicker`, `xdg-desktop-portal-hyprland`.
`modules/common.nix` garde `xwayland-satellite`. `home/common.nix` perd `./hyprland.nix`.

## Compositeur

Entrée de session : `programs.mango.enable = true` (NixOS) + `wayland.windowManager.mango.enable`
(HM, `systemd.enable = true`). SDDM `defaultSession = "mango"`. Config générée dans
`~/.config/mango/config.conf` ; la couleur des bordures vient d'un fichier
`~/.local/state/osyx/mango-colors.conf` inclus par `source_optional=` (écrit par `themes`).

Réglages repris d'osyx : `gaps` 6/18 → `gappih/gappiv=6`, `gappoh/gappov=18`,
`border_px=2`, `border_radius=12`, blur actif, opacité inactive 0.90, `repeat_rate=40`,
`repeat_delay=250`, touchpad `natural_scroll`/`tap_to_click`. Layout par défaut : `scroller`
(`scroller_default_proportion=0.9`, `scroller_proportion_preset=0.5,0.8,1.0`).
Clavier : `xkb_rules_layout=us_qwerty-fr` (symboles déjà installés).
Moniteurs : les deux `monitorrule` ci-dessus (reprise du fichier existant).
Tags : 1–9 par moniteur (Mango n'a pas de tag 10).

## Keybinds

Syntaxe Mango : `bind=MODS,KEY,ACTION,ARG` (modificateurs `SUPER|CTRL|ALT|SHIFT|NONE`
combinés par `+`). `l` = actif écran verrouillé, `r` = au relâchement.

### Apps (schéma ALT d'osyx)

| Touches | Action |
|---|---|
| `ALT+Return`, `ALT+K`, `ALT+Q` | `spawn,kitty` |
| `SUPER+Space` | `spawn,wofi --show drun` |
| `ALT+O` | `spawn,obsidian` |
| `ALT+E` | `spawn,zeditor` |
| `SUPER+ALT+F` | `spawn,nemo` (ex-`ALT+F`) |
| `SUPER+ALT+S` | `spawn,spotify` (ex-`ALT+S`) |
| `ALT+G` | `spawn,zen` |
| `ALT+L` | `spawn,swaylock` |
| `ALT+M` | `spawn,ctrlyx-lite` |
| `ALT+P` | `spawn,powyx` |
| `ALT+V` | `spawn,vocaster` (script porté) |
| `ALT+W` | `spawn,asryx` |
| `ALT+R` | `spawn_shell,themes rotate` |
| `ALT+SHIFT+C/Y/S` | web apps zen (`--new-window`/app mode) : calendar, youtube, soundcloud |

### Fenêtres

| osyx | Mango |
|---|---|
| `SUPER+Q`, `ALT+F4` | `killclient` |
| `SUPER+F` | `togglemaximizescreen` |
| `SUPER+V` | `togglefloating` |
| `SUPER+P` (pseudotile) | supprimé : pas d'équivalent en scroller |
| `SUPER+S` (togglesplit) | `switch_layout` |
| `SUPER+←↑↓→` | `focusdir,left/up/down/right` |
| `SUPER+SHIFT+←↑↓→` | `exchange_client,left/up/down/right` |
| `ALT+Tab` / `ALT+SHIFT+Tab` | `focusstack,next` / `focusstack,prev` |
| `SUPER+mouse gauche/droit` | `mousebind=SUPER,btn_left,moveresize,curmove` / `…btn_right,moveresize,curresize` |

### Tags (workspaces)

| osyx | Mango |
|---|---|
| `SUPER+1..9` | `view,N` |
| `SUPER+SHIFT+1..9` | `tag,N` |
| `SUPER+0` (ws 10) | `toggleoverview` (pas de tag 10) |
| `CTRL+ALT+←/→` | `viewtoleft` / `viewtoright` |
| binds AZERTY (`ampersand`, `eacute`, …) | supprimés : clavier `qwerty-fr` |

### Matériel et captures

| Touches | Action |
|---|---|
| `F1/F2/F3`, `XF86AudioMute/Lower/Raise` | `bindl=NONE,…,spawn,pamixer -t / -d 5 / -i 5` |
| `XF86AudioMicMute` | `pamixer --default-source -t` |
| `F6/F7`, `XF86MonBrightnessDown/Up` | `brightnessctl set 5%- / +5%` |
| `F9`, `XF86Launch2` | `shot-full` (capture écran complet) |
| `F10`, `Print`, `Sys_Req` | `shot-mac` (région) |
| `SUPER+SHIFT+S` | `spawn_shell,grim -g "$(slurp)" - \| swappy -f -` |
| `SUPER+SHIFT+B` | bascule `wlsunset` (lumière bleue) |
| `SUPER+Escape` | `spawn,systemctl poweroff` |
| `SUPER+SHIFT+W` | sélecteur de wallpaper (`wofi` sur `assets/wallpapers`, applique via `swww`) |
| `SUPER+X` / `SUPER+SHIFT+X` | historique presse-papier (`cliphist` + wofi) / purge |

`shot-full`, `shot-mac`, `vocaster` sont des scripts Nix portés (`home/osyx/bin/`) ;
`home/screenshot.nix` existant reste la base de `shot-*` (vérifié au moment du plan).
`SUPER+P` de l'ancien `screenshot region` est libéré.

## Règles et démarrage

- `window_rule` : overlays `powyx` et `ctrlyx-lite` (`is_floating:1,is_fullscreen:1,no_animation:1`
  sur `title:^powyx$` / `^ctrlyx-lite$`), opacité terminal 0.97, opacité 0.9 pour
  obsidian/zed/zen.
- Démarrage (`autostart_sh`) : `mako`, `swww-daemon`, restauration du wallpaper,
  `wlsunset` (21h→5h, 4500 K), `blueman-applet`, `pavucontrol --hide-window`, `clipvault`/`cliphist`
  watchers, puis `window_rule_once` pour placer obsidian (tag 1), 3 kitty (tag 3), zen (tag 2).
  Le hack Chromium d'osyx (règles à usage unique liées au PID Hyprland) n'est pas porté.
- Env : `NIXOS_OZONE_WL=1`, `XDG_CURRENT_DESKTOP=mango`, curseur capitaine-cursors (déjà configuré).

## Thèmes (`flavors`)

- Le générateur Python (`generate.py` + `generator/`, templates `*.j2`, palettes `*.toml`) est copié
  dans `home/osyx/assets/flavors/`. Un `pkgs.runCommand` l'exécute **au build** pour chaque palette
  et publie les sorties dans `…/share/osyx/themes/<palette>/`.
- Les templates Hypr (`hypr.lua.j2`) sont remplacés par `mango-colors.conf.j2`
  (`focus_color`, `border_color`, `urgent_color`). Template `ctrlyx.yaml.j2` ignoré.
  Le template `wofi.css.j2` et `mako.conf.j2` sont gardés.
- Script `themes <nom|rotate|list>` (écrit en fish-agnostique `pkgs.writeShellApplication`) :
  1. crée/met à jour les symlinks `~/.local/state/osyx/{kitty,tmux,starship,mako,wofi,dircolors,mango-colors}`
     vers la palette choisie ; mémorise le nom dans `~/.local/state/osyx/theme.current` ;
  2. recharge : `makoctl reload`, `kill -SIGUSR1` kitty, `tmux source-file`, reload Mango.
  Les configs home-manager kitty/tmux/starship/wofi/mako incluent ces fichiers (`include`/`source`).
- Palettes disponibles : `blush, gilded, kyanite, malachite, sakura, vermilion, versailles`.
  Palette par défaut : `versailles`.
- Wallpapers : copiés dans `~/Pictures/osyx/` par home-manager ; `thyx` utilise les siens
  (`presets/*.conf`) et le preset suit le nom de palette si un preset existe (`blush, gilded,
  malachite, sakura`), sinon `cinder`.
- Rechargement de Mango depuis `themes` : on essaie la sous-commande `mmsg` qui dispatche
  `reload_config` (nom exact vérifié avec `mmsg -h` au premier pas du plan). Si elle n'existe pas,
  `themes` n'agit pas sur Mango et le keybind `SUPER+SHIFT+R` (`reload_config`) recharge les
  bordures à la main.

## Briques UI

- **powyx** : QML (Qt6). `package` : `qt6.qtdeclarative` + wrapper qui lance `qml6 src/Main.qml`
  avec verrou `flock`, lit `powyx.toml` (généré par flavors). Actions : lock (swaylock),
  sleep, restart, shutdown (`systemctl`).
- **ctrlyx-lite** : menu wofi (un seul script, sans QML) listant wifi (`nmcli`),
  bluetooth (`bluetoothctl`), volume (`pamixer`), luminosité (`brightnessctl`), night shift,
  verrou/power. Port direct de `bin/{wifi,bluetooth,volume,brightness,night-shift}`.
- **lookas** : `rustPlatform.buildRustPackage` depuis l'input `lookas` (`cargoLock.lockFile`),
  `buildInputs = [alsa-lib]`. Config `~/.config/lookas.toml` depuis le template flavors.
- **asryx** : voir Risques.
- **thyx** : `services.displayManager.sddm.thyx.enable = true` + `sddm.enable`, `wayland.enable`.

## Risques et repli

| Risque | Repli |
|---|---|
| `asryx` (C++/whisper.cpp + modèle ggml) difficile à packager | package optionnel : si le build échoue on le désactive (`enable = false`), `ALT+W` non bindé, rien d'autre ne casse |
| `lookas` crate/ALSA | `alsa-lib` + `pkg-config` ; sinon retiré |
| noms d'actions Mango changent (v0.15) | `mango -c config.conf -p` valide la config au build via `runCommand` |
| `work` hôte partage `home/common.nix` | tout le port reste dans `home/mango/` + `home/osyx/`, importés par `home.nix` ; `work.nix` n'importe pas Mango (ou importe, à vérifier au plan) |
| flake lock changé | `nix flake lock --update-input mango …` seulement ; les autres inputs inchangés |

## Vérification

1. `nix flake check` / `nix build .#nixosConfigurations.home.config.system.build.toplevel`.
2. `mango -c <config.conf généré> -p` : zéro erreur.
3. `nixos-rebuild test` (ou `nh os test`) avant `switch`, puis connexion SDDM en TTY2 de secours
   disponible (Hyprland retiré seulement en dernière étape du plan).
4. Parcours manuel de chaque ligne des tableaux keybinds.
5. `themes list`, `themes versailles`, `themes rotate` : les 6 cibles changent.

## Ordre d'exécution (pour le plan)

1. Flake : ajout mango/lookas/asryx/thyx, `mmsg -h`, build à vide.
2. `modules/mango.nix` + `home/mango/*` (session minimale, keybinds, rules).
3. `home/osyx/ui.nix` (wofi, mako, swww, wlsunset, swaylock, captures).
4. flavors + `themes`.
5. powyx, ctrlyx-lite, lookas, thyx/SDDM.
6. asryx (optionnel).
7. Retrait de Hyprland/Caelestia, README mis à jour.
