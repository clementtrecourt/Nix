import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Widget Calendrier « À venir » (moyen, 344×164) façon macOS :
// à gauche le jour (rouge) et la date en grand ; à droite les prochains
// événements (barre de couleur, titre, horaire) ou « Aucun événement aujourd'hui ».
//
// Source des événements (simple, sans serveur CalDAV) : fichier JSON
//   ~/.local/state/quickshell/by-shell/<id>/events.json  (Quickshell.statePath)
//   [{ "date": "2026-11-23", "start": "14:00", "end": "15:00",
//      "title": "Réunion", "color": "#FF9F0A" }, ...]
Item {
    id: w

    property date now: new Date()
    width: 344
    height: 164

    readonly property var dayNames: ["DIMANCHE", "LUNDI", "MARDI", "MERCREDI", "JEUDI", "VENDREDI", "SAMEDI"]
    readonly property string todayIso: Qt.formatDate(now, "yyyy-MM-dd")
    readonly property string nowHm: Qt.formatTime(now, "HH:mm")

    property var allEvents: []
    readonly property var upcoming: allEvents
        .filter(e => e.date === todayIso && (e.end || e.start || "99:99") >= nowHm)
        .sort((a, b) => (a.start || "").localeCompare(b.start || ""))
        .slice(0, 3)

    Timer {
        interval: 30000
        running: w.visible
        repeat: true
        onTriggered: w.now = new Date()
    }

    FileView {
        path: Quickshell.statePath("events.json")
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { w.allEvents = JSON.parse(text()) ?? []; } catch (e) { w.allEvents = []; }
        }
        onLoadFailed: w.allEvents = []
    }

    WidgetTile { anchors.fill: parent }

    // Colonne date
    Column {
        x: 16
        y: 14
        spacing: -2
        Text {
            text: w.dayNames[w.now.getDay()]
            color: Theme.red
            font.family: Theme.font
            font.pixelSize: 11
            font.weight: Font.Bold
            font.letterSpacing: 0.3
        }
        Text {
            text: w.now.getDate()
            color: Theme.label
            font.family: Theme.fontDisplay
            font.pixelSize: 40
            font.weight: Font.Normal
        }
    }

    // Événements
    Column {
        id: evCol
        x: 128
        y: 16
        width: w.width - x - 16
        spacing: 6
        visible: w.upcoming.length > 0
        Repeater {
            model: w.upcoming
            Item {
                required property var modelData
                width: evCol.width
                height: 36
                Rectangle {
                    width: 4
                    height: parent.height
                    radius: 2
                    color: modelData.color || Theme.accent
                }
                Rectangle {
                    anchors.fill: parent
                    radius: 5
                    color: Qt.alpha(modelData.color || Theme.accent, 0.18)
                }
                Column {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 14
                    Text {
                        width: parent.width
                        text: modelData.title || ""
                        color: Theme.label
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        text: (modelData.start || "") + (modelData.end ? " – " + modelData.end : "")
                        color: Theme.labelSecondary
                        font.family: Theme.font
                        font.pixelSize: 11
                    }
                }
            }
        }
    }

    Text {
        visible: w.upcoming.length === 0
        x: 128
        width: w.width - x - 16
        anchors.verticalCenter: parent.verticalCenter
        text: "Aucun événement aujourd'hui"
        color: Theme.labelSecondary
        font.family: Theme.font
        font.pixelSize: 13
        font.weight: Font.Medium
        wrapMode: Text.Wrap
    }
}
