{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  xdg.configFile."xkb/symbols/us_qwerty-fr".source = "${inputs.qwerty-fr}/linux/us_qwerty-fr";

  xdg.configFile."mango/autostart.sh" = {
    executable = true;
    text = ''
      noctalia &
      zen &
      kitty &
    '';
  };

  xdg.configFile."mango/config.conf".text = ''
    # Autostart
    exec-once = ~/.config/mango/autostart.sh

    # Environment variables
    env = QT_QPA_PLATFORMTHEME,qt6ct
    env = QT5_QPA_PLATFORMTHEME,qt5ct
    env = XCURSOR_THEME,macos-tahoe-cursor
    env = XCURSOR_SIZE,24
    env = XDG_CURRENT_DESKTOP,mango
    env = XDG_SESSION_TYPE,wayland
    env = MOZ_ENABLE_WAYLAND,1
    env = ELECTRON_OZONE_PLATFORM_HINT,auto
    env = XDG_DATA_DIRS,${config.home.homeDirectory}/.local/share:${config.home.homeDirectory}/.nix-profile/share:/etc/profiles/per-user/${config.home.username}/share:/run/current-system/sw/share

    # Visual Effects
    blur = 1
    blur_layer = 1
    blur_optimized = 0
    blur_params_num_passes = 3
    blur_params_radius = 2
    blur_params_noise = 0
    blur_params_brightness = 1
    blur_params_contrast = 1
    blur_params_saturation = 1.2

    shadows = 1
    layer_shadows = 0
    shadow_only_floating = 1
    shadows_size = 10
    shadows_blur = 15
    shadows_position_x = 0
    shadows_position_y = 0

    border_radius = 10
    no_radius_when_single = 0
    focused_opacity = 1.0
    unfocused_opacity = 1.0
    borderpx = 2
    gappih = 5
    gappiv = 5
    gappoh = 5
    gappov = 5

    layerrule = layer_name:.*noctalia-panel*,noblur:0,noanim:1

    # Animations
    animations = 1
    layer_animations = 1
    animation_type_open = zoom
    animation_type_close = zoom
    animation_fade_in = 1
    animation_fade_out = 1
    tag_animation_direction = 0
    zoom_initial_ratio = 0.6
    zoom_end_ratio = 0.8
    fadein_begin_opacity = 1.0
    fadeout_begin_opacity = 1.0

    animation_duration_move = 200
    animation_duration_open = 180
    animation_duration_tag = 180
    animation_duration_close = 100
    animation_duration_focus = 0

    animation_curve_open = 0.15,1.0,0.2,1.0
    animation_curve_move = 0.15,1.0,0.2,1.0
    animation_curve_tag = 0.15,1.0,0.2,1.0
    animation_curve_close = 0.1,1.0,0.1,1.0
    animation_curve_focus = 0.15,1.0,0.2,1.0
    animation_curve_opafadeout = 0.15,1.0,0.2,1.0
    animation_curve_opafadein = 0.15,1.0,0.2,1.0

    # Layouts & Scroller
    tagrule = id:1,layout_name:dwindle
    tagrule = id:2,layout_name:scroller
    tagrule = appid:zen.*,tag:1
    tagrule = appid:kitty,tag:2

    scroller_structs = 10
    scroller_default_proportion = 1
    scroller_focus_center = 0
    scroller_prefer_center = 1
    edge_scroller_pointer_focus = 1
    scroller_ignore_proportion_single = 1
    scroller_default_proportion_single = 1.0
    scroller_proportion_preset = 0.5,0.7,1.0

    new_is_master = 0
    default_mfact = 0.6
    default_nmaster = 1
    smartgaps = 0

    dwindle_split_ratio = 0.6
    dwindle_smart_split = 1
    dwindle_hsplit = 1
    dwindle_vsplit = 1
    dwindle_preserve_split = 1
    dwindle_smart_resize = 1

    scratchpad_width_ratio = 0.8
    scratchpad_height_ratio = 0.9

    # Overview
    hotarea_size = 10
    enable_hotarea = 1
    hotarea_corner = 1
    overviewgappi = 5
    overviewgappo = 50

    # Input & Devices
    repeat_rate = 25
    repeat_delay = 400
    numlockon = 1
    xkb_rules_layout = us_qwerty-fr
    xkb_rules_variant = qwerty-fr

    disable_trackpad = 0
    tap_to_click = 1
    tap_and_drag = 1
    drag_lock = 1
    trackpad_natural_scrolling = 0
    trackpad_disable_while_typing = 1
    swipe_min_threshold = 1

    mouse_natural_scrolling = 0
    cursor_size = 24
    cursor_theme = capitaine-cursors
    drag_tile_to_tile = 1

    # Miscellaneous
    no_border_when_single = 0
    axis_bind_apply_timeout = 100
    focus_on_activate = 0
    idleinhibit_ignore_visible = 0
    sloppyfocus = 1
    warpcursor = 1
    focus_cross_monitor = 0
    focus_cross_tag = 0
    enable_floating_snap = 0
    snap_distance = 30

    # Keybinds
    bind = SUPER+SHIFT+CTRL,q,quit
    bind = SUPER,q,killclient
    bind = SUPER,r,reload_config

    bind = SUPER,s,toggle_named_scratchpad,Spotify,none,spotify

    bind = SUPER,T,spawn,kitty
    bind = SUPER,E,spawn,kitty -e yazi
    bind = SUPER+SHIFT,UP,viewtoleft_have_client
    bind = SUPER+SHIFT,DOWN,viewtoright_have_client

    bind = SUPER+CTRL,Up,viewtoleft,0
    bind = SUPER+CTRL,Down,viewtoright,0
    bind = SUPER+CTRL+ALT,Up,tagtoleft,0
    bind = SUPER+CTRL+ALT,Down,tagtoright,0

    bind = SUPER,1,view,1
    bind = SUPER,2,view,2
    bind = SUPER,3,view,3
    bind = SUPER,4,view,4
    bind = SUPER,5,view,5
    bind = SUPER,6,view,6
    bind = SUPER,7,view,7
    bind = SUPER,8,view,8
    bind = SUPER,9,view,9

    bind = SUPER+SHIFT,1,tag,1
    bind = SUPER+SHIFT,2,tag,2
    bind = SUPER+SHIFT,3,tag,3
    bind = SUPER+SHIFT,4,tag,4
    bind = SUPER+SHIFT,5,tag,5
    bind = SUPER+SHIFT,6,tag,6
    bind = SUPER+SHIFT,7,tag,7
    bind = SUPER+SHIFT,8,tag,8
    bind = SUPER+SHIFT,9,tag,9

    bind = SUPER+CTRL,Left,focusmon,left
    bind = SUPER+CTRL,Right,focusmon,right
    bind = SUPER+SHIFT+CTRL,Left,tagmon,left
    bind = SUPER+SHIFT+CTRL,Right,tagmon,right

    bind = SUPER,equal,resizewin,5,0
    bind = SUPER,minus,resizewin,-5,0
    bind = SUPER+CTRL,equal,resizewin,0,5
    bind = SUPER+CTRL,minus,resizewin,0,-5
    bind = SUPER,W,togglefloating
    bind = SUPER,Tab,toggleoverview
    bind = ALT,Tab,focusstack,next
    bind = SUPER,f,togglefullscreen

    bind = CTRL,d,setlayout,DW
    bind = SUPER+ALT,f,set_proportion,1.0
    bind = SUPER+SHIFT,c,scroller_stack,right
    bind = SUPER,c,scroller_stack,left

    bind = ALT+SHIFT,X,incgaps,1
    bind = ALT+SHIFT,Z,incgaps,-1
    bind = ALT+SHIFT,R,togglegaps
    bind = SUPER+SHIFT,A,spawn,$HOME/.config/mango/bin/toggle-outer-gaps.sh

    bind = SUPER,A,spawn,noctalia msg panel-toggle launcher
    bind = SUPER,l,spawn,noctalia msg session lock
    bind = SUPER,comma,spawn,noctalia msg settings-toggle
    bind = SUPER,Escape,spawn,noctalia msg panel-toggle session
    bind = SUPER,V,spawn,noctalia msg panel-toggle clipboard
    bind = SUPER,P,spawn,noctalia msg screenshot-region
    bind = SUPER+SHIFT,w,spawn,noctalia msg panel-toggle wallpaper
    bind = NONE,XF86AudioRaiseVolume,spawn,noctalia msg volume-up
    bind = NONE,XF86AudioLowerVolume,spawn,noctalia msg volume-down
    bind = NONE,XF86AudioMute,spawn,noctalia msg volume-mute
    bind = NONE,XF86MonBrightnessUp,spawn,noctalia msg brightness-up
    bind = NONE,XF86MonBrightnessDown,spawn,noctalia msg brightness-down

    # Mouse & Gestures
    mousebind = SUPER,btn_left,moveresize,curmove
    mousebind = SUPER,btn_right,moveresize,curresize

    axisbind = SUPER,UP,focusdir,left
    axisbind = SUPER,DOWN,focusdir,right

    gesturebind = none,up,4,viewtoright,0
    gesturebind = none,down,4,viewtoleft,0
    gesturebind = none,left,3,focusdir,left
    gesturebind = none,right,3,focusdir,right
    gesturebind = none,up,3,focusdir,up
    gesturebind = none,down,3,focusdir,down

    # Source Noctalia & Monitors
    source-optional = ~/.config/mango/noctalia.conf
    source-optional = ~/.config/mango/monitors.conf
  '';

  home.activation.createEmptyNoctaliaConf = lib.hm.dag.entryAfter ["writeBoundary"] ''
    mkdir -p $HOME/.config/mango
    touch $HOME/.config/mango/noctalia.conf
  '';
}
