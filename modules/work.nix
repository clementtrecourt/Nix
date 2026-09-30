{pkgs, ...}: {
  # Autorise votre utilisateur à lancer des machines virtuelles KVM sans sudo
  users.users.clem.extraGroups = ["kvm docker"];

  virtualisation.docker.enable = true;
  # Outils système pour la virtualisation et l'accès distant
  networking.firewall.allowedTCPPorts = [8000];
  environment.systemPackages = with pkgs; [
    qemu
    anydesk
    python3Packages.pip
    tigervnc
    teams-for-linux
  ];
}
