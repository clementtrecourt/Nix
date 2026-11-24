import QtQuick
import Quickshell
import qs.common
import qs.session as Session
import qs.finder as Finder

// Barre latérale de Réglages Système (Tahoe 26) : plaque de Liquid Glass
// inset de 8 pt (215 pt de large, coins de 18 pt), feux tricolores, champ
// Search en capsule, carte utilisateur (avatar 38 pt, nom en gras, « NixOS »),
// puis les panneaux par groupes : pastilles de 20 pt, lignes de 32 pt,
// 13 pt de plus entre groupes ; panneau choisi = pilule bleue + texte blanc
// (grise quand la fenêtre n'est pas au premier plan).
Item {
    id: root

    required property var sw            // SettingsWindow
    property Item backdropItem: null

    function focusSearch() { searchInput.forceActiveFocus(); }

    Finder.FinderGlass {
        anchors.fill: parent
        radius: SStyle.sidebarRadius
        backdropItem: root.backdropItem
        tint: Theme.dark ? Qt.rgba(0.14, 0.15, 0.16, 0.62) : Qt.rgba(0.975, 0.975, 0.978, 0.66)
        veil: 0.62
        veilColor: Theme.dark ? Qt.rgba(0.10, 0.115, 0.125, 1) : Qt.rgba(0.976, 0.976, 0.976, 1)
        shadowBlur: 0.55
        shadowColor: Qt.rgba(0, 0, 0, Theme.dark ? 0.30 : 0.07)
        rimColor: Theme.dark ? Qt.rgba(1, 1, 1, 0.26) : Qt.rgba(1, 1, 1, 0.95)
        rimBase: 0.35
        edgeDarken: Theme.dark ? 0.20 : 0.05
        glowColor: Theme.dark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(1, 1, 1, 0.5)
        shadeColor: Theme.dark ? Qt.rgba(0, 0, 0, 0.10) : Qt.rgba(0, 0, 0, 0.02)
    }

    // Glisser la fenêtre par le haut de la barre
    MouseArea {
        width: parent.width
        height: 44
        onPressed: root.sw.startSystemMove()
        onDoubleClicked: root.sw.zoomWindow(false)
    }

    Finder.TrafficLights {
        x: 19 - SStyle.sidebarInset
        y: 20 - SStyle.sidebarInset
        active: root.sw.active
        onCloseClicked: root.sw.closeWindow()
        onMinimizeClicked: root.sw.minimizeWindow()
        onZoomClicked: root.sw.zoomWindow(true)
    }

    // ---- Search ----
    Rectangle {
        id: search
        x: SStyle.searchX
        y: SStyle.searchY
        width: parent.width - 2 * SStyle.searchX
        height: SStyle.searchHeight
        radius: height / 2
        color: SStyle.searchFill
        border.width: searchInput.activeFocus ? 3 : 0
        border.color: Qt.rgba(SStyle.accent.r, SStyle.accent.g, SStyle.accent.b, 0.5)

        Symbol {
            x: 9
            anchors.verticalCenter: parent.verticalCenter
            name: "magnifyingglass"
            size: 14
            color: SStyle.secondary
        }
        TextInput {
            id: searchInput
            x: 29
            width: parent.width - x - (Nav.search ? 26 : 10)
            anchors.verticalCenter: parent.verticalCenter
            font.family: Theme.font
            font.pixelSize: SStyle.body
            color: SStyle.label
            selectByMouse: true
            selectionColor: Qt.rgba(SStyle.accent.r, SStyle.accent.g, SStyle.accent.b, 0.4)
            clip: true
            text: Nav.search
            onTextEdited: Nav.search = text
            Keys.onEscapePressed: { Nav.search = ""; root.sw.focusContent(); }
            Keys.onReturnPressed: { if (Nav.results.length) { Nav.go(Nav.results[0].id); } }
            Keys.onDownPressed: list.forceActiveFocus()
        }
        Text {
            x: 29
            anchors.verticalCenter: parent.verticalCenter
            visible: !searchInput.text
            text: "Search"
            font.family: Theme.font
            font.pixelSize: SStyle.body
            color: SStyle.secondary
        }
        Symbol {
            visible: Nav.search !== ""
            anchors.right: parent.right
            anchors.rightMargin: 7
            anchors.verticalCenter: parent.verticalCenter
            name: "xmark.circle.fill"
            size: 14
            color: SStyle.tertiary
            MouseArea { anchors.fill: parent; anchors.margins: -3; onClicked: Nav.search = "" }
        }
    }

    // ---- Liste ----
    Flickable {
        id: list
        y: search.y + search.height + 6
        width: parent.width
        height: parent.height - y - 6
        clip: true
        contentHeight: col.implicitHeight + 14
        boundsBehavior: Flickable.StopAtBounds
        // Le haut de la liste (carte utilisateur) suit les mesures de la barre
        readonly property real origin: y

        Keys.onUpPressed: root.step(-1)
        Keys.onDownPressed: root.step(1)

        Column {
            id: col
            width: list.width

            // Carte utilisateur
            Item {
                id: card
                visible: !Nav.search
                width: parent.width
                // centre de la carte à cardCenterY depuis le haut de la barre
                height: visible ? (SStyle.firstRowCenterY - 16) - list.origin : 0

                Rectangle {
                    x: SStyle.pillInset
                    width: parent.width - 2 * SStyle.pillInset
                    y: Math.round(SStyle.cardCenterY - list.origin - 26)
                    height: 52
                    radius: 12
                    visible: Nav.pane === "account"
                    color: root.sw.active ? SStyle.selection : SStyle.selectionInactive
                }
                Session.Avatar {
                    x: SStyle.avatarX
                    y: Math.round(SStyle.cardCenterY - list.origin - size / 2)
                    size: SStyle.avatarSize
                    shadow: false
                    source: Users.faceUrl
                    name: Users.fullName
                }
                Column {
                    x: SStyle.cardTextX
                    width: parent.width - x - 10
                    y: Math.round(SStyle.cardCenterY - list.origin - height / 2)
                    spacing: 0
                    Text {
                        width: parent.width
                        text: Users.fullName
                        elide: Text.ElideRight
                        font.family: Theme.font
                        font.pixelSize: SStyle.body
                        font.weight: Font.Bold
                        color: Nav.pane === "account" && root.sw.active ? "#FFFFFF" : SStyle.label
                    }
                    Text {
                        width: parent.width
                        text: "NixOS"
                        elide: Text.ElideRight
                        font.family: Theme.font
                        font.pixelSize: SStyle.small
                        color: Nav.pane === "account" && root.sw.active ? Qt.rgba(1, 1, 1, 0.8) : SStyle.secondary
                    }
                }
                MouseArea {
                    x: SStyle.pillInset
                    width: parent.width - 2 * SStyle.pillInset
                    y: Math.round(SStyle.cardCenterY - list.origin - 26)
                    height: 52
                    onClicked: Nav.go("account")
                }
            }

            Repeater {
                model: Nav.search ? Nav.results : Nav.sidebarPanes

                Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property var prev: index > 0 ? (Nav.search ? Nav.results : Nav.sidebarPanes)[index - 1] : null
                    readonly property bool groupStart: !Nav.search && index > 0 && prev && prev.group !== modelData.group
                    readonly property bool current: Nav.search ? Nav.pane === modelData.id : Nav.sidebarPane === modelData.id
                    width: col.width
                    height: SStyle.row + (groupStart ? SStyle.groupGap : 0)

                    Rectangle {
                        x: SStyle.pillInset
                        width: parent.width - 2 * SStyle.pillInset
                        y: parent.height - SStyle.row
                        height: SStyle.row
                        radius: SStyle.pillRadius
                        visible: row.current
                        color: root.sw.active ? SStyle.selection : SStyle.selectionInactive
                    }
                    PaneIcon {
                        x: SStyle.rowIconCenterX - SStyle.rowIcon / 2
                        y: parent.height - SStyle.row / 2 - SStyle.rowIcon / 2
                        spec: row.modelData
                        size: SStyle.rowIcon
                    }
                    Text {
                        x: SStyle.rowTextX
                        width: parent.width - x - 14
                        y: parent.height - SStyle.row
                        height: SStyle.row
                        verticalAlignment: Text.AlignVCenter
                        text: row.modelData.name
                        elide: Text.ElideRight
                        font.family: Theme.font
                        font.pixelSize: SStyle.sidebarFont
                        color: row.current && root.sw.active ? "#FFFFFF" : SStyle.sidebarText
                    }
                    MouseArea {
                        y: parent.height - SStyle.row
                        width: parent.width
                        height: SStyle.row
                        onClicked: { Nav.go(row.modelData.id); list.forceActiveFocus(); }
                    }
                }
            }
            // Aucun résultat
            Text {
                visible: Nav.search !== "" && Nav.results.length === 0
                width: col.width
                height: 60
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: "No Results"
                font.family: Theme.font
                font.pixelSize: SStyle.body
                color: SStyle.secondary
            }
        }
    }

    function step(d) {
        const l = Nav.search ? Nav.results : Nav.sidebarPanes;
        let i = l.findIndex(p => p.id === (Nav.search ? Nav.pane : Nav.sidebarPane));
        i = Math.max(0, Math.min(l.length - 1, i + d));
        if (l[i]) Nav.go(l[i].id);
    }
}
