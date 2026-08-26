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

* **Compositeur Wayland** : [MangoWM](https://github.com/mangowm/mango) avec layout *Scroller* & animations fluides.
* **Barre & Thème Dynamique** : [Noctalia](https://github.com/noctalia-dev/noctalia) (panneau de contrôle, widgets, thèmes dynamiques).
* **Navigateur Web** : [Zen Browser](https://zen-browser.app) optimisé avec **Betterfox v148** et **Smoothfox** injectés via les Enterprise Policies NixOS.
* **Éditeur de Code** : **Zed Editor** & **Neovim (LazyVim)** déclaratifs avec serveurs LSP intégrés (`nixd`, `rust-analyzer`, Node.js).
* **Terminal & Shell** : **Kitty** (typographie *IBM Plex Mono / BlexMono Nerd Font*, hints natifs) + **Fish** (Starship, Zoxide, Direnv, abréviations).
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
│   ├── common.nix        # Socle commun NixOS (Polices, Pipewire, Greetd, SOPS, Caches)
│   ├── gaming.nix        # Optimisations jeux (Steam, Gamemode, sysctl max_map_count)
│   ├── work.nix          # Outils de virtualisation MicroVM & KVM
│   ├── zen-browser.nix   # Configuration déclarative Zen Browser (Betterfox)
│   └── scripts/
│       ├── auto-cleaner.nix  # Timer systemd de purge automatique de la corbeille/caches
│       ├── organizer.nix     # Timer systemd de rangement intelligent de Downloads
│       ├── copy-tree.nix     # CLI copy-tree : copie l'arborescence filtrée
│       └── copy-context.nix  # CLI copy-context : exporte tout le projet en Markdown pour LLM
└── home/
    ├── common.nix        # Socle Home Manager (GTK, Qt, Curseur, Git, Yazi, Paquets)
    ├── fish.nix          # Shell Fish (abréviations nrs, fonctions personnalisées)
    ├── kitty.nix         # Terminal Kitty (polices, opacité, raccourcis hints)
    ├── mango.nix         # Configuration MangoWM (keybinds, layout scroller, animations)
    ├── noctalia.nix      # Widgets, barre et gestionnaire de session Noctalia
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
