import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

ColumnLayout {
    id: root

    property alias cfg_refreshInterval: intervalSpin.value
    property alias cfg_targetContainer: containerField.text
    property alias cfg_enableNotifications: notificationsCheck.checked
    property alias cfg_showAllContainers: showAllCheck.checked
    property alias cfg_panelIconSize: panelIconSpin.value
    property alias cfg_panelFontSize: panelFontSpin.value
    property alias cfg_popupWidth: popupWidthSpin.value
    property alias cfg_popupHeight: popupHeightSpin.value
    property alias cfg_popupCardFontSize: cardFontSpin.value
    property alias cfg_panelFontColor: panelColorField.text
    property alias cfg_popupCardFontColor: cardColorField.text
    property alias cfg_borderThickness: borderSpin.value

    spacing: Kirigami.Units.largeSpacing

    // ── Docker ──────────────────────────────────────────────────────────
    PlasmaComponents3.Label {
        text: i18n("Docker Settings"); font.weight: Font.Bold
    }
    PlasmaComponents3.Label {
        text: i18n("Refresh Interval (ms):"); font: Kirigami.Theme.smallFont
    }
    QQC2.SpinBox {
        id: intervalSpin
        from: 1000; to: 300000; stepSize: 1000; editable: true
        Layout.fillWidth: true
        textFromValue: function(v) { return v + " ms" }
        valueFromText: function(t) { return parseInt(t) }
    }
    PlasmaComponents3.Label {
        text: i18n("Target Container:"); font: Kirigami.Theme.smallFont
        Layout.topMargin: Kirigami.Units.smallSpacing
    }
    QQC2.TextField {
        id: containerField
        Layout.fillWidth: true; placeholderText: i18n("e.g. test-node")
    }

    Kirigami.Separator { Layout.fillWidth: true; Layout.topMargin: Kirigami.Units.smallSpacing }

    // ── Notifications ───────────────────────────────────────────────────
    PlasmaComponents3.Label {
        text: i18n("Behavior"); font.weight: Font.Bold
    }
    QQC2.CheckBox {
        id: notificationsCheck
        text: i18n("Enable desktop notifications")
    }
    QQC2.CheckBox {
        id: showAllCheck
        text: i18n("Show all containers (including stopped)")
    }

    Kirigami.Separator { Layout.fillWidth: true; Layout.topMargin: Kirigami.Units.smallSpacing }

    // ── Panel Appearance ────────────────────────────────────────────────
    PlasmaComponents3.Label {
        text: i18n("Panel Appearance"); font.weight: Font.Bold
    }

    RowLayout {
        Layout.fillWidth: true
        PlasmaComponents3.Label { text: i18n("Icon:"); font: Kirigami.Theme.smallFont; Layout.alignment: Qt.AlignVCenter }
        QQC2.SpinBox {
            id: panelIconSpin; from: 12; to: 48; stepSize: 2; editable: true; Layout.fillWidth: true
            textFromValue: function(v) { return v + " px" }; valueFromText: function(t) { return parseInt(t) }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        PlasmaComponents3.Label { text: i18n("Font:"); font: Kirigami.Theme.smallFont; Layout.alignment: Qt.AlignVCenter }
        QQC2.SpinBox {
            id: panelFontSpin; from: 8; to: 24; stepSize: 1; editable: true; Layout.fillWidth: true
            textFromValue: function(v) { return v + " px" }; valueFromText: function(t) { return parseInt(t) }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        PlasmaComponents3.Label { text: i18n("Color:"); font: Kirigami.Theme.smallFont; Layout.alignment: Qt.AlignVCenter }
        QQC2.TextField {
            id: panelColorField; Layout.fillWidth: true; placeholderText: i18n("Auto (status based)")
            font: Kirigami.Theme.smallFont
        }
    }
    PlasmaComponents3.Label {
        text: i18n("Leave color empty for auto: green=running, orange=partial, red=stopped")
        font: Kirigami.Theme.smallFont; opacity: 0.5; Layout.fillWidth: true; wrapMode: Text.WordWrap
    }

    Kirigami.Separator { Layout.fillWidth: true; Layout.topMargin: Kirigami.Units.smallSpacing }

    // ── Popup Appearance ────────────────────────────────────────────────
    PlasmaComponents3.Label {
        text: i18n("Popup Appearance"); font.weight: Font.Bold
    }

    RowLayout {
        Layout.fillWidth: true
        PlasmaComponents3.Label { text: i18n("Width:"); font: Kirigami.Theme.smallFont; Layout.alignment: Qt.AlignVCenter }
        QQC2.SpinBox {
            id: popupWidthSpin; from: 24; to: 60; stepSize: 2; editable: true; Layout.fillWidth: true
            textFromValue: function(v) { return v + " GU" }; valueFromText: function(t) { return parseInt(t) }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        PlasmaComponents3.Label { text: i18n("Height:"); font: Kirigami.Theme.smallFont; Layout.alignment: Qt.AlignVCenter }
        QQC2.SpinBox {
            id: popupHeightSpin; from: 16; to: 50; stepSize: 2; editable: true; Layout.fillWidth: true
            textFromValue: function(v) { return v + " GU" }; valueFromText: function(t) { return parseInt(t) }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        PlasmaComponents3.Label { text: i18n("Font:"); font: Kirigami.Theme.smallFont; Layout.alignment: Qt.AlignVCenter }
        QQC2.SpinBox {
            id: cardFontSpin; from: 0; to: 20; stepSize: 1; editable: true; Layout.fillWidth: true
            textFromValue: function(v) { return v === 0 ? "Auto" : v + " px" }; valueFromText: function(t) { return t === "Auto" ? 0 : parseInt(t) }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        PlasmaComponents3.Label { text: i18n("Color:"); font: Kirigami.Theme.smallFont; Layout.alignment: Qt.AlignVCenter }
        QQC2.TextField {
            id: cardColorField; Layout.fillWidth: true; placeholderText: i18n("Theme default")
            font: Kirigami.Theme.smallFont
        }
    }
    PlasmaComponents3.Label {
        text: i18n("Font 0 = theme default. Color: hex (#ff0000) or name (red). Empty = theme default.")
        font: Kirigami.Theme.smallFont; opacity: 0.5; Layout.fillWidth: true; wrapMode: Text.WordWrap
    }

    Kirigami.Separator { Layout.fillWidth: true; Layout.topMargin: Kirigami.Units.smallSpacing }

    // ── Borders ────────────────────────────────────────────────────────
    PlasmaComponents3.Label {
        text: i18n("Borders"); font.weight: Font.Bold
    }
    RowLayout {
        Layout.fillWidth: true
        PlasmaComponents3.Label { text: i18n("Thickness:"); font: Kirigami.Theme.smallFont; Layout.alignment: Qt.AlignVCenter }
        QQC2.SpinBox {
            id: borderSpin; from: 0; to: 5; stepSize: 1; editable: true; Layout.fillWidth: true
            textFromValue: function(v) { return v + " px" }; valueFromText: function(t) { return parseInt(t) }
        }
    }
    PlasmaComponents3.Label {
        text: i18n("0 = no border, 1 = default, 2-5 = thicker")
        font: Kirigami.Theme.smallFont; opacity: 0.5
    }
}
