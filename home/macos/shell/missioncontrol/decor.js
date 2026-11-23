.pragma library

// Décorations serveur des fenêtres, telles que les dessine Hyprland (plugin
// hyprbars, coins, liseré, ombre). Une capture Wayland de toplevel ne contient
// que le contenu du client : Mission Control redessine donc la barre de titre
// pour que la vignette soit identique à la fenêtre réelle.
//
// ⚠ Reflète les windowrule de home/macos/hyprland.nix (section hyprbars /
// rounding) : à garder synchronisé si ces règles changent.

const CSD_LIST = /^(zen.*|firefox.*|librewolf|brave-browser.*|chromium.*|google-chrome.*|helium.*|zed|Zed|code|Code|code-oss|cursor|obsidian|discord|vesktop|teams-for-linux|steam|spotify|Spotify|motrix.*|WaveFlow|waveflow|gtk3-.*|gtk4-.*|gnome-.*|nautilus|file-roller|evince|eog|totem|baobab|seahorse|pavucontrol|nwg-look|blueman-manager|easyeffects|heroic|freetube|FreeTube)$/;
const QT_LIKE = /^(org\.kde\..*|org\.qt-project\..*|io\.mpv\.Mpv)$/;
const QT_ROUND = /^(org\.kde\..*|org\.qt-project\..*)$/;
const TERMINALS = /^(kitty|foot|footclient|Alacritty)$/;

const barHeight = 32;

// La fenêtre a-t-elle une barre de titre hyprbars ? (règles appliquées dans l'ordre)
function hasBar(cls, fullscreen) {
    if (fullscreen) return false;
    let bar = true;
    if (/\./.test(cls)) bar = false;
    if (QT_LIKE.test(cls)) bar = true;
    if (CSD_LIST.test(cls)) bar = false;
    return bar;
}

// Rayon des coins (decoration:rounding et règles par classe)
function radius(cls, fullscreen) {
    if (fullscreen) return 0;
    if (QT_ROUND.test(cls)) return 16;
    if (/\./.test(cls) || CSD_LIST.test(cls)) return 24;
    return 16;
}

// Couleur de la barre (Terminal.app : couleur du fond du terminal)
function barColor(cls) {
    return TERMINALS.test(cls) ? "#1e1e1e" : "#242424";
}
