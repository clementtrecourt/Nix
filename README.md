# ❄️ Mon Écosystème NixOS & Dotfiles

> Configuration NixOS déclarative, modulaire et multi-machines gérée avec les Flakes, Home Manager, SOPS-Nix et un cache binaire auto-hébergé sur Homelab.

---

## 🖥️ Les Machines

| Hôte | Usage | Spécificités & Optimisations |
| :--- | :--- | :--- |
| **`home`** | 🎮 Gaming & Personnel | Noyau **CachyOS (Scheduler BORE)**, Steam, Proton-GE, Gamemode, CoreCtrl (AMD GPU) |
| **`work`** | 💼 Travail & Développement | **MicroVM.nix** (VMs légères éphémères KVM), TigerVNC, Outils réseau |
| **`homelab`** | 🖧 Serveur 24/7 (Debian) | Cache binaire privé **Attic** via Tailscale, rétention automatique & déduplication |

---

## ⚡ Stack & Environnement

* **Bureau façon macOS Tahoe (macOS 26 « Liquid Glass »)** :
  * **Compositeur** : [Hyprland](https://hypr.land) 0.56 — fenêtres flottantes centrées (en cascade pour une même app), coins continus, grande ombre douce, liseré d'un pixel, flou des matériaux, glissement des espaces, gestes du pavé tactile (3/4 doigts, Mission Control), clic pour focaliser.
  * **Barres de titre** : plugin [hyprbars](https://github.com/hyprwm/hyprland-plugins) réglé façon Tahoe (feux tricolores Ø 14 pt à gauche, symboles × − ⤢ au survol, titre centré en Inter Semi-Bold, double-clic = Zoom) ; masquées pour les apps à décorations client (GTK/libadwaita, navigateurs, Electron).
  * **Shell** : écrit sur mesure en [Quickshell](https://quickshell.org) (QML) — barre des menus, Dock, Centre de contrôle, OSD, Spotlight, notifications, Mission Control, Cmd+Tab, verrouillage, agent Polkit. Service systemd `macos-shell`.
  * **Thèmes** : [MacTahoe](https://github.com/vinceliuice) GTK 3/4 + libadwaita (sombre, accent bleu), icônes **MacTahoe-Apple-dark** (vraies icônes d'apps de macOS 26 tirées de l'input de flake `macos-icons`, jamais copiées dans le dépôt, sur base MacTahoe), Kvantum MacTahoe pour Qt, curseur `macOS` (apple-cursor), police d'interface **Inter** (substitut de SF Pro), Kitty aux couleurs de Terminal.app.
* **Navigateur Web** : [Zen Browser](https://zen-browser.app) optimisé avec **Betterfox v148** et **Smoothfox** injectés via les Enterprise Policies NixOS.
* **Éditeur de Code** : **Zed Editor** & **Neovim (LazyVim)** déclaratifs avec serveurs LSP intégrés (`nixd`, `rust-analyzer`, Node.js).
* **Terminal & Shell** : **Kitty** (typographie *JetBrains Mono Nerd Font*, couleurs du Terminal de macOS, hints natifs) + **Fish** (Starship, Zoxide, Direnv, abréviations).
* **Multiplexeur** : **Tmux** optimisé (navigation vim, splits sans préfixe, copy-mode Wayland).
* **Gestion des Secrets** : **SOPS-Nix** avec chiffrement cryptographique asymétrique (`age` dérivé des clés SSH).
* **Réseau Privé Sécurisé** : **Tailscale** reliant toutes les machines et le Homelab.

---

## 📁 Arborescence du Dépôt

```text
.
├── flake.nix             # Point d'entrée multi-hôtes (outputs, overlays, mkHost)
├── flake.lock            # Verrouillage reproductible des dépendances
├── .sops.yaml            # Définition des clés de chiffrement SOPS autorisées
├── secrets/
│   └── secrets.yaml      # Fichier chiffré contenant les mots de passe et clés API
├── hosts/
│   ├── home/             # Configuration spécifique de la machine Gaming
│   │   ├── configuration.nix
│   │   └── hardware-configuration.nix
│   └── work/             # Configuration spécifique de la machine de Travail
│       ├── configuration.nix
│       └── hardware-configuration.nix
├── modules/
│   ├── common.nix        # Socle commun NixOS (Hyprland, Polices Inter, Pipewire, Greetd, Caches)
│   ├── gaming.nix        # Optimisations jeux (Steam, Gamemode, sysctl max_map_count)
│   ├── work.nix          # Outils de virtualisation MicroVM & KVM
│   ├── zen-browser.nix   # Configuration déclarative Zen Browser (Betterfox)
│   └── scripts/
│       ├── auto-cleaner.nix  # Timer systemd de purge automatique de la corbeille/caches
│       ├── organizer.nix     # Timer systemd de rangement intelligent de Downloads
│       ├── copy-tree.nix     # CLI copy-tree : copie l'arborescence filtrée
│       └── copy-context.nix  # CLI copy-context : exporte tout le projet en Markdown pour LLM
└── home/
    ├── common.nix        # Socle Home Manager (importe macos/, Git, Yazi, Paquets)
    ├── fish.nix          # Shell Fish (abréviations nrs, fonctions personnalisées)
    ├── kitty.nix         # Terminal Kitty (couleurs de Terminal.app, 80×24)
    ├── macos/            # Bureau macOS Tahoe
    │   ├── default.nix   # Point d'entrée (importé par common.nix)
    │   ├── hyprland.nix  # Hyprland : rendu, règles, hyprbars, gestes, raccourcis Cmd
    │   ├── shell.nix     # Installation du shell Quickshell + service systemd macos-shell
    │   ├── theme.nix     # GTK/icônes/Kvantum MacTahoe, curseur macOS, Inter, dconf
    │   ├── pkgs/         # Paquets locaux : thèmes MacTahoe, scripts macos-wm / macos-screenshot
    │   ├── shell/        # Code QML du shell (barre des menus, Dock, Spotlight…)
    │   └── dev/          # Banc de test : Hyprland imbriqué (nested.sh, hyprland-dev.conf)
    ├── tmux.nix          # Configuration Tmux
    ├── work.nix          # Overrides utilisateur machine pro
    └── zed.nix           # Configuration complète de Zed Editor
```

---

## 🛠️ Commandes & Workflow du Quotidien

| Commande / Raccourci | Action |
| :--- | :--- |
| **`nrs`** | Formate le code (`nix fmt`), applique la configuration (`nh os switch`) et pousse le binaire sur le Homelab (`attic push`) |
| **`nru`** | Met à jour les inputs du Flake et applique la configuration |
| **`nix fmt`** | Formate instantanément tous les fichiers `.nix` avec **Alejandra** |
| **`, <commande>`** | Exécute n'importe quel binaire sans l'installer (ex: `, cowsay "Hello"`, `, dust`) |
| **`copy-context`** | Analyse le projet, ignore les fichiers inutiles et copie toute l'arborescence + le code dans le presse-papier en Markdown |
| **`copy-tree`** | Copie uniquement l'arbre visuel du dossier dans le presse-papier |
| **`Alt + s`** *(dans Kitty)* | **Flash Motion** : affiche des étiquettes sur tous les mots à l'écran pour les copier instantanément |
| **`Alt + f`** *(dans Kitty)* | **Path Motion** : affiche des étiquettes sur les chemins de fichiers à l'écran pour les copier |

### ⌘ Raccourcis du bureau macOS (⌘ = touche Super)

| Raccourci | Action |
| :--- | :--- |
| **`⌘ Espace`** | Spotlight |
| **`F4`** | Apps (Launchpad) |
| **`⌘ Tab`** / **`⌘ ⇧ Tab`** | Sélecteur d'apps (validé au relâchement de ⌘) |
| **`⌘ ⌥ Échap`** | Forcer à quitter |
| **`⌃ ⌘ Q`** | Verrouiller l'écran |
| **`⌃ ↑`** / **`F3`** / 4 doigts vers le haut | Mission Control |
| **`⌃ ↓`** / 4 doigts vers le bas | Exposé de l'app |
| **`⌃ ←`** / **`⌃ →`** / 3-4 doigts horizontaux | Espace précédent / suivant |
| **`⌃ 1…9`** / **`⌃ ⇧ 1…9`** | Aller à l'espace N / y envoyer la fenêtre |
| **`⌘ Q`** | Quitter l'app (toutes ses fenêtres) |
| **`⌘ W`** / **`⌘ M`** / **`⌘ H`** | Fermer la fenêtre / la réduire / masquer l'app |
| **`` ⌘ ` ``** | Fenêtre suivante de la même app |
| **`⌃ ⌘ F`** | Plein écran |
| **`⌘ Entrée`** | Terminal (Kitty) |
| **`⌘ C/V/X/Z/A/S/F/T/N/P/L/R…`**, **`⌘ 1…9`** | Envoyés à l'app en Ctrl (Ctrl+Maj pour copier/coller dans les terminaux) |
| **`⌘ ⇧ Z`** / **`⌘ ⇧ T`** | Rétablir / rouvrir l'onglet |
| **`⌘ ←/→`**, **`⌘ ↑/↓`** | Début/fin de ligne, début/fin du document |
| **`⌘ ⇧ 3`** / **`⌘ ⇧ 4`** (+ **`Espace`** = fenêtre) | Capture de l'écran / d'une zone → `~/Pictures/Screenshots/Capture d’écran … .png` |
| **`⌃ ⌘ ⇧ 3/4`** | Capture vers le presse-papiers |
| **`⌘ ⇧ 5`** | Outil Capture d'écran |
| Touches volume / luminosité | wpctl / brightnessctl + OSD du shell |

> Banc de test du shell : `NESTED_ID=moi home/macos/dev/nested.sh start 1512x982 && home/macos/dev/nested.sh shell` (Hyprland imbriqué rendu sur une sortie headless, captures avec `nested.sh shot`).

---

## 🔐 Gestion des Secrets (SOPS-Nix) & Ajout d'une Machine

Tous les secrets (`secrets/secrets.yaml`) sont chiffrés avec le format `age` en utilisant les clés publiques SSH des machines autorisées.

### Cas 1 : Autoriser la machine `home` (ou corriger une erreur de déchiffrement)

1. Sur la machine `home`, générez sa clé hôte si elle n'existe pas encore :

   ```bash
   sudo ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ""
   ```

2. Obtenez sa clé publique `age` :

   ```bash
   , ssh-to-age -i /etc/ssh/ssh_host_ed25519_key.pub
   ```

   (Copiez la chaîne `age1...` obtenue.)

3. Dans `.sops.yaml`, déclarez la clé :

   ```yaml
   keys:
     - &clem age1ty8cc3ps0d4ksuhuuf2n59wr3dpx9sswxzl5xhqccwcw73mc2stq7cudwq
     - &machine_work age1_CLE_WORK...
     - &machine_home age1_VOTRE_CLE_HOME_ETAPE_2 # <-- Ajoutez ici

   creation_rules:
     - path_regex: secrets/[^/]+\.(yaml|json|env)$
       key_groups:
         - age:
             - *clem
             - *machine_work
             - *machine_home # <-- Ajoutez ici
   ```

4. Mettez à jour le chiffrement du fichier sans toucher au contenu :

   ```bash
   , sops updatekeys secrets/secrets.yaml
   ```

5. Validez et poussez :

   ```bash
   git add -A && git commit -m "fix(sops): add home machine key" && git push
   ```

### Cas 2 : Procédure Générique pour TOUT nouveau PC à l'avenir

Quand vous installez un nouveau PC (ex: laptop, nas, desktop-3) :

1. Sur le nouveau PC, récupérez sa clé publique `age` :

   ```bash
   sudo ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ""
   , ssh-to-age -i /etc/ssh/ssh_host_ed25519_key.pub
   ```

2. Sur n'importe quel PC existant, éditez `.sops.yaml` pour ajouter la nouvelle machine :

   ```yaml
   keys:
     - &clem age1ty8cc3ps0d4ksuhuuf2n59wr3dpx9sswxzl5xhqccwcw73mc2stq7cudwq
     - &machine_work age1_WORK...
     - &machine_home age1_HOME...
     - &machine_nouveau age1_NOUVELLE_CLE_ETAPE_1 # <-- Nouveau PC

   creation_rules:
     - path_regex: secrets/[^/]+\.(yaml|json|env)$
       key_groups:
         - age:
             - *clem
             - *machine_work
             - *machine_home
             - *machine_nouveau # <-- Nouveau PC
   ```

3. Re-chiffrez et poussez :

   ```bash
   , sops updatekeys secrets/secrets.yaml
   git commit -am "chore(sops): add new machine key" && git push
   ```

4. Sur le nouveau PC, récupérez le dépôt et appliquez :

   ```bash
   git pull
   nh os switch
   ```

---

## 📦 Cache Binaire Homelab (Attic)

Le cache binaire tourne dans un conteneur Docker sur le serveur Debian à l'adresse `http://192.168.1.10:8081/main-cache`.

- **Connexion au cache** :
  ```bash
  attic login homelab http://192.168.1.10:8081 <TOKEN_JWT>
  ```
- **Pousser manuellement le système** :
  ```bash
  attic push main-cache $(readlink -f /run/current-system)
  ```
- **Nettoyage automatique** : Une tâche cron sur le serveur exécute `atticadm garbage-collect` tous les dimanches pour supprimer les paquets non utilisés depuis plus de 30 jours.
