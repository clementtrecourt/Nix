import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.common

// Carte de notification macOS Tahoe (bannière et Centre de notifications).
//
//  ┌───────────────────────────────────────────────┐
//  │ [icône]  URGENT (si critique)                  │
//  │          Titre (semi-gras)                 now │
//  │          Corps du message, jusqu'à 4 lignes…   │
//  │                                  [Options ⌄]   │  ← au survol
//  └───────────────────────────────────────────────┘
//    └───────── lamelles de la pile (même app) ──┘
//
// Au survol : bouton × en haut à gauche (à cheval sur le coin) et, si la
// notification a des actions, une capsule en bas à droite : le libellé de
// l'action s'il n'y en a qu'une, sinon « Options ⌄ » qui ouvre le menu des
// actions (ActionMenu, fourni par la fenêtre via `menuHost`) sous la carte.
// La carte ne s'agrandit pas : seul le corps se rétrécit pour laisser la place
// à la capsule. « Reply » (réponse en ligne) ouvre un champ de saisie.
Item {
    id: card

    property NotifEntry entry
    property int stackCount: 1          // nb de notifications de la pile (lamelles)
    property bool closable: true
    property bool interactive: true
    // Le × efface toute la pile (« Clear All » au survol, comme macOS)
    property bool clearAllMode: false
    // Menu des actions de la fenêtre (ActionMenu), null = pas de menu
    property Item menuHost: null
    // Aperçu masqué (System Settings > Notifications > Show previews) : nom de
    // l'app et « Notification », sans le contenu ni l'image
    readonly property bool previewHidden: NotifStore.previewHidden(entry)
    readonly property string shownImage: entry && !previewHidden ? entry.image : ""

    signal clicked()
    signal closeClicked()

    // Pointeur réellement sur la carte (ou sur son ×)
    readonly property bool pointerInside: hover.hovered || closeBtn.containsMouse
    readonly property bool menuOpenHere: !!menuHost && menuHost.card === card && menuHost.open
    readonly property bool hovered: (pointerInside || NotifStore.debugHover || menuOpenHere || replying) && interactive

    // Actions : celles de l'app + « Reply » si l'app accepte une réponse en ligne
    readonly property int actionCount: entry ? entry.actions.length + (entry.canReply ? 1 : 0) : 0
    readonly property bool hasActions: actionCount > 0
    readonly property bool showButton: hasActions && hovered && !replying
    readonly property bool singleAction: actionCount === 1
    readonly property string buttonText: !singleAction ? "Options"
        : (entry.canReply ? "Reply" : entry.actions[0].text)

    // Réponse en ligne en cours
    property bool replying: false
    readonly property real plateHeight: plate.height

    // ---- Géométrie Tahoe (mesurée sur les images Apple de macOS 26) ----
    // Relevé sur l'image Apple « view app notifications » (macOS 26, 1,94 px/pt) :
    // arc d'angle équivalent à un cercle de ~19 pt.
    readonly property int radius: 19
    // Verre laiteux : blanc à ~70 % en clair, gris très sombre translucide en sombre.
    readonly property color tint: Theme.dark ? Qt.rgba(0.11, 0.11, 0.12, 0.52) : Qt.rgba(0.985, 0.985, 0.99, 0.70)
    readonly property int padH: 12
    readonly property int padV: 12
    readonly property int iconSize: 36            // ~32 pt visibles (marge de l'icône)
    readonly property int peek: 9               // dépassement de chaque lamelle
    readonly property int slivers: Math.min(stackCount - 1, 2)
    // Icône « générique » : l'app émettrice est inconnue
    readonly property bool genericIcon: !!entry && entry.appIcon === NotifStore.genericIcon
    readonly property bool timeSensitive: !!entry && entry.urgency >= 2

    width: 344
    implicitHeight: plate.height + stackPeek
    property real stackPeek: slivers * peek
    Behavior on stackPeek { NumberAnimation { duration: Theme.durMed * NotifStore.slow; easing.type: Easing.OutCubic } }

    function openMenu() {
        if (menuHost) menuHost.openFor(card, entry);
    }
    function startReply() {
        replying = true;
        NotifStore.replying = entry;
        Qt.callLater(() => replyInput.forceActiveFocus());
    }
    function cancelReply() {
        replying = false;
        replyInput.text = "";
        if (NotifStore.replying === entry) NotifStore.replying = null;
    }
    function sendReply() {
        const t = replyInput.text.trim();
        if (!t) return;
        const e = entry;
        cancelReply();
        NotifStore.reply(e, t);
    }
    onEntryChanged: if (replying) cancelReply()
    Component.onDestruction: if (replying && NotifStore.replying === entry) NotifStore.replying = null

    // Débogage (pas de souris dans le banc de test) : ouvrir le menu des actions
    Connections {
        target: NotifStore
        function onDebugActionsChanged() {
            if (NotifStore.debugActions && card.hasActions && !card.singleAction && card.visible) card.openMenu();
        }
        function onDebugReplyChanged() {
            if (NotifStore.debugReply && card.entry && card.entry.canReply && card.visible) card.startReply();
            else if (!NotifStore.debugReply && card.replying) card.cancelReply();
        }
    }

    // ---- Lamelles de la pile (derrière) ----
    // Le verre est translucide : chaque lamelle est découpée pour ne montrer que
    // la partie qui dépasse sous la carte (ou la lamelle) précédente.
    Repeater {
        model: 2
        Item {
            id: sliver
            required property int index
            readonly property int level: index + 1
            readonly property bool active: card.slivers >= level
            // Haut de la zone visible : bas de l'élément au-dessus (moins l'arrondi)
            readonly property real clipTop: plate.height + (level - 1) * card.peek - 3
            z: -level
            x: level * 12
            y: clipTop
            width: card.width - level * 2 * 12
            height: card.peek + 3 + 16      // + place pour l'ombre
            clip: true
            visible: opacity > 0
            opacity: active ? (level === 1 ? 0.9 : 0.7) : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durMed * NotifStore.slow } }

            NotifGlass {
                width: parent.width
                height: 44
                // Bas de la lamelle : peek px sous l'élément du dessus
                y: (sliver.active ? card.peek + 3 : 0) - height
                Behavior on y { NumberAnimation { duration: Theme.durMed * NotifStore.slow; easing.type: Easing.OutCubic } }
                radius: card.radius - sliver.level * 4
                tint: card.tint
                // Pas d'ombre propre : elle s'ajouterait à celle de la carte et
                // dépasserait le seuil de flou de Hyprland (halo rectangulaire).
                shadowEnabled: false
            }
        }
    }

    // ---- Plaque principale ----
    NotifGlass {
        id: plate
        width: card.width
        // Hauteur paire (voir NotifGlass)
        height: 2 * Math.ceil((Math.max(card.iconSize, textCol.implicitHeight) + card.padV * 2
                + (card.replying ? replyRow.height + 10 : 0)) / 2)
        radius: card.radius
        tint: card.tint
        Behavior on height { NumberAnimation { duration: Theme.durMed * NotifStore.slow; easing.type: Easing.OutCubic } }

        HoverHandler { id: hover }

        MouseArea {
            anchors.fill: parent
            enabled: card.interactive
            cursorShape: Qt.PointingHandCursor
            onClicked: if (!card.replying) card.clicked()
        }

        // Icône d'app, ou avatar rond + pastille d'app (style "communication")
        Item {
            id: iconBox
            x: card.padH
            width: card.iconSize
            height: card.iconSize
            y: card.padV + (Math.max(card.iconSize, textCol.implicitHeight) - card.iconSize) / 2

            IconImage {
                anchors.fill: parent
                visible: !card.shownImage
                source: card.entry ? card.entry.appIcon : ""
                asynchronous: true
                mipmap: true
            }
            ClippingRectangle {
                visible: !!card.shownImage
                anchors.fill: parent
                anchors.margins: 1
                radius: width / 2
                color: Theme.fill
                Image {
                    anchors.fill: parent
                    source: card.shownImage
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(96, 96)
                    smooth: true
                }
            }
            // Pastille de l'app (seulement si on connaît l'app)
            IconImage {
                visible: !!card.shownImage && !card.genericIcon
                width: 18
                height: 18
                x: parent.width - 14
                y: parent.height - 14
                source: card.entry ? card.entry.appIcon : ""
                asynchronous: true
                mipmap: true
            }
        }

        // Colonne de texte
        ColumnLayout {
            id: textCol
            x: iconBox.x + card.iconSize + 10
            y: card.padV
            width: plate.width - x - card.padH - 2
            spacing: 1

            // Niveau d'interruption « Time Sensitive », petites capitales grises ;
            // l'heure reste sur la première ligne (coin haut droit), comme macOS.
            RowLayout {
                visible: card.timeSensitive
                Layout.fillWidth: true
                Layout.topMargin: 2
                Layout.bottomMargin: 1
                spacing: 6
                Text {
                    Layout.fillWidth: true
                    text: "TIME SENSITIVE"
                    color: Theme.labelSecondary
                    font.family: Theme.font
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                // Au survol (capsule d'action visible), l'heure s'efface (image Apple)
                Text {
                    text: timeLabel.text
                    opacity: card.showButton ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                    color: Theme.labelSecondary
                    font.family: Theme.font
                    font.pixelSize: 12
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text {
                    Layout.fillWidth: true
                    text: !card.entry ? "" : card.previewHidden ? card.entry.appName : (card.entry.summary || card.entry.appName)
                    color: Theme.label
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    textFormat: Text.PlainText
                }
                Text {
                    id: timeLabel
                    visible: !card.timeSensitive
                    opacity: card.showButton ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                    Layout.alignment: Qt.AlignVCenter
                    text: card.entry ? NotifStore.relTime(card.entry.time) : ""
                    color: Theme.labelSecondary
                    font.family: Theme.font
                    font.pixelSize: 12
                }
            }

            // Corps (affiché aussi quand le titre est vide : le titre devient alors le
            // nom de l'app). Au survol, il se rétrécit pour laisser place à la
            // capsule d'action SANS changer de nombre de lignes (la dernière est
            // tronquée « … ») : pas de saut de hauteur de la carte ni de la pile.
            Text {
                id: bodyText
                Layout.preferredWidth: textCol.width - (card.showButton ? actBtn.width + 8 : 0)
                visible: text.length > 0
                text: !card.entry ? "" : card.previewHidden ? "Notification" : card.entry.body
                color: Theme.label
                opacity: 0.92
                font.family: Theme.font
                font.pixelSize: 13
                wrapMode: Text.Wrap
                maximumLineCount: Math.max(1, Math.min(4, bodyMeasure.lineCount))
                elide: Text.ElideRight
                textFormat: Text.PlainText
                lineHeight: 1.04
            }
        }
        // Nombre de lignes du corps en pleine largeur (hors survol)
        Text {
            id: bodyMeasure
            visible: false
            width: textCol.width
            text: bodyText.text
            font: bodyText.font
            wrapMode: Text.Wrap
            maximumLineCount: 4
            textFormat: Text.PlainText
            lineHeight: 1.04
        }

        // ---- Capsule d'action (bas droite) : « Options ⌄ » ou l'action unique ----
        Rectangle {
            id: actBtn
            anchors.right: parent.right
            anchors.rightMargin: 10
            y: Math.max(card.padV + 17, card.padV + Math.max(card.iconSize, textCol.implicitHeight) + 2 - height)
            width: Math.min(150, btnRow.implicitWidth + 22)
            height: 21
            radius: height / 2
            color: btnMouse.pressed ? (Theme.dark ? Qt.rgba(1, 1, 1, 0.26) : Qt.rgba(0, 0, 0, 0.16))
                 : (btnMouse.containsMouse || card.menuOpenHere) ? (Theme.dark ? Qt.rgba(1, 1, 1, 0.19) : Qt.rgba(0, 0, 0, 0.12))
                 : (Theme.dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.075))
            opacity: card.showButton ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }

            Row {
                id: btnRow
                anchors.centerIn: parent
                spacing: 4
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 150 - 22 - (card.singleAction ? 0 : 12))
                    text: card.hasActions ? card.buttonText : ""
                    color: Theme.label
                    font.family: Theme.font
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
                Symbol {
                    visible: !card.singleAction
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 1
                    name: "chevron.down"
                    size: 8
                    color: Theme.label
                }
            }
            MouseArea {
                id: btnMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: card.showButton
                onClicked: {
                    if (!card.singleAction) {
                        if (card.menuOpenHere) card.menuHost.close();
                        else card.openMenu();
                    } else if (card.entry.canReply) card.startReply();
                    else NotifStore.invoke(card.entry, card.entry.actions[0]);
                }
            }
        }

        // ---- Réponse en ligne (Messages, etc.) ----
        Item {
            id: replyRow
            x: textCol.x
            width: textCol.width
            height: 30
            y: card.padV + Math.max(card.iconSize, textCol.implicitHeight) + 10
            visible: opacity > 0
            opacity: card.replying ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Theme.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.65)
                border.width: 1
                border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.12)
            }
            TextInput {
                id: replyInput
                x: 12
                width: parent.width - x - 34
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.label
                selectionColor: Theme.accent
                selectedTextColor: "white"
                font.family: Theme.font
                font.pixelSize: 13
                clip: true
                Keys.onReturnPressed: card.sendReply()
                Keys.onEnterPressed: card.sendReply()
                Keys.onEscapePressed: card.cancelReply()
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !replyInput.text
                    text: card.entry && card.entry.replyPlaceholder ? card.entry.replyPlaceholder : "Reply"
                    color: Theme.labelTertiary
                    font: replyInput.font
                }
            }
            // Bouton d'envoi : flèche blanche dans un disque bleu (Messages)
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                height: 22
                radius: 11
                color: Theme.accent
                opacity: replyInput.text.trim() ? 1 : 0.4
                Symbol {
                    anchors.centerIn: parent
                    name: "arrow.right"
                    rotation: -90
                    size: 12
                    color: "white"
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: card.sendReply()
                }
            }
        }
    }

    // ---- Bouton × (à cheval sur le coin haut-gauche) ----
    CloseButton {
        id: closeBtn
        // Centre à ~(4 ; 6) pt du coin de la carte (image Apple, macOS 26)
        x: -6
        y: -4
        tint: card.tint
        z: 10
        visible: card.closable
        shown: card.hovered || containsMouse
        clearAll: card.clearAllMode
        onTriggered: card.closeClicked()
    }
}
