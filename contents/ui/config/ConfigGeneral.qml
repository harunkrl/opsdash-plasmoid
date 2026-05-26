import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

ColumnLayout {
    id: root

    property alias cfg_refreshInterval: intervalSpin.value
    property alias cfg_targetContainer: containerField.text

    spacing: Kirigami.Units.largeSpacing

    // ── Refresh Interval ────────────────────────────────────────────────
    PlasmaComponents3.Label {
        text: i18n("Refresh Interval (milliseconds):")
        Layout.fillWidth: true
    }

    QQC2.SpinBox {
        id: intervalSpin
        from: 1000
        to: 300000
        stepSize: 1000
        editable: true
        Layout.fillWidth: true

        textFromValue: function (value) {
            return value + " ms";
        }

        valueFromText: function (text) {
            return parseInt(text);
        }
    }

    PlasmaComponents3.Label {
        text: i18n("How often to check for active containers. Default: 10000 ms (10 s).")
        font: Kirigami.Theme.smallFont
        opacity: 0.7
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
    }

    // ── Target Container ────────────────────────────────────────────────
    PlasmaComponents3.Label {
        text: i18n("Target Container Name:")
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.largeSpacing
    }

    QQC2.TextField {
        id: containerField
        Layout.fillWidth: true
        placeholderText: i18n("e.g. test-node")
    }

    PlasmaComponents3.Label {
        text: i18n("The Docker container used by the \"Open Docker Logs\" button.")
        font: Kirigami.Theme.smallFont
        opacity: 0.7
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
    }
}
