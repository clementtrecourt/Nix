import QtQuick
import qs.common

// Fond de widget Tahoe (verre, coins continus 22 pt). Les widgets du Centre de
// notifications sont légèrement plus denses que les bannières.
Glass {
    radius: 22
    tint: Theme.dark ? Qt.rgba(0.10, 0.10, 0.11, 0.50) : Qt.rgba(0.98, 0.98, 0.99, 0.55)
    shadowOffset: 6
    shadowBlur: 0.8
}
