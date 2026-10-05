{pkgs, ...}: {
  # Autorise votre utilisateur à lancer des machines virtuelles KVM sans sudo
  users.users.clem.extraGroups = ["kvm docker"];

  virtualisation.docker.enable = true;
  # Outils système pour la virtualisation et l'accès distant
  networking.firewall.allowedTCPPorts = [8000];
  networking.extraHosts = ''
    10.217.30.2 diffmed-sfn.cpa-sante.priv
    10.217.30.2 diffmed-sfn-stats.cpa-sante.priv
  '';
  environment.systemPackages = with pkgs; [
    qemu
    anydesk
    oath-toolkit
    ansible
    python3Packages.pip
    tigervnc
    teams-for-linux
  ];
}
