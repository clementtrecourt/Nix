{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ./zen-browser.nix
    scripts/organizer.nix
    scripts/auto-cleaner.nix
    scripts/copy-context.nix
  ];

  # ============================================
  # ============================================

  # ============================================
  # 2. Configuration Nix & Caches
  # ============================================
  virtualisation.docker.enable = true;
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    auto-optimise-store = true;
    max-jobs = "auto";
    cores = 0;
    warn-dirty = false;
    builders-use-substitutes = true;

    # Caches binaires
    substituters = [
      "https://cache.nixos.org"
      "http://192.168.1.10:8081/main-cache"
    ];

    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "main-cache:sgv8zNRoeNIWhI18L7eyR7n/qHYA3HMqQq8mannz5kQ="
    ];
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  programs.nix-index-database.comma.enable = true;
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5; # Déclenche si moins de 5% de RAM disponible
    enableNotifications = true; # Envoie une notification si un processus est tué
  };
  services.tailscale = {
    enable = true;
  };
  services.fstrim = {
    enable = true;
    interval = "weekly";
  };
  boot.initrd.systemd.enable = true;
  services.xserver.xkb = {
    layout = "qwerty-fr";
    variant = "";
    extraLayouts.qwerty-fr = {
      description = "US keyboard with french symbols - AltGr combination";
      languages = ["eng"];
      symbolsFile = "${inputs.qwerty-fr}/linux/us_qwerty-fr";
    };
  };
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.compressor = "zstd";
  services.nscd.enable = true;
  services.udisks2.enable = true;
  services.gvfs.enable = true;
  nixpkgs.config.allowUnfree = true;
  zramSwap = {
    enable = true;
    memoryPercent = 50; # Utilise jusqu'à 50% de la RAM comme swap compressé
  };

  # Session : Hyprland (bureau macOS Tahoe) via start-hyprland (lanceur/watchdog
  # officiel depuis Hyprland 0.53), depuis un shell de connexion fish.
  services.greetd = let
    session = "${pkgs.fish}/bin/fish --login -c ${config.programs.hyprland.package}/bin/start-hyprland";
  in {
    enable = true;
    settings = {
      initial_session = {
        command = session;
        user = "clem";
      };
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd '${session}'";
        user = "greeter";
      };
    };
  };
  boot.kernel.sysctl = {
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
  };
  programs.dconf.enable = true;
  systemd.coredump.enable = false;
  environment.variables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };
  networking.modemmanager.enable = false;
  time.timeZone = "Europe/Paris";
  services.timesyncd.enable = true;
  networking.networkmanager.enable = true;
  systemd.services.NetworkManager-wait-online.enable = false;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      ibm-plex
      inter # police d'interface macOS (SF Pro n'est pas redistribuable)
      (google-fonts.override {fonts = ["Readex Pro"];})
      nerd-fonts.im-writing
      nerd-fonts.jetbrains-mono
      nerd-fonts.symbols-only
      nerd-fonts.blex-mono
    ];
    fontconfig = {
      defaultFonts = {
        monospace = ["IBM Plex Mono"];
        sansSerif = ["Inter"];
        serif = ["IBM Plex Serif"];
      };
      # Interface façon macOS : sans-serif, polices Apple/web système et polices
      # courantes -> Inter (les monospaces sont conservées)
      localConf = ''
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
        <fontconfig>
          <match target="pattern">
            <test qual="any" name="family"><string>sans-serif</string></test>
            <edit name="family" mode="assign" binding="strong">
              <string>Inter</string>
            </edit>
          </match>

          <match target="pattern">
            <test qual="any" name="family"><string>Arial</string></test>
            <edit name="family" mode="assign" binding="strong">
              <string>Inter</string>
            </edit>
          </match>

          <match target="pattern">
            <test qual="any" name="family"><string>Helvetica</string></test>
            <edit name="family" mode="assign" binding="strong">
              <string>Inter</string>
            </edit>
          </match>

          <match target="pattern">
            <test qual="any" name="family"><string>Helvetica Neue</string></test>
            <edit name="family" mode="assign" binding="strong">
              <string>Inter</string>
            </edit>
          </match>

          <match target="pattern">
            <test qual="any" name="family"><string>Roboto</string></test>
            <edit name="family" mode="assign" binding="strong">
              <string>Inter</string>
            </edit>
          </match>

          <match target="pattern">
            <test qual="any" name="family"><string>Segoe UI</string></test>
            <edit name="family" mode="assign" binding="strong">
              <string>Inter</string>
            </edit>
          </match>

          <match target="pattern">
            <test qual="any" name="family"><string>Verdana</string></test>
            <edit name="family" mode="assign" binding="strong">
              <string>Inter</string>
            </edit>
          </match>

          <match target="pattern">
            <test qual="any" name="family"><string>Calibri</string></test>
            <edit name="family" mode="assign" binding="strong">
              <string>Inter</string>
            </edit>
          </match>

          <match target="pattern">
            <test qual="any" name="family"><string>SF Pro</string></test>
            <edit name="family" mode="assign" binding="strong">
              <string>Inter</string>
            </edit>
          </match>

          <match target="pattern">
            <test qual="any" name="family"><string>SF Pro Text</string></test>
            <edit name="family" mode="assign" binding="strong">
              <string>Inter</string>
            </edit>
          </match>

          <match target="pattern">
            <test qual="any" name="family"><string>SF Pro Display</string></test>
            <edit name="family" mode="assign" binding="strong">
              <string>Inter</string>
            </edit>
          </match>

          <match target="pattern">
            <test qual="any" name="family"><string>.AppleSystemUIFont</string></test>
            <edit name="family" mode="assign" binding="strong">
              <string>Inter</string>
            </edit>
          </match>

          <match target="pattern">
            <test qual="any" name="family"><string>-apple-system</string></test>
            <edit name="family" mode="assign" binding="strong">
              <string>Inter</string>
            </edit>
          </match>

          <match target="pattern">
            <test qual="any" name="family"><string>BlinkMacSystemFont</string></test>
            <edit name="family" mode="assign" binding="strong">
              <string>Inter</string>
            </edit>
          </match>

          <match target="pattern">
            <test qual="any" name="family"><string>system-ui</string></test>
            <edit name="family" mode="assign" binding="strong">
              <string>Inter</string>
            </edit>
          </match>

          <!-- SF Mono -> JetBrains Mono -->
          <match target="pattern">
            <test qual="any" name="family"><string>SF Mono</string></test>
            <edit name="family" mode="assign" binding="strong">
              <string>JetBrains Mono</string>
            </edit>
          </match>
        </fontconfig>
      '';
    };
  };

  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;

  programs.fish.enable = true;
  networking.firewall = {
    enable = true;
    allowPing = true;
    # Add specific ports here if needed later (e.g. 8080, 22)
    allowedTCPPorts = [8096];
  };
  users.users.clem = {
    isNormalUser = true;
    extraGroups = ["wheel" "corectrl"];
    shell = pkgs.fish;
  };

  # Hyprland (config utilisateur : home/macos/hyprland.nix) + portails
  programs.hyprland = {
    enable = true;
    withUWSM = false;
    xwayland.enable = true;
  };
  xdg.portal = {
    enable = true;
    extraPortals = [pkgs.xdg-desktop-portal-gtk];
    config.hyprland.default = ["hyprland" "gtk"];
  };
  programs.nix-ld.enable = true;
  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 4d --keep 3";
    flake = "/home/clem/Nix";
  };
  environment.systemPackages = with pkgs; [
    xwayland-satellite
    fzf
    ripgrep
    fd
    btop
    jq
    tree
    neovim
    vim
    wl-clipboard
    nemo
    gcc
    gnumake
    unrar
    unzip
    tldr
    spotify-spotx
    zip
    python3
    brave
    attic-client
    (callPackage ./waveflow.nix {})
    inputs.helium-flake.packages.${pkgs.stdenv.hostPlatform.system}.default
    mpvpaper
  ];
}
