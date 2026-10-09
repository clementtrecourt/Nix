import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick

PanelWindow {
    id: win

    visible: !Notifs.dnd && Notifs.list.values.length > 0
    anchors { top: true; right: true }
    margins { top: Config.notifMargin; right: Config.notifMargin }
    implicitWidth: Config.notifWidth
    implicitHeight: col.implicitHeight
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-notifications"

    Column {
        id: col
        width: parent.width
        spacing: 8

        Repeater {
            model: Notifs.list

            Rectangle {
                id: card
                required property var modelData
                readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
                readonly property string iconSrc: modelData.image !== ""
                    ? modelData.image
                    : (modelData.appIcon !== "" ? Quickshell.iconPath(modelData.appIcon, true) : "")

                width: col.width
                height: content.implicitHeight + 24
                radius: 12
                color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.92)
                border.width: critical ? 2 : 1
                border.color: critical ? Colors.error : Colors.outline

                // expiration (les critiques restent jusqu'à action)
                Timer {
                    running: !card.critical && !hover.hovered
                    interval: card.modelData.expireTimeout > 0
                        ? card.modelData.expireTimeout * 1000 : Config.notifTimeout
                    onTriggered: card.modelData.expire()
                }

                HoverHandler { id: hover }

                // clic sur la carte = fermer
                MouseArea {
                    anchors.fill: parent
                    onClicked: card.modelData.dismiss()
                }

                Row {
                    id: content
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                    spacing: 12

                    Image {
                        visible: card.iconSrc !== ""
                        width: visible ? 40 : 0
                        height: 40
                        source: card.iconSrc
                        fillMode: Image.PreserveAspectFit
                        sourceSize: Qt.size(80, 80)
                    }

                    Column {
                        width: parent.width - (card.iconSrc !== "" ? 52 : 0)
                        spacing: 4

                        Text {
                            width: parent.width
                            text: card.modelData.appName
                            color: Colors.textMuted
                            elide: Text.ElideRight
                            font { family: Config.font; pixelSize: 11 }
                        }
                        Text {
                            width: parent.width
                            text: card.modelData.summary
                            color: Colors.text
                            wrapMode: Text.Wrap
                            font { family: Config.font; pixelSize: 14; weight: Font.DemiBold }
                        }
                        Text {
                            visible: text !== ""
                            width: parent.width
                            text: card.modelData.body
                            color: Colors.textMuted
                            textFormat: Text.StyledText
                            wrapMode: Text.Wrap
                            maximumLineCount: 6
                            elide: Text.ElideRight
                            font { family: Config.font; pixelSize: 12 }
                        }

                        Row {
                            visible: card.modelData.actions.length > 0
                            spacing: 6

                            Repeater {
                                model: card.modelData.actions

                                Rectangle {
                                    id: btn
                                    required property var modelData
                                    width: label.implicitWidth + 20
                                    height: 26
                                    radius: 6
                                    color: Colors.primary

                                    Text {
                                        id: label
                                        anchors.centerIn: parent
                                        text: btn.modelData.text
                                        color: Colors.primaryText
                                        font { family: Config.font; pixelSize: 12 }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: btn.modelData.invoke()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
