''
  mako &
  awww-daemon &
  wallpaper restore &
  wlsunset -S 05:00 -s 17:30 -d 1800 -t 3500 -T 6500 &
  blueman-applet &
  # messageries : la window_rule de rules.nix les envoie dans le workspace spécial (tag 0)
  for app in discord whatsapp-electron teams-for-linux; do
    command -v "$app" >/dev/null && "$app" &
  done
  command -v themes >/dev/null && themes apply-default
''
