{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # <-- 1. Chaotic-Nyx (pour le PC Home)
    chaotic.url = "https://flakehub.com/f/chaotic-cx/nyx/*.tar.gz";

    # <-- 2. MicroVM (pour le PC Work)
    microvm = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    polymc.url = "github:PolyMC/PolyMC";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lazyvim = {
      url = "github:pfassina/lazyvim-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    spotx-nix = {
      url = "github:SpotX-Official/SpotX-Nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    qwerty-fr = {
      url = "github:qwerty-fr/qwerty-fr";
      flake = false;
    };

    mango = {
      url = "github:DreamMaoMao/mango";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lookas = {
      url = "github:rccyx/lookas";
      flake = false;
    };
    asryx = {
      url = "github:rccyx/asryx";
      flake = false;
    };
    thyx = {
      url = "github:rccyx/thyx";
      flake = false;
    };
    helium-flake = {
      url = "github:oxcl/nix-flake-helium-browser";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    nix-index-database,
    helium-flake,
    lazyvim,
    chaotic,
    microvm,
    ...
  } @ inputs: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};

    mkHost = hostPath: homeModule: extraModules:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {inherit inputs;};
        modules =
          [
            hostPath
            nix-index-database.nixosModules.nix-index

            {
              nixpkgs.overlays = [
                inputs.spotx-nix.overlays.default
                inputs.helium-flake.overlays.default
                inputs.polymc.overlay
              ];
            }

            inputs.mango.nixosModules.mango
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "bak";
              home-manager.users.clem = import homeModule;
              home-manager.extraSpecialArgs = {inherit inputs;};
              home-manager.sharedModules = [
                inputs.mango.hmModules.mango
              ];
            }
          ]
          ++ extraModules; # <-- Permet d'ajouter des modules spécifiques par machine
      };
  in {
    packages.${system} = import ./pkgs/osyx {inherit pkgs inputs;};

    checks.${system} = {
      dynamic-palette = pkgs.runCommand "dynamic-palette-check" {nativeBuildInputs = [(pkgs.python3.withPackages (p: [p.jinja2]))];} ''
        mkdir work
        cp -r ${./home/osyx/assets/flavors} work/flavors
        chmod -R u+w work
        cd work/flavors
        python3 generate.py --from-matugen ${./home/osyx/assets/flavors/tests/matugen-fixture.json}
        for f in .config/kitty/osyx.conf .config/gtk-3.0/gtk.css .config/zed/themes/osyx.json \
                 .config/mako/config .config/starship.toml .config/mango/colors.conf .dircolors; do
          test -s "../$f" || { echo "manquant: $f" >&2; exit 1; }
        done
        python3 - <<'EOF'
        import tomllib
        ref = tomllib.load(open("palettes/versailles.toml", "rb"))
        dyn = tomllib.load(open("palettes/dynamic.toml", "rb"))
        a = {s: set(v) for s, v in ref.items()}
        b = {s: set(v) for s, v in dyn.items()}
        assert a == b, (a, b)
        EOF
        grep -q '^background #19120c' ../.config/kitty/osyx.conf
        echo ok > $out
      '';
      themes-dynamic = pkgs.runCommand "themes-dynamic-check" {nativeBuildInputs = [pkgs.imagemagick];} ''
        export HOME=$TMPDIR/home OSYX_NO_RELOAD=1
        mkdir -p "$HOME"
        magick -size 64x64 xc:'#cc5533' "$TMPDIR/img.png"
        t=${self.packages.${system}.themes}/bin/themes
        s=$HOME/.local/state/osyx
        $t from-wallpaper "$TMPDIR/img.png"
        test "$($t current)" = dynamic
        test "$($t mode)" = dynamic
        for l in kitty.conf gtk.css qt6ct.conf zed.json nvim-theme.lua swaylock.conf mako.conf wofi.css tmux.conf starship.toml mango-colors.conf; do
          test -s "$s/$l" || { echo "lien d'état manquant: $l" >&2; exit 1; }
        done
        grep -qE '^background #[0-9a-f]{6}$' "$s/kitty.conf"
        # palette épinglée : le suivi du wallpaper est désactivé
        $t apply sakura
        test "$($t mode)" = fixed
        test "$($t current)" = sakura
        # retour au dynamique sans wallpaper mémorisé : échec propre
        if $t dynamic 2>err; then echo "dynamic sans wallpaper doit échouer" >&2; exit 1; fi
        grep -q wallpaper err
        echo "$TMPDIR/img.png" > "$s/wallpaper"
        $t dynamic
        test "$($t mode)" = dynamic
        # image illisible : échec, thème inchangé
        echo "pas une image" > "$TMPDIR/bad.png"
        before=$($t current)
        if $t from-wallpaper "$TMPDIR/bad.png" 2>/dev/null; then echo "image illisible doit échouer" >&2; exit 1; fi
        test "$($t current)" = "$before"
        echo ok > $out
      '';

      themes-reload-kitty = pkgs.runCommand "themes-reload-kitty-check" {} ''
        export HOME=$TMPDIR/home
        mkdir -p "$HOME" "$TMPDIR/k"
        # sous Nix le processus kitty s'appelle .kitty-wrapped
        printf '#!${pkgs.runtimeShell}\ntrap "touch $TMPDIR/got-usr1" USR1\nwhile true; do sleep 0.1; done\n' > "$TMPDIR/k/.kitty-wrapped"
        chmod +x "$TMPDIR/k/.kitty-wrapped"
        "$TMPDIR/k/.kitty-wrapped" &
        pid=$!
        sleep 0.5
        ${self.packages.${system}.themes}/bin/themes apply sakura
        sleep 0.5
        kill $pid 2>/dev/null || true
        test -e "$TMPDIR/got-usr1"
        echo ok > $out
      '';

      monitors-match-hardware = pkgs.runCommand "monitors-match-hardware-check" {} ''
        cfg=${self.nixosConfigurations.home.config.home-manager.users.clem.xdg.configFile."mango/config.conf".source}
        if grep -q 'HDMI-A-3' "$cfg"; then echo "règle pour un écran inexistant (HDMI-A-3)" >&2; exit 1; fi
        grep -q 'monitor_rule=name:^DP-2$,width:2560,height:1440,refresh:143.998,x:1920,y:0' "$cfg"
        grep -q 'monitor_rule=name:^DP-3$,width:1920,height:1080,refresh:60,x:0,y:0' "$cfg"
        echo ok > $out
      '';

      mango-reload-on-switch = pkgs.runCommand "mango-reload-on-switch-check" {} ''
        test ${
          if self.nixosConfigurations.home.config.home-manager.users.clem.home.activation ? reloadMango
          then "yes"
          else "no"
        } = yes
        echo ok > $out
      '';

      mango-commands-exist = let
        cfg = self.nixosConfigurations.home.config;
        hm = cfg.home-manager.users.clem;
      in
        pkgs.runCommand "mango-commands-exist-check" {} ''
          conf=${hm.xdg.configFile."mango/config.conf".source}
          auto=${hm.xdg.configFile."mango/autostart.sh".source}
          missing=0
          {
            sed -nE 's/^bind[a-z]* *= *[^,]*,[^,]*,spawn(_shell)?,//p' "$conf"
            grep -vE '^(#|$|/nix|command )' "$auto" | sed 's/ *&$//'
          } | awk '{print $1}' | sort -u | while read -r c; do
            test -n "$c" || continue
            if [ -x "${hm.home.path}/bin/$c" ] || [ -x "${cfg.system.path}/bin/$c" ]; then :; else
              echo "commande introuvable: $c" >&2; echo "$c" >> missing.txt
            fi
          done
          test ! -e missing.txt
          echo ok > $out
        '';

      wallpaper-cli = pkgs.runCommand "wallpaper-cli-check" {} ''
        export HOME=$TMPDIR/home OSYX_WALLPAPER_DIRS="$TMPDIR/wp"
        mkdir -p "$HOME" "$TMPDIR/wp" "$TMPDIR/bin"
        touch "$TMPDIR/wp/a.png" "$TMPDIR/wp/b.png"
        printf '#!${pkgs.runtimeShell}\necho "$@" >> "$TMPDIR/awww.log"\n' > "$TMPDIR/bin/awww"
        chmod +x "$TMPDIR/bin/awww"
        export PATH="$TMPDIR/bin:$PATH"
        h=${self.packages.${system}.wallpaper}/bin
        $h/wallpaper set "$TMPDIR/wp/b.png"
        grep -q "img $TMPDIR/wp/b.png" "$TMPDIR/awww.log"
        test "$(cat "$HOME/.local/state/osyx/wallpaper")" = "$TMPDIR/wp/b.png"
        : > "$TMPDIR/awww.log"
        $h/wallpaper restore
        grep -q "img $TMPDIR/wp/b.png" "$TMPDIR/awww.log"
        rm "$HOME/.local/state/osyx/wallpaper"; : > "$TMPDIR/awww.log"
        $h/wallpaper restore
        grep -q "img $TMPDIR/wp/a.png" "$TMPDIR/awww.log"
        if $h/wallpaper set "$TMPDIR/wp/inexistant.png" 2>/dev/null; then echo "set sur fichier absent doit échouer" >&2; exit 1; fi
        # thème dynamique : déclenché seulement si le mode n'est pas épinglé
        printf '#!${pkgs.runtimeShell}\nif [ "$1" = mode ]; then echo "$FAKE_MODE"; else echo "$@" >> "$TMPDIR/themes.log"; fi\n' > "$TMPDIR/bin/themes"
        chmod +x "$TMPDIR/bin/themes"
        FAKE_MODE=dynamic $h/wallpaper set "$TMPDIR/wp/a.png"
        grep -q "from-wallpaper $TMPDIR/wp/a.png" "$TMPDIR/themes.log"
        rm -f "$TMPDIR/themes.log"
        FAKE_MODE=fixed $h/wallpaper set "$TMPDIR/wp/b.png"
        test ! -e "$TMPDIR/themes.log"
        echo ok > $out
      '';
      no-swww = pkgs.runCommand "no-swww-check" {} ''
        if grep -rn swww ${./home} ${./pkgs} ${./modules}; then
          echo "swww a été renommé awww : binaires swww/swww-daemon introuvables" >&2; exit 1
        fi
        test -x ${pkgs.awww}/bin/awww-daemon
        echo ok > $out
      '';

      sddm-x11-greeter = pkgs.runCommand "sddm-x11-greeter-check" {} ''
        test ${
          if
            !self.nixosConfigurations.home.config.services.displayManager.sddm.wayland.enable
            && self.nixosConfigurations.home.config.services.xserver.enable
          then "yes"
          else "no"
        } = yes
        echo ok > $out
      '';

      wlsunset-hours = pkgs.runCommand "wlsunset-hours-check" {} ''
        grep -q -- '-S 05:00 -s 21:00' ${./home/mango/autostart.nix}
        grep -q -- '-S 05:00 -s 21:00' ${./home/osyx/bin.nix}
        echo ok > $out
      '';
      mango-no-bare-fkeys = pkgs.runCommand "mango-no-bare-fkeys-check" {} ''
        cfg=${self.nixosConfigurations.home.config.home-manager.users.clem.xdg.configFile."mango/config.conf".source}
        if grep -qE '^bind[a-z]* *= *NONE,F([0-9]|1[0-2]),' "$cfg"; then
          echo "bare F-key binds steal keys from every app" >&2; exit 1
        fi
        grep -q 'XF86AudioRaiseVolume' "$cfg"
        echo ok > $out
      '';
      desktop-services = pkgs.runCommand "desktop-services-check" {} ''
        test ${
          if self.nixosConfigurations.home.config.services.gnome.gnome-keyring.enable
          then "yes"
          else "no"
        } = yes
        echo ok > $out
      '';
      themes-live-reload = pkgs.runCommand "themes-live-reload-check" {} ''
        s=${self.packages.${system}.themes}/bin/themes
        grep -q 'gtk-theme' $s
        grep -q 'touch -h' $s
        echo ok > $out
      '';

      asryx-bin = pkgs.runCommand "asryx-bin-check" {} ''
        out_text=$(${self.packages.${system}.asryx}/bin/asryx bogus 2>&1 || true)
        echo "$out_text" | grep -q "voice to text"
        echo ok > $out
      '';

      lookas-bin = pkgs.runCommand "lookas-bin-check" {} ''
        b=${self.packages.${system}.lookas}/bin/lookas
        test -x "$b"
        ${pkgs.glibc.bin}/bin/ldd "$b" | grep -q libasound
        echo ok > $out
      '';

      powyx-lock = pkgs.runCommand "powyx-lock-check" {} ''
        export XDG_RUNTIME_DIR=$TMPDIR/run XDG_CONFIG_HOME=$TMPDIR/cfg
        mkdir -p "$XDG_RUNTIME_DIR" "$XDG_CONFIG_HOME/powyx"
        cat > "$XDG_CONFIG_HOME/powyx/powyx.toml" <<'EOF'
        [actions]
        lock = "true"
        suspend = "true"
        reboot = "true"
        shutdown = "true"

        [theme]
        confirm = "#E7BE5B"
        EOF
        sed -i 's/^ *//' "$XDG_CONFIG_HOME/powyx/powyx.toml"
        printf '#!${pkgs.runtimeShell}\necho x >> "$COUNT"\nsleep 2\n' > runner
        chmod +x runner
        export POWYX_QML_RUNNER=$PWD/runner COUNT=$PWD/count
        ${self.packages.${system}.powyx}/bin/powyx &
        sleep 0.7
        ${self.packages.${system}.powyx}/bin/powyx
        wait
        test "$(wc -l < count)" = 1
        echo ok > $out
      '';
      osyx-qml-lint = pkgs.runCommand "osyx-qml-lint" {nativeBuildInputs = [pkgs.qt6.qtdeclarative];} ''
        qmllint $(find ${./home/osyx/assets/powyx/src} -name '*.qml' | sort)
        echo ok > $out
      '';

      osyx-themes = pkgs.runCommand "osyx-themes-check" {} ''
        t=${self.packages.${system}.osyx-themes}
        n=0
        for p in blush gilded kyanite malachite sakura vermilion versailles; do
          test -s "$t/$p/.config/mako/config"
          test -s "$t/$p/.config/mango/colors.conf"
          test -s "$t/$p/.config/tmux/osyx-theme.conf"
          n=$((n+1))
        done
        test "$n" = 7
        grep -q 'focus_color=0xbcaaa4ff' "$t/versailles/.config/mango/colors.conf"
        for p in blush gilded kyanite malachite sakura vermilion versailles; do
          for f in .config/kitty/osyx.conf .config/gtk-3.0/gtk.css .config/gtk-4.0/gtk.css \
                   .config/qt6ct/colors/osyx.conf .config/zed/themes/osyx.json \
                   .config/nvim/osyx-theme.lua .config/swaylock/config; do
            test -s "$t/$p/$f" || { echo "missing $p/$f" >&2; exit 1; }
          done
          ${pkgs.jq}/bin/jq empty "$t/$p/.config/zed/themes/osyx.json"
        done
        grep -q '^background #3e2723' "$t/versailles/.config/kitty/osyx.conf"
        echo ok > $out
      '';
      themes-cli = pkgs.runCommand "themes-cli-check" {} ''
        export HOME=$TMPDIR/home OSYX_NO_RELOAD=1
        mkdir -p "$HOME"
        t=${self.packages.${system}.themes}/bin/themes
        $t apply versailles
        test "$($t current)" = versailles
        if $t apply nope 2>err; then echo "apply nope should fail" >&2; exit 1; fi
        grep -q inconnu err
        test "$($t current)" = versailles
        rm "$HOME/.local/state/osyx/theme.current"
        $t rotate
        $t list | grep -qx "$($t current)"
        test "$($t list | wc -l)" = 7
        $t apply versailles
        # le thème ne doit PAS toucher au fond d'écran de l'utilisateur
        mkdir -p "$TMPDIR/bin"
        printf '#!${pkgs.runtimeShell}\necho "$@" >> "$TMPDIR/awww.log"\n' > "$TMPDIR/bin/awww"
        chmod +x "$TMPDIR/bin/awww"
        PATH="$TMPDIR/bin:$PATH" $t apply sakura
        test ! -e "$TMPDIR/awww.log"
        $t apply versailles
        for l in kitty.conf gtk.css qt6ct.conf zed.json nvim-theme.lua swaylock.conf; do
          test -s "$HOME/.local/state/osyx/$l" || { echo "missing state link $l" >&2; exit 1; }
        done
        echo ok > $out
      '';

      osyx-bin = pkgs.runCommand "osyx-bin-check" {} ''
        p=${self.nixosConfigurations.home.config.home-manager.users.clem.home.path}/bin
        for b in shot-full shot-mac vocaster nightshift clip-menu clip-purge; do
          test -x "$p/$b" || { echo "missing binary: $b" >&2; exit 1; }
        done
        echo ok > $out
      '';

      # La source du fichier est déjà validée par `mango -c … -p` dans le module HM.
      mango-config = pkgs.runCommand "mango-config-check" {} ''
        cfg=${self.nixosConfigurations.home.config.home-manager.users.clem.xdg.configFile."mango/config.conf".source}
        grep -q "killclient" "$cfg"
        touch $out
      '';
    };

    formatter.${system} = pkgs.writeShellScriptBin "nix-fmt" ''
      if [ "$#" -eq 0 ]; then
        exec ${pkgs.alejandra}/bin/alejandra .
      else
        exec ${pkgs.alejandra}/bin/alejandra "$@"
      fi
    '';

    nixosConfigurations = {
      # Machine Home avec Chaotic-Nyx
      home = mkHost ./hosts/home/configuration.nix ./home/home.nix [
        chaotic.nixosModules.default
      ];

      # Machine Work avec MicroVM
      work = mkHost ./hosts/work/configuration.nix ./home/work.nix [
        microvm.nixosModules.host
      ];
    };
  };
}
