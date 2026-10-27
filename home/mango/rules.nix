{
  window_rule = [
    "is_floating:1,is_fullscreen:1,no_animation:1,title:^powyx$"
    "is_floating:1,is_fullscreen:1,no_animation:1,title:^ctrlyx-lite$"
    "unfocused_opacity:0.97,app_id:^(kitty)$"
    "focused_opacity:0.9,app_id:^(dev.zed.Zed|zen|zen-beta)$"
  ];

  window_rule_once = [
    "tags:2,app_id:^(zen|zen-beta)$"
    "tags:3,app_id:^kitty$"
  ];

  tag_rule = ["id:*,layout_name:scroller"];
}
