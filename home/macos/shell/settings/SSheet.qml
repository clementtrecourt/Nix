import QtQuick
import qs.common

// Feuille modale de Tahoe (Details…, Night Shift…, mot de passe Wi‑Fi…).
// Déclarée dans un panneau, mais dessinée dans la couche `overlay` de la
// fenêtre (SheetView, créée à la première ouverture : un élément reparenté
// depuis le panneau défilant n'est pas redessiné). Le contenu est un
// Component (`body`), instancié dans la feuille.
Item {
    id: root

    property bool shown: false
    property real sheetWidth: 440
    property string doneText: "Done"
    property string cancelText: ""
    property bool doneEnabled: true
    property Component body: null
    signal done()
    signal cancelled()

    visible: false
    width: 0
    height: 0

    property var _view: null
    onShownChanged: {
        if (!shown || _view) return;
        const host = Nav.window ? Nav.window.overlay : null;
        if (host) _view = viewComp.createObject(host, { sheet: root });
    }
    Component.onDestruction: if (_view) _view.destroy()
    Component { id: viewComp; SheetView {} }
}
