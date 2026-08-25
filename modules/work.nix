{pkgs, ...}: {
  # Autorise votre utilisateur à lancer des machines virtuelles KVM sans sudo
  users.users.clem.extraGroups = ["kvm"];

  # Outils système pour la virtualisation et l'accès distant
  environment.systemPackages = with pkgs; [
    qemu
    tigervnc
  ];
}
