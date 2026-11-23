import QtQuick
import Quickshell
import qs.common
import qs.services

// Module Concentration déplié, comme sur Tahoe : la liste des modes (Ne pas
// déranger, Sommeil, Personnel, Travail), chacun avec sa pastille de couleur.
// Clic sur un mode = l'activer (sans limite) / le désactiver. Le bouton « … »
// d'un mode (au survol) déplie ses durées : Pendant 1 heure, Jusqu'à ce soir,
// Jusqu'à demain matin (coche sur l'option en cours).
Column {
    id: root

    width: CCStyle.width

    // Mode dont les durées sont dépliées ("" = aucun)
    property string optionsFor: ""

    DetailHeader { title: "Concentration" }

    component Option: DetailRow {
        id: opt
        property string kind
        property string modeId
        showIcon: false
        indent: 35
        implicitHeight: 30
        readonly property bool current: Focus.doNotDisturb && Focus.mode === modeId && Focus.untilKind === kind
        trailingSymbol: current ? "checkmark" : ""
    }

    Repeater {
        model: Focus.modes

        Column {
            id: modeItem
            required property var modelData
            readonly property bool isActive: Focus.doNotDisturb && Focus.mode === modelData.id
            readonly property bool open: root.optionsFor === modelData.id
            width: root.width

            DetailRow {
                symbol: modeItem.modelData.symbol
                glyphSize: 15
                text: modeItem.modelData.name
                detail: modeItem.isActive ? Focus.untilLabel : ""
                active: modeItem.isActive
                activeColor: modeItem.modelData.color
                actionSymbol: "ellipsis"
                actionShown: modeItem.open
                onClicked: Focus.toggleMode(modeItem.modelData.id)
                onActionClicked: root.optionsFor = modeItem.open ? "" : modeItem.modelData.id
            }

            // Durées du mode (sous-menu « … »)
            Column {
                width: parent.width
                visible: modeItem.open
                Option {
                    modeId: modeItem.modelData.id
                    kind: "hour"
                    text: "Pendant 1 heure"
                    onClicked: { Focus.setMode(modeId); Focus.forOneHour(); }
                }
                // macOS ne propose « ce soir » qu'avant 19 h
                Option {
                    modeId: modeItem.modelData.id
                    kind: "tonight"
                    visible: new Date().getHours() < 19
                    text: "Jusqu’à ce soir"
                    onClicked: { Focus.setMode(modeId); Focus.untilTonight(); }
                }
                Option {
                    modeId: modeItem.modelData.id
                    kind: "morning"
                    text: "Jusqu’à demain matin"
                    onClicked: { Focus.setMode(modeId); Focus.untilTomorrowMorning(); }
                }
            }
        }
    }

    DetailFooter {
        text: "Réglages Concentration…"
        onClicked: {
            CCActions.openSettings("notifications");
            ShellState.close();
        }
    }
}
