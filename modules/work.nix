{pkgs, ...}: {
  # Autorise votre utilisateur à lancer des machines virtuelles KVM sans sudo
  users.users.clem.extraGroups = ["kvm docker"];

  virtualisation.docker.enable = true;
  # Outils système pour la virtualisation et l'accès distant
  networking.firewall.allowedTCPPorts = [8000];
  programs.gpu-screen-recorder.enable = true;
  hardware.graphics.enable = true;
  environment.systemPackages = with pkgs; [
    qemu
    anydesk
    oath-toolkit
    ansible
    python3Packages.pip
    tigervnc
    teams-for-linux
    wf-recorder
  ];
}
