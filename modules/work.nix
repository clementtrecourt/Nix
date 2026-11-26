{pkgs, ...}: let
  # Le plugin Systancia Gate (téléchargé dans ~/.IPdiva) lance les ressources SSH via
  # "/usr/bin/x-terminal-emulator -e <commande>" (alternative Debian) : on l'émule avec kitty.
  # Les arguments reçus sont tracés dans /tmp/x-terminal-emulator.log pour le débogage.
  xTerminalEmulator = pkgs.writeShellScript "x-terminal-emulator" ''
    printf '%s\n' "$(date '+%F %T') $*" >> /tmp/x-terminal-emulator.log
    [ "$1" = "-e" ] && shift
    # Commande passée en une seule chaîne ("ssh -p 1234 user@127.0.0.1") ou en arguments séparés
    [ $# -eq 1 ] && set -- sh -c "$1"
    # En cas d'échec (ex. clé SSH refusée), la fenêtre reste ouverte pour lire l'erreur
    exec ${pkgs.kitty}/bin/kitty sh -c '
      "$@"; rc=$?
      if [ "$rc" -ne 0 ]; then printf "\n[code %s] Entrée pour fermer… " "$rc"; read -r _; fi
    ' sh "$@"
  '';
in {
  # Autorise votre utilisateur à lancer des machines virtuelles KVM sans sudo
  users.users.clem.extraGroups = ["kvm docker"];

  # GateClient (wxWidgets 3.0) force la langue "English" -> en_GB, sinon popup d'erreur au démarrage
  i18n.extraLocales = ["en_GB.UTF-8/UTF-8" "fr_FR.UTF-8/UTF-8"];

  # Chemins Debian codés en dur dans le plugin Systancia Gate
  systemd.tmpfiles.rules = [
    "L+ /usr/bin/x-terminal-emulator - - - - ${xTerminalEmulator}"
    "L+ /usr/bin/zenity - - - - ${pkgs.zenity}/bin/zenity"
  ];

  virtualisation.docker.enable = true;
  # Outils système pour la virtualisation et l'accès distant
  networking.firewall.allowedTCPPorts = [8000];
  environment.systemPackages = with pkgs; [
    qemu
    anydesk
    oath-toolkit
    ansible
    python3Packages.pip
    tigervnc
    teams-for-linux
    # Systancia Gate (portail d'accès distant) : cf. pkgs/gateclient/default.nix
    (callPackage ../pkgs/gateclient {})
  ];
}
