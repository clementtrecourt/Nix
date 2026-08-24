{ config, lib, pkgs, inputs, ... }:
{
  imports = [
      ./firefox.nix
    ];
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    max-jobs = "auto";
    cores = 0;
    warn-dirty = false;
    builders-use-substitutes = true;
  };
  hardware.graphics.enable32Bit = true;
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
        languages   = [ "eng" ];
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
  services.greetd = {
    enable = true;
    settings = {
      initial_session = { command = "mango"; user = "clem"; };
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --cmd mango";
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
  environment.variables = { EDITOR = "nvim"; VISUAL = "nvim"; };
  networking.modemmanager.enable = false;
  time.timeZone = "Europe/Paris";
  services.timesyncd.enable = true;
  networking.networkmanager.enable = true;
  systemd.services.NetworkManager-wait-online.enable = false;

  hardware.graphics.enable = true; # enable32Bit géré à part si gaming

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
  fonts = {
      enableDefaultPackages = true;
      packages = with pkgs; [
        ibm-plex
        (google-fonts.override { fonts = [ "Readex Pro" ]; })
        nerd-fonts.im-writing
        nerd-fonts.jetbrains-mono
        nerd-fonts.symbols-only
      ];
      fontconfig = {
        defaultFonts = {
          monospace = [ "IBM Plex Mono" ];
          sansSerif = [ "Readex Pro" ];
          serif = [ "IBM Plex Serif" ];
        };
        localConf = ''
          <?xml version="1.0"?>
          <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
          <fontconfig>
            <!-- Alias generic sans-serif -->
            <match target="pattern">
              <test qual="any" name="family"><string>sans-serif</string></test>
              <edit name="family" mode="assign" binding="strong">
                <string>Readex Pro</string>
              </edit>
            </match>

            <!-- Force specific common font substitutions -->
            <match target="pattern">
              <test qual="any" name="family"><string>Arial</string></test>
              <edit name="family" mode="assign" binding="strong">
                <string>Readex Pro</string>
              </edit>
            </match>

            <match target="pattern">
              <test qual="any" name="family"><string>Helvetica</string></test>
              <edit name="family" mode="assign" binding="strong">
                <string>Readex Pro</string>
              </edit>
            </match>

            <match target="pattern">
              <test qual="any" name="family"><string>Roboto</string></test>
              <edit name="family" mode="assign" binding="strong">
                <string>Readex Pro</string>
              </edit>
            </match>

            <match target="pattern">
              <test qual="any" name="family"><string>Segoe UI</string></test>
              <edit name="family" mode="assign" binding="strong">
                <string>Readex Pro</string>
              </edit>
            </match>

            <match target="pattern">
              <test qual="any" name="family"><string>Verdana</string></test>
              <edit name="family" mode="assign" binding="strong">
                <string>Readex Pro</string>
              </edit>
            </match>

            <match target="pattern">
              <test qual="any" name="family"><string>Calibri</string></test>
              <edit name="family" mode="assign" binding="strong">
                <string>Readex Pro</string>
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
    # allowedTCPPorts = [ 8080 ];
  };
  users.users.clem = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.fish;
    hashedPassword = "$y$j9T$VC7rDnqaqcmhe5kp3O.KS0$bPN8wmEwcGLgl0wTF7ouClBPYh3ixUTTMz0aZhWvfB4";
  };

  programs.mango.enable = true;
  programs.nix-ld.enable = true;
  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 4d --keep 3";
    flake = "/home/clem/Nix";
  };
  environment.systemPackages = with pkgs; [
    kitty xwayland-satellite tmux starship fish zoxide direnv fzf
    bat eza ripgrep fd btop jq tree
    git lazygit
    neovim vim zed-editor
    wl-clipboard nemo waybar
    capitaine-cursors
    gcc
    gnumake
    unrar unzip tldr spotify zip yazi vlc python3
    brave
    stremio-linux-shell
  ];
}
