{ pkgs, ... }:
{
  hardware.graphics.enable32Bit = true;

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    gamescopeSession.enable = true;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };

  programs.gamescope.enable = true;
  programs.gamemode.enable = true;

  # Bluetooth for controllers
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  programs.corectrl.enable = true;
  hardware.amdgpu.overdrive.enable = true;
  services.ananicy = {
    enable = true;
    package = pkgs.ananicy-cpp;
    rulesVR = with pkgs; [
      ananicy-rules-ksysguard
    ];
  };
  services.udev.packages = [ pkgs.game-devices-udev-rules ];
  boot.kernel.sysctl = {
    # Nécessaire pour Steam/Proton, Star Citizen et les gros jeux (évite les crashs mémoire)
    "vm.max_map_count" = 2147483642;

    # Réduit l'utilisation agressive du swap pour privilégier la RAM physique (plus rapide)
    "vm.swappiness" = 10;

    # Augmente la limite de fichiers ouverts en même temps
    "fs.file-max" = 2097152;
  };
  hardware.amdgpu.initrd.enable = true;
  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";
  environment.systemPackages = with pkgs; [
    heroic mangohud
    wineWow64Packages.stable
    winetricks protontricks
    ludusavi
    nvtopPackages.amd  # GPU process monitor (like btop, but for GPU)
    lm_sensors         # Command-line tool 'sensors' to check temperatures
  ];
}
