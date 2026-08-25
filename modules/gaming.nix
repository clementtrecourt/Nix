{pkgs, ...}: {
  hardware.graphics.enable32Bit = true;

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    gamescopeSession.enable = true;
    extraCompatPackages = [pkgs.proton-ge-bin];
  };

  programs.gamescope.enable = true;
  programs.gamemode.enable = true;

  # Bluetooth for controllers
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;
  services.flatpak.enable = true;
  boot.kernelPackages = pkgs.linuxPackages_cachyos;
  programs.corectrl.enable = true;
  hardware.amdgpu.overdrive.enable = true;
  services.udev.packages = [pkgs.game-devices-udev-rules];
  programs.appimage = {
    enable = true;
    binfmt = true;
  };
  boot.kernel.sysctl = {
    # Nécessaire pour Steam/Proton, Star Citizen et les gros jeux (évite les crashs mémoire)
    "vm.max_map_count" = 1048576;
  };
  hardware.amdgpu.initrd.enable = true;
  environment.systemPackages = with pkgs; [
    heroic
    mangohud
    wineWow64Packages.stable
    stremio-linux-shell
    winetricks
    protontricks
    ludusavi
    linux-wallpaperengine
    nvtopPackages.amd # GPU process monitor (like btop, but for GPU)
    lm_sensors # Command-line tool 'sensors' to check temperatures
  ];
}
