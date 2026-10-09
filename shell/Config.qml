pragma Singleton
import Quickshell

Singleton {
    // "left" | "right" | "top" | "bottom"
    readonly property string barPosition: "left"
    readonly property int thickness: 40
    // 0.0 transparent -> 1.0 opaque
    readonly property real opacity: 0.6
    // coins arrondis (0 = carré)
    readonly property int radius: 0
    // > 0 = barre flottante détachée des bords
    readonly property int margin: 0
    readonly property string font: "Readex Pro"
    readonly property string wallpaperDir: Quickshell.env("HOME") + "/Pictures/walls-catppuccin-mocha/"
        readonly property real pickerWidthRatio: 0.9   // part de la largeur de l'écran
    readonly property int pickerHeight: 500        // hauteur max (réduite si l'écran est petit)
    readonly property int pickerCount: 6           // nombre max de tuiles visibles
    readonly property real pickerMinAspect: 0.4    // largeur mini d'une tuile / sa hauteur
    readonly property real pickerSkew: -0.25       // 0 = tuiles droites
    readonly property real pickerDim: 0.5          // assombrissement du fond (0 = aucun)
        readonly property int notifWidth: 360
    readonly property int notifMargin: 12
    readonly property int notifTimeout: 5000
        readonly property int launcherWidth: 640
        readonly property bool wsHideEmpty: true   // cacher les tags vides (sauf l'actif)
    readonly property int wsSize: 26
    readonly property int launcherRows: 8      // lignes visibles
        readonly property real overlayDim: 0.5
    readonly property string iconFont: "JetBrainsMono Nerd Font"

        readonly property string lockSh: "pidof hyprlock >/dev/null || hyprlock"
    function lockCmd() { return ["sh", "-c", lockSh] }
}
