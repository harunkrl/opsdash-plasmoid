import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

Item {
    id: root
    implicitWidth: Kirigami.Units.gridUnit * 25
    implicitHeight: Kirigami.Units.gridUnit * 20

    property alias cfg_dockerHost: dockerHostField.text
    property alias cfg_refreshInterval: intervalSpin.value
    property alias cfg_targetContainer: containerField.text

    QQC2.ScrollView {
        anchors.fill: parent
        Kirigami.FormLayout {
            width: parent.width

            Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Docker Settings") }
            
            QQC2.TextField {
                id: dockerHostField
                Kirigami.FormData.label: i18n("Docker Host:")
                placeholderText: i18n("Localhost (empty) or ssh://user@ip")
                Layout.fillWidth: true
            }

            QQC2.SpinBox {
                id: intervalSpin
                Kirigami.FormData.label: i18n("Refresh Interval:")
                from: 1000; to: 300000; stepSize: 1000; editable: true
                textFromValue: function(v) { return v + " ms" }
                valueFromText: function(t) { return parseInt(t) }
            }

            QQC2.TextField {
                id: containerField
                Kirigami.FormData.label: i18n("Target Container:")
                placeholderText: i18n("e.g. test-node")
                Layout.fillWidth: true
            }
        }
    }
}
