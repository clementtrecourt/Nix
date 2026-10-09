import Quickshell
import QtQuick

Text {
    required property bool vertical

    SystemClock { id: clock; precision: SystemClock.Minutes }

    text: Qt.formatDateTime(clock.date, vertical ? "HH\nmm" : "HH:mm")
    color: Colors.text
    horizontalAlignment: Text.AlignHCenter
    font { family: Config.font; pixelSize: 14; weight: Font.Medium }
}
