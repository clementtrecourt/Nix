{
  lib,
  apps,
}: let
  inherit (lib) range;
  n = toString;

  tagBinds = lib.concatMap (i: [
    "SUPER,${n i},view,${n i}"
    "SUPER+SHIFT,${n i},tag,${n i}"
  ]) (range 1 9);

  hw = key: cmd: "NONE,${key},spawn,${cmd}";
in {
  bind =
    [
      # Apps (schéma ALT d'osyx)
      "ALT,Return,spawn,${apps.term}"
      "ALT,k,spawn,${apps.term}"
      "ALT,q,spawn,${apps.term}"
      "SUPER,space,spawn,${apps.menu}"
      "ALT,e,spawn,${apps.editor}"
      "SUPER+ALT,f,spawn,${apps.files}"
      "SUPER+ALT,s,spawn,spotify"
      "ALT,g,spawn,${apps.browser}"
      "ALT,l,spawn,${apps.lock}"
      "ALT,m,spawn,${apps.control}"
      "ALT,p,spawn,${apps.power}"
      "ALT,v,spawn,vocaster"
      "ALT,r,spawn_shell,themes rotate"
      "SUPER+ALT,r,spawn,themes dynamic"
      "ALT+SHIFT,c,spawn,${apps.browser} --new-window https://calendar.google.com"
      "ALT+SHIFT,y,spawn,${apps.browser} --new-window https://youtube.com"
      "ALT+SHIFT,s,spawn,${apps.browser} --new-window https://soundcloud.com"

      # Fenêtres
      "SUPER,q,killclient"
      "ALT,F4,killclient"
      "SUPER,f,togglemaximizescreen"
      "SUPER,v,togglefloating"
      "SUPER,s,switch_layout"
      "SUPER,Left,focusdir,left"
      "SUPER,Right,focusdir,right"
      "SUPER,Up,focusdir,up"
      "SUPER,Down,focusdir,down"
      "SUPER+SHIFT,Left,exchange_client,left"
      "SUPER+SHIFT,Right,exchange_client,right"
      "SUPER+SHIFT,Up,exchange_client,up"
      "SUPER+SHIFT,Down,exchange_client,down"
      "ALT,Tab,focusstack,next"
      "ALT+SHIFT,Tab,focusstack,prev"

      # Tags
      "SUPER,0,toggleoverview"
      "CTRL+ALT,Left,viewtoleft"
      "CTRL+ALT,Right,viewtoright"

      # Captures et divers
      "NONE,XF86Launch2,spawn,shot-full"
      "NONE,Print,spawn,shot-mac"
      "SUPER,Print,spawn,shot-full"
      "SUPER+SHIFT,s,spawn_shell,grim -g \"$(slurp)\" - | swappy -f -"
      "SUPER+SHIFT,b,spawn,nightshift"
      "SUPER+SHIFT,w,spawn,wallpaper pick"
      "SUPER+SHIFT,r,reload_config"
      "SUPER,Escape,spawn,systemctl poweroff"
      "SUPER,x,spawn,clip-menu"
      "SUPER+SHIFT,x,spawn,clip-purge"
    ]
    ++ tagBinds
    ++ lib.optional (apps.asryx != null) "ALT,w,spawn,${apps.asryx}";

  bindl = [
    (hw "XF86AudioMute" "pamixer -t")
    (hw "XF86AudioLowerVolume" "pamixer -d 5")
    (hw "XF86AudioRaiseVolume" "pamixer -i 5")
    (hw "XF86AudioMicMute" "pamixer --default-source -t")
    (hw "XF86MonBrightnessDown" "brightnessctl set 5%-")
    (hw "XF86MonBrightnessUp" "brightnessctl set +5%")
  ];

  mousebind = [
    "SUPER,btn_left,moveresize,curmove"
    "SUPER,btn_right,moveresize,curresize"
  ];
}
