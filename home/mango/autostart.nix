''
  mako &
  swww-daemon &
  wlsunset -S 21:00 -s 05:00 -t 4500 &
  blueman-applet &
  wl-paste --watch cliphist store &
  command -v themes >/dev/null && themes apply-default
''
