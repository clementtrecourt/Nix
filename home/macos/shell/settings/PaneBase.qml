import QtQuick

// Racine d'un panneau : colonne de groupes espacés de 10 pt (la fenêtre fixe
// la largeur et transmet `sw`, la fenêtre, et `paneId`).
Column {
    property var sw: null
    property string paneId: ""
    readonly property var spec: Nav.info(paneId)
    spacing: SStyle.groupSpacing
}
