import QtQuick
import qs.common

// Barre sous la barre d'outils du Finder de Tahoe :
//  - recherche : « Search:  This Mac  “dossier” » (portée, la choisie sur une
//    pastille grise), « Save » et « + » à droite ;
//  - Corbeille : « Trash » à gauche, bouton « Empty » à droite.
Item {
    id: root
    required property var fw

    Rectangle { anchors.fill: parent; color: FStyle.contentBg }
    Rectangle { y: parent.height - 1; width: parent.width; height: 1; color: FStyle.gridLine }

    // Bouton capsule de la barre (pastille grise si choisi / bouton poussoir)
    component BarButton: Rectangle {
        id: b
        property string text: ""
        property string symbol: ""
        property bool chosen: false
        property bool push: false
        property bool enabledButton: true
        signal clicked()
        height: 22
        width: symbol ? 26 : Math.ceil(t.implicitWidth) + 20
        radius: height / 2
        color: push ? (ma.pressed ? FStyle.toolSelected : (Theme.dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.06)))
                    : (chosen || ma.pressed ? FStyle.toolSelected : (ma.containsMouse ? FStyle.toolHover : "transparent"))
        opacity: enabledButton ? 1 : 0.4
        Text {
            id: t
            visible: !b.symbol
            anchors.centerIn: parent
            text: b.text
            font.family: Theme.font
            font.pixelSize: 12
            font.weight: b.chosen ? Font.DemiBold : Font.Normal
            color: Theme.label
        }
        Symbol {
            visible: !!b.symbol
            x: Math.round((parent.width - width) / 2)
            y: Math.round((parent.height - height) / 2)
            name: b.symbol
            size: 12
            color: Theme.label
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            enabled: b.enabledButton
            onClicked: b.clicked()
        }
    }

    // ---- Recherche ----
    Row {
        visible: root.fw.subBar === "search"
        x: 14
        y: Math.round((parent.height - 1 - height) / 2)
        spacing: 6
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Search:"
            font.family: Theme.font
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: FStyle.secondaryText
        }
        BarButton {
            text: "This Mac"
            chosen: root.fw.searchScope === "mac"
            onClicked: root.fw.searchScope = "mac"
        }
        BarButton {
            text: "“" + Fs.displayName(root.fw.path) + "”"
            chosen: root.fw.searchScope === "folder"
            onClicked: root.fw.searchScope = "folder"
        }
    }
    Row {
        visible: root.fw.subBar === "search"
        anchors.right: parent.right
        anchors.rightMargin: 12
        y: Math.round((parent.height - 1 - height) / 2)
        spacing: 6
        BarButton { text: "Save"; push: true; enabledButton: false }
        BarButton { symbol: "plus"; push: true; enabledButton: false }
    }

    // ---- Corbeille ----
    Text {
        visible: root.fw.subBar === "trash"
        x: 14
        y: Math.round((parent.height - 1 - height) / 2)
        text: "Trash"
        font.family: Theme.font
        font.pixelSize: 13
        font.weight: Font.Bold
        color: Theme.label
    }
    BarButton {
        visible: root.fw.subBar === "trash"
        anchors.right: parent.right
        anchors.rightMargin: 12
        y: Math.round((parent.height - 1 - height) / 2)
        text: "Empty"
        push: true
        enabledButton: root.fw.lister.entries.length > 0
        onClicked: Fs.emptyTrash()
    }
}
