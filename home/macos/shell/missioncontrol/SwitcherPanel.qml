import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.common
import qs.services

// Panneau du sélecteur Cmd+Tab, mesuré sur une capture de macOS 26 (1440x900) :
//  - icônes : dessin de 103 pt, pas de 134 pt ;
//  - marge de 36 pt entre le bord du panneau et les icônes, hauteur 175 pt ;
//  - sélection : carré arrondi de 121 pt (icône + 9 pt), rayon 33 pt, gris
//    translucide ; coins du panneau concentriques (33 + 27 = 60 pt) ;
//  - nom de l'app sous la sélection, 13 pt semi-gras ;
//  - verre "clair" très transparent (flou Hyprland), sans ombre portée.
PanelWindow {
    id: panel

    required property var switcher            // AppSwitcher (état de la séquence)

    readonly property var items: switcher.items
    readonly property int count: items.length

    // Réduction si les apps ne tiennent pas dans la largeur de l'écran
    readonly property real naturalW: count * 134 + 41
    readonly property real k: Math.min(1, ((screen?.width ?? 1512) - 64) / Math.max(1, naturalW))

    readonly property real art: 103 * k                 // dessin visible de l'icône
    readonly property real pitch: 134 * k
    readonly property real pad: 36 * k
    readonly property real iconBox: art / 0.875         // le carré arrondi MacTahoe occupe 112/128 du cadre
    readonly property real selSize: art + 18 * k
    readonly property real panelW: count * pitch + 41 * k
    readonly property real panelH: 175 * k
    readonly property real artTop: pad

    // Nom affiché : celui du .desktop, sinon la classe rendue lisible
    // ("org.gnome.Calculator" -> "Calculator", "kitty" -> "Kitty")
    function appName(cls) {
        if (Apps.entryFor(cls)) return Apps.name(cls);
        const last = String(cls).split(".").pop();
        return last.charAt(0).toUpperCase() + last.slice(1);
    }

    implicitWidth: Math.ceil(panelW)
    implicitHeight: Math.ceil(panelH)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "macos-appswitcher"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // La surface est créée (invisible) dès le premier Cmd+Tab pour prendre le
    // clavier : on voit ainsi passer le relâchement de Cmd même si Hyprland ne
    // déclenche pas le bindrt. Le contenu n'apparaît qu'après 120 ms
    // (switcher.shown), en fondu très bref : le panneau macOS est quasi instantané.
    Item {
        id: body
        anchors.fill: parent
        focus: true
        opacity: 0
        NumberAnimation {
            id: fadeIn
            target: body
            property: "opacity"
            from: 0
            to: 1
            duration: 90
            easing.type: Easing.OutQuad
        }
        Connections {
            target: panel
            function onVisibleChanged() {
                fadeIn.stop();
                body.opacity = 0;
                if (panel.visible) body.forceActiveFocus();
            }
        }
        Connections {
            target: panel.switcher
            function onShownChanged() {
                if (panel.switcher.shown) fadeIn.restart();
                else { fadeIn.stop(); body.opacity = 0; }
            }
        }

        Glass {
            anchors.fill: parent
            radius: 60 * panel.k
            shadowEnabled: false
            // Clair : sur un terminal sombre (~40) la capture de référence donne
            // ~90-130, soit un voile blanc d'environ 40 %
            tint: Theme.dark ? Qt.rgba(0.08, 0.08, 0.09, 0.38) : Qt.rgba(0.85, 0.85, 0.87, 0.40)
        }

        // Sélection
        Rectangle {
            id: selection
            visible: panel.count > 0
            width: panel.selSize
            height: panel.selSize
            radius: 33 * panel.k
            x: panel.pad + panel.switcher.index * panel.pitch + panel.art / 2 - width / 2
            y: panel.artTop + panel.art / 2 - height / 2
            color: Theme.dark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.25)
        }

        // Icônes
        Repeater {
            model: panel.items

            Item {
                id: cell
                required property var modelData
                required property int index
                x: panel.pad + index * panel.pitch + panel.art / 2 - width / 2
                y: panel.artTop + panel.art / 2 - height / 2
                width: panel.iconBox
                height: panel.iconBox

                IconImage {
                    anchors.fill: parent
                    source: Apps.icon(cell.modelData)
                    implicitSize: panel.iconBox
                    asynchronous: false
                }

                MouseArea {
                    // Zone de survol : toute la colonne de l'icône
                    x: (cell.width - panel.pitch) / 2
                    y: -panel.artTop + (cell.height - panel.art) / 2
                    width: panel.pitch
                    height: panel.panelH
                    hoverEnabled: true
                    enabled: panel.switcher.shown
                    // Comme macOS : la sélection suit la souris seulement si elle bouge
                    onPositionChanged: panel.switcher.select(cell.index)
                    onClicked: { panel.switcher.select(cell.index); panel.switcher.commit(); }
                }
            }
        }

        // Nom de l'app sélectionnée, centré sous la sélection
        Text {
            id: label
            readonly property real cx: selection.x + selection.width / 2
            text: panel.count > 0 ? panel.appName(panel.items[panel.switcher.index] ?? "") : ""
            color: Theme.label
            font.family: Theme.font
            font.pixelSize: Math.round(13 * panel.k)
            font.weight: Font.DemiBold
            // Ligne de base à 11 pt du bas du panneau
            y: panel.panelH - 11 * panel.k - baselineOffset
            x: Math.max(8, Math.min(panel.width - width - 8, cx - width / 2))
            width: Math.min(implicitWidth, panel.width - 16)
            elide: Text.ElideRight
        }

        // Clavier tant que le panneau est visible (Cmd encore enfoncé)
        Keys.onPressed: e => {
            const sw = panel.switcher;
            if (e.key === Qt.Key_Right || (e.key === Qt.Key_Tab && !(e.modifiers & Qt.ShiftModifier))) sw.step(1);
            else if (e.key === Qt.Key_Left || e.key === Qt.Key_Backtab || e.key === Qt.Key_QuoteLeft
                     || (e.key === Qt.Key_Tab && (e.modifiers & Qt.ShiftModifier))) sw.step(-1);
            else if (e.key === Qt.Key_Escape || e.key === Qt.Key_Period) sw.cancel();
            else if (e.key === Qt.Key_Q) sw.quitSelected();
            else if (e.key === Qt.Key_H) sw.hideSelected();
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) sw.commit();
            else return;
            e.accepted = true;
        }
        // Relâchement de Cmd vu directement (secours si le bindrt n'arrive pas)
        Keys.onReleased: e => {
            if (e.key === Qt.Key_Super_L || e.key === Qt.Key_Super_R || e.key === Qt.Key_Meta) {
                panel.switcher.commit();
                e.accepted = true;
            }
        }
    }
}
