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
      # Apps (tout sur SUPER ; seul ALT+Tab reste sur ALT)
      "SUPER,t,spawn,${apps.term}"
      "SUPER,A,spawn,${apps.menu}"
      "SUPER,e,spawn,${apps.editor}"
      "SUPER+ALT,f,spawn,${apps.files}"
      "SUPER+ALT,s,spawn,spotify"
      "SUPER,g,spawn,${apps.browser}"
      "SUPER,l,spawn,${apps.lock}"
      "SUPER+SHIFT,l,spawn,swaylock"
      "SUPER,m,spawn,${apps.control}"
      "SUPER+SHIFT,p,spawn,${apps.power}"
      "SUPER,r,spawn_shell,themes rotate"
      "SUPER+ALT,r,spawn,themes dynamic"
      "SUPER+SHIFT,c,spawn,${apps.browser} --new-window https://calendar.google.com"
      "SUPER+SHIFT,y,spawn,${apps.browser} --new-window https://youtube.com"
      "SUPER+SHIFT,u,spawn,${apps.browser} --new-window https://soundcloud.com"

      # Fenêtres
      "SUPER,q,killclient"
      "SUPER,f,togglemaximizescreen"
      "SUPER+SHIFT,f,togglefloating"
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
      "SUPER,TAB,toggleoverview"
      "SUPER,d,toggle_special_tag"
      "SUPER+CTRL,Left,viewtoleft"
      "SUPER+CTRL,Right,viewtoright"

      # Captures et divers
      "NONE,XF86Launch2,spawn,shot-full"
      "NONE,Print,spawn,shot-mac"
      "SUPER,Print,spawn,shot-full"
      "SUPER,p,spawn_shell,grim -g \"$(slurp)\" - | swappy -f -"
      "SUPER+SHIFT,b,spawn,nightshift"
      "SUPER,Escape,spawn_shell,notify-send -t 4000 -h string:x-canonical-private-synchronous:clock \"$(date +%H:%M)\" \"$(date '+%A %d %B')\""
      "SUPER+SHIFT,w,spawn,wallpaper pick"
      "SUPER+ALT,w,spawn,wallpaper pick-classic"
      "SUPER+SHIFT,r,reload_config"
      "SUPER,v,spawn,vicinae deeplink vicinae://launch/clipboard/history"
      "SUPER,i,spawn,vicinae deeplink vicinae://launch/core/search-emojis"
      "SUPER,slash,spawn,vicinae deeplink vicinae://launch/files/search"
      "SUPER+SHIFT,x,spawn,vicinae deeplink vicinae://launch/clipboard/clear-history"
    ]
    ++ tagBinds
    ++ lib.optional (apps.asryx != null) "SUPER,w,spawn,${apps.asryx}";

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
