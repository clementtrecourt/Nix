import QtQuick
import Quickshell
import qs.common
import qs.services

// Module Écran déplié (clic sur "Écran" hors du curseur, comme sur Tahoe) :
// luminosité, Mode sombre, Night Shift, lien vers les réglages des écrans.
Column {
    id: root

    width: CCStyle.width

    DetailHeader { title: "Écran" }

    Item {
        width: parent.width
        height: 34
        Symbol {
            x: 21 - width / 2
            anchors.verticalCenter: parent.verticalCenter
            name: "sun.min.fill"
            size: 16
            color: CCStyle.text
        }
        CCSlider {
            x: 31.5
            width: parent.width - 31.5 - 33
            anchors.verticalCenter: parent.verticalCenter
            value: Brightness.value
            interactive: Brightness.available
            opacity: Brightness.available ? 1 : CCStyle.disabledOpacity
            onMoved: v => Brightness.set(v)
        }
        Symbol {
            x: parent.width - 21 - width / 2
            anchors.verticalCenter: parent.verticalCenter
            name: "sun.max.fill"
            size: 17
            color: CCStyle.text
        }
    }

    Item { width: 1; height: 6 }

    DetailRow {
        symbol: "circle.lefthalf.filled"
        glyphSize: 15
        text: "Mode sombre"
        active: Theme.dark
        onClicked: Appearance.toggle()
    }
    DetailRow {
        symbol: "sun.max.fill"
        glyphSize: 15
        text: "Night Shift"
        detail: NightShift.available ? "" : "Indisponible"
        active: NightShift.on
        activeColor: Theme.orange
        opacity: NightShift.available ? 1 : CCStyle.disabledOpacity
        onClicked: NightShift.toggle()
    }

    DetailFooter {
        text: "Réglages des écrans…"
        onClicked: {
            CCActions.openSettings("display");
            ShellState.close();
        }
    }
}
