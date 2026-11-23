import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Widget Calendrier « À venir » (moyen, 344×164) façon macOS Tahoe (mesuré sur
// l'image Apple « Notifications and widgets in Notification Center ») :
//  - en haut à gauche le jour (rouge) et la date en grand ;
//  - les événements sur deux colonnes : 2 sous la date, puis jusqu'à 4 à droite ;
//    chacun dans une pilule teintée de sa couleur, avec une barre verticale, le
//    titre en gras et l'horaire dans une teinte foncée (claire en mode sombre) ;
//  - sans autre événement aujourd'hui : « Aucun autre événement aujourd’hui » sous
//    la date, et les événements de demain à droite (en-tête « DEMAIN »).
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
    readonly property string tomorrowIso: Qt.formatDate(new Date(now.getTime() + 86400000), "yyyy-MM-dd")
    readonly property string nowHm: Qt.formatTime(now, "HH:mm")

    property var allEvents: []
    function sorted(l) { return l.slice().sort((a, b) => (a.start || "").localeCompare(b.start || "")); }
    readonly property var todayAll: allEvents.filter(e => e.date === todayIso)
    readonly property var upcoming: sorted(todayAll.filter(e => (e.end || e.start || "99:99") >= nowHm))
    readonly property var tomorrow: upcoming.length ? [] : sorted(allEvents.filter(e => e.date === tomorrowIso))
    // Répartition : 2 sous la date, le reste (4 max) à droite
    readonly property var leftEvents: upcoming.slice(0, 2)
    readonly property var rightEvents: upcoming.length ? upcoming.slice(2, 6) : tomorrow.slice(0, 3)

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

    // Jour et date
    Text {
        x: 18
        y: 15
        text: w.dayNames[w.now.getDay()]
        color: Theme.red
        font.family: Theme.font
        font.pixelSize: 11
        font.weight: Font.Bold
        font.letterSpacing: 0.3
    }
    Text {
        x: 17
        y: 29
        text: w.now.getDate()
        color: Theme.label
        font.family: Theme.fontDisplay
        font.pixelSize: 32
        font.weight: Font.Normal
    }

    // Colonne gauche (sous la date)
    Column {
        x: 18
        y: 73
        width: 146
        spacing: 5
        Repeater {
            model: w.leftEvents
            EventPill { required property var modelData; event: modelData; width: 146; height: 27 }
        }
    }
    Text {
        visible: w.upcoming.length === 0
        x: 18
        y: 76
        width: 146
        text: w.todayAll.length ? "Aucun autre événement aujourd’hui" : "Aucun événement aujourd’hui"
        color: Theme.labelSecondary
        font.family: Theme.font
        font.pixelSize: 12
        font.weight: Font.Medium
        wrapMode: Text.Wrap
    }

    // Colonne droite
    Column {
        x: 180
        y: 18
        width: 146
        spacing: 4
        Text {
            visible: w.upcoming.length === 0 && w.tomorrow.length > 0
            text: "DEMAIN"
            color: Theme.labelSecondary
            font.family: Theme.font
            font.pixelSize: 11
            font.weight: Font.Bold
            font.letterSpacing: 0.3
            bottomPadding: 2
        }
        Repeater {
            model: w.rightEvents
            EventPill { required property var modelData; event: modelData; width: 146; height: 28 }
        }
    }

    // Pilule d'événement : fond teinté, barre de couleur, titre gras + horaire
    component EventPill: Item {
        id: pill
        property var event: ({})
        readonly property color base: event.color || Theme.accent
        // Texte : teinte foncée de la couleur (claire en mode sombre)
        readonly property color ink: Theme.dark ? Qt.lighter(base, 1.25) : Qt.darker(base, 1.65)
        Rectangle {
            anchors.fill: parent
            radius: 5
            color: Qt.alpha(pill.base, Theme.dark ? 0.24 : 0.16)
        }
        Rectangle {
            x: 3
            y: 4
            width: 3
            height: parent.height - 8
            radius: 1.5
            color: pill.base
        }
        Column {
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 14
            spacing: -1
            Text {
                width: parent.width
                text: pill.event.title || ""
                color: pill.ink
                font.family: Theme.font
                font.pixelSize: 12
                font.weight: Font.Bold
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: (pill.event.start || "") + (pill.event.end ? "–" + pill.event.end : "")
                color: pill.ink
                opacity: 0.9
                font.family: Theme.font
                font.pixelSize: 11
                font.weight: Font.Medium
                font.features: { "tnum": 1 }
            }
        }
    }
}
