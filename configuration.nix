
{ config, lib, pkgs, inputs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      ./zen.nix
    ];
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    extra-substituters = [ "https://noctalia.cachix.org" ];
    extra-trusted-public-keys = [ "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4=" ];
    auto-optimise-store = true;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
  virtualisation.docker.enable = true;
  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  nixpkgs.config.allowUnfree = true;
  # programs.skwd-wall.enable = true; # disabled: skwd-daemon build hits a rustc SIGSEGV in today's nixpkgs-unstable
  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;
  programs.mango.enable = true;

  services.greetd = {
    enable = true;

    settings = {
      initial_session = {
        command = "mango";
        user = "clem";
      };

      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --cmd mango";
        user = "greeter";
      };
    };
  };

  environment.variables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  networking.hostName = "nixos"; # Define your hostname.
  time.timeZone = "Europe/Paris";
  services.timesyncd.enable = true;
  services.flatpak.enable = true;

  networking.networkmanager.enable = true;

  services.xserver.enable = true;

  # GPU (AMD) — drivers 32-bit pour les jeux
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Steam avec Proton et Gamescope
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    gamescopeSession.enable = true;
    # Proton-GE : meilleure compatibilité que le Proton officiel
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };
  programs.gamescope.enable = true;


  # Optimisation performances gaming
  programs.gamemode.enable = true;

  # Overclocking / monitoring GPU AMD
  programs.corectrl.enable = true;
  hardware.amdgpu.overdrive.enable = true;

  # Règles udev pour les contrôleurs (PS4/PS5/Xbox/Switch)
  services.udev.packages = [ pkgs.game-devices-udev-rules ];

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  # Requis par Noctalia (wifi/bluetooth/power-profile/battery)
  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;

  # Fish shell
  programs.fish.enable = true;


  users.users.clem = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    shell = pkgs.fish;
  };

  programs.firefox.enable = true;

  environment.systemPackages = with pkgs; [
    # Terminal & shell tools
    kitty
    tmux
    starship
    fish
    zoxide
    direnv
    fzf
    # Meilleurs alternatives CLI
    bat          # cat avec coloration
    eza          # ls amélioré (aussi en user pkg, ici pour root)
    ripgrep      # grep rapide
    fd           # find rapide
    btop         # htop moderne
    jq           # JSON en CLI
    # Git
    git
    lazygit
    # Éditeurs
    neovim
    vim
    zed-editor
    # Wayland / Desktop
    wl-clipboard # copier-coller Wayland (wl-copy / wl-paste)
    nemo         # gestionnaire de fichiers
    waybar
    # Gaming
    heroic
    mangohud
    wineWow64Packages.stable     # 32+64 bit
    winetricks
    protontricks
    # Système
    inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
    vicinae
    claude-code
    # Fonts & thème
    capitaine-cursors
    ibm-plex
    # Utilitaires
    unrar
    unzip
    tldr
    spotify
    linux-wallpaperengine
  ];
  system.stateVersion = "26.05"; # Did you read the comment?
}

