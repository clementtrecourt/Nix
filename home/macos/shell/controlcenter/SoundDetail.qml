import QtQuick
import Quickshell
import qs.common
import qs.services

// Module Son déplié : curseur de volume, liste des sorties (la sortie active a
// sa pastille bleue), lien vers les réglages.
Column {
    id: root

    width: CCStyle.width

    DetailHeader { title: "Sound" }

    Item {
        width: parent.width
        height: 34
        Symbol {
            x: 21 - width / 2
            anchors.verticalCenter: parent.verticalCenter
            name: Audio.muted ? "speaker.slash.fill" : "speaker.fill"
            size: 18
            color: CCStyle.text
        }
        CCSlider {
            x: 31.5
            width: parent.width - 31.5 - 35
            anchors.verticalCenter: parent.verticalCenter
            value: Audio.muted ? 0 : Audio.volume
            onMoved: v => Audio.setVolume(v)
        }
        Symbol {
            x: parent.width - 21 - width / 2
            anchors.verticalCenter: parent.verticalCenter
            name: "speaker.wave.3.fill"
            size: 20
            color: CCStyle.text
        }
    }

    DetailCaption { text: "Output" }
    Repeater {
        model: Audio.outputs
        DetailRow {
            required property var modelData
            symbol: Audio.iconOf(modelData)
            text: Audio.nameOf(modelData)
            active: modelData === Audio.sink
            onClicked: Audio.setDefault(modelData)
        }
    }

    DetailFooter {
        text: "Sound Settings…"
        onClicked: {
            CCActions.openSettings("sound");
            ShellState.close();
        }
    }
}
