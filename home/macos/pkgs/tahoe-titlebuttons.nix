# Feux tricolores de Tahoe 26 pour les apps GTK3 / GTK4 (libadwaita) : SVG dessinés
# aux couleurs du shell (common/Theme.qml : trafficRed/Yellow/Green + anneau d'un
# demi-point) et aux mêmes couleurs que les barres hyprbars, symboles au survol
# (✕, −, deux triangles du plein écran), gris translucide en arrière-plan.
# macos-appearance s'en sert pour écrire le CSS utilisateur GTK3 / GTK4 selon le mode.
{runCommand}:
runCommand "tahoe-titlebuttons" {} ''
  d=$out/share/tahoe-titlebuttons
  mkdir -p $d

  # disque <fichier> <remplissage> <anneau> [symbole SVG]
  disc() {
    cat >"$d/$1.svg" <<EOF
  <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 14 14">
    <circle cx="7" cy="7" r="6.75" fill="$2"/>
    <circle cx="7" cy="7" r="6.5" fill="none" stroke="$3" stroke-width="0.5"/>
    $4
  </svg>
  EOF
  }

  # Symboles de Tahoe (couleur sombre de chaque bouton)
  close='<path d="M4.6 4.6l4.8 4.8M9.4 4.6l-4.8 4.8" stroke="#8c1a10" stroke-width="1.3" stroke-linecap="round"/>'
  minimize='<path d="M3.8 7h6.4" stroke="#8f5a00" stroke-width="1.3" stroke-linecap="round"/>'
  maximize='<path d="M4.1 4.1h4.6l-4.6 4.6zM9.9 9.9h-4.6l4.6-4.6z" fill="#1b6a1d"/>'

  disc close "#EC6765" "#E73935"
  disc close-hover "#EC6765" "#E73935" "$close"
  disc close-active "#C9524F" "#C42E2B" "$close"
  disc minimize "#F2CA44" "#EEBA0B"
  disc minimize-hover "#F2CA44" "#EEBA0B" "$minimize"
  disc minimize-active "#CFAA30" "#C99B05" "$minimize"
  disc maximize "#65C466" "#35B338"
  disc maximize-hover "#65C466" "#35B338" "$maximize"
  disc maximize-active "#4FA650" "#2A962D" "$maximize"
  # Fenêtre inactive : voile translucide (Theme.trafficInactive / trafficInactiveRing)
  disc backdrop-dark '#FFFFFF" fill-opacity="0.18' '#FFFFFF" stroke-opacity="0.22'
  disc backdrop-light '#000000" fill-opacity="0.137' '#000000" stroke-opacity="0.176'
''
