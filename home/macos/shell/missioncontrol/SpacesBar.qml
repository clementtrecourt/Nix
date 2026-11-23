import QtQuick
import QtQuick.Effects
import Quickshell
import qs.common

// Barre des Spaces de Mission Control (macOS Tahoe).
//  - repliée : simple rangée de libellés "Bureau 1  Bureau 2 ..." en haut ;
//  - dépliée (survol, ou fenêtre glissée vers le haut) : vignettes des bureaux
//    (1/10e de l'écran, 32 pt d'écart), bureau courant cerné de bleu (3 pt,
//    détaché de 1 pt), libellé dessous, bouton "+" rond à droite.
// Mesures relevées sur une capture 1440x900 de macOS 26 : vignettes 144x90 à
// 28 pt du haut, bande de 146 pt, "+" de 32 pt centré à 34 pt du bord droit.
Item {
    id: bar

    required property Item backdrop          // fond d'écran (pour le flou de la bande)
    required property Item wallpaper         // fond d'écran seul (vignettes)
    required property var monitor            // HyprlandMonitor
    property real progress: 1                // entrée/sortie de Mission Control
    property bool forceExpanded: false
    property int forceHoverSpace: -1         // débogage : survol forcé d'un bureau
    property bool dragActive: false          // une fenêtre est en cours de glisser
    property point dragPoint: Qt.point(-1, -1)

    signal spaceClicked(int id)

    readonly property real thumbW: Math.round(width / 10)
    readonly property real thumbH: Math.round(screenH / 10)
    property real screenH: 982
    readonly property real thumbTop: 28
    readonly property real gap: 32
    readonly property real expandedH: thumbTop + thumbH + 28
    readonly property real collapsedH: 34

    readonly property bool hoveredBand: barHover.hovered
    readonly property bool expanded: forceExpanded || hoveredBand || (dragActive && dragPoint.y < expandedH + 120)
    property real ex: expanded ? 1 : 0
    Behavior on ex { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

    readonly property real bandH: collapsedH + (expandedH - collapsedH) * ex
    height: bandH

    readonly property var ids: Spaces.ids
    readonly property real rowW: ids.length * thumbW + (ids.length - 1) * gap
    readonly property real collapsedPitch: Math.max(84, labelProbe.implicitWidth + 34)

    // Bureau sous un point (coordonnées de la barre) : id, -1 = "+", 0 = rien
    function spaceAt(px, py) {
        if (py > bandH) return 0;
        if (Math.hypot(px - addButton.x - addButton.width / 2, py - addButton.y - addButton.height / 2) < 26) return -1;
        for (let i = 0; i < repeater.count; i++) {
            const it = repeater.itemAt(i);
            if (it && px >= it.x - gap / 2 && px <= it.x + it.width + gap / 2) return it.wsId;
        }
        return 0;
    }

    // Survol de la bande (un HoverHandler ne bloque pas les vignettes)
    HoverHandler {
        id: barHover
    }

    Text {
        id: labelProbe
        visible: false
        text: Spaces.label(88)
        font.family: Theme.font
        font.pixelSize: 12
    }

    // ---- Bande : fond d'écran flouté + voile, ombre dessous ----
    Item {
        id: band
        width: parent.width
        height: bar.bandH
        clip: true

        ShaderEffectSource {
            id: bandSrc
            anchors.fill: parent
            sourceItem: bar.backdrop
            sourceRect: Qt.rect(0, 0, band.width, band.height)
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: bandSrc
            blurEnabled: true
            blur: 1.0
            blurMax: 48
            saturation: 0.15
            autoPaddingEnabled: false
        }
        Rectangle {
            anchors.fill: parent
            color: Theme.dark ? Qt.rgba(0, 0, 0, 0.16) : Qt.rgba(1, 1, 1, 0.07)
        }
        // Liseré clair en bas de la bande (verre)
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Theme.dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.18)
        }
    }
    Rectangle {
        anchors.top: band.bottom
        width: parent.width
        height: 30
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, Theme.dark ? 0.20 : 0.13) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // ---- Bureaux ----
    Repeater {
        id: repeater
        model: bar.ids

        Item {
            id: space
            required property int modelData
            required property int index
            readonly property int wsId: modelData
            readonly property bool isCurrent: (bar.monitor?.activeWorkspace?.id ?? Spaces.current) === wsId
            readonly property bool dropTarget: bar.dragActive && bar.spaceAt(bar.dragPoint.x, bar.dragPoint.y) === wsId
            readonly property bool hovered: thumbMouse.containsMouse || closeMouse.containsMouse || bar.forceHoverSpace === wsId

            // Position dépliée (vignette) et repliée (libellé seul)
            readonly property real exX: (bar.width - bar.rowW) / 2 + index * (bar.thumbW + bar.gap)
            readonly property real coCenter: bar.width / 2 + (index - (bar.ids.length - 1) / 2) * bar.collapsedPitch

            x: exX
            y: bar.thumbTop
            width: bar.thumbW
            height: bar.thumbH

            // Vignette
            Item {
                id: thumbBox
                anchors.fill: parent
                opacity: Math.max(0, (bar.ex - 0.25) / 0.75)
                transform: Translate { y: -(1 - bar.ex) * (bar.thumbH + bar.thumbTop) * 0.6 }

                SpaceThumb {
                    anchors.fill: parent
                    wsId: space.wsId
                    monitor: bar.monitor
                    wallpaper: bar.wallpaper
                    live: bar.ex > 0 && bar.progress > 0
                    screenW: bar.width
                    screenH: bar.screenH
                }
                // Bureau courant / cible du glisser : cadre bleu 3 pt détaché de 1 pt
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -4
                    radius: 5
                    color: "transparent"
                    border.width: 3
                    border.color: "#3B99FC"
                    visible: space.isCurrent || space.dropTarget
                    opacity: space.dropTarget && !space.isCurrent ? 0.75 : 1
                }
                MouseArea {
                    id: thumbMouse
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    onClicked: bar.spaceClicked(space.wsId)
                }

                // Bouton de fermeture (coin haut-gauche, au survol)
                Rectangle {
                    id: closeBtn
                    width: 20
                    height: 20
                    radius: 10
                    x: -width / 2 + 2
                    y: -height / 2 + 2
                    color: closeMouse.pressed ? Qt.rgba(0.32, 0.32, 0.34, 0.95) : Qt.rgba(0.20, 0.20, 0.22, 0.88)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.28)
                    visible: bar.ids.length > 1 && space.hovered && bar.ex > 0.9 && !bar.dragActive
                    Repeater {
                        model: [45, -45]
                        Rectangle {
                            required property var modelData
                            anchors.centerIn: parent
                            width: 9
                            height: 1.6
                            radius: 0.8
                            color: "white"
                            rotation: modelData
                            antialiasing: true
                        }
                    }
                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        anchors.margins: -3
                        hoverEnabled: true
                        onClicked: Spaces.remove(space.wsId)
                    }
                }
            }

            // Libellé : glisse de la rangée repliée à sa place sous la vignette
            Text {
                id: label
                text: Spaces.label(space.wsId)
                color: Theme.dark ? Qt.rgba(1, 1, 1, 0.92) : Qt.rgba(0, 0, 0, 0.85)
                font.family: Theme.font
                font.pixelSize: 12
                renderType: Text.NativeRendering
                readonly property real exLX: (space.width - implicitWidth) / 2
                readonly property real coLX: space.coCenter - space.x - implicitWidth / 2
                readonly property real exLY: bar.thumbH + 6
                readonly property real coLY: (bar.collapsedH - implicitHeight) / 2 - bar.thumbTop
                x: coLX + (exLX - coLX) * bar.ex
                y: coLY + (exLY - coLY) * bar.ex
            }
        }
    }

    // ---- Bouton "+" (nouveau bureau) ----
    Rectangle {
        id: addButton
        width: 32
        height: 32
        radius: 16
        x: bar.width - 34 - width / 2
        y: bar.thumbTop + bar.thumbH / 2 - height / 2
        opacity: Math.max(0, (bar.ex - 0.4) / 0.6)
        visible: opacity > 0
        readonly property bool hot: addHover.containsMouse || (bar.dragActive && bar.spaceAt(bar.dragPoint.x, bar.dragPoint.y) === -1)
        color: Theme.dark ? Qt.rgba(1, 1, 1, hot ? 0.24 : 0.14) : Qt.rgba(1, 1, 1, hot ? 0.32 : 0.20)
        border.width: 1
        border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(0.85, 0.97, 1, 0.85)

        Repeater {
            model: [0, 90]
            Rectangle {
                required property var modelData
                anchors.centerIn: parent
                width: 19
                height: 2
                radius: 1
                rotation: modelData
                color: Theme.dark ? "white" : Qt.rgba(0, 0, 0.12, 0.92)
                antialiasing: true
            }
        }
        MouseArea {
            id: addHover
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            onClicked: Spaces.add()
        }
    }
}
