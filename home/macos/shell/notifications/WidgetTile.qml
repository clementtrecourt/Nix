import QtQuick
import qs.common

// Fond de widget Tahoe. Les widgets du Centre de notifications (style « Par
// défaut ») sont bien plus opaques que les bannières : blanc quasi plein en
// clair (~246 sur l'image Apple de macOS 26), gris anthracite neutre en sombre.
// Arrondi plus grand que celui des bannières (~26 pt contre ~22 pt).
NotifGlass {
    radius: 26
    tint: Theme.dark ? Qt.rgba(0.135, 0.135, 0.145, 0.80) : Qt.rgba(0.965, 0.965, 0.97, 0.93)
    shadowOffset: 6
    shadowBlur: 0.8
}
