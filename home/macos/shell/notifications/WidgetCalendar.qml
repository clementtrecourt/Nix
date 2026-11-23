import QtQuick
import qs.common

// Widget Calendrier « Mois » (petit, 164×164), façon macOS Tahoe :
// nom du mois en rouge, initiales des jours, grille des dates, aujourd'hui dans
// une pastille rouge, week-ends atténués.
Item {
    id: w

    property date today: new Date()
    width: 164
    height: 164

    readonly property int year: today.getFullYear()
    readonly property int month: today.getMonth()
    // Lundi = premier jour (locale française)
    readonly property int firstOffset: (new Date(year, month, 1).getDay() + 6) % 7
    readonly property int daysInMonth: new Date(year, month + 1, 0).getDate()
    readonly property int rows: Math.ceil((firstOffset + daysInMonth) / 7)
    readonly property var monthNames: ["JANVIER", "FÉVRIER", "MARS", "AVRIL", "MAI", "JUIN", "JUILLET",
                                       "AOÛT", "SEPTEMBRE", "OCTOBRE", "NOVEMBRE", "DÉCEMBRE"]

    WidgetTile { anchors.fill: parent }

    Text {
        id: monthLabel
        x: 15
        y: 12
        text: w.monthNames[w.month]
        color: Theme.red
        font.family: Theme.font
        font.pixelSize: 11
        font.weight: Font.Bold
        font.letterSpacing: 0.3
    }

    Grid {
        id: grid
        x: 9
        y: monthLabel.y + monthLabel.height + 6
        columns: 7
        columnSpacing: 0
        rowSpacing: 0
        readonly property real cellW: (w.width - 18) / 7
        readonly property real cellH: Math.min(18, (w.height - y - 10) / (w.rows + 1))

        // Initiales des jours
        Repeater {
            model: ["L", "M", "M", "J", "V", "S", "D"]
            Text {
                required property string modelData
                required property int index
                width: grid.cellW
                height: grid.cellH
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: modelData
                color: index >= 5 ? Theme.labelTertiary : Theme.labelSecondary
                font.family: Theme.font
                font.pixelSize: 9
                font.weight: Font.Bold
            }
        }
        // Dates
        Repeater {
            model: w.rows * 7
            Item {
                required property int index
                readonly property int day: index - w.firstOffset + 1
                readonly property bool valid: day >= 1 && day <= w.daysInMonth
                readonly property bool isToday: valid && day === w.today.getDate()
                readonly property bool weekend: index % 7 >= 5
                width: grid.cellW
                height: grid.cellH
                Rectangle {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    radius: 9
                    color: Theme.red
                    visible: parent.isToday
                }
                Text {
                    anchors.centerIn: parent
                    visible: parent.valid
                    text: parent.day
                    color: parent.isToday ? "white" : (parent.weekend ? Theme.labelSecondary : Theme.label)
                    font.family: Theme.font
                    font.pixelSize: 10
                    font.weight: parent.isToday ? Font.Bold : Font.DemiBold
                    font.features: { "tnum": 1 }
                }
            }
        }
    }
}
