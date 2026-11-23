import QtQuick
import Quickshell
import qs.common
import qs.services

// Module Concentration déplié : "Ne pas déranger" et ses durées (macOS :
// Pendant 1 heure / Jusqu'à ce soir / Jusqu'à demain matin).
Column {
    id: root

    width: CCStyle.width

    DetailHeader { title: "Concentration" }

    DetailRow {
        symbol: "moon.fill"
        glyphSize: 15
        text: "Ne pas déranger"
        detail: Focus.untilLabel
        active: Focus.doNotDisturb
        onClicked: Focus.toggle()
    }

    component Option: DetailRow {
        showIcon: false
        property bool current: false
        trailingSymbol: current ? "checkmark" : ""
    }

    Item { width: 1; height: 4 }
    DetailCaption { text: "Activer" }
    Option {
        text: "Pendant 1 heure"
        onClicked: Focus.forOneHour()
    }
    Option {
        text: "Jusqu'à ce soir"
        onClicked: Focus.untilTonight()
    }
    Option {
        text: "Jusqu'à demain matin"
        onClicked: Focus.untilTomorrowMorning()
    }

    DetailFooter {
        text: "Réglages Concentration…"
        onClicked: {
            Quickshell.execDetached(["gnome-control-center", "notifications"]);
            ShellState.close();
        }
    }
}
