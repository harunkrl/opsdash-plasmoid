import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

Kirigami.FormLayout {
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
    property alias cfg_panelIconName: panelIconField.text
    property alias cfg_cardIconName: cardIconField.text

    // ── Docker ──────────────────────────────────────────────────────────
    Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Docker Settings") }

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

    // ── Notifications ───────────────────────────────────────────────────
    Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Behavior") }

    QQC2.CheckBox {
        id: notificationsCheck
        text: i18n("Enable desktop notifications")
    }

    QQC2.CheckBox {
        id: showAllCheck
        text: i18n("Show all containers (including stopped)")
    }

    // ── Panel Appearance ────────────────────────────────────────────────
    Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Panel Appearance") }

    QQC2.SpinBox {
        id: panelIconSpin
        Kirigami.FormData.label: i18n("Icon Size:")
        from: 12; to: 48; stepSize: 2; editable: true
        textFromValue: function(v) { return v + " px" }
        valueFromText: function(t) { return parseInt(t) }
    }

    RowLayout {
        Kirigami.FormData.label: i18n("Custom Icon:")
        Layout.fillWidth: true
        QQC2.TextField {
            id: panelIconField; Layout.fillWidth: true; placeholderText: i18n("Default: docker whale")
        }
        Kirigami.Icon {
            Layout.preferredHeight: 24; Layout.preferredWidth: 24
            source: panelIconField.text.length > 0 ? panelIconField.text : Qt.resolvedUrl("../../ui/icons/docker.svg")
            Layout.alignment: Qt.AlignVCenter
        }
    }
    Kirigami.InlineMessage {
        text: i18n("Leave empty for default docker icon. You can use system icon names or file paths.")
        type: Kirigami.MessageType.Information
        visible: true
        Layout.fillWidth: true
    }

    QQC2.SpinBox {
        id: panelFontSpin
        Kirigami.FormData.label: i18n("Font Size:")
        from: 8; to: 24; stepSize: 1; editable: true
        textFromValue: function(v) { return v + " px" }
        valueFromText: function(t) { return parseInt(t) }
    }

    QQC2.TextField {
        id: panelColorField
        Kirigami.FormData.label: i18n("Color:")
        Layout.fillWidth: true; placeholderText: i18n("Auto (status based)")
    }
    Kirigami.InlineMessage {
        text: i18n("Leave empty for auto: green=running, orange=partial, red=stopped")
        type: Kirigami.MessageType.Information
        visible: true
        Layout.fillWidth: true
    }

    // ── Popup Appearance ────────────────────────────────────────────────
    Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Popup Appearance") }

    QQC2.SpinBox {
        id: popupWidthSpin
        Kirigami.FormData.label: i18n("Width:")
        from: 24; to: 60; stepSize: 2; editable: true
        textFromValue: function(v) { return v + " GU" }
        valueFromText: function(t) { return parseInt(t) }
    }

    QQC2.SpinBox {
        id: popupHeightSpin
        Kirigami.FormData.label: i18n("Height:")
        from: 16; to: 50; stepSize: 2; editable: true
        textFromValue: function(v) { return v + " GU" }
        valueFromText: function(t) { return parseInt(t) }
    }

    RowLayout {
        Kirigami.FormData.label: i18n("Card Icon:")
        Layout.fillWidth: true
        QQC2.TextField {
            id: cardIconField; Layout.fillWidth: true; placeholderText: i18n("Default: docker whale")
        }
        Kirigami.Icon {
            Layout.preferredHeight: 24; Layout.preferredWidth: 24
            source: cardIconField.text.length > 0 ? cardIconField.text : Qt.resolvedUrl("../../ui/icons/docker.svg")
            Layout.alignment: Qt.AlignVCenter
        }
    }

    QQC2.SpinBox {
        id: cardFontSpin
        Kirigami.FormData.label: i18n("Card Font Size:")
        from: 0; to: 20; stepSize: 1; editable: true
        textFromValue: function(v) { return v === 0 ? "Auto" : v + " px" }
        valueFromText: function(t) { return t === "Auto" ? 0 : parseInt(t) }
    }

    QQC2.TextField {
        id: cardColorField
        Kirigami.FormData.label: i18n("Card Font Color:")
        Layout.fillWidth: true; placeholderText: i18n("Theme default")
    }

    // ── Borders ────────────────────────────────────────────────────────
    Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Borders") }

    QQC2.SpinBox {
        id: borderSpin
        Kirigami.FormData.label: i18n("Thickness:")
        from: 0; to: 5; stepSize: 1; editable: true
        textFromValue: function(v) { return v + " px" }
        valueFromText: function(t) { return parseInt(t) }
    }
}
