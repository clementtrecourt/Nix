import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.common
import qs.services

// Bannières de notification macOS : en haut à droite, sous la barre des menus,
// une carte par application (les notifications d'une même app s'empilent).
// Entrée : glisse depuis le bord droit (ressort amorti). Sortie : repart vers la
// droite en accélérant. Survol = pause du minuteur ; glisser vers la droite = ranger.
PanelWindow {
    id: win

    // Écran actif (macOS affiche les bannières sur l'écran principal / actif)
    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

    readonly property int cardWidth: 344
    // Mesuré sur les images Apple de macOS 26 : bord droit à ~16 pt de l'écran,
    // haut de la bannière à ~33 pt du milieu du texte de la barre des menus.
    readonly property int edgeMargin: 16      // marge au bord droit de l'écran
    readonly property int leftRoom: 24        // place pour le × (à cheval) et l'ombre
    readonly property int topGap: 17          // espace sous la barre des menus

    // Liquid Glass : les cartes réfractent une capture de l'écran prise juste
    // avant l'apparition de la première bannière. La fenêtre n'est mappée que
    // s'il y a des bannières (ou pendant l'animation de sortie de la dernière) :
    // sinon la capture la contiendrait elle-même.
    readonly property bool hasBanners: NotifStore.bannerModel.count > 0
    onHasBannersChanged: if (!hasBanners) exitHold.restart()
    Timer {
        id: exitHold
        interval: 420 * NotifStore.slow
    }
    property Item glassBackdrop: backdrop
    GlassBackdrop {
        id: backdrop
        mode: "snapshot"
        screen: win.screen
        // Ouverture du Centre de notifications : bannières retirées sans animation
        // (sinon elles apparaîtraient dans la capture de fond du Centre)
        want: (win.hasBanners || exitHold.running) && !NotifStore.centerOpen
    }
    visible: backdrop.pass

    // "macos-lg-*" : pas de flou Hyprland (le verre floute et réfracte lui-même)
    WlrLayershell.namespace: "macos-lg-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    // Clavier seulement pendant une réponse en ligne
    WlrLayershell.keyboardFocus: NotifStore.replying && NotifStore.replying.popup
                                 ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; right: true }
    margins.top: Theme.menuBarHeight
    implicitWidth: cardWidth + edgeMargin + leftRoom
    implicitHeight: Math.max(200, (screen?.height ?? 900) - Theme.menuBarHeight - 120)
    color: "transparent"

    // Seule la zone occupée par les bannières (et le menu Options) capte la souris
    mask: Region {
        item: maskItem
        Region { item: actionMenu }
    }
    Item {
        id: maskItem
        width: win.width
        height: list.count > 0 ? Math.min(win.height, list.y + list.contentHeight + 12) : 0
    }

    // Menu « Options » des bannières (au-dessus de toutes les cartes)
    ActionMenu { id: actionMenu }

    ListView {
        id: list
        x: win.leftRoom
        y: win.topGap
        width: win.cardWidth
        height: win.height - y
        interactive: false
        spacing: 10
        model: NotifStore.bannerModel

        // Arrivée : depuis le bord droit de l'écran, décélération "ressort amorti"
        add: Transition {
            NumberAnimation {
                property: "x"
                from: win.cardWidth + win.edgeMargin + 16
                to: 0
                duration: 520 * NotifStore.slow
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.16, 1.0, 0.3, 1.0, 1, 1]
            }
        }
        // Départ : repart vers la droite en accélérant
        remove: Transition {
            ParallelAnimation {
                NumberAnimation {
                    property: "x"
                    to: win.cardWidth + win.edgeMargin + 30
                    duration: 340 * NotifStore.slow
                    easing.type: Easing.InCubic
                }
                NumberAnimation {
                    property: "opacity"
                    to: 0
                    duration: 340 * NotifStore.slow
                    easing.type: Easing.InQuart
                }
            }
        }
        displaced: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: 380 * NotifStore.slow
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.2, 0.9, 0.25, 1.0, 1, 1]
            }
            NumberAnimation { property: "opacity"; to: 1; duration: Theme.durFast }
        }
        // Au remplacement en tête (même app), on réinitialise x (au cas où un
        // glissement était en cours).
        move: Transition {
            NumberAnimation { properties: "x,y"; duration: 380 * NotifStore.slow; easing.type: Easing.OutCubic }
        }

        delegate: Item {
            id: del
            required property string key
            required property int rev
            required property int index

            width: win.cardWidth
            height: card.implicitHeight

            // Notifications encore en bannière pour cette app (plus récente d'abord)
            readonly property var items: {
                NotifStore.entries;
                return NotifStore.bannerItems(key);
            }
            property var shown: null
            onItemsChanged: {
                if (items.length > 0) {
                    if (shown && shown !== items[0]) bump.restart();
                    shown = items[0];
                }
            }
            // Minuterie remise à zéro seulement quand une notification rejoint ou met
            // à jour CETTE bannière (pas à l'arrivée d'une notification d'une autre app).
            // Temps écoulé compté par pas : la pause (survol, glissement) garde la
            // liaison `running` intacte (Timer.restart() la casserait).
            onRevChanged: elapsed = 0
            property int elapsed: 0
            readonly property bool isAlert: items.some(e => e.urgency >= 2)

            // Minuteur d'affichage (pause au survol / pendant un glissement)
            Timer {
                interval: 100
                repeat: true
                running: !del.isAlert && !card.hovered && !drag.active && del.items.length > 0
                onTriggered: {
                    del.elapsed += interval;
                    if (del.elapsed >= NotifStore.bannerDuration) NotifStore.hideBanner(del.key);
                }
            }

            NotificationCard {
                id: card
                x: drag.active ? Math.max(0, drag.translation.x) : 0
                Behavior on x {
                    enabled: !drag.active
                    NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                }
                entry: del.shown
                menuHost: actionMenu
                stackCount: Math.max(1, del.items.length)
                clearAllMode: del.items.length > 1
                onClicked: if (entry) NotifStore.activate(entry)
                onCloseClicked: {
                    if (del.items.length > 1) for (const e of del.items) NotifStore.dismiss(e);
                    else if (entry) NotifStore.dismiss(entry);
                }

                // Petit "rebond" quand une nouvelle notification rejoint la pile
                transform: Scale {
                    id: bumpScale
                    origin.x: card.width / 2
                    origin.y: 0
                }
                SequentialAnimation {
                    id: bump
                    NumberAnimation { target: bumpScale; properties: "xScale,yScale"; to: 0.97; duration: 90; easing.type: Easing.OutQuad }
                    NumberAnimation { target: bumpScale; properties: "xScale,yScale"; to: 1.0; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
                }

                DragHandler {
                    id: drag
                    target: null
                    xAxis.enabled: true
                    yAxis.enabled: false
                    onActiveChanged: if (!active && translation.x > 70) NotifStore.hideBanner(del.key)
                }
            }
        }
    }
}
