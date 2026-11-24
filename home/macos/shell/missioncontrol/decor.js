.pragma library

// Décorations serveur des fenêtres, telles que les dessine Hyprland (coins,
// liseré, ombre). Une capture Wayland de toplevel ne contient que le contenu du
// client : Mission Control redessine ces décorations pour que la vignette soit
// identique à la fenêtre réelle. Pas de barre de titre serveur (plus de plugin
// hyprbars) : hasBar() est toujours faux, le code de la barre reste inactif.
//
// ⚠ Reflète les windowrule de home/macos/hyprland-look.nix (section
// rounding) : à garder synchronisé si ces règles changent.

const CSD_LIST = /^(zen.*|firefox.*|librewolf|brave-browser.*|chromium.*|google-chrome.*|helium.*|zed|Zed|code|Code|code-oss|cursor|obsidian|discord|vesktop|teams-for-linux|steam|spotify|Spotify|motrix.*|WaveFlow|waveflow|gtk3-.*|gtk4-.*|gnome-.*|nautilus|file-roller|evince|eog|totem|baobab|seahorse|pavucontrol|nwg-look|blueman-manager|easyeffects|heroic|freetube|FreeTube)$/;
const QT_ROUND = /^(org\.kde\..*|org\.qt-project\..*)$/;
const TERMINALS = /^(kitty|foot|footclient|Alacritty)$/;

const barHeight = 32;

// La fenêtre a-t-elle une barre de titre serveur ? Plus jamais (hyprbars retiré).
function hasBar(cls, fullscreen) {
    return false;
}

// Rayon des coins (decoration:rounding et règles par classe)
function radius(cls, fullscreen) {
    if (fullscreen) return 0;
    if (QT_ROUND.test(cls)) return 16;
    if (/\./.test(cls) || CSD_LIST.test(cls)) return 26;
    return 16;
}

// Couleur de la barre (Terminal.app : couleur du fond du terminal)
function barColor(cls) {
    return TERMINALS.test(cls) ? "#1e1e1e" : "#333333";
}
