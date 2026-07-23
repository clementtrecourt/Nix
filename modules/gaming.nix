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

  programs.corectrl.enable = true;
  hardware.amdgpu.overdrive.enable = true; # ⚠️ AMD-only, à retirer si work = Intel/Nvidia

  services.udev.packages = [ pkgs.game-devices-udev-rules ];

  environment.systemPackages = with pkgs; [
    heroic mangohud
    wineWow64Packages.stable
    winetricks protontricks
    linux-wallpaperengine
  ];
}