import QtQuick
import qs.common

// En-tête de section entre deux groupes (13 pt gras) : centre à 38 pt sous le
// groupe précédent, 18 pt au-dessus du suivant (espacement de colonne 10 pt
// compris). `detail` : texte secondaire à droite (« Show All (34) »).
Item {
    id: root

    property string text
    property string detail
    signal detailClicked()

    width: parent ? parent.width : 0
    height: 36

    Text {
        x: SStyle.pad
        anchors.verticalCenter: parent.top
        anchors.verticalCenterOffset: 28
        text: root.text
        font.family: Theme.font
        font.pixelSize: SStyle.body
        font.weight: Font.Bold
        color: SStyle.label
    }
    Text {
        anchors.right: parent.right
        anchors.rightMargin: SStyle.pad
        anchors.verticalCenter: parent.top
        anchors.verticalCenterOffset: 28
        visible: root.detail !== ""
        text: root.detail
        font.family: Theme.font
        font.pixelSize: SStyle.body
        color: SStyle.secondary
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            onClicked: root.detailClicked()
        }
    }
}
