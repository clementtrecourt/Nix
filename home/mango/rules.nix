{
  window_rule = [
    "is_floating:1,is_fullscreen:1,no_animation:1,title:^powyx$"
    "is_floating:1,is_fullscreen:1,no_animation:1,title:^ctrlyx-lite$"
    "is_floating:1,width:0.55,height:0.7,app_id:waypaper"
    "focused_opacity:1.0,unfocused_opacity:1.0,app_id:^(zen|zen-beta)$"
    # messageries dans le workspace spécial (SUPER+D)
    "tags:0,app_id:^(discord|com.github.dagmoller.whatsapp-electron|teams-for-linux)$"
  ];

  # sélection de capture (slurp) : sans flou ni animation, sinon l'écran est flouté pendant le choix
  layer_rule = ["no_animation:1,no_blur:1,layer_name:selection"];

  window_rule_once = [
    "tags:1,app_id:^(zen|zen-beta)$"
  ];

  tag_rule = ["id:*,layout_name:scroller"];
}
