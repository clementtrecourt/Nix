import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.common
import qs.services

// Module 2x2 "Now Playing" : pochette, titre, artiste, précédent /
// lecture-pause / suivant. Cotes relevées sur la capture Apple de Tahoe 26
// (module 139 pt, 1,96 px/pt) : vignette 40 pt à 13,8 pt du bord, « Not
// Playing » 13 pt semibold (haut des capitales à 77 pt), ⏮ / ⏭ centrés à 32 pt
// des bords, commandes centrées à ~26 pt du bas ; en "vibrancy".
// Titre / artiste trop longs : ni « … » ni coupure de mot, le texte est rogné
// et défile (Tahoe : « Black Country, New Rc », « usic To Refine To fea »).
// Écran 1x : positions arrondies au pixel.
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
    // Le défilement ne tourne que quand le module est affiché
    readonly property bool shownOnScreen: QsWindow.window?.visible ?? false

    implicitWidth: CCStyle.span(2)
    implicitHeight: CCStyle.span(2)
    radius: CCStyle.radiusLarge
    interactive: false

    // Cadre de la vignette (40 pt) : pochette au format de l'image (Tahoe garde
    // le format : vignette vidéo paysage centrée dans le cadre)
    readonly property int artBox: 40
    // Tahoe : vignette à 13,8 pt des bords (14 ici)
    readonly property int artX: 14
    readonly property int artY: 14

    // Vignette vide (verre plus clair) tant qu'il n'y a pas de pochette.
    // Simple Rectangle : un ClippingRectangle translucide rend ici un carré
    // sombre aux coins crénelés.
    Rectangle {
        x: np.artX
        y: np.artY
        width: np.artBox
        height: np.artBox
        radius: 8
        color: Qt.rgba(1, 1, 1, 0.13)
        visible: artImg.status !== Image.Ready
    }
    ClippingRectangle {
        id: art
        readonly property real aspect: artImg.implicitHeight > 0 ? artImg.implicitWidth / artImg.implicitHeight : 1
        width: aspect >= 1 ? np.artBox : Math.round(np.artBox * aspect)
        height: aspect >= 1 ? Math.round(np.artBox / aspect) : np.artBox
        x: np.artX + Math.round((np.artBox - width) / 2)
        y: np.artY + Math.round((np.artBox - height) / 2)
        radius: Math.min(8, Math.min(width, height) / 4)
        color: "transparent"
        visible: artImg.status === Image.Ready

        Image {
            id: artImg
            anchors.fill: parent
            source: np.player?.trackArtUrl ?? ""
            // 1x : image décodée à sa taille d'affichage (net, sans
            // redimensionnement au rendu) ; le format d'origine est gardé
            sourceSize: Qt.size(np.artBox, np.artBox)
            fillMode: Image.Stretch
            asynchronous: true
        }
        MouseArea {
            anchors.fill: parent
            enabled: !!np.player && np.player.canRaise
            onClicked: { np.player.raise(); ShellState.close(); }
        }
    }

    // Texte rogné qui défile s'il dépasse (aller simple vers la gauche, pause
    // au début, reprise en boucle avec une copie à la suite)
    component Marquee: Item {
        id: mq
        property string text
        property color color: CCStyle.text
        property int pixelSize: CCStyle.titleSize
        property int weight: Font.Normal
        // Retrait du texte au repos dans la zone rognée
        property int inset: 0
        property bool running: false
        readonly property bool overflow: label.implicitWidth > width - inset
        readonly property int gap: 28
        implicitHeight: label.implicitHeight
        clip: true

        Item {
            id: strip
            x: mq.inset
            height: parent.height
            Text {
                id: label
                renderType: Text.NativeRendering
                text: mq.text
                color: mq.color
                font.family: Theme.font
                font.letterSpacing: CCStyle.tracking
                font.pixelSize: mq.pixelSize
                font.weight: mq.weight
            }
            Text {
                renderType: Text.NativeRendering
                visible: mq.overflow
                x: label.implicitWidth + mq.gap
                text: mq.text
                color: mq.color
                font: label.font
            }
        }

        SequentialAnimation {
            running: mq.overflow && mq.running
            loops: Animation.Infinite
            onRunningChanged: if (!running) strip.x = mq.inset
            PropertyAction { target: strip; property: "x"; value: mq.inset }
            PauseAnimation { duration: 2500 }
            NumberAnimation {
                target: strip
                property: "x"
                from: mq.inset
                to: mq.inset - Math.round(label.implicitWidth + mq.gap)
                // ~30 pt/s, comme le défilement du Control Center
                duration: Math.round((label.implicitWidth + mq.gap) / 30 * 1000)
            }
        }
        // Retour au début quand le texte change
        onTextChanged: strip.x = inset
    }

    Column {
        // Zone rognée de 10 pt à 10 pt des bords, texte au repos à 13 pt (fût du
        // « N » aligné sur la vignette, à 14 pt) ; haut des capitales de « Not
        // Playing » à 77 pt du haut (Tahoe)
        x: 10
        y: np.hasTrack ? 64 : 73
        width: parent.width - 2 * x
        spacing: 1
        Marquee {
            width: parent.width
            inset: 3
            text: np.hasTrack ? np.player.trackTitle : "Not Playing"
            color: CCStyle.text
            pixelSize: CCStyle.titleSize
            weight: Font.DemiBold
            running: np.shownOnScreen
        }
        Marquee {
            width: parent.width
            inset: 3
            visible: np.hasTrack && text !== ""
            text: np.player?.trackArtist ?? ""
            color: CCStyle.textSecondary
            pixelSize: CCStyle.subtitleSize
            running: np.shownOnScreen
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
            x: Math.round((ctl.width - width) / 2)
            y: Math.round((ctl.height - height) / 2)
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

    readonly property int ctlY: Math.round(np.height - 26 - 34 / 2)
    Ctl {
        x: Math.round(32 - width / 2)
        y: np.ctlY
        symbol: "backward.fill"
        glyph: 26
        active: np.hasTrack && np.player.canGoPrevious
        onActivated: np.player.previous()
    }
    Ctl {
        x: Math.round(np.width / 2 - width / 2)
        y: np.ctlY
        // Pause : barres alignées sur les pixels à 26 pt (nettes en 1x)
        symbol: np.player?.isPlaying ? "cc.pause.fill" : "play.fill"
        glyph: np.player?.isPlaying ? 26 : 27
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
        x: Math.round(np.width - 32 - width / 2)
        y: np.ctlY
        symbol: "forward.fill"
        glyph: 26
        active: np.hasTrack && np.player.canGoNext
        onActivated: np.player.next()
    }
}
