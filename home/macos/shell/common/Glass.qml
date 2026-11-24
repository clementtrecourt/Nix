import QtQuick
import Quickshell
import qs.common

// Plaque « Liquid Glass » commune (macOS Tahoe) : LiquidGlass dont le fond est
// fourni par la fenêtre.
//
//  - Si la fenêtre déclare `property Item glassBackdrop: <GlassBackdrop>`, le
//    verre RÉFRACTE ce fond (lentille de bord, flou léger, teinte adaptative,
//    liseré spéculaire, bande d'épaisseur) : voir common/GlassBackdrop.qml.
//  - Sinon : repli sans réfraction (teinte + liseré ; le flou vient de la
//    layerrule Hyprland du namespace "macos-*").
//
// Même API qu'avant (radius, tint, thick, shadowEnabled, shadowBlur,
// shadowOffset, shadowColor, réglages fins du liseré, contenu par défaut) ;
// `overlay` : voile dense composé par-dessus le fond réfracté (remplace un
// Rectangle peint sous le verre, qui serait masqué par la réfraction).
//
// L'ombre déborde de l'item (de ~3 x shadowBlur x 14 px) : prévoir cette marge
// dans la fenêtre.
//
// Usage : Glass { radius: Theme.radiusPanel; <contenu> }
LiquidGlass {
    id: root

    readonly property var _bd: QsWindow.window?.glassBackdrop ?? null

    tint: thick ? Theme.glassThick : Theme.glass
    backdrop: _bd ? _bd.mode : "none"
    backdropItem: _bd
    windowOrigin: _bd && _bd.origin ? _bd.origin : _autoWindowOrigin
}
