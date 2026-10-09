import QtQuick
import QtQuick.Layouts

GridLayout {
    required property bool vertical
    property string align: "start"

    columns: vertical ? 1 : 100
    rowSpacing: 10
    columnSpacing: 10

    anchors {
        top: vertical && align === "start" ? parent.top : undefined
        bottom: vertical && align === "end" ? parent.bottom : undefined
        left: !vertical && align === "start" ? parent.left : undefined
        right: !vertical && align === "end" ? parent.right : undefined
        verticalCenter: (!vertical || align === "center") ? parent.verticalCenter : undefined
        horizontalCenter: (vertical || align === "center") ? parent.horizontalCenter : undefined
        margins: 10
    }
}
