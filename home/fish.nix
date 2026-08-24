{ config, lib, pkgs, ... }:

{
  # Assure que les outils utilisés par les alias/fonctions sont présents
  home.packages = with pkgs; [
    eza
    lazygit
    zoxide
    direnv
  ];

  programs.fish = {
    enable = true;

    # ============================================
    # Aliases
    # ============================================
    shellAliases = {
      ls = "eza --icons --group-directories-first";
    };

    # ============================================
    # Abbreviations (développées automatiquement à l'espace)
    # ============================================
    shellAbbrs = {
      # Navigation / eza
      l = "ls -1";
      ll = "ls -l";
      la = "ls -a";
      lla = "ls -la";
      dev = "~/Code/devcontainer/adm.sh";

      # Editeur
      n = "nvim";

      # Git
      lg = "lazygit";
      gs = "git status";
      ga = "git add .";
      gc = "git commit -am";
      gd = "git diff";
      gl = "git log";
      gp = "git push";
      gpl = "git pull";
      gco = "git checkout";
      gsw = "git switch";
      gsm = "git switch main";
      gb = "git branch";
      gbd = "git branch -d";
      gst = "git stash";
      gsp = "git stash pop";
      gsh = "git show";
      gf = "git fetch";
      gcl = "git clone";

      # NixOS & nh
      nrs = "nh os switch";
      nru = "nh os switch --update";
      nrt = "nh os test";
      nrb = "nh os boot";
      nrg = "nh clean all";
      npk = "nh search";
      nsh = "nix-shell -p";
    };

    # ============================================
    # Fonctions Fish personnalisées
    # ============================================
    functions = {
      # Créer un dossier et y entrer
      mkcd = ''
        mkdir -p $argv[1] && cd $argv[1]
      '';

      # Extraire n'importe quelle archive
      extract = ''
        if not test -f $argv[1]
            echo "Fichier introuvable : $argv[1]"
            return 1
        end
        switch $argv[1]
            case "*.tar.bz2"  ; tar xjf $argv[1]
            case "*.tar.gz"   ; tar xzf $argv[1]
            case "*.tar.xz"   ; tar xJf $argv[1]
            case "*.tar.zst"  ; tar --use-compress-program=unzstd -xf $argv[1]
            case "*.tar"      ; tar xf  $argv[1]
            case "*.bz2"      ; bunzip2  $argv[1]
            case "*.gz"       ; gunzip   $argv[1]
            case "*.zip"      ; unzip    $argv[1]
            case "*.rar"      ; unrar x  $argv[1]
            case "*.7z"       ; 7z x     $argv[1]
            case "*.zst"      ; unzstd   $argv[1]
            case "*"
                echo "Format non reconnu : $argv[1]"
                return 1
        end
      '';

      # Nettoyage complet du store Nix
      nixclean = ''
        set before (df -h / | awk 'NR==2{print $3}')
        echo "Espace utilisé avant : $before"
        sudo nix-collect-garbage -d
        sudo nix store optimise
        set after (df -h / | awk 'NR==2{print $3}')
        echo "Espace utilisé après : $after"
      '';

      # Wrapper SSH intelligent avec fallback ssh-copy-id
      ssh = ''
        command ssh -o BatchMode=yes -o ConnectTimeout=5 $argv 2>/dev/null
        set exit_code $status

        if test $exit_code -eq 0
            return 0
        end

        set target ""
        for arg in $argv
            if string match -qr '^[^-]' -- $arg
                set target $arg
            end
        end

        if test -z "$target"
            command ssh $argv
            return $status
        end

        echo "🔑 Clé absente pour $target — lancement de ssh-copy-id..."
        if ssh-copy-id $target
            echo "✅ Clé copiée. Reconnexion..."
            command ssh $argv
        else
            echo "⚠️  ssh-copy-id échoué, connexion normale..."
            command ssh $argv
        end
      '';

      # Résumé des informations système
      sysinfo = ''
        set kernel (uname -r)
        set nix_ver (nix --version 2>/dev/null | head -1)
        set gen (sudo nix-env --list-generations --profile /nix/var/nix/profiles/system 2>/dev/null | tail -1)
        set disk (df -h / | awk 'NR==2{print $3"/"$2" ("$5")"}')
        set mem (free -h | awk '/^Mem/{print $3"/"$2}')
        set cpu (grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | string trim)
        set uptime_str (uptime -p)

        echo ""
        echo "  Kernel    : $kernel"
        echo "  Nix       : $nix_ver"
        echo "  Génération: $gen"
        echo "  CPU       : $cpu"
        echo "  RAM       : $mem"
        echo "  Disque    : $disk"
        echo "  Uptime    : $uptime_str"
        echo ""
      '';
    };

    # ============================================
    # Initialisation au démarrage du shell
    # ============================================
    interactiveShellInit = ''
      set -g fish_greeting ""
      # 1. Gestion SSH Agent
      if not set -q SSH_AUTH_SOCK
          ssh-agent -c | source >/dev/null 2>&1
      end
      if test -f ~/.ssh/id_ed25519
          ssh-add -l >/dev/null 2>&1 || ssh-add ~/.ssh/id_ed25519 >/dev/null 2>&1
      end

      # 2. Thème dynamique Matugen / Noctalia (si présent)
      if test -f ~/.config/fish/conf.d/matugen.fish
          source ~/.config/fish/conf.d/matugen.fish
      end

      # 3. Marqueur de prompt (jump entre prompts dans les terminaux)
      function mark_prompt_start --on-event fish_prompt
          echo -en "\e]133;A\e\\"
      end

      # 4. Intégrations interactives (Starship, Zoxide, Direnv)
      command -v starship &>/dev/null && starship init fish | source
      command -v zoxide &>/dev/null && zoxide init fish --cmd cd | source
      command -v direnv &>/dev/null && direnv hook fish | source

      # 5. Attachement automatique à tmux (session 'main')
      if not set -q TMUX
          exec tmux new-session -A -s main
      end
    '';
  };
}
