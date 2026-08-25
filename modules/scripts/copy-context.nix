{pkgs, ...}: let
  copyContext = pkgs.writeShellApplication {
    name = "copy-context";
    runtimeInputs = with pkgs; [
      tree
      fd
      file
      wl-clipboard
    ];
    text = ''
      TARGET_DIR="''${1:-.}"

      # Liste complète des exclusions (dossiers, caches, assets lourds, binaires)
      EXCLUDES=(
        # Git & Nix
        ".git"
        ".direnv"
        ".devenv"
        "result"
        "result*"

        # JavaScript / Node
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

        # Formats médias / binaires / polices
        "*.png"
        "*.jpg"
        "*.jpeg"
        "*.webp"
        "*.gif"
        "*.ico"
        "*.svg"
        "*.pdf"
        "*.woff"
        "*.woff2"
        "*.ttf"
        "*.eot"
        "*.mp4"
        "*.mp3"
        "*.zip"
        "*.tar.*"
      )

      # Motif pour la commande tree
      OLD_IFS="''${IFS}"
      IFS="|"
      TREE_IGNORE="''${EXCLUDES[*]}"
      IFS="''${OLD_IFS}"

      # Arguments pour la commande fd
      FD_EXCLUDE_ARGS=()
      for item in "''${EXCLUDES[@]}"; do
        FD_EXCLUDE_ARGS+=(--exclude "''$item")
      done

      echo "🔍 Analyse du projet dans : ''$TARGET_DIR..."

      # 1. Génération de l'arborescence
      TREE_OUTPUT=$(tree "''$TARGET_DIR" -a --gitignore -I "''$TREE_IGNORE")

      TMP_OUTPUT=$(mktemp)

      {
        echo "# Arborescence du projet"
        echo '```text'
        echo "''$TREE_OUTPUT"
        echo '```'
        echo ""
        echo "# Contenu des fichiers"
        echo ""
      } > "''$TMP_OUTPUT"

      # 2. Concaténation de chaque fichier texte
      FILE_COUNT=0

      while IFS= read -r filepath; do
        # Vérification si le fichier est binaire (évite de copier des binaires corrompus)
        MIME=$(file -b --mime-encoding "''$filepath")
        if [ "''$MIME" = "binary" ]; then
          continue
        fi

        FILE_COUNT=$((FILE_COUNT + 1))
        EXT="''${filepath##*.}"

        {
          echo "## Fichier : \`''$filepath\`"
          echo "\`\`\`''$EXT"
          cat "''$filepath"
          echo ""
          echo "\`\`\`"
          echo ""
        } >> "''$TMP_OUTPUT"
      done < <(fd . "''$TARGET_DIR" --type f --hidden "''${FD_EXCLUDE_ARGS[@]}")

      # 3. Copie dans le presse-papier Wayland
      wl-copy < "''$TMP_OUTPUT"
      rm -f "''$TMP_OUTPUT"

      echo -e "📋 \e[32mSuccès ! L'arborescence et ''$FILE_COUNT fichiers ont été copiés dans le presse-papier au format Markdown !\e[0m"
    '';
  };
in {
  environment.systemPackages = [
    copyContext
  ];
}
