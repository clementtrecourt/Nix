# Port osyx → NixOS + MangoWM Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remplacer Hyprland + Caelestia par MangoWM et la stack UI d'osyx (powyx, lookas, asryx, thyx, flavors, keybinds) dans `~/Nix`.

**Architecture:** Les paquets osyx vivent dans `pkgs/osyx/*.nix` (callPackage), exposés par `packages.x86_64-linux` et vérifiés par `checks` dans le flake. La config Mango est générée par `home/mango/` (fonctions pures → `wayland.windowManager.mango.settings`). L'intégration par outil (kitty, tmux, wofi, mako…) est dans `home/osyx/`. Hyprland reste installé et sélectionnable dans SDDM jusqu'à la dernière tâche.

**Tech Stack:** Nix flakes, NixOS unstable, home-manager, Mango v0.15 (`hmModules.mango` / `nixosModules.mango`), Python/Jinja (flavors), Qt6 QML (powyx), Rust (lookas), CMake/whisper.cpp (asryx), SDDM (thyx).

**Spec:** `docs/superpowers/specs/2026-10-27-osyx-mango-port-design.md`

## Global Constraints

- Travail sur la branche `feat/mango-port` dans `~/Nix` (`git switch -c feat/mango-port`). Le `flake.lock` déjà modifié avant le début est commité avec la tâche 1.
- Formatage : `nix fmt` (alejandra) avant chaque commit.
- Commits terminés par `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.
- Apps : terminal `kitty`, éditeur `zeditor`, fichiers `nemo`, navigateur `zen`. Clavier `us_qwerty-fr` (pas de binds AZERTY).
- Tags Mango 1–9 seulement. `SUPER+0` = `toggleoverview`.
- `ALT+S`/`ALT+F` interdits (hints Kitty) : spotify = `SUPER+ALT+S`, nemo = `SUPER+ALT+F`.
- Écrans (hôte `home` uniquement, jamais dans `common.nix`) : `DP-3` 1920x1080@60 en x=0, `HDMI-A-3` 1920x1080@60 en x=1920.
- Palette par défaut `versailles`. Palettes : `blush gilded kyanite malachite sakura vermilion versailles`.
- Le thème système (`themes`) doit couvrir : mango, mako, wofi, powyx, lookas, tmux, starship, dircolors, kitty, GTK3/4, Qt (qt6ct), Zed, nvim, swaylock. Source unique : section `[kitty]` des palettes.
- État runtime des thèmes : `${XDG_STATE_HOME:-~/.local/state}/osyx/`.
- Mango partagé par les hôtes `home` et `work` (via `home/common.nix` / `modules/common.nix`).
- Hors périmètre : provisioning, zsh, jarvis, CI. `jarvis` et `ctrlyx` ne sont jamais référencés.

## Review Focus

- Hôte `work` : ses écrans ne s'appellent pas `DP-3`/`HDMI-A-3` → aucune `monitorrule` dans la config partagée (Tâche 2).
- Premier démarrage sans `~/.local/state/osyx/` → la session démarre quand même et un thème par défaut est posé (Tâches 2, 4).
- `themes` avec un nom inconnu → code ≠ 0, message d'erreur, état inchangé (Tâche 4).
- `themes rotate` sans `theme.current` existant → choisit une palette valide, pas de crash (Tâche 4).
- `asryx` ne se package pas → build vert, pas de bind `ALT+W`, aucune erreur d'éval (Tâche 8).
- Caractères spéciaux Nix/Mango dans les binds (`$(slurp)`, `|`, `%`, `"`) → config validée par `mango -p` (Tâche 2).
- Une app GTK/Qt/Zed/nvim déjà ouverte doit changer de couleurs au `themes apply` sans redémarrage (Tâche 4b).
- `powyx` lancé deux fois → un seul processus (Tâche 6).

---

### Task 1: Inputs du flake et sorties `packages`/`checks`

**Files:**
- Modify: `flake.nix`, `flake.lock`
- Create: `pkgs/osyx/default.nix`

**Interfaces:**
- Produces: inputs `mango` (flake, `follows nixpkgs`), `lookas`/`asryx`/`thyx` (`flake = false`) ; sortie `packages.x86_64-linux` alimentée par `import ./pkgs/osyx {inherit pkgs inputs;}` qui retourne `{osyx-themes, themes, powyx, ctrlyx-lite, lookas, asryx}` (attrset de dérivations, vide au départ sauf ce que les tâches suivantes ajoutent) ; sortie `checks.x86_64-linux` (attrset, vide au départ).

- [ ] **Step 1: Créer la branche** `git switch -c feat/mango-port` dans `~/Nix`.
- [ ] **Step 2: Ajouter les inputs** dans `flake.nix` : `mango.url = "github:DreamMaoMao/mango"` avec `inputs.nixpkgs.follows = "nixpkgs"` ; `lookas`, `asryx`, `thyx` en `github:rccyx/<nom>` avec `flake = false`. Ne pas retirer Caelestia.
- [ ] **Step 3: Verrouiller sans mettre à jour les autres** : `nix flake lock` (ajoute seulement les inputs manquants). Vérifier `git diff flake.lock` : uniquement des ajouts, plus le changement préexistant.
- [ ] **Step 4: Créer `pkgs/osyx/default.nix`** : `{pkgs, inputs}: {}` ; brancher `packages.${system} = import ./pkgs/osyx {inherit pkgs inputs;};` et `checks.${system} = {};` dans les `outputs`.
- [ ] **Step 5: Vérifier** : `nix flake check --no-build` → sort sans erreur ; `nix eval .#nixosConfigurations.home.config.system.build.toplevel.drvPath` → affiche un chemin `.drv`.
- [ ] **Step 6: Récupérer la syntaxe IPC** : `nix run github:DreamMaoMao/mango#mango -- -h` et `nix shell github:DreamMaoMao/mango -c mmsg -h` ; noter dans le message de commit la sous-commande `mmsg` qui exécute `reload_config` (`mmsg dispatch …` ou équivalent). Les tâches 4 et 6 l'utilisent via la variable `mmsgReload` définie dans `pkgs/osyx/default.nix` (chaîne de commande complète).
- [ ] **Step 7: Commit** `feat(flake): inputs mango, lookas, asryx, thyx`.

---

### Task 2: Session Mango (config générée + check de validation)

**Files:**
- Create: `modules/mango.nix`, `home/mango/default.nix`, `home/mango/binds.nix`, `home/mango/rules.nix`, `home/mango/autostart.nix`
- Modify: `modules/common.nix` (import `./mango.nix`), `home/common.nix` (import `./mango`), `home/home.nix` (monitorrule), `flake.nix` (check `mango-config`, `mango.nixosModules.mango` et `mango.hmModules.mango` dans `mkHost`)
- Test: `checks.x86_64-linux.mango-config`

**Interfaces:**
- Consumes: inputs `mango` (Tâche 1).
- Produces :
  - `binds.nix : {lib, pkgs}: [string]` — la liste `bind`/`bindl`… sous forme de lignes `MODS,KEY,ACTION,ARG` ; les clés `bindl`, `mousebind`, `axisbind` sont exposées en attrset : retourne `{bind = [..]; bindl = [..]; mousebind = [..]; axisbind = [..];}`.
  - `rules.nix : {} : {window_rule = [..]; window_rule_once = [..]; tag_rule = [..];}`.
  - `autostart.nix : {pkgs}: string` (corps du script `autostart_sh`, sans shebang).
  - Options consommées par les tâches suivantes : `osyx.apps` (attrset de noms de commandes : `term="kitty"`, `menu="wofi --show drun"`, `editor="zeditor"`, `files="nemo"`, `browser="zen"`, `lock="swaylock"`, `power="powyx"`, `control="ctrlyx-lite"`, `asryx = null | "asryx"`) déclarées dans `home/mango/default.nix` via `options.osyx.apps`.

- [ ] **Step 1: Écrire le check qui échoue** dans `flake.nix` : `checks.${system}.mango-config` = `runCommand` qui exécute `${inputs.mango.packages.${system}.mango}/bin/mango -c ${self.nixosConfigurations.home.config.home-manager.users.clem.xdg.configFile."mango/config.conf".source} -p` et `touch $out`. Lancer `nix build .#checks.x86_64-linux.mango-config` → **échoue** (fichier absent).
- [ ] **Step 2: `modules/mango.nix`** : `programs.mango.enable = true;` (importer `mango.nixosModules.mango` dans `mkHost`). Garder `programs.hyprland` et la session `hyprland` (secours). `services.displayManager.defaultSession` reste `hyprland` pour l'instant.
- [ ] **Step 3: `home/mango/default.nix`** : importer `mango.hmModules.mango` (sharedModules du flake), `wayland.windowManager.mango = {enable = true; systemd.enable = true; settings = …; autostart_sh = import ./autostart.nix {inherit pkgs;};}`. Valeurs du spec : `gappih=6 gappiv=6 gappoh=18 gappov=18`, `border_px=2`, `border_radius=12`, `blur=1`, `unfocused_opacity=0.90`, `focused_opacity=1.0`, `repeat_rate=40`, `repeat_delay=250`, `xkb_rules_layout="us_qwerty-fr"`, `tap_to_click=1`, `trackpad_natural_scrolling=1`, `new_is_master=0`, layout par défaut `scroller` via `tag_rule = map (i: "id:${toString i},layout_name:scroller") (range 1 9)`, `scroller_default_proportion=0.9`, `scroller_proportion_preset="0.5,0.8,1.0"`, `source_optional = "~/.local/state/osyx/mango-colors.conf"`. Fusionner `binds.nix`/`rules.nix` avec `//` (pas de définitions multiples de `settings`).
- [ ] **Step 4: `binds.nix`** : reproduire exactement les tableaux « Keybinds » du spec. Exemples épinglés : `"ALT,Return,spawn,${apps.term}"`, `"SUPER,Q,killclient"`, `"SUPER+SHIFT,s,spawn_shell,grim -g \"$(slurp)\" - | swappy -f -"`, `"SUPER,0,toggleoverview"`, `"SUPER+ALT,s,spawn,spotify"`, `"SUPER+ALT,f,spawn,${apps.files}"`, `"CTRL+ALT,Left,viewtoleft"`, `"ALT,Tab,focusstack,next"`, `"SUPER+SHIFT,r,reload_config"`. Boucle `1..9` pour `view`/`tag`. `bindl` pour `F1/F2/F3/F6/F7` et les `XF86*`. `mousebind=["SUPER,btn_left,moveresize,curmove" "SUPER,btn_right,moveresize,curresize"]`. `ALT,w,spawn,asryx` n'est ajouté que si `apps.asryx != null`.
- [ ] **Step 5: `rules.nix`** : `window_rule` pour `title:^powyx$` et `title:^ctrlyx-lite$` (`is_floating:1,is_fullscreen:1,no_animation:1`), `app_id:^(kitty)$` → `unfocused_opacity:0.97`, `app_id:^(obsidian|dev.zed.Zed|zen)$` → `focused_opacity:0.9`. `window_rule_once` : obsidian → `tags:1`, kitty → `tags:3`, zen → `tags:2`.
- [ ] **Step 6: `autostart.nix`** : lancer `mako`, `swww-daemon`, `wlsunset -S 21:00 -s 05:00 -t 4500` (lever 05:00, coucher 21:00 ; basculable via le script `nightshift` de la tâche 3), `blueman-applet`, `wl-paste --watch cliphist store`, puis `themes apply-default` (défini Tâche 4 ; en attendant, `command -v themes >/dev/null && themes apply-default`).
- [ ] **Step 7: Moniteurs** : dans `home/home.nix` seulement, ajouter `wayland.windowManager.mango.settings.monitorrule = ["name:^DP-3$,width:1920,height:1080,refresh:60,x:0,y:0,scale:1,vrr:0,rr:0" "name:^HDMI-A-3$,width:1920,height:1080,refresh:60,x:1920,y:0,scale:1,vrr:0,rr:0"];` — attention : `settings` ne fusionne pas entre modules ; si l'éval échoue, passer par `extraConfig`.
- [ ] **Step 8: Vérifier** : `nix build .#checks.x86_64-linux.mango-config` → **PASS**. Puis `grep -c "SUPER,Q,killclient" $(nix eval --raw …xdg.configFile.\"mango/config.conf\".source)` → `1`. Puis `nh os test .` et se connecter à la session `mango` depuis SDDM (TTY2 ouvert au cas où).
- [ ] **Step 9: Commit** `feat(mango): session, keybinds, rules, autostart`.

---

### Task 3: Briques UI (wofi, mako, wallpaper, verrou, night shift, captures)

**Files:**
- Create: `home/osyx/default.nix`, `home/osyx/ui.nix`, `home/osyx/bin/` (un `.nix` par script)
- Modify: `home/common.nix` (import `./osyx`), `home/screenshot.nix` (ajout `shot-full`/`shot-mac`), `modules/common.nix` (`security.pam.services.swaylock = {};`)

**Interfaces:**
- Produces (binaires dans le PATH) : `shot-full`, `shot-mac`, `vocaster`, `wallpaper-pick`, `nightshift` (toggle `wlsunset`), `clip-menu`, `clip-purge`.
- Consumes: `osyx.apps` (Tâche 2).

- [ ] **Step 1: Écrire le test** : `checks.x86_64-linux.osyx-bin` = `runCommand` qui exige que chaque binaire ci-dessus existe dans `home-manager.users.clem.home.path` (`test -x $path/bin/<nom>`). Lancer → **FAIL**.
- [ ] **Step 2: `ui.nix`** : `home.packages` = `wofi mako swww wlsunset swaylock grim slurp swappy cliphist wl-clipboard pamixer brightnessctl pavucontrol blueman`. Copier `docs/ui/wofi.md`/`mako.md` d'osyx pour les options statiques ; `~/.config/wofi/config` depuis `osyx/config/.config/wofi/config` (`xdg.configFile`).
- [ ] **Step 3: `shot-full` / `shot-mac`** dans `home/screenshot.nix` : `shot-full` = `grim` de tous les écrans → fichier + `wl-copy` ; `shot-mac` = `screenshot region` existant. Même dossier `~/Pictures/Screenshots`.
- [ ] **Step 4: Scripts portés** (`writeShellApplication`) : `vocaster` d'après `provisioning/setup/sound/_mute-unmute-vocaster.sh`, `nightshift` (`pkill wlsunset || wlsunset …`), `wallpaper-pick` (liste `~/Pictures/osyx/*` dans wofi puis `swww img`), `clip-menu` (`cliphist list | wofi --dmenu | cliphist decode | wl-copy`), `clip-purge` (`cliphist wipe`). Wallpapers : copier `osyx/packages/flavors/backgrounds/*` vers `home/osyx/assets/wallpapers/` et les poser dans `~/Pictures/osyx/` via `home.file`.
- [ ] **Step 5: Vérifier** : check **PASS** ; `nh os test .` ; dans la session Mango : `F9` crée un PNG dans `~/Pictures/Screenshots`, `SUPER+Space` ouvre wofi, `ALT+L` verrouille (swaylock se déverrouille avec le mot de passe).
- [ ] **Step 6: Commit** `feat(osyx): wofi, mako, swww, swaylock, captures, scripts`.

---

### Task 4: Moteur de thèmes `flavors` + script `themes`

**Files:**
- Create: `home/osyx/assets/flavors/` (copie de `osyx/packages/flavors/{generate.py,generator,palettes,templates}`), `home/osyx/assets/flavors/templates/mango-colors.conf.j2`, `pkgs/osyx/osyx-themes.nix`, `pkgs/osyx/themes.nix`, `home/osyx/themes.nix`
- Modify: `home/osyx/assets/flavors/generator/config.py` (OUTPUTS), `pkgs/osyx/default.nix`, `flake.nix` (checks), `home/kitty.nix`/`home/tmux.nix`/`home/fish.nix` (inclusions)
- Test: `checks.x86_64-linux.osyx-themes`, `checks.x86_64-linux.themes-cli`

**Interfaces:**
- Produces:
  - `osyx-themes : derivation` — pour chaque palette `P`, `$out/P/.config/{mako/config,starship.toml,wofi/style.css,powyx/powyx.toml,lookas.toml}`, `$out/P/.tmux.conf`, `$out/P/.dircolors`, `$out/P/.config/mango/colors.conf`. Méthode : pour chaque palette, copier `flavors/` dans `$TMP/P/flavors`, exécuter `python3 generate.py P` (le générateur écrit relativement au parent de `flavors/`, donc dans `$TMP/P`), puis copier `$TMP/P` (sans `flavors`) vers `$out/P`.
  - `themes : derivation` (binaire `themes`) : sous-commandes `list`, `current`, `apply <nom>`, `apply-default`, `rotate`. Variables : `OSYX_THEMES_DIR` (défaut = store path d'`osyx-themes`), `OSYX_STATE_DIR` (défaut `${XDG_STATE_HOME:-$HOME/.local/state}/osyx`), `OSYX_NO_RELOAD=1` saute les rechargements. `apply` crée dans `OSYX_STATE_DIR` les liens `mako.conf starship.toml wofi.css tmux.conf dircolors mango-colors.conf lookas.toml powyx.toml` vers `$OSYX_THEMES_DIR/<nom>/…` et écrit `theme.current`. Rechargement (sauf `OSYX_NO_RELOAD`) : `makoctl reload`, `pkill -USR1 kitty`, `tmux source-file` si un serveur tourne, `${mmsgReload}` (Tâche 1). Chaque rechargement est tolérant (`|| true`).
- Consumes: `mmsgReload` (Tâche 1).

- [ ] **Step 1: Écrire les checks qui échouent.** `osyx-themes` : pour les 7 palettes, `test -s $themes/<P>/.config/mako/config && test -s $themes/<P>/.config/mango/colors.conf`. `themes-cli` (dans un `runCommand`, `HOME=$TMPDIR`, `OSYX_NO_RELOAD=1`) : (a) `themes apply versailles` → exit 0 et `themes current` affiche `versailles` ; (b) `themes apply nope` → exit ≠ 0, stderr contient `inconnu` et `themes current` affiche toujours `versailles` ; (c) `rm theme.current; themes rotate` → exit 0 et `themes current` ∈ liste des palettes ; (d) `themes list | wc -l` → `7`. Lancer → **FAIL**.
- [ ] **Step 2: Template Mango** `mango-colors.conf.j2` : `focus_color=0x{{ hyprland_active_border }}ff`, `border_color=0x{{ hyprland_inactive_border }}ff`, `urgent_color=0x{{ hyprland_active_border }}ff`. Dans `config.py` : remplacer l'entrée `hypr.lua.j2` par `"mango-colors.conf.j2": ".config/mango/colors.conf"` et supprimer `ctrlyx.yaml.j2` ; supprimer `hypr.lua.j2` et `ctrlyx.yaml.j2` des templates. Dans `powyx.toml.j2` / `config`, remplacer `lock = "hyprlock"` par `lock = "swaylock"` (si présent dans le template).
- [ ] **Step 3: Implémenter `osyx-themes.nix`** (`{runCommand, python3Packages}`, dépendance `jinja2`) selon l'interface.
- [ ] **Step 4: Implémenter `themes.nix`** (`writeShellApplication`, `runtimeInputs = [coreutils procps libnotify]`). `rotate` : prochaine palette alphabétique après `current`, ou `versailles` si pas d'état. `apply-default` : n'applique que si `theme.current` est absent.
- [ ] **Step 5: Vérifier** : les deux checks → **PASS**.
- [ ] **Step 6: Intégration** (`home/osyx/themes.nix`) : `programs.kitty.extraConfig` inchangé (kitty n'a pas de template) ; `programs.tmux.extraConfig += "source-file -q ~/.local/state/osyx/tmux.conf"` en dernier ; `programs.fish.shellInit += "set -gx STARSHIP_CONFIG ~/.local/state/osyx/starship.toml"` avec repli `~/.config/starship.toml` si absent ; `xdg.configFile."mako/config"` et `wofi/style.css` deviennent des liens vers l'état (`mkOutOfStoreSymlink`) ; `DIRCOLORS` via `eval (dircolors -c …)` dans fish. Garder `themes` dans `home.packages`. Ajouter `ALT,r` déjà présent (Tâche 2) → `spawn_shell,themes rotate`.
- [ ] **Step 7: Vérifier** : `nh os test .`, relancer la session Mango, `themes versailles` puis `themes sakura` : les bordures, mako (`notify-send test`), tmux et le prompt changent.
- [ ] **Step 8: Commit** `feat(osyx): moteur de thèmes flavors + commande themes`.

---

### Task 4b: Thème système sur toutes les apps (kitty, GTK, Qt, Zed, nvim, swaylock)

**Files:**
- Create: templates `kitty.conf.j2`, `gtk.css.j2`, `qt6ct-colors.conf.j2`, `zed-theme.json.j2`, `nvim-theme.lua.j2`, `swaylock.conf.j2` dans `home/osyx/assets/flavors/templates/`
- Modify: `generator/config.py` (OUTPUTS), `pkgs/osyx/themes.nix` (liens + rechargements), `home/kitty.nix`, `home/common.nix` (gtk/qt), `home/zed.nix`, LazyVim (`home/osyx/themes.nix`), `home/osyx/ui.nix` (swaylock)
- Test: `checks.x86_64-linux.osyx-themes` étendu, `checks.x86_64-linux.themes-cli` étendu

**Interfaces:**
- Consumes: variables de palette de la section `[kitty]` (`kitty_bg`, `kitty_fg`, `kitty_cursor`, `kitty_selection_bg`, `kitty_selection_fg`, `kitty_color0..15`) ; c'est la **source unique** de toutes les couleurs ci-dessous (aucune palette modifiée).
- Produces, par palette `P`, dans `$out/P/` : `.config/kitty/osyx.conf`, `.config/gtk-3.0/gtk.css`, `.config/gtk-4.0/gtk.css`, `.config/qt6ct/colors/osyx.conf`, `.config/zed/themes/osyx.json`, `.config/nvim/osyx-theme.lua`, `.config/swaylock/config`. `themes apply` ajoute à l'état les liens `kitty.conf gtk.css qt6ct.conf zed.json nvim-theme.lua swaylock.conf` et les installe aux emplacements ci-dessus via liens symboliques depuis `~/.config/…` (déclarés dans HM par `mkOutOfStoreSymlink` vers `~/.local/state/osyx/…`).
- Rechargements ajoutés à `themes apply` (tous tolérants) : kitty = `pkill -USR1 -x kitty` ; GTK = `gsettings set org.gnome.desktop.interface color-scheme prefer-dark` puis re-signal par `dconf write /org/gnome/desktop/interface/gtk-theme` vers sa valeur courante pour forcer la relecture de `gtk.css` ; Zed = écrire `"theme": "Osyx"` (Zed relit le dossier `themes/` à chaud) ; nvim = pour chaque socket `nvim --server` actif envoyer `<Cmd>lua dofile(vim.fn.expand("~/.config/nvim/osyx-theme.lua"))<CR>` ; swaylock = lu à chaque lancement (rien à recharger).

- [ ] **Step 1: Étendre les checks (échouent)** : `osyx-themes` exige les 7 fichiers ci-dessus non vides pour chaque palette ; vérifier que `kitty/osyx.conf` contient `background #<kitty_bg>` pour `versailles` (`background #3e2723`) et que `zed/themes/osyx.json` est du JSON valide (`jq empty`). `themes-cli` : après `themes apply versailles`, les 7 liens existent dans `OSYX_STATE_DIR`. Lancer → **FAIL**.
- [ ] **Step 2: Templates** :
  - `kitty.conf.j2` : `foreground`, `background`, `cursor`, `selection_background/foreground`, `color0..15`, `active_border_color`, `url_color`, tabs (`active_tab_background` = `kitty_cursor`). Pas d'opacité (elle reste dans `home/kitty.nix`).
  - `gtk.css.j2` : `@define-color accent_bg_color`, `accent_color`, `window_bg_color`, `window_fg_color`, `view_bg_color`, `view_fg_color`, `headerbar_bg_color`, `card_bg_color`, `popover_bg_color` (libadwaita) + règles `window`, `headerbar`, `.view`, `entry` pour GTK3. Même contenu pour GTK3 et GTK4.
  - `qt6ct-colors.conf.j2` : section `[ColorScheme]` avec `active_colors`, `inactive_colors`, `disabled_colors` (20 entrées `#AARRGGBB` : WindowText, Button, Light, Midlight, Dark, Mid, Text, BrightText, ButtonText, Base, Window, Shadow, Highlight, HighlightedText, Link, LinkVisited, AlternateBase, NoRole, ToolTipBase, ToolTipText).
  - `zed-theme.json.j2` : schéma Zed (`$schema`, `name: "Osyx"`, `author`, un thème `Osyx` `appearance: "dark"` avec `style` : `background`, `editor.background`, `text`, `border`, `element.*`, `terminal.*` (ansi depuis `kitty_color*`), `syntax` (comment, keyword, string, function, type…) mappés sur `color1..color6`).
  - `nvim-theme.lua.j2` : `vim.cmd("hi clear")`, `vim.o.termguicolors = true`, puis `vim.api.nvim_set_hl(0, group, {fg=, bg=})` pour `Normal NormalFloat CursorLine Visual Comment String Function Keyword Type Identifier Statement PreProc Special LineNr StatusLine Pmenu PmenuSel` + `vim.g.terminal_color_0..15`.
  - `swaylock.conf.j2` : `color=<kitty_bg>`, `inside-color`, `ring-color=<kitty_cursor>`, `key-hl-color`, `text-color=<kitty_fg>`.
- [ ] **Step 3: `OUTPUTS`** : ajouter les 7 couples (template → chemin relatif ci-dessus) ; les tests de la Tâche 4 restent verts.
- [ ] **Step 4: Intégration par app** :
  - `home/kitty.nix` : remplacer `include dank-tabs.conf` et `include dank-theme.conf` par `include ~/.local/state/osyx/kitty.conf` ; conserver le `background #000000` forcé **uniquement** si l'utilisateur le demande (sinon retirer : le fond vient du thème).
  - `home/common.nix` : `gtk.theme` passe à un thème neutre sombre libadwaita (`adw-gtk3-dark`) ; `gtk.gtk3.extraCss`/`gtk4.extraCss` inutiles, `~/.config/gtk-{3,4}.0/gtk.css` sont des liens vers l'état ; `qt` : `platformTheme.name = "qt6ct"`, `style.name = "Fusion"` (kvantum retiré), `~/.config/qt6ct/qt6ct.conf` contient `color_scheme_path=~/.config/qt6ct/colors/osyx.conf` et `custom_palette=true`.
  - `home/zed.nix` : `userSettings.theme = "Osyx"` et `~/.config/zed/themes/osyx.json` lien vers l'état.
  - LazyVim : `~/.config/nvim/lua/plugins/osyx.lua` (via `programs.lazyvim.extraConfig` ou `xdg.configFile`) exécutant `dofile(osyx-theme.lua)` à `ColorScheme`/`VimEnter`.
  - `swaylock` : `swaylock` lancé avec `-C ~/.local/state/osyx/swaylock.conf` dans les binds et dans `powyx.toml`.
- [ ] **Step 5: Vérifier** : checks **PASS**. `nh os test .`, session Mango : `themes sakura` puis `themes versailles` ; observer le changement **sans relancer** les apps dans kitty, nemo (GTK), pavucontrol (GTK), un client Qt (`qt6ct`), Zed (thème `Osyx`), nvim ouvert, et `ALT+L` (swaylock coloré).
- [ ] **Step 6: Limites documentées dans le README** (Tâche 9) : le navigateur zen, Spotify, Obsidian, Discord et les applis Electron/Chromium ont leur propre moteur de thème et **ne sont pas** pilotés par `themes`. Les lister, sans promesse. Le login SDDM est statique (preset `cinder`).
- [ ] **Step 7: Commit** `feat(osyx): thème système sur kitty, GTK, Qt, Zed, nvim, swaylock`.

---

### Task 5: Login SDDM avec thyx

**Files:**
- Modify: `modules/sddm.nix` (réécriture), `flake.nix` (retirer `caelestia-sddm` plus tard, Tâche 9)
- Test: `nix build` du `toplevel` et assertion d'éval

**Interfaces:**
- Consumes: input `thyx` (Tâche 1), son `module.nix` (option `services.displayManager.sddm.thyx.enable`).
- Produces: SDDM thème `thyx`, session par défaut `mango`.

- [ ] **Step 1: Écrire l'assertion** : `nix eval .#nixosConfigurations.home.config.services.displayManager.sddm.theme` doit valoir `"thyx"`. Lancer → **FAIL** (valeur différente).
- [ ] **Step 2: Réécrire `modules/sddm.nix`** : `imports = ["${inputs.thyx}/module.nix"];`, `services.displayManager.sddm = {enable = true; wayland.enable = true; thyx.enable = true;};`, `services.displayManager.defaultSession = "mango";`. Lire `thyx/README.md` pour toute variable de greeter requise (réglages `GreeterEnvironment`). Supprimer `services.xserver.enable` du fichier uniquement si le README ne l'exige pas. Retirer rootSync/syncCmd/activationScript/sudo rule de Caelestia. Conserver `fonts.packages` utiles.
- [ ] **Step 3: Preset** : le greeter est système, il ne suit donc pas `themes` au runtime. Utiliser le preset `cinder` (celui du `theme.conf` par défaut de thyx) ; ne rien configurer de plus.
- [ ] **Step 4: Vérifier** : assertion **PASS** ; `nix build .#nixosConfigurations.home.config.system.build.toplevel --no-link` ; `nh os test .` ; au prochain boot (ou `systemctl restart display-manager` depuis TTY2 après avoir enregistré le travail) le login thyx s'affiche et propose `mango` et `hyprland`.
- [ ] **Step 5: Commit** `feat(sddm): thème thyx, session mango par défaut`.

---

### Task 6: powyx et ctrlyx-lite

**Files:**
- Create: `pkgs/osyx/powyx.nix`, `pkgs/osyx/ctrlyx-lite.nix`, `home/osyx/assets/powyx/` (copie de `osyx/packages/powyx/{src,icons}`)
- Modify: `pkgs/osyx/default.nix`, `home/osyx/default.nix` (paquets), `flake.nix` (checks)
- Test: `checks.x86_64-linux.powyx-lock`, `checks.x86_64-linux.osyx-qml-lint`

**Interfaces:**
- Produces: binaire `powyx` (wrapper `flock -n` sur `$XDG_RUNTIME_DIR/powyx.lock` puis `qml6 <store>/share/powyx/src/Main.qml`, lisant `~/.config/powyx/powyx.toml` ← lien vers l'état `powyx.toml` de la Tâche 4) ; binaire `ctrlyx-lite` (menu wofi : entrées Wi-Fi, Bluetooth, Volume, Luminosité, Night shift, Verrouiller, Quitter ; chaque entrée appelle `nmcli`, `bluetoothctl`, `pamixer`, `brightnessctl`, `nightshift`).
- Consumes: `themes` (état `powyx.toml`).

- [ ] **Step 1: Écrire les checks qui échouent.** `osyx-qml-lint` : `qmllint` (`qt6.qtdeclarative`) sur `src/**/*.qml` sans erreur. `powyx-lock` : lancer le wrapper avec `QML_RUNNER=true` (variable lue par le wrapper pour remplacer `qml6` en test) deux fois en parallèle sur le même `XDG_RUNTIME_DIR`, le premier tenant le verrou via un `sleep` → le second sort avec le code 0 sans lancer `QML_RUNNER` (compteur dans un fichier). Lancer → **FAIL**.
- [ ] **Step 2: `powyx.nix`** : installe `src` et `icons` dans `$out/share/powyx`, wrapper `writeShellApplication` avec `runtimeInputs = [util-linux qt6.qtdeclarative]` et `QML_IMPORT_PATH`. Toml absent → le wrapper échoue avec un message clair (`themes apply-default`).
- [ ] **Step 3: `ctrlyx-lite.nix`** : `writeShellApplication`, `runtimeInputs = [wofi networkmanager bluez pamixer brightnessctl]`. Ouverture avec `wofi --dmenu --prompt control`, `case` sur l'entrée choisie.
- [ ] **Step 4: Vérifier** : checks **PASS** ; `nh os test .` ; `ALT+P` ouvre powyx en plein écran flottant (la règle de la Tâche 2), un second `ALT+P` n'en ouvre pas un autre ; `ALT+M` ouvre le menu.
- [ ] **Step 5: Commit** `feat(osyx): powyx et ctrlyx-lite`.

---

### Task 7: lookas

**Files:**
- Create: `pkgs/osyx/lookas.nix`
- Modify: `pkgs/osyx/default.nix`, `home/osyx/default.nix`, `flake.nix` (check)
- Test: `checks.x86_64-linux.lookas-version`

**Interfaces:**
- Produces: binaire `lookas` ; config `~/.config/lookas.toml` lien vers l'état `lookas.toml` (Tâche 4).

- [ ] **Step 1: Écrire le check** : `${lookas}/bin/lookas --help` sort avec code 0 (ou `--version`, selon ce que la CLI accepte). Lancer → **FAIL**.
- [ ] **Step 2: `lookas.nix`** : `rustPlatform.buildRustPackage { src = inputs.lookas; cargoLock.lockFile = "${inputs.lookas}/Cargo.lock"; nativeBuildInputs = [pkg-config]; buildInputs = [alsa-lib]; }`.
- [ ] **Step 3: Vérifier** : check **PASS**. Si le build échoue, lire l'erreur, corriger la dépendance manquante ; si impossible en 3 tentatives, retirer lookas de `home.packages` et noter l'échec dans le commit.
- [ ] **Step 4: Commit** `feat(osyx): lookas`.

---

### Task 8: asryx (optionnel)

**Files:**
- Create: `pkgs/osyx/asryx.nix`
- Modify: `pkgs/osyx/default.nix`, `home/mango/default.nix` (`osyx.apps.asryx`), `flake.nix` (check)

**Interfaces:**
- Produces: binaire `asryx` si le build passe. `osyx.apps.asryx = "asryx"` seulement dans ce cas ; sinon `null` (aucun bind `ALT+W`).

- [ ] **Step 1: Écrire le check** : `${asryx}/bin/asryx --help` code 0. Lancer → **FAIL**.
- [ ] **Step 2: `asryx.nix`** : `stdenv.mkDerivation` avec `cmake ninja pkg-config`, `whisper-cpp` (ou la version vendored si le `CMakeLists` la télécharge — dans ce cas fournir la source via `FETCHCONTENT_SOURCE_DIR_*`, le sandbox n'ayant pas de réseau), OpenMP, et les libs audio demandées par `CMakeLists.txt` (lire `find_package`). Le modèle ggml n'est pas packagé : le documenter dans le message de commit (télécharger à la main dans `~/.local/share/asryx`).
- [ ] **Step 3: Vérifier** : check **PASS** ; sinon, après 3 tentatives, laisser `osyx.apps.asryx = null`, ne rien exposer dans `packages`, vérifier `nix flake check --no-build` OK et le bind `ALT,w` absent de `config.conf` (`grep -c "ALT,w" … = 0`).
- [ ] **Step 4: Commit** `feat(osyx): asryx` (ou `chore(osyx): asryx désactivé, build impossible`).

---

### Task 9: Retrait d'Hyprland et Caelestia, documentation

**Files:**
- Delete: `home/hyprland.nix`, `home/hypr-user.lua`
- Modify: `flake.nix` (retirer `caelestia-shell`, `caelestia-dots`, `caelestia-sddm`, leur `sharedModules`), `flake.lock`, `home/common.nix` (retirer `./hyprland.nix`, `hyprshot hyprshade hyprlock hyprpicker`, `hyprcursor`), `modules/common.nix` (retirer `programs.hyprland`, `security.pam.services.hyprlock`), `home/fish.nix` (retirer la mention Hyprland dans le commentaire TMUX), `README.md`, `modules/sddm.nix` (défaut `mango` déjà posé)

**Interfaces:** aucune nouvelle.

- [ ] **Step 1: Écrire le test qui échoue** : `grep -rniE "hypr|caelestia" --include=*.nix --include=*.lua . | grep -v docs/` doit être vide (hors `programs.mango`, `hyprcursor` retiré). Lancer → **FAIL**.
- [ ] **Step 2: Retirer** les éléments listés ; `nix flake lock` pour purger les inputs Caelestia (aucune autre mise à jour).
- [ ] **Step 3: README** : remplacer la section « Stack » : MangoWM + stack osyx (thyx, powyx, flavors, lookas, asryx) au lieu de Noctalia ; mettre à jour l'arborescence (`home/mango/`, `home/osyx/`, `pkgs/osyx/`) ; ajouter la table des keybinds principaux et la commande `themes`.
- [ ] **Step 4: Vérifier** : le grep est vide ; `nix flake check` complet (tous les checks verts) ; `nix build .#nixosConfigurations.{home,work}.config.system.build.toplevel --no-link` verts pour **les deux** hôtes ; `nh os test .` ; redémarrer et passer par le parcours manuel du spec : chaque ligne des tableaux keybinds, `themes list|versailles|rotate`.
- [ ] **Step 5: Commit** `refactor: retire Hyprland et Caelestia, README Mango + osyx`, puis `git switch main && git merge --ff-only feat/mango-port` après accord de l'utilisateur, puis `nrs` (déploiement).
