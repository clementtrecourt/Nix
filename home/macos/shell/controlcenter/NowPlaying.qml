import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.common
import qs.services

// Module 2x2 "Lecture en cours" : pochette, titre, artiste, précédent /
// lecture-pause / suivant. Cotes relevées sur Tahoe : pochette 39 pt à 13 pt du
// bord, commandes centrées à 28 / 67 / 106 pt, à 106 pt du haut.
CCTile {
    id: np

    // Lecteur affiché : celui qui joue, sinon le premier qui peut être piloté
    readonly property var players: Mpris.players.values
    readonly property MprisPlayer player: players.find(p => p.isPlaying) ?? players.find(p => p.canControl) ?? null
    readonly property bool hasTrack: !!player && (player.trackTitle ?? "") !== ""

    implicitWidth: CCStyle.span(2)
    implicitHeight: CCStyle.span(2)
    radius: CCStyle.radiusLarge
    interactive: false

    // Pochette (ou vignette vide)
    ClippingRectangle {
        id: art
        x: 13
        y: 13
        width: 39
        height: 39
        radius: 7
        color: Qt.rgba(1, 1, 1, 0.14)

        Image {
            anchors.fill: parent
            source: np.player?.trackArtUrl ?? ""
            sourceSize: Qt.size(96, 96)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
        }
        MouseArea {
            anchors.fill: parent
            enabled: !!np.player && np.player.canRaise
            onClicked: { np.player.raise(); ShellState.close(); }
        }
    }

    Column {
        x: 15
        y: np.hasTrack ? 61 : 69
        width: parent.width - 2 * x
        spacing: 1
        Text {
            width: parent.width
            text: np.hasTrack ? np.player.trackTitle : "Pas de lecture"
            color: CCStyle.text
            font.family: Theme.font
            font.letterSpacing: CCStyle.tracking
            font.pixelSize: np.hasTrack ? CCStyle.titleSize : 13
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            visible: np.hasTrack && text !== ""
            text: np.player?.trackArtist ?? ""
            color: CCStyle.textSecondary
            font.family: Theme.font
            font.letterSpacing: CCStyle.tracking
            font.pixelSize: CCStyle.subtitleSize
            elide: Text.ElideRight
        }
    }

    component Ctl: Item {
        id: ctl
        property string symbol
        property int glyph: 22
        property bool active: true
        signal activated()
        width: 34
        height: 30
        Symbol {
            anchors.centerIn: parent
            name: ctl.symbol
            size: ctl.glyph
            color: CCStyle.text
            opacity: ctl.active ? (cma.pressed ? 0.6 : 1) : 0.35
        }
        MouseArea {
            id: cma
            anchors.fill: parent
            enabled: ctl.active
            onClicked: ctl.activated()
        }
        scale: cma.pressed ? 0.86 : 1
        Behavior on scale { SpringAnimation { spring: 6; damping: 0.4; epsilon: 0.0005 } }
    }

    Ctl {
        x: 28 - width / 2
        y: 106 - height / 2
        symbol: "backward.fill"
        glyph: 24
        active: !!np.player && np.player.canGoPrevious
        onActivated: np.player.previous()
    }
    Ctl {
        x: np.width / 2 - width / 2
        y: 106 - height / 2
        symbol: np.player?.isPlaying ? "pause.fill" : "play.fill"
        glyph: 21
        active: !!np.player && np.player.canTogglePlaying
        onActivated: np.player.togglePlaying()
    }
    Ctl {
        x: np.width - 28 - width / 2
        y: 106 - height / 2
        symbol: "forward.fill"
        glyph: 24
        active: !!np.player && np.player.canGoNext
        onActivated: np.player.next()
    }
}
