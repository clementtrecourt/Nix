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

    DetailHeader { title: "Recopie de l’écran" }

    Item {
        width: parent.width
        height: 40
        Text {
            renderType: Text.CurveRendering
            x: 16
            width: parent.width - 32
            anchors.verticalCenter: parent.verticalCenter
            text: "Aucun appareil disponible"
            color: CCStyle.textSecondary
            font.family: Theme.font
            font.letterSpacing: CCStyle.tracking
            font.pixelSize: CCStyle.rowSize
            elide: Text.ElideRight
        }
    }

    DetailFooter {
        text: "Réglages des écrans…"
        onClicked: {
            CCActions.openSettings("display");
            ShellState.close();
        }
    }
}
