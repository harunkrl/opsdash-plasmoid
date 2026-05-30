import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

Item {
    id: root
    implicitWidth: Kirigami.Units.gridUnit * 25
    implicitHeight: Kirigami.Units.gridUnit * 20

    property alias cfg_enableNotifications: notificationsCheck.checked
    property alias cfg_enableResourceAlerts: resourceAlertsCheck.checked
    property alias cfg_cpuAlertThreshold: cpuAlertSpin.value
    property alias cfg_memAlertThreshold: memAlertSpin.value
    property alias cfg_showAllContainers: showAllCheck.checked

    QQC2.ScrollView {
        anchors.fill: parent
        Kirigami.FormLayout {
            width: parent.width

            Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Alerts & Notifications") }

            QQC2.CheckBox {
                id: notificationsCheck
                text: i18n("Enable desktop notifications for state changes")
            }

            QQC2.CheckBox {
                id: resourceAlertsCheck
                text: i18n("Enable high resource usage alerts")
            }

            QQC2.SpinBox {
                id: cpuAlertSpin
                Kirigami.FormData.label: i18n("CPU Alert Threshold:")
                from: 50; to: 500; stepSize: 5; editable: true
                textFromValue: function(v) { return v + " %" }
                valueFromText: function(t) { return parseInt(t) }
            }

            QQC2.SpinBox {
                id: memAlertSpin
                Kirigami.FormData.label: i18n("Mem Alert Threshold:")
                from: 50; to: 100; stepSize: 5; editable: true
                textFromValue: function(v) { return v + " %" }
                valueFromText: function(t) { return parseInt(t) }
            }

            Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Display") }

            QQC2.CheckBox {
                id: showAllCheck
                text: i18n("Show all containers (including stopped)")
            }
        }
    }
}
