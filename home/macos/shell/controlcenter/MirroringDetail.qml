import QtQuick
import Quickshell
import qs.common
import qs.services

// Module Recopie de l'écran déplié (Tahoe : liste des récepteurs AirPlay).
// AirPlay n'existe pas ici : la liste reste vide, avec le lien vers les
// réglages des écrans comme sur macOS.
Column {
    id: root

    width: CCStyle.width

    DetailHeader { title: "Screen Mirroring" }

    Item {
        width: parent.width
        height: 40
        Text {
            renderType: Text.CurveRendering
            x: 16
            width: parent.width - 32
            anchors.verticalCenter: parent.verticalCenter
            text: "No Devices Available"
            color: CCStyle.textSecondary
            font.family: Theme.font
            font.letterSpacing: CCStyle.tracking
            font.pixelSize: CCStyle.rowSize
            elide: Text.ElideRight
        }
    }

    DetailFooter {
        text: "Displays Settings…"
        onClicked: {
            CCActions.openSettings("display");
            ShellState.close();
        }
    }
}
