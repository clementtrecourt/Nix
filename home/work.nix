{
  config,
  pkgs,
  ...
}: {
  imports = [./common.nix];

  # Overrides spécifiques au PC de travail, si besoin :
  # programs.git.settings.user.email = "clement@axeesante.com";

  home.packages = with pkgs; [
    tigervnc
    teams-for-linux
    nettools
    sshuttle
    easyeffects
    heroic
  ];

  # Les liens ipdiva:// du portail Systancia Gate ouvrent GateClient (modules/work.nix)
  xdg.mimeApps.defaultApplications."x-scheme-handler/ipdiva" = ["gateclient.desktop"];
}
