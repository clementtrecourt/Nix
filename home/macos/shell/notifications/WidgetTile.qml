import QtQuick
import qs.common

// Fond de widget Tahoe. Les widgets du Centre de notifications (style « Par
// défaut ») sont bien plus opaques que les bannières : blanc quasi plein en
// clair (245 relevé sur l'image Apple de macOS 26), gris anthracite neutre en sombre.
// Arrondi plus grand que celui des bannières (~22 pt contre ~19 pt, relevés
// sur l'image Apple « Notification Center » de macOS 26).
NotifGlass {
    radius: 22
    tint: Theme.dark ? Qt.rgba(0.135, 0.135, 0.145, 0.82) : Qt.rgba(0.962, 0.962, 0.962, 0.98)
    shadowOffset: 6
    shadowBlur: 0.8
}
