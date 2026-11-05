{
  config,
  pkgs,
  ...
}: {
  imports = [./common.nix];

  # Écrans propres au PC work
  osyx.monitors = [
    {
      match = { manufacturer = "SAM"; product = "0d21"; };
      position = "left";
    }
    {
      match = { manufacturer = "PHL"; product = "c085"; };
      position = "right";
    }
  ];


  # Disposition des écrans propre à work
  wayland.windowManager.mango.extraConfig = ''
    monitor_rule=name:^DP-3$,width:1920,height:1080,refresh:60,x:0,y:0,scale:1
    monitor_rule=name:^HDMI-A-3$,width:1920,height:1080,refresh:60,x:1920,y:0,scale:1,primary:1
  '';

  # Overrides spécifiques au PC de travail, si besoin :
  # programs.git.settings.user.email = "clement@axeesante.com";

  home.packages = with pkgs; [
    tigervnc
    teams-for-linux
    nettools
    sshuttle
    easyeffects
  ];
}
