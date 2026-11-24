# Écran de connexion : greeter DMS (greetd + niri + Quickshell), à l'identique
# de la session : mêmes couleurs, même fond d'écran, mêmes polices, mêmes écrans.
#
# Fonctionnement :
#   - au démarrage de greetd, le module upstream copie dans /var/lib/dms-greeter
#     les réglages DMS de clem : settings.json (thème perso, polices), session.json
#     (fond d'écran, y compris par écran), dms-colors.json et le fichier de thème ;
#   - dms-greeter-sync refait cette copie dès que ces fichiers changent, donc un
#     nouveau fond d'écran ou thème est repris sans redémarrer ;
#   - /etc/greetd/niri_overrides.kdl donne au niri du greeter les mêmes écrans
#     que la session (my.display, modules/display.nix).
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  user = "clem";
  home = config.users.users.${user}.home;

  # Fichiers suivis : tout changement relance la copie vers le greeter
  watched = [
    "${home}/.config/dms/settings.json"
    # settings.json est un lien vers le dépôt (home/dms.nix) : DMS remplace la
    # cible de façon atomique, il faut donc aussi surveiller le vrai fichier
    "${home}/Nix/home/dms/settings.json"
    "${home}/.local/state/dms/session.json"
    "${home}/.cache/dms/dms-colors.json"
  ];
in {
  programs.dms-greeter = {
    enable = true;
    compositor.name = "niri";
    configHome = home;
    # Paquet du flake du greeter : son nixpkgs a la version de Go requise
    # (même raison que pour DMS, cf. home/dms.nix)
    package = inputs.dms-greeter.packages.${pkgs.stdenv.hostPlatform.system}.dms-greeter;
  };

  # Pas d'ouverture de session automatique (pas d'initial_session ni de
  # services.displayManager.autoLogin) : le greeter s'affiche à chaque démarrage.

  # Mêmes écrans et même curseur que la session
  environment.etc."greetd/niri_overrides.kdl".text = ''
    ${config.my.display.niriOutputsKdl}
    cursor {
        xcursor-theme "capitaine-cursors"
        xcursor-size 24
    }
  '';

  # Resynchronise le greeter quand le thème / le fond d'écran DMS change.
  # On réutilise exactement le script de copie du module upstream (preStart de
  # greetd) : on ne peut pas redémarrer greetd, ça fermerait la session en cours.
  systemd.services.dms-greeter-sync = {
    description = "Copie le thème et le fond d'écran DMS vers le greeter";
    startLimitIntervalSec = 0;
    serviceConfig.Type = "oneshot";
    script = config.systemd.services.greetd.preStart;
  };
  systemd.paths.dms-greeter-sync = {
    wantedBy = ["multi-user.target"];
    pathConfig = {
      PathChanged = watched;
      # DMS réécrit parfois ces fichiers plusieurs fois d'affilée
      TriggerLimitIntervalSec = "10s";
      TriggerLimitBurst = 20;
    };
  };
}
