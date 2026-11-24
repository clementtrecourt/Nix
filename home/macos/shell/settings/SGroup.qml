import QtQuick

// Section arrondie du formulaire groupé de Tahoe (fond gris très léger sur le
// fond blanc de la fenêtre, coins de 13 pt) ; les lignes (SRow) s'empilent et
// tracent elles-mêmes leur séparateur.
Rectangle {
    id: root

    default property alias content: col.data
    property alias spacing: col.spacing

    width: parent ? parent.width : 0
    implicitHeight: col.implicitHeight
    height: implicitHeight
    radius: SStyle.groupRadius
    color: SStyle.groupFill
    clip: false

    Column {
        id: col
        width: parent.width
    }
}
