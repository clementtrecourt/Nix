import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

// Panneau du sélecteur Cmd+Tab, mesuré sur une capture de macOS 26 (1440x900) :
//  - icônes : dessin de 103 pt, pas de 134 pt ;
//  - marge de 36 pt entre le bord du panneau et les icônes, hauteur 175 pt ;
//  - sélection : carré arrondi de 121 pt (icône + 9 pt), rayon 33 pt, gris
//    translucide ; coins du panneau concentriques (33 + 27 = 60 pt) ;
//  - nom de l'app sous la sélection, 13 pt semi-gras ;
//  - Liquid Glass très transparent (réfraction d'une capture de l'écran),
//    sans ombre portée.
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
    // Toile de l'icône : le squircle d'une toile Apple en occupe 80,5 % (celui
    // de MacTahoe 87,5 %, ramené à 80,5 % comme dans le Dock)
    readonly property real canvas: art / 0.805
    readonly property real selSize: art + 18 * k
    readonly property real panelW: count * pitch + 41 * k
    readonly property real panelH: 175 * k
    readonly property real artTop: pad
    // Position du pointeur à l'apparition du panneau (survol sans mouvement ignoré)
    property bool pointerAnchored: false
    property point pointerAnchor: Qt.point(0, 0)
    onContentShownChanged: pointerAnchored = false

    // Nom affiché : même nom que le Dock ("kitty" -> "Terminal")
    function appName(cls) { return Apps.displayName(cls); }

    implicitWidth: Math.ceil(panelW)
    implicitHeight: Math.ceil(panelH)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    // "macos-lg-*" : pas de flou Hyprland (le verre réfracte lui-même la capture)
    WlrLayershell.namespace: "macos-lg-appswitcher"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Fond du verre : capture de l'écran prise dès le premier Cmd+Tab. La
    // surface est alors déjà mappée (pour le clavier) mais son contenu est à
    // opacité 0 et son namespace n'est pas flouté : elle est invisible dans la
    // capture. L'image arrive en ~50 ms, bien avant les 120 ms d'attente du
    // panneau : aucun retard ajouté dans le cas normal.
    property Item glassBackdrop: backdrop
    GlassBackdrop {
        id: backdrop
        mode: "snapshot"
        screen: panel.screen
        want: panel.visible
        timeout: 200
    }
    // Contenu affiché : 120 ms écoulées ET capture disponible
    readonly property bool contentShown: switcher.shown && backdrop.pass

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
            target: panel
            function onContentShownChanged() {
                if (panel.contentShown) fadeIn.restart();
                else { fadeIn.stop(); body.opacity = 0; }
            }
        }

        Glass {
            anchors.fill: parent
            radius: 60 * panel.k
            shadowEnabled: false
            // Verre très transparent : le fond (flouté, réfracté au bord) reste
            // bien lisible au travers, à peine assombri en mode sombre
            tint: Theme.dark ? Qt.rgba(0.10, 0.10, 0.11, 0.30) : Qt.rgba(1, 1, 1, 0.14)
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
                // Icône résolue comme dans le Dock (DockIcons, voir AppSwitcher)
                readonly property var info: panel.switcher.icons.resolved[panel.switcher.iconKey(modelData)] ?? null
                readonly property bool boxed: !!info && !!info.foreign
                readonly property real iconScale: info && info.apple ? 1 : 0.805 / 0.875
                // Taille dessinée sur des pixels entiers (net à l'échelle 1)
                readonly property real drawn: Math.round(boxed ? panel.art * 0.66 : panel.canvas * iconScale)
                x: Math.round(panel.pad + index * panel.pitch + panel.art / 2 - width / 2)
                y: Math.round(panel.artTop + panel.art / 2 - height / 2)
                width: Math.round(panel.canvas)
                height: width

                // Squircle gris des icônes absentes du thème (comme le Dock)
                Rectangle {
                    visible: cell.boxed
                    anchors.centerIn: parent
                    width: Math.round(panel.art)
                    height: width
                    radius: width * 0.225
                    gradient: Gradient {
                        GradientStop { position: 0; color: Theme.dark ? "#4a4a4e" : "#fbfbfd" }
                        GradientStop { position: 1; color: Theme.dark ? "#323235" : "#e4e4e8" }
                    }
                    border.width: 0.5
                    border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.08)
                }
                Image {
                    anchors.centerIn: parent
                    width: cell.drawn
                    height: cell.drawn
                    source: cell.info && cell.info.path ? cell.info.path : Apps.icon(cell.modelData)
                    sourceSize: Qt.size(cell.drawn, cell.drawn)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: false
                    smooth: true
                }

                // Pastille de notifications (rouge, coin haut-droit du squircle ;
                // « 148 » de Mail sur Tahoe 26 : hauteur ≈ 0,40 × l'icône)
                readonly property int badge: panel.switcher.badgeCount(modelData)
                Rectangle {
                    visible: cell.badge > 0
                    readonly property real h: Math.round(panel.art * 0.40)
                    height: h
                    width: Math.max(h, Math.round(badgeText.implicitWidth + h * 0.6))
                    radius: h / 2
                    x: Math.round(cell.width / 2 + panel.art / 2 - panel.art * 0.12 - h / 2 - (width - h) / 2)
                    y: Math.round(cell.height / 2 - panel.art / 2 + panel.art * 0.10 - h / 2)
                    color: "#FF3B30"
                    Text {
                        id: badgeText
                        anchors.centerIn: parent
                        text: cell.badge > 999 ? "999+" : String(cell.badge)
                        color: "white"
                        font.family: Theme.font
                        font.pixelSize: Math.round(parent.h * 0.6)
                        font.weight: Font.Medium
                        renderType: Text.NativeRendering
                    }
                }

                MouseArea {
                    // Zone de survol : toute la colonne de l'icône
                    x: (cell.width - panel.pitch) / 2
                    y: -panel.artTop + (cell.height - panel.art) / 2
                    width: panel.pitch
                    height: panel.panelH
                    hoverEnabled: true
                    enabled: panel.contentShown
                    // Comme macOS : la sélection suit la souris seulement si elle
                    // bouge (le panneau qui apparaît sous un pointeur immobile
                    // génère aussi un événement de position : ignoré)
                    onPositionChanged: e => {
                        const pt = mapToItem(body, e.x, e.y);
                        if (!panel.pointerAnchored) {
                            panel.pointerAnchored = true;
                            panel.pointerAnchor = pt;
                            return;
                        }
                        if (Math.hypot(pt.x - panel.pointerAnchor.x, pt.y - panel.pointerAnchor.y) < 3) return;
                        panel.pointerAnchor = Qt.point(-1000, -1000);
                        panel.switcher.select(cell.index);
                    }
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
            y: Math.round(panel.panelH - 11 * panel.k - baselineOffset)
            x: Math.round(Math.max(8, Math.min(panel.width - width - 8, cx - width / 2)))
            width: Math.min(implicitWidth, panel.width - 16)
            elide: Text.ElideRight
            renderType: Text.NativeRendering
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
