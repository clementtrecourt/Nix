import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    // nom de la layer, utile pour les règles de blur côté mango
    WlrLayershell.namespace: "qs-bar"

    readonly property string pos: Config.barPosition
    readonly property bool vertical: pos === "left" || pos === "right"

    anchors {
        left: pos !== "right"
        right: pos !== "left"
        top: pos !== "bottom"
        bottom: pos !== "top"
    }
    margins {
        left: Config.margin
        right: Config.margin
        top: Config.margin
        bottom: Config.margin
    }
    implicitWidth: vertical ? Config.thickness : 0
    implicitHeight: vertical ? 0 : Config.thickness

    // la fenêtre est transparente, le fond est dessiné dedans
    color: "transparent"

    Item {
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            radius: Config.radius
            color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, Config.opacity)
        }

        Zone {
            vertical: bar.vertical
            align: "start"
            Workspaces {
                vertical: bar.vertical
                screenName: bar.modelData.name
            }
        }

        Zone {
            vertical: bar.vertical
            align: "center"
            Clock { vertical: bar.vertical }
        }

        Zone {
            vertical: bar.vertical
            align: "end"
            Volume {}
        }
    }
}
