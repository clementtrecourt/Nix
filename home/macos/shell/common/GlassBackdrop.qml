import QtQuick
import Quickshell

// Fournisseur de fond Liquid Glass d'UNE fenêtre : tous les Glass de la fenêtre
// réfractent ce fond (common/Glass.qml le trouve via la propriété
// `glassBackdrop` de la fenêtre).
//
// Deux modes :
//  - "wallpaper" : le fond d'écran en direct (Dock, barre de menus : derrière eux,
//    il n'y a que le fond d'écran grâce à leur zone exclusive) ;
//  - "snapshot"  : capture de l'écran prise juste AVANT que la fenêtre ne
//    devienne visible (panneaux temporaires : Control Center, Spotlight, menus,
//    notifications…). La capture est gardée tant que la fenêtre reste visible
//    (animation de fermeture comprise), puis libérée.
//
// Branchement d'une fenêtre (exemple Control Center) :
//
//   PanelWindow {
//       id: win
//       // namespace en "macos-lg-*" : Hyprland ne floute pas ces surfaces
//       // (le verre floute et réfracte lui-même ; un second flou se verrait)
//       WlrLayershell.namespace: "macos-lg-controlcenter"
//       property Item glassBackdrop: bd
//       GlassBackdrop {
//           id: bd
//           mode: "snapshot"
//           screen: win.screen
//           want: cc.shown || content.opacity > 0.001   // l'ancienne condition de visibilité
//       }
//       visible: bd.pass                                // au lieu de l'ancienne condition
//       ...
//   }
//
// `pass` suit `want`, mais à l'ouverture il ne passe à vrai qu'une fois la
// capture arrivée (~50 ms ; au plus `timeout` ms si la capture échoue). Une
// réouverture pendant l'animation de fermeture garde la capture courante (la
// fenêtre est encore visible : une nouvelle capture la contiendrait).
//
// `origin` : position de la fenêtre sur l'écran (repère de la capture). Par
// défaut, calculée depuis les ancres/marges ; à fixer si la fenêtre est décalée
// par la zone exclusive d'une autre surface (ex. couche plein écran en
// ExclusionMode.Normal sous la barre de menus : Qt.point(0, Theme.menuBarHeight)).
Item {
    id: root

    property string mode: "snapshot"
    property var screen: null
    property bool want: false
    property var origin: null
    property int timeout: 160

    readonly property bool pass: mode === "wallpaper" ? want : (want && _gate)
    // Prêt à être lu (LiquidGlass vérifie `ready` avant de réfracter)
    readonly property bool ready: mode === "wallpaper" ? true : snap.ready

    property bool _gate: false
    readonly property var _win: QsWindow.window

    width: screen?.width ?? 0
    height: screen?.height ?? 0
    // Jamais affiché : seulement rendu dans les textures des verres
    visible: false

    function _open() {
        if (mode !== "snapshot") return;
        if (_win?.visible && snap.ready) { _gate = true; return; }
        snap.capture();
        fallback.restart();
    }

    onWantChanged: {
        if (want) _open();
        else _gate = false;
    }
    Component.onCompleted: if (want) _open()

    // Libère la capture quand la fenêtre est vraiment cachée
    Connections {
        target: root._win
        function onVisibleChanged() {
            if (!root._win.visible && !root.want) snap.release();
        }
    }
    Connections {
        target: snap
        function onCaptured() { if (root.want) root._gate = true; }
    }
    Timer {
        id: fallback
        interval: root.timeout
        onTriggered: if (root.want) root._gate = true
    }

    Loader {
        anchors.fill: parent
        active: root.mode === "wallpaper"
        sourceComponent: LiquidGlassWallpaper {
            visible: true
            screen: root.screen
        }
    }
    LiquidGlassSnapshot {
        id: snap
        anchors.fill: parent
        visible: root.mode === "snapshot"
        screen: root.mode === "snapshot" ? root.screen : null
    }
}
