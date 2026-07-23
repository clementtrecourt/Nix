{ config, lib, pkgs, inputs, ... }:
{
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
  services.xserver.xkb = {
      layout = "qwerty-fr";
      variant = "";
      extraLayouts.qwerty-fr = {
        description = "US keyboard with french symbols - AltGr combination";
        languages   = [ "eng" ];
        symbolsFile = "${inputs.qwerty-fr}/linux/us_qwerty-fr";
      };
  };
  virtualisation.docker.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  nixpkgs.config.allowUnfree = true;
  programs.mango.enable = true;

  services.greetd = {
    enable = true;
    settings = {
      initial_session = { command = "start-hyprland"; user = "clem"; };
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --cmd start-hyprland";
        user = "greeter";
      };
    };
  };

  environment.variables = { EDITOR = "nvim"; VISUAL = "nvim"; };

  time.timeZone = "Europe/Paris";
  services.timesyncd.enable = true;
  services.flatpak.enable = true;
  networking.networkmanager.enable = true;
  services.xserver.enable = true;

  hardware.graphics.enable = true; # enable32Bit géré à part si gaming

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;

  programs.fish.enable = true;

  users.users.clem = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    shell = pkgs.fish;
    hashedPassword = "$y$j9T$VC7rDnqaqcmhe5kp3O.KS0$bPN8wmEwcGLgl0wTF7ouClBPYh3ixUTTMz0aZhWvfB4";
  };

  programs.firefox.enable = true;

  environment.systemPackages = with pkgs; [
    kitty tmux starship fish zoxide direnv fzf
    bat eza ripgrep fd btop jq
    git lazygit
    neovim vim zed-editor
    wl-clipboard nemo waybar
    inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
    vicinae
    capitaine-cursors ibm-plex
    unrar unzip tldr spotify
  ];
}
