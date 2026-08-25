{ pkgs, ... }:

let
  copyTree = pkgs.writeShellApplication {
    name = "copy-tree";
    runtimeInputs = with pkgs; [
      fd
      wl-clipboard
    ];
    text = ''
      MODE="tree"
      TARGET_DIR="."
      DEPTH_ARGS=()

      # Liste des dossiers et fichiers inutiles à ignorer
      EXCLUDES=(
        # Contrôle de version & Nix
        ".git"
        ".direnv"
        ".devenv"
        "result"
        "result-*"

        # JavaScript / TypeScript / Node
        "node_modules"
        ".next"
        ".nuxt"
        ".turbo"
        ".npm"
        ".pnpm-store"
        "package-lock.json"
        "pnpm-lock.yaml"
        "yarn.lock"

        # Python / Rust / C++
        "__pycache__"
        ".venv"
        "venv"
        "env"
        ".pytest_cache"
        ".mypy_cache"
        ".ruff_cache"
        "target"
        "*.pyc"

        # Builds & Caches
        "dist"
        "build"
        "out"
        ".cache"
        ".parcel-cache"

        # IDEs & OS
        ".idea"
        ".vscode"
        ".DS_Store"
        "Thumbs.db"
      )

      # Construction dynamique des filtres d'exclusion
      EXCLUDE_ARGS=()
      for item in "''${EXCLUDES[@]}"; do
        EXCLUDE_ARGS+=(--exclude "''$item")
      done

      # Analyse des arguments CLI
      while [ "''$#" -gt 0 ]; do
        case "''$1" in
          -l|--list)
            MODE="list"
            shift
            ;;
          -d|--depth)
            DEPTH_ARGS=(--max-depth "''$2")
            shift 2
            ;;
          -h|--help)
            echo "Usage: copy-tree [OPTIONS] [DOSSIER]"
            echo ""
            echo "Options:"
            echo "  -l, --list      Affiche sous forme de liste plate plutôt qu'un arbre"
            echo "  -d, --depth N   Limite la profondeur d'exploration à N niveaux"
            echo "  -h, --help      Affiche cette aide"
            exit 0
            ;;
          *)
            TARGET_DIR="''$1"
            shift
            ;;
        esac
      done

      # Exécution de fd
      if [ "''$MODE" = "tree" ]; then
        OUTPUT=$(fd . "''$TARGET_DIR" --tree --hidden "''${EXCLUDE_ARGS[@]}" "''${DEPTH_ARGS[@]}")
      else
        OUTPUT=$(fd . "''$TARGET_DIR" --hidden "''${EXCLUDE_ARGS[@]}" "''${DEPTH_ARGS[@]}")
      fi

      # Affichage et copie dans le presse-papier Wayland
      echo "''$OUTPUT"
      echo "''$OUTPUT" | wl-copy
      echo -e "\n📋 \e[32mArborescence copiée dans le presse-papier !\e[0m"
    '';
  };
in
{
  environment.systemPackages = [
    copyTree
  ];
}
