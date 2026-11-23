# Reprendre la session Claude Code « bureau macOS Tahoe » sur un autre PC

Ce dossier est temporaire : il contient la conversation Claude Code (`session.tar.zst`, en clair)
pour continuer le travail de la branche `feat/macos` sur le PC `home`. À supprimer avant de merger.

Session : `472ae197-f077-435f-8a7f-4a97abd9aa56`

## Sur le PC home

```bash
cd ~/Nix && git fetch origin && git worktree add .claude/worktrees/feat-macos feat/macos
echo ".claude/worktrees/" >> ~/Nix/.git/info/exclude
mkdir -p ~/.claude/projects
nix run nixpkgs#zstd -- -d -c ~/Nix/.claude/worktrees/feat-macos/.claude-transfer/session.tar.zst | tar -C ~/.claude/projects -xf -
cd ~/Nix/.claude/worktrees/feat-macos && claude --resume 472ae197-f077-435f-8a7f-4a97abd9aa56
```

Puis dire à Claude : « reprends le workflow macOS là où il s'est arrêté ». Le script du workflow est dans
`~/.claude/projects/-home-clem-Nix--claude-worktrees-feat-macos/472ae197-…/workflows/scripts/`.

## État au moment du push

- Squelette du shell Quickshell (`home/macos/shell`) + banc de test Hyprland imbriqué (`home/macos/dev/nested.sh`).
- Workflow multi-agents (8 composants : menubar, dock, controlcenter, spotlight, notifications, missioncontrol,
  session, nix) interrompu en cours de phase « Build » : le code des composants est partiel (WIP).
- `home/macos/dev/icon-pkg` contient un chemin du store propre à ce PC : le reconstruire sur home
  (`nix build` du paquet `home/macos/pkgs/mactahoe-icon-theme.nix`) ou supprimer le fichier.
