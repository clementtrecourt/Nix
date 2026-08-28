# Dans modules/gaming.nix
{ pkgs, ... }:

let
  username = "clem";
  mountPoint = "/home/${username}/DeltaDrive";
in
{
  # 1. Autoriser les montages FUSE pour les utilisateurs non-root
  programs.fuse.userAllowOther = true;

  # 2. Vos options gaming existantes (Steam, Gamemode, etc.)
  hardware.graphics.enable32Bit = true;
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    gamescopeSession.enable = true;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };
  programs.gamescope.enable = true;
  programs.gamemode.enable = true;
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;
  services.flatpak.enable = true;
  programs.corectrl.enable = true;
  hardware.amdgpu.overdrive.enable = true;
  services.udev.packages = [ pkgs.game-devices-udev-rules ];
  boot.kernel.sysctl = {
    "vm.max_map_count" = 1048576;
  };
  hardware.amdgpu.initrd.enable = true;

  # 3. Paquets gaming + rclone + mGBA
  environment.systemPackages = with pkgs; [
    rclone
    fuse3
    mgba                      # Émulateur Game Boy Advance
    heroic
    mangohud
    wineWow64Packages.stable
    stremio-linux-shell
    winetricks
    protontricks
    linux-wallpaperengine
    nvtopPackages.amd
    lm_sensors
  ];

  # 4. Service Systemd automatique de montage Dropbox
  systemd.user.services.rclone-delta-mount = {
    description = "Montage automatique du Dropbox de Delta (rclone)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "default.target" ];

    # Crée le dossier s'il n'existe pas
    preStart = "${pkgs.coreutils}/bin/mkdir -p ${mountPoint}";

    serviceConfig = {
      Type = "simple";
      # Note : Delta sur iOS crée généralement ses sauvegardes dans "Apps/Delta" ou à la racine "Delta"
      ExecStart = ''
        ${pkgs.rclone}/bin/rclone mount dropbox:Apps/Delta ${mountPoint} \
          --config=/home/${username}/.config/rclone/rclone.conf \
          --vfs-cache-mode full \
          --vfs-cache-max-age 24h \
          --dir-cache-time 1m \
          --allow-other
      '';
      ExecStop = "${pkgs.fuse3}/bin/fusermount3 -u ${mountPoint}";
      Restart = "on-failure";
      RestartSec = "10s";
      Environment = [ "PATH=/run/wrappers/bin:$PATH" ];
    };
  };
}
