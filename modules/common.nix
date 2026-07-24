{ config, lib, pkgs, inputs, ... }:
{
  imports = [
      ./zen.nix
    ];
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    max-jobs = "auto";
    cores = 0;
    builders-use-substitutes = true;
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
  programs.ssh.startAgent = true;
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.timeout = 1;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages;
  boot.initrd.compressor = "zstd";
  services.nscd.enable = true;

  nixpkgs.config.allowUnfree = true;

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



  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;

  programs.fish.enable = true;

  users.users.clem = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
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
    capitaine-cursors ibm-plex
    unrar unzip tldr spotify zip
  ];
}
