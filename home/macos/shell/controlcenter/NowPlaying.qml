import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.common
import qs.services

// Module 2x2 "Now Playing" : pochette, titre, artiste, précédent /
// lecture-pause / suivant. Cotes relevées sur la capture Apple de Tahoe 26
// (module 139 pt) : vignette 40 pt à 13,5 pt du bord, « Not Playing » 13 pt
// semibold (haut des capitales à 74 pt), commandes centrées à 29 pt des bords
// et à 29 pt du bas ; ⏮/⏭ ~21 pt de large, ▶ ~19 pt de haut, en "vibrancy".
CCTile {
    id: np

    // Lecteur affiché : celui qui joue, sinon le premier qui peut être piloté
    readonly property var players: Mpris.players.values
    readonly property MprisPlayer player: players.find(p => p.isPlaying) ?? players.find(p => p.canControl) ?? null
    // Lecteur lancé par ▶ quand aucun lecteur MPRIS n'est ouvert
    readonly property string fallbackApp: "spotify"
    // Apps.all : dépendance explicite (byId n'est pas réactif, les entrées
    // .desktop arrivent après le démarrage)
    readonly property bool fallbackAvailable: Apps.all.length > 0 && !!Apps.entryFor(fallbackApp)
    readonly property bool hasTrack: !!player && (player.trackTitle ?? "") !== ""

    implicitWidth: CCStyle.span(2)
    implicitHeight: CCStyle.span(2)
    radius: CCStyle.radiusLarge
    interactive: false

    // Vignette vide (verre plus clair) et pochette par-dessus. La vignette est
    // un simple Rectangle : un ClippingRectangle translucide rend ici un carré
    // sombre aux coins crénelés.
    Rectangle {
        x: art.x
        y: art.y
        width: art.width
        height: art.height
        radius: art.radius
        color: Qt.rgba(1, 1, 1, 0.13)
    }
    ClippingRectangle {
        id: art
        x: 13.5
        y: 13.5
        width: 40
        height: 40
        radius: 8
        color: "transparent"

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
        y: np.hasTrack ? 62 : 71
        width: parent.width - 2 * x
        spacing: 1
        Text {
            renderType: Text.NativeRendering
            width: parent.width
            text: np.hasTrack ? np.player.trackTitle : "Not Playing"
            color: CCStyle.text
            font.family: Theme.font
            font.letterSpacing: CCStyle.tracking
            font.pixelSize: CCStyle.titleSize
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Text {
            renderType: Text.NativeRendering
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
        property int glyph: 26
        property bool active: true
        signal activated()
        width: 40
        height: 34
        // Vibrancy : blanc translucide (prend la teinte du fond), atténué
        // quand la commande est indisponible. Symbol ignore l'alpha de sa
        // couleur (colorisation MultiEffect) : la transparence passe par opacity.
        Symbol {
            anchors.centerIn: parent
            name: ctl.symbol
            size: ctl.glyph
            color: CCStyle.text
            opacity: (ctl.active ? CCStyle.vibrant.a : CCStyle.vibrantDim.a) * (cma.pressed ? 0.6 : 1)
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
        x: 29 - width / 2
        y: np.height - 29 - height / 2
        symbol: "backward.fill"
        glyph: 26
        active: np.hasTrack && np.player.canGoPrevious
        onActivated: np.player.previous()
    }
    Ctl {
        x: np.width / 2 - width / 2
        y: np.height - 29 - height / 2
        symbol: np.player?.isPlaying ? "pause.fill" : "play.fill"
        glyph: 27
        // Sans lecteur, Tahoe garde ▶ actif (il lance Musique) : ici, le
        // lecteur de musique épinglé au Dock (Spotify) s'il est installé.
        readonly property bool canToggle: !!np.player && np.player.canTogglePlaying
        active: canToggle || (!np.hasTrack && np.fallbackAvailable)
        onActivated: {
            if (canToggle) np.player.togglePlaying();
            else { Apps.launch(np.fallbackApp); ShellState.close(); }
        }
    }
    Ctl {
        x: np.width - 29 - width / 2
        y: np.height - 29 - height / 2
        symbol: "forward.fill"
        glyph: 26
        active: np.hasTrack && np.player.canGoNext
        onActivated: np.player.next()
    }
}
