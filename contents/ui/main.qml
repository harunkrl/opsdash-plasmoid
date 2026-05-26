import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    property string containerCount: "0"
    property var containerNames: []

    // ── Plasmoid metadata ───────────────────────────────────────────────
    Plasmoid.title: "OpsDash"
    Plasmoid.icon: "network-server"
    toolTipMainText: "OpsDash"
    toolTipSubText: i18n("Active containers: %1", root.containerCount)

    // ── Panel strip (icon + count) ──────────────────────────────────────
    compactRepresentation: MouseArea {
        anchors.fill: parent
        hoverEnabled: true

        property bool wasExpanded: false

        onPressed: mouse => {
            wasExpanded = root.expanded;
        }

        onClicked: mouse => {
            root.expanded = !wasExpanded;
        }

        RowLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: "network-server"
                Layout.fillHeight: true
                Layout.preferredWidth: height
                Layout.alignment: Qt.AlignVCenter
            }

            PlasmaComponents3.Label {
                text: root.containerCount
                font.weight: Font.Bold
                Layout.alignment: Qt.AlignVCenter
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                Layout.minimumWidth: implicitWidth
                Layout.preferredWidth: implicitWidth
            }
        }
    }

    // ── Popup (click to open) ───────────────────────────────────────────
    fullRepresentation: PlasmaExtras.Representation {
        collapseMarginsHint: true

        ColumnLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.largeSpacing

            // ── Header ──────────────────────────────────────────────────
            Kirigami.Heading {
                text: i18n("OpsDash Control Center")
                level: 2
                type: Kirigami.HeadingType.Primary
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
            }

            // ── Status Card ─────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: statusRow.height + Kirigami.Units.largeSpacing * 2
                radius: Kirigami.Units.cornerRadius
                color: Kirigami.ColorUtils.tintWithAlpha(
                    Kirigami.Theme.backgroundColor,
                    Kirigami.Theme.textColor,
                    0.05
                )
                border.color: Kirigami.ColorUtils.tintWithAlpha(
                    Kirigami.Theme.textColor,
                    Kirigami.Theme.backgroundColor,
                    0.85
                )
                border.width: 1

                RowLayout {
                    id: statusRow
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        margins: Kirigami.Units.largeSpacing
                    }
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        source: "emblem-success"
                        Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                        Layout.alignment: Qt.AlignVCenter
                    }

                    PlasmaComponents3.Label {
                        text: i18n("Local Engine:")
                        font.bold: true
                        Layout.alignment: Qt.AlignVCenter
                    }

                    PlasmaComponents3.Label {
                        text: i18n("Running")
                        color: Kirigami.Theme.positiveTextColor
                        font.bold: true
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Item { Layout.fillWidth: true }

                    PlasmaComponents3.Label {
                        text: i18n("Containers: %1", root.containerCount)
                        font.bold: true
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }

            // ── Separator ───────────────────────────────────────────────
            Kirigami.Separator {
                Layout.fillWidth: true
            }

            // ── Section Label ───────────────────────────────────────────
            PlasmaComponents3.Label {
                text: i18n("Running Containers")
                font: Kirigami.Theme.smallFont
                opacity: 0.6
                Layout.fillWidth: true
                Layout.bottomMargin: -Kirigami.Units.smallSpacing
            }

            // ── Dynamic Container List ──────────────────────────────────
            PlasmaComponents3.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: Kirigami.Units.gridUnit * 4

                ListView {
                    id: containerList
                    model: root.containerNames
                    spacing: Kirigami.Units.smallSpacing
                    clip: true

                    delegate: Kirigami.AbstractCard {
                        width: ListView.view.width - ListView.view.leftMargin - ListView.view.rightMargin
                        padding: Kirigami.Units.smallSpacing

                        readonly property string containerName: modelData

                        contentItem: RowLayout {
                            spacing: Kirigami.Units.smallSpacing

                            Kirigami.Icon {
                                source: "application-x-executable"
                                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                                Layout.alignment: Qt.AlignVCenter
                            }

                            PlasmaComponents3.Label {
                                text: containerName
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                                Layout.alignment: Qt.AlignVCenter
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                Kirigami.Icon {
                                    anchors.fill: parent
                                    source: "utilities-terminal"
                                    opacity: parent.containsMouse ? 1.0 : 0.7
                                }

                                onClicked: {
                                    actionSource.connectSource(
                                        "bash -c \"konsole -e bash -c 'docker logs --tail 50 -f "
                                        + containerName + "'\""
                                    );
                                }
                            }
                        }
                    }

                    // ── Empty state ──────────────────────────────────────
                    PlasmaExtras.PlaceholderMessage {
                        anchors.centerIn: parent
                        width: parent.width - Kirigami.Units.gridUnit * 4
                        visible: containerList.count === 0
                        iconName: "dialog-information"
                        text: i18n("No running containers")
                    }
                }
            }
        }
    }

    // ── Data source: container count ────────────────────────────────────
    Plasma5Support.DataSource {
        id: countSource
        engine: "executable"
        connectedSources: []

        onNewData: function (source, data) {
            var stdout = data["stdout"];
            if (stdout !== undefined) {
                root.containerCount = stdout.trim();
            }
            countSource.disconnectSource(source);
        }
    }

    // ── Data source: container names ────────────────────────────────────
    Plasma5Support.DataSource {
        id: namesSource
        engine: "executable"
        connectedSources: []

        onNewData: function (source, data) {
            var stdout = data["stdout"];
            if (stdout !== undefined && stdout.trim().length > 0) {
                root.containerNames = stdout.trim().split("\n");
            } else {
                root.containerNames = [];
            }
            namesSource.disconnectSource(source);
        }
    }

    // ── Data source: fire-and-forget actions (open konsole) ─────────────
    Plasma5Support.DataSource {
        id: actionSource
        engine: "executable"
        connectedSources: []

        onNewData: function (source, data) {
            // We don't care about output — just clean up
            actionSource.disconnectSource(source);
        }
    }

    // ── Timer: refresh all data ─────────────────────────────────────────
    Timer {
        interval: Plasmoid.configuration.refreshInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            countSource.connectSource("docker ps -q | wc -l");
            namesSource.connectSource("docker ps --format '{{.Names}}'");
        }
    }
}
