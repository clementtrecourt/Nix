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
//  - sans autre événement aujourd'hui : « No more events today » sous
//    la date, et les événements de demain à droite (en-tête « TOMORROW »).
//
// Source des événements (simple, sans serveur CalDAV) : fichier JSON
//   ~/.local/state/quickshell/by-shell/<id>/events.json  (Quickshell.statePath)
//   [{ "date": "2026-11-23", "start": "14:00", "end": "15:00",
//      "title": "Meeting", "color": "#FF9F0A" }, ...]
Item {
    id: w

    property date now: new Date()
    width: 344
    height: 164

    readonly property var dayNames: ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"]
    readonly property string todayIso: Qt.formatDate(now, "yyyy-MM-dd")
    readonly property string tomorrowIso: Qt.formatDate(new Date(now.getTime() + 86400000), "yyyy-MM-dd")
    readonly property string nowHm: Qt.formatTime(now, "HH:mm")

    // Horaire au format du widget macOS (image Apple, macOS 26) : « 1 – 1:30PM »,
    // « 5:30 – 7PM », « 11:30AM – 1PM » : pas de « :00 » aux heures pleines,
    // AM/PM collé au chiffre, en petites capitales réduites, une seule fois si
    // la plage ne change pas de demi-journée. Texte riche (taille de AM/PM).
    function hm(t) {
        const [h, m] = String(t).split(":").map(Number);
        return { t: (h % 12 || 12) + (m ? ":" + String(m).padStart(2, "0") : ""), p: h < 12 ? "AM" : "PM" };
    }
    function ampm(p) { return "<span style=\"font-size:8px\">" + p + "</span>"; }
    function timeRange(start, end) {
        if (!start) return "";
        const a = hm(start);
        if (!end) return a.t + ampm(a.p);
        const b = hm(end);
        const dash = "\u2009–\u2009";
        return a.p === b.p ? a.t + dash + b.t + ampm(b.p) : a.t + ampm(a.p) + dash + b.t + ampm(b.p);
    }

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
        spacing: 6
        Repeater {
            model: w.leftEvents
            EventPill { required property var modelData; event: modelData; width: 146; height: 26 }
        }
    }
    Text {
        visible: w.upcoming.length === 0
        x: 18
        y: 76
        width: 146
        text: w.todayAll.length ? "No more events today" : "No events today"
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
        spacing: 6
        Text {
            visible: w.upcoming.length === 0 && w.tomorrow.length > 0
            text: "TOMORROW"
            color: Theme.labelSecondary
            font.family: Theme.font
            font.pixelSize: 11
            font.weight: Font.Bold
            font.letterSpacing: 0.3
            bottomPadding: 2
        }
        Repeater {
            model: w.rightEvents
            EventPill { required property var modelData; event: modelData; width: 146; height: 26 }
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
                text: w.timeRange(pill.event.start, pill.event.end)
                textFormat: Text.RichText
                color: pill.ink
                opacity: 0.9
                font.family: Theme.font
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
        }
    }
}
