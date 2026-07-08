import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Controls as QQC2

import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.notification as KNotification

PlasmoidItem {
    id: root

    property string containerCount: "0"
    property var containers: []
    property var displayContainers: []
    property var containerStats: ({})
    property var containerPorts: ({})
    property var cpuHistory: ({})
    property var previousStates: ({})
    property var systemOverview: ({ images: 0, totalContainers: 0 })
    property var alertCount: ({})
    property var imagesListModel: []
    property bool initialized: false
    property bool isFetching: false
    property bool showAll: Plasmoid.configuration.showAllContainers
    property string searchFilter: ""
    property int sortMode: 0
    readonly property int historySize: 30
    readonly property string defaultIcon: Qt.resolvedUrl("icons/docker.svg")
    readonly property string resolvedPanelIcon: Plasmoid.configuration.panelIconName && Plasmoid.configuration.panelIconName.length > 0 ? Plasmoid.configuration.panelIconName : defaultIcon
    readonly property string resolvedCardIcon: Plasmoid.configuration.cardIconName && Plasmoid.configuration.cardIconName.length > 0 ? Plasmoid.configuration.cardIconName : defaultIcon
    readonly property string dcmd: Plasmoid.configuration.dockerHost && Plasmoid.configuration.dockerHost.length > 0 ? "docker -H " + Plasmoid.configuration.dockerHost : "docker"

    readonly property color sepColor: Kirigami.ColorUtils.tintWithAlpha(
        Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.2)

    // ── Panel warning color ─────────────────────────────────────────────
    readonly property color panelColor: {
        var custom = Plasmoid.configuration.panelFontColor;
        if (custom && custom.length > 0) return custom;
        var total = systemOverview.totalContainers;
        if (total === 0) return Kirigami.Theme.disabledTextColor;
        var running = parseInt(containerCount);
        if (running === 0) return Kirigami.Theme.negativeTextColor;
        if (running < total) return "#f67400";
        return Kirigami.Theme.positiveTextColor;
    }

    // ── Warning badge ────────────────────────────────────────
    readonly property bool hasWarning: {
        var total = systemOverview.totalContainers;
        if (total === 0) return false;
        return parseInt(containerCount) < total;
    }


    // ── Helpers ─────────────────────────────────────────────────────────
    function fmtUptime(status) {
        if (!status || status.indexOf("Up") !== 0) return "";
        var up = status.substring(3), r = "";
        var dm=up.match(/(\d+)\s+day/);  if(dm) r+=dm[1]+"d";
        var hm=up.match(/(\d+)\s+hour/); if(hm) r+=(r?" ":"")+hm[1]+"h";
        var mm=up.match(/(\d+)\s+min/);  if(mm) r+=(r?" ":"")+mm[1]+"m";
        var sm=up.match(/(\d+)\s+sec/);  if(sm) r+=(r?" ":"")+sm[1]+"s";
        if(up.match(/About an hour/)) r="~1h";
        if(up.match(/About a minute/)) r="~1m";
        return r || up;
    }
    function stateColor(s) {
        if(s==="running") return Kirigami.Theme.positiveTextColor;
        if(s==="paused") return "#f67400";
        if(s==="restarting") return "#3daee9";
        if(s==="exited"||s==="dead") return Kirigami.Theme.negativeTextColor;
        return Kirigami.Theme.disabledTextColor;
    }
    function stateIcon(s) {
        if(s==="running") return "emblem-success";
        if(s==="paused") return "media-playback-pause";
        if(s==="restarting") return "view-refresh";
        if(s==="exited") return "process-stop";
        if(s==="dead") return "edit-delete-remove";
        return "dialog-question";
    }
    function stateLabel(s) {
        if(s==="running") return i18n("Running");
        if(s==="paused") return i18n("Paused");
        if(s==="restarting") return i18n("Restarting");
        if(s==="exited") return i18n("Stopped");
        if(s==="dead") return i18n("Dead");
        if(s==="created") return i18n("Created");
        return s;
    }
    function parseMemToMiB(m) {
        var u=m.split(" / ")[0].trim(),x=u.match(/([\d.]+)\s*([KMG]iB)/);
        if(!x)return 0; var v=parseFloat(x[1]);
        if(x[2]==='KiB')return v/1024; if(x[2]==='MiB')return v; if(x[2]==='GiB')return v*1024; return 0;
    }
    function formatMem(m) {
        if(m>=1024)return(m/1024).toFixed(1)+" GiB";
        if(m>=1)return m.toFixed(1)+" MiB";
        return(m*1024).toFixed(0)+" KiB";
    }
    function fmtNet(s) {
        var p=s.split(" / ");
        return p.length===2?"\u2191"+p[0].trim()+" \u2193"+p[1].trim():s;
    }

    // ── Aggregates ──────────────────────────────────────────────────────
    readonly property real totalCpu: { var s=0; for(var k in containerStats)s+=containerStats[k].cpu; return Math.round(s*100)/100; }
    readonly property real totalMem: { var s=0; for(var k in containerStats)s+=containerStats[k].memMiB; return Math.round(s*10)/10; }

    // ── Sort & Filter ───────────────────────────────────────────────────
    function updateDisplay() {
        var list = containers.slice();
        if (searchFilter.length > 0) {
            var sf = searchFilter.toLowerCase();
            list = list.filter(function(c){ return c.name.toLowerCase().indexOf(sf)>=0; });
        }
        list.sort(function(a,b){
            var pa = a.project || "zzzz";
            var pb = b.project || "zzzz";
            if (pa !== pb) return pa.localeCompare(pb);
            
            var order={running:0,restarting:1,paused:2,created:3,exited:4,dead:5};
            var oa=order[a.state]!==undefined?order[a.state]:6;
            var ob=order[b.state]!==undefined?order[b.state]:6;
            switch(sortMode){
            case 1: if(oa!==ob)return oa-ob; return a.name.localeCompare(b.name);
            case 2: var ca=containerStats[a.name]?containerStats[a.name].cpu:0;
                    var cb=containerStats[b.name]?containerStats[b.name].cpu:0;
                    if(cb!==ca)return cb-ca; return a.name.localeCompare(b.name);
            case 3: var ma=containerStats[a.name]?containerStats[a.name].memMiB:0;
                    var mb=containerStats[b.name]?containerStats[b.name].memMiB:0;
                    if(mb!==ma)return mb-ma; return a.name.localeCompare(b.name);
            default: return a.name.localeCompare(b.name);
            }
        });
        displayContainers = list;
    }
    onContainersChanged: updateDisplay()
    onSearchFilterChanged: updateDisplay()
    onSortModeChanged: updateDisplay()

    // ── Inline Components ───────────────────────────────────────────────

    component Sparkline : Item {
        property var points: []
        property color lc: Kirigami.Theme.positiveTextColor
        implicitWidth: 44; implicitHeight: 12
        
        Shape {
            anchors.fill: parent
            asynchronous: true
            vendorExtensionsEnabled: true
            
            ShapePath {
                id: sPath
                strokeWidth: 1.2
                strokeColor: parent.parent.lc
                fillColor: "transparent"
                startX: 0; startY: height
                PathPolyline { id: poly }
            }
        }
        
        onPointsChanged: {
            if (points.length < 2) return;
            var mx = 0;
            for (var i = 0; i < points.length; i++) if (points[i] > mx) mx = points[i];
            if (mx <= 0) mx = 1;
            
            var pList = [];
            for (var i = 0; i < points.length; i++) {
                var x = (i / (points.length - 1)) * width;
                var y = height - (points[i] / mx) * (height * 0.8) - height * 0.1;
                pList.push(Qt.point(x, y));
            }
            sPath.startX = pList[0].x;
            sPath.startY = pList[0].y;
            poly.path = pList;
        }
    }

    // ── Plasmoid metadata ───────────────────────────────────────────────
    Plasmoid.title: "OpsDash"
    Plasmoid.icon: "docker"
    toolTipMainText: "OpsDash"
    toolTipSubText: i18n("%1/%2 up \u00B7 CPU %3% \u00B7 Mem %4",
        containerCount, systemOverview.totalContainers,
        totalCpu.toFixed(1), formatMem(totalMem))

    KNotification.Notification {
        id: generalNotification
        eventId: "notification"
        componentName: "plasma_workspace"
    }

    // ═════════════════════════════════════════════════════════════════════
    // PANEL STRIP (with warning badge)
    // ═════════════════════════════════════════════════════════════════════
    compactRepresentation: MouseArea {
        hoverEnabled: true
        implicitWidth: row.width + Kirigami.Units.smallSpacing * 2
        implicitHeight: row.height
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight
        Layout.minimumWidth: implicitWidth
        Layout.minimumHeight: implicitHeight
        property bool we: false
        onPressed: mouse => { we = root.expanded; }
        onClicked: mouse => { root.expanded = !we; }
        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon {
                source: root.resolvedPanelIcon
                Layout.preferredHeight: Plasmoid.configuration.panelIconSize
                Layout.preferredWidth: Plasmoid.configuration.panelIconSize
                Layout.alignment: Qt.AlignVCenter
            }
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: Math.max(implicitHeight, badgeLabel.implicitWidth + Kirigami.Units.smallSpacing * 1.5)
                implicitHeight: badgeLabel.implicitHeight + Kirigami.Units.smallSpacing
                radius: implicitHeight / 2
                color: Kirigami.ColorUtils.tintWithAlpha(Kirigami.Theme.backgroundColor, root.panelColor, 0.15)
                border.color: root.panelColor
                border.width: 1
                
                PlasmaComponents3.Label {
                    id: badgeLabel
                    anchors.centerIn: parent
                    text: root.containerCount
                    font.weight: Font.Bold
                    font.pixelSize: Plasmoid.configuration.panelFontSize * 0.85
                    color: root.panelColor
                }
            }
            // warning badge
            Kirigami.Icon {
                visible: root.hasWarning
                source: "dialog-warning"
                Layout.preferredHeight: parent.height * 0.5
                Layout.preferredWidth: Layout.preferredHeight
                Layout.alignment: Qt.AlignVCenter
                opacity: 0.85
                PlasmaComponents3.ToolTip {
                    visible: parent.visible && parent.parent.parent.containsMouse
                    text: i18n("Some containers are not running!")
                    delay: Kirigami.Units.toolTipDelay
                }
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════════
    // POPUP
    // ═════════════════════════════════════════════════════════════════════
    fullRepresentation: PlasmaExtras.Representation {
        Layout.preferredWidth: Kirigami.Units.gridUnit * Plasmoid.configuration.popupWidth
        Layout.preferredHeight: Kirigami.Units.gridUnit * Plasmoid.configuration.popupHeight

        ColumnLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.gridUnit * 0.8
            Layout.margins: Kirigami.Units.gridUnit * 0.8
            Layout.topMargin: Kirigami.Units.gridUnit
            Layout.bottomMargin: Kirigami.Units.gridUnit

            // Header
            RowLayout {
                Layout.fillWidth: true; spacing: Kirigami.Units.smallSpacing
                Kirigami.Heading { text:i18n("OpsDash");level:2;type:Kirigami.HeadingType.Primary;Layout.fillWidth:true;Layout.topMargin:Kirigami.Units.smallSpacing }
                PlasmaComponents3.BusyIndicator {
                    running: root.isFetching
                    visible: root.isFetching
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    Layout.alignment: Qt.AlignVCenter
                }
                PlasmaComponents3.ToolButton {
                    icon.name: "view-visible"
                    icon.color: root.showAll ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                    Layout.alignment: Qt.AlignVCenter
                    PlasmaComponents3.ToolTip.text: root.showAll ? i18n("Showing all") : i18n("Running only")
                    PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
                    PlasmaComponents3.ToolTip.visible: hovered
                    onClicked: { root.showAll = !root.showAll; Plasmoid.configuration.showAllContainers = root.showAll; Plasmoid.configuration.showAllContainersChanged(); }
                }
            }

            // Status Card
            Rectangle {
                Layout.fillWidth:true;Layout.preferredHeight:sc.height+Kirigami.Units.gridUnit
                radius:Kirigami.Units.cornerRadius
                color:Kirigami.ColorUtils.tintWithAlpha(Kirigami.Theme.backgroundColor,Kirigami.Theme.textColor,0.05)
                border.color:Kirigami.ColorUtils.tintWithAlpha(root.panelColor,Kirigami.Theme.backgroundColor,0.7);border.width:Plasmoid.configuration.borderThickness
                ColumnLayout {
                    id:sc
                    anchors{left:parent.left;right:parent.right;verticalCenter:parent.verticalCenter;margins:Kirigami.Units.gridUnit*1.2}
                    spacing:Kirigami.Units.smallSpacing
                    RowLayout {
                        Layout.fillWidth:true;spacing:Kirigami.Units.smallSpacing
                        Kirigami.Icon{source:"emblem-success";Layout.preferredHeight:Kirigami.Units.iconSizes.small;Layout.preferredWidth:Kirigami.Units.iconSizes.small}
                        PlasmaComponents3.Label{text:i18n("Engine:");font.pixelSize:Kirigami.Theme.defaultFont.pixelSize}
                        PlasmaComponents3.Label{text:i18n("Running");color:Kirigami.Theme.positiveTextColor;font.pixelSize:Kirigami.Theme.defaultFont.pixelSize}
                        Item{Layout.fillWidth:true}
                        PlasmaComponents3.Label{text:i18n("%1/%2 up",root.containerCount,root.systemOverview.totalContainers);font.pixelSize:Kirigami.Theme.defaultFont.pixelSize;color:root.panelColor}
                        Rectangle{Layout.preferredWidth:1;Layout.preferredHeight:10;color:sepColor}
                        PlasmaComponents3.Label{text:root.systemOverview.images+" "+i18n("images");font.pixelSize:Kirigami.Theme.defaultFont.pixelSize;opacity:0.6}
                    }
                    RowLayout {
                        Layout.fillWidth:true;spacing:Kirigami.Units.smallSpacing
                        PlasmaComponents3.Label{text:"CPU";font:Kirigami.Theme.smallFont;opacity:0.4}
                        PlasmaComponents3.ProgressBar{Layout.preferredWidth: 60; Layout.alignment: Qt.AlignVCenter; value: root.totalCpu / 100.0}
                        PlasmaComponents3.Label{text:root.totalCpu.toFixed(1)+"%";font:Kirigami.Theme.smallFont; Layout.preferredWidth: Kirigami.Units.gridUnit*2}
                        Rectangle{Layout.preferredWidth:1;Layout.preferredHeight:10;color:sepColor}
                        PlasmaComponents3.Label{text:"Mem";font:Kirigami.Theme.smallFont;opacity:0.4}
                        PlasmaComponents3.Label{text:formatMem(root.totalMem);font:Kirigami.Theme.smallFont}
                    }
                    RowLayout {
                        Layout.fillWidth:true;spacing:Kirigami.Units.smallSpacing
                        PlasmaComponents3.Label{text:i18n("Quick:");font:Kirigami.Theme.smallFont;opacity:0.4}
                        // Start All
                        PlasmaComponents3.ToolButton {
                            id: qStartBtn
                            icon.name: qStartBusy.running ? "emblem-checked" : "media-playback-start"
                            Layout.alignment: Qt.AlignVCenter
                            opacity: qStartBusy.running ? 1.0 : 0.7
                            PlasmaComponents3.ToolTip.text: i18n("Start All")
                            PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
                            PlasmaComponents3.ToolTip.visible: hovered
                            Timer { id: qStartBusy; interval: 2000 }
                            onClicked: {
                                qStartBusy.start();
                                for(var i=0;i<root.containers.length;i++){
                                    var c=root.containers[i];
                                    if(c.state==="exited"||c.state==="created"||c.state==="paused") actionSource.connectSource(root.dcmd + " start "+c.name);
                                }
                            }
                        }
                        // Stop All
                        PlasmaComponents3.ToolButton {
                            id: qStopBtn
                            icon.name: qStopBusy.running ? "emblem-checked" : "process-stop"
                            Layout.alignment: Qt.AlignVCenter
                            opacity: qStopBusy.running ? 1.0 : 0.7
                            PlasmaComponents3.ToolTip.text: i18n("Stop All")
                            PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
                            PlasmaComponents3.ToolTip.visible: hovered
                            Timer { id: qStopBusy; interval: 2000 }
                            onClicked: {
                                qStopBusy.start();
                                for(var i=0;i<root.containers.length;i++){
                                    var c=root.containers[i];
                                    if(c.state==="running") actionSource.connectSource(root.dcmd + " stop "+c.name);
                                }
                            }
                        }
                        // Restart All
                        PlasmaComponents3.ToolButton {
                            id: qRestartBtn
                            icon.name: qRestartBusy.running ? "emblem-checked" : "view-refresh"
                            Layout.alignment: Qt.AlignVCenter
                            opacity: qRestartBusy.running ? 1.0 : 0.7
                            PlasmaComponents3.ToolTip.text: i18n("Restart All")
                            PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
                            PlasmaComponents3.ToolTip.visible: hovered
                            Timer { id: qRestartBusy; interval: 2000 }
                            onClicked: {
                                qRestartBusy.start();
                                for(var i=0;i<root.containers.length;i++){
                                    var c=root.containers[i];
                                    if(c.state==="running") actionSource.connectSource(root.dcmd + " restart "+c.name);
                                }
                            }
                        }
                        // System Prune
                        PlasmaComponents3.ToolButton {
                            id: qPruneBtn
                            icon.name: qPruneBusy.running ? "emblem-checked" : "edit-delete-sweep"
                            Layout.alignment: Qt.AlignVCenter
                            opacity: qPruneBusy.running ? 1.0 : 0.7
                            PlasmaComponents3.ToolTip.text: i18n("Prune Unused Data")
                            PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
                            PlasmaComponents3.ToolTip.visible: hovered
                            Timer { id: qPruneBusy; interval: 2000 }
                            onClicked: {
                                qPruneBusy.start();
                                actionSource.connectSource(root.dcmd + " system prune -f");
                            }
                        }
                        Item{Layout.fillWidth:true}
                    }
                }
            }

            Kirigami.Separator{Layout.fillWidth:true}

            // Search
            RowLayout {
                Layout.fillWidth:true;spacing:Kirigami.Units.smallSpacing
                Kirigami.Icon{source:"edit-find";Layout.preferredHeight:Kirigami.Units.iconSizes.small;Layout.preferredWidth:Kirigami.Units.iconSizes.small;opacity:0.4}
                PlasmaComponents3.TextField {
                    Layout.fillWidth: true
                    placeholderText: i18n("Search containers...")
                    font: Kirigami.Theme.smallFont
                    clearButtonShown: true
                    onTextChanged: root.searchFilter = text
                }
            }

            // Sort buttons
            RowLayout {
                Layout.fillWidth: true; spacing: Kirigami.Units.smallSpacing
                PlasmaComponents3.Label { text: i18n("Sort:"); font: Kirigami.Theme.smallFont; opacity: 0.5; Layout.alignment: Qt.AlignVCenter }
                PlasmaComponents3.ComboBox {
                    Layout.fillWidth: true
                    model: [i18n("Name"), i18n("State"), i18n("CPU"), i18n("Mem")]
                    currentIndex: root.sortMode
                    onActivated: function(index) { root.sortMode = index; }
                }
                Item{Layout.fillWidth:true}
                PlasmaComponents3.Label{text:(root.showAll?i18n("All"):i18n("Running"))+" ("+containerList.count+")";font:Kirigami.Theme.smallFont;opacity:0.35;Layout.alignment:Qt.AlignVCenter}
            }

            // Container List
            PlasmaComponents3.ScrollView {
                Layout.fillWidth:true;Layout.fillHeight:true;Layout.minimumHeight:Kirigami.Units.gridUnit*6
                ListView {
                    id:containerList;model:root.displayContainers;spacing:3;clip:true
                    
                    section.property: "project"
                    section.delegate: Rectangle {
                        width: ListView.view.width
                        height: (section !== "" && section !== "zzzz") ? Kirigami.Units.gridUnit * 1.5 : 0
                        visible: height > 0
                        color: Kirigami.ColorUtils.tintWithAlpha(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.05)
                        RowLayout {
                            anchors.fill: parent; anchors.margins: Kirigami.Units.smallSpacing
                            Kirigami.Icon { source: "folder-symbolic"; Layout.preferredWidth: Kirigami.Units.iconSizes.small; Layout.preferredHeight: Kirigami.Units.iconSizes.small; opacity: 0.7 }
                            PlasmaComponents3.Label { text: section; font.weight: Font.Bold; opacity: 0.8; Layout.fillWidth: true }
                            PlasmaComponents3.ToolButton {
                                icon.name: "media-playback-start"; width: Kirigami.Units.iconSizes.small; height: Kirigami.Units.iconSizes.small
                                PlasmaComponents3.ToolTip { text: i18n("Start Project") }
                                onClicked: root.runProjectAction(section, "start")
                            }
                            PlasmaComponents3.ToolButton {
                                icon.name: "media-playback-stop"; width: Kirigami.Units.iconSizes.small; height: Kirigami.Units.iconSizes.small
                                PlasmaComponents3.ToolTip { text: i18n("Stop Project") }
                                onClicked: root.runProjectAction(section, "stop")
                            }
                            PlasmaComponents3.ToolButton {
                                icon.name: "system-reboot"; width: Kirigami.Units.iconSizes.small; height: Kirigami.Units.iconSizes.small
                                PlasmaComponents3.ToolTip { text: i18n("Restart Project") }
                                onClicked: root.runProjectAction(section, "restart")
                            }
                        }
                    }
                    
                    add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Kirigami.Units.shortDuration } }
                    remove: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Kirigami.Units.shortDuration } }
                    displaced: Transition { NumberAnimation { properties: "x,y"; duration: Kirigami.Units.shortDuration } }

                    delegate: Kirigami.AbstractCard {
                        id: delegateCard
                        width:ListView.view.width-ListView.view.leftMargin-ListView.view.rightMargin
                        readonly property string cn:modelData.name
                        readonly property string cs:modelData.state
                        readonly property string cst:modelData.status
                        readonly property var st:root.containerStats[cn]||null
                        readonly property var ch:root.cpuHistory[cn]||[]
                        readonly property string ports:root.containerPorts[cn]||""
                        readonly property bool run:cs==="running"
                        
                        property bool expanded: false

                        HoverHandler { id: cardHover }
                        
                        TapHandler {
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onTapped: function(eventPoint) {
                                if (eventPoint.button === Qt.RightButton) {
                                    cardMenu.popup();
                                } else {
                                    delegateCard.expanded = !delegateCard.expanded;
                                }
                            }
                        }
                        
                        PlasmaComponents3.Menu {
                            id: cardMenu
                            PlasmaComponents3.MenuItem {
                                text: i18n("Start"); icon.name: "media-playback-start"; visible: cs==="exited"||cs==="created"||cs==="paused"
                                onClicked: actionSource.connectSource(root.dcmd + " start "+cn)
                            }
                            PlasmaComponents3.MenuItem {
                                text: i18n("Stop"); icon.name: "process-stop"; visible: run
                                onClicked: actionSource.connectSource(root.dcmd + " stop "+cn)
                            }
                            PlasmaComponents3.MenuItem {
                                text: i18n("Restart"); icon.name: "view-refresh"; visible: run
                                onClicked: actionSource.connectSource(root.dcmd + " restart "+cn)
                            }
                            PlasmaComponents3.MenuItem {
                                text: i18n("Logs"); icon.name: "utilities-terminal"; visible: run
                                onClicked: actionSource.connectSource("konsole --noclose -e bash -c 'echo \"=== Logs for "+cn+" ===\"; docker logs --tail 50 -f "+cn+"'")
                            }
                            PlasmaComponents3.MenuItem {
                                text: i18n("Exec (Shell)"); icon.name: "system-run"; visible: run
                                onClicked: actionSource.connectSource("konsole -e " + root.dcmd + " exec -it "+cn+" /bin/sh")
                            }
                            PlasmaComponents3.MenuItem {
                                text: i18n("Remove"); icon.name: "edit-delete-remove"; visible: !run
                                onClicked: actionSource.connectSource(root.dcmd + " rm "+cn)
                            }
                        }

                        background:Rectangle {
                            radius:4
                            color: Kirigami.ColorUtils.tintWithAlpha(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, cardHover.hovered ? (run?0.08:0.12) : (run?0.03:0.06))
                            border.color: Kirigami.ColorUtils.tintWithAlpha(stateColor(cs), Kirigami.Theme.backgroundColor, cardHover.hovered ? 0.8 : 0.55)
                            border.width: Plasmoid.configuration.borderThickness
                            opacity: run ? 1.0 : (cardHover.hovered ? 0.9 : 0.75)
                            Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
                            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
                            Behavior on border.color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
                        }

                        contentItem: ColumnLayout {
                            spacing:2

                            // Row 1: dot + icon + name + uptime
                            RowLayout {
                                Layout.fillWidth:true;spacing:Kirigami.Units.smallSpacing
                                Rectangle{Layout.preferredWidth:4;Layout.fillHeight:true;Layout.topMargin:2;Layout.bottomMargin:2;radius:2;color:stateColor(cs)}
                                Kirigami.Icon{source:root.resolvedCardIcon;Layout.preferredHeight:Plasmoid.configuration.popupCardFontSize>0?Plasmoid.configuration.popupCardFontSize*1.45:Kirigami.Units.iconSizes.small;Layout.preferredWidth:Plasmoid.configuration.popupCardFontSize>0?Plasmoid.configuration.popupCardFontSize*1.45:Kirigami.Units.iconSizes.small;Layout.alignment:Qt.AlignVCenter;opacity:run?1.0:0.5}
                                PlasmaComponents3.Label{text:cn;font.weight:Font.Bold;font.pixelSize:Plasmoid.configuration.popupCardFontSize>0?Plasmoid.configuration.popupCardFontSize:Kirigami.Theme.smallFont.pixelSize;color:Plasmoid.configuration.popupCardFontColor.length>0?Plasmoid.configuration.popupCardFontColor:Kirigami.Theme.textColor;Layout.fillWidth:true;Layout.alignment:Qt.AlignVCenter;elide:Text.ElideRight;opacity:run?1.0:0.6}
                                PlasmaComponents3.Label{visible:run;text:fmtUptime(cst);font:Kirigami.Theme.smallFont;opacity:0.4;Layout.alignment:Qt.AlignVCenter}

                                // Inline actions
                                RowLayout {
                                    spacing: 0; Layout.alignment: Qt.AlignVCenter
                                    opacity: cardHover.hovered ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }

                                    // Start
                                    PlasmaComponents3.ToolButton {
                                        visible: cs==="exited"||cs==="created"||cs==="paused"
                                        property bool busy: false
                                        Timer { id: cStartT; interval: 2000; onTriggered: parent.busy = false }
                                        icon.name: busy ? "emblem-checked" : "media-playback-start"
                                        display: PlasmaComponents3.AbstractButton.IconOnly
                                        enabled: !busy
                                        PlasmaComponents3.ToolTip.text: i18n("Start")
                                        PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
                                        PlasmaComponents3.ToolTip.visible: hovered
                                        onClicked: { busy=true; cStartT.start(); actionSource.connectSource(root.dcmd + " start "+cn); }
                                    }

                                    // Stop
                                    PlasmaComponents3.ToolButton {
                                        visible: run
                                        property bool busy: false
                                        Timer { id: cStopT; interval: 2000; onTriggered: parent.busy = false }
                                        icon.name: busy ? "emblem-checked" : "process-stop"
                                        display: PlasmaComponents3.AbstractButton.IconOnly
                                        enabled: !busy
                                        PlasmaComponents3.ToolTip.text: i18n("Stop")
                                        PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
                                        PlasmaComponents3.ToolTip.visible: hovered
                                        onClicked: { busy=true; cStopT.start(); actionSource.connectSource(root.dcmd + " stop "+cn); }
                                    }

                                    // Restart
                                    PlasmaComponents3.ToolButton {
                                        visible: run
                                        property bool busy: false
                                        Timer { id: cRestartT; interval: 2000; onTriggered: parent.busy = false }
                                        icon.name: busy ? "emblem-checked" : "view-refresh"
                                        display: PlasmaComponents3.AbstractButton.IconOnly
                                        enabled: !busy
                                        PlasmaComponents3.ToolTip.text: i18n("Restart")
                                        PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
                                        PlasmaComponents3.ToolTip.visible: hovered
                                        onClicked: { busy=true; cRestartT.start(); actionSource.connectSource(root.dcmd + " restart "+cn); }
                                    }

                                    // Logs
                                    PlasmaComponents3.ToolButton {
                                        visible: run
                                        property bool busy: false
                                        Timer { id: cLogsT; interval: 1500; onTriggered: parent.busy = false }
                                        icon.name: busy ? "emblem-checked" : "utilities-terminal"
                                        display: PlasmaComponents3.AbstractButton.IconOnly
                                        enabled: !busy
                                        PlasmaComponents3.ToolTip.text: i18n("Logs")
                                        PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
                                        PlasmaComponents3.ToolTip.visible: hovered
                                        onClicked: { busy=true; cLogsT.start(); actionSource.connectSource("konsole --noclose -e bash -c 'echo \"=== Logs for "+cn+" ===\"; docker logs --tail 50 -f "+cn+"'"); }
                                    }

                                    // Exec
                                    PlasmaComponents3.ToolButton {
                                        visible: run
                                        property bool busy: false
                                        Timer { id: cExecT; interval: 1500; onTriggered: parent.busy = false }
                                        icon.name: busy ? "emblem-checked" : "system-run"
                                        display: PlasmaComponents3.AbstractButton.IconOnly
                                        enabled: !busy
                                        PlasmaComponents3.ToolTip.text: i18n("Exec Shell")
                                        PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
                                        PlasmaComponents3.ToolTip.visible: hovered
                                        onClicked: { busy=true; cExecT.start(); actionSource.connectSource("konsole -e " + root.dcmd + " exec -it "+cn+" /bin/sh"); }
                                    }

                                    // Remove
                                    PlasmaComponents3.ToolButton {
                                        visible: !run
                                        property bool busy: false
                                        Timer { id: cRemoveT; interval: 2000; onTriggered: parent.busy = false }
                                        icon.name: busy ? "emblem-checked" : "edit-delete-remove"
                                        display: PlasmaComponents3.AbstractButton.IconOnly
                                        enabled: !busy
                                        PlasmaComponents3.ToolTip.text: i18n("Remove")
                                        PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
                                        PlasmaComponents3.ToolTip.visible: hovered
                                        onClicked: { busy=true; cRemoveT.start(); actionSource.connectSource(root.dcmd + " rm "+cn); }
                                    }
                                }
                            }

                            // Row 2a: Stats (running) — clean, no inline buttons
                            RowLayout {
                                Layout.fillWidth:true;spacing:Kirigami.Units.smallSpacing;visible:run&&st!==null
                                Item{Layout.preferredWidth:4}Item{Layout.preferredWidth:Kirigami.Units.iconSizes.small}Item{Layout.preferredWidth:Kirigami.Units.smallSpacing}
                                
                                PlasmaComponents3.Label{text:"CPU";font:Kirigami.Theme.smallFont;opacity:0.35}
                                PlasmaComponents3.ProgressBar{Layout.preferredWidth: 40; Layout.alignment: Qt.AlignVCenter; value: (st?st.cpu:0)/100.0}
                                PlasmaComponents3.Label{text:st?st.cpu.toFixed(1)+"%":"";font:Kirigami.Theme.smallFont;color:st&&st.cpu>=85?Kirigami.Theme.negativeTextColor:st&&st.cpu>=60?"#f67400":Kirigami.Theme.textColor;Layout.preferredWidth:Kirigami.Units.gridUnit*2}
                                
                                Sparkline{Layout.preferredWidth: 44; points:ch;lc:st&&st.cpu>=85?Kirigami.Theme.negativeTextColor:st&&st.cpu>=60?"#f67400":Kirigami.Theme.positiveTextColor}
                                
                                Rectangle{Layout.preferredWidth:1;Layout.preferredHeight:10;color:sepColor;Layout.leftMargin:Kirigami.Units.smallSpacing;Layout.rightMargin:Kirigami.Units.smallSpacing}
                                PlasmaComponents3.Label{text:st?st.memUsed:"";font:Kirigami.Theme.smallFont;color:st&&st.memPerc>=85?Kirigami.Theme.negativeTextColor:st&&st.memPerc>=60?"#f67400":Kirigami.Theme.textColor;Layout.preferredWidth:Kirigami.Units.gridUnit*4}
                                
                                Rectangle{Layout.preferredWidth:1;Layout.preferredHeight:10;color:sepColor;Layout.rightMargin:Kirigami.Units.smallSpacing}
                                Kirigami.Icon{source:"network-server-symbolic";Layout.preferredHeight:Kirigami.Units.iconSizes.tiny;Layout.preferredWidth:Kirigami.Units.iconSizes.tiny;opacity:0.4}
                                PlasmaComponents3.Label{text:st?fmtNet(st.netIO):"";font:Kirigami.Theme.smallFont;opacity:0.55;Layout.fillWidth:true;elide:Text.ElideRight}
                            }

                            // Row 2b: Status (stopped)
                            RowLayout {
                                Layout.fillWidth:true;spacing:4;visible:!run
                                Item{Layout.preferredWidth:4}Item{Layout.preferredWidth:Kirigami.Units.iconSizes.small}Item{Layout.preferredWidth:Kirigami.Units.smallSpacing}
                                Kirigami.Icon{source:stateIcon(cs);Layout.preferredHeight:Kirigami.Units.iconSizes.tiny;Layout.preferredWidth:Kirigami.Units.iconSizes.tiny;opacity:0.35}
                                PlasmaComponents3.Label{text:cst;font:Kirigami.Theme.smallFont;opacity:0.35;Layout.fillWidth:true;elide:Text.ElideRight}
                            }

                            // Row 3: Port info
                            RowLayout {
                                Layout.fillWidth:true;spacing:4;visible:ports.length>0
                                Item{Layout.preferredWidth:4}Item{Layout.preferredWidth:Kirigami.Units.iconSizes.small}Item{Layout.preferredWidth:Kirigami.Units.smallSpacing}
                                Kirigami.Icon{source:"network-server";Layout.preferredHeight:Kirigami.Units.iconSizes.tiny;Layout.preferredWidth:Kirigami.Units.iconSizes.tiny;opacity:0.3}
                                PlasmaComponents3.Label{text:ports;font:Kirigami.Theme.smallFont;opacity:0.3;Layout.fillWidth:true;elide:Text.ElideRight}
                            }

                            // Expanded Details View
                            Kirigami.Separator { visible: delegateCard.expanded; Layout.fillWidth: true; Layout.topMargin: Kirigami.Units.smallSpacing }
                            ColumnLayout {
                                visible: delegateCard.expanded
                                Layout.fillWidth: true
                                spacing: Kirigami.Units.smallSpacing
                                
                                RowLayout {
                                    PlasmaComponents3.Label { text: i18n("Full Status:"); font: Kirigami.Theme.smallFont; opacity: 0.6 }
                                    PlasmaComponents3.Label { text: cst; font: Kirigami.Theme.smallFont; Layout.fillWidth: true; elide: Text.ElideRight }
                                }
                                RowLayout {
                                    visible: ports.length > 0
                                    PlasmaComponents3.Label { text: i18n("Ports:"); font: Kirigami.Theme.smallFont; opacity: 0.6; Layout.alignment: Qt.AlignTop }
                                    PlasmaComponents3.Label { text: ports; font: Kirigami.Theme.smallFont; Layout.fillWidth: true; wrapMode: Text.Wrap }
                                }
                                RowLayout {
                                    visible: st !== null
                                    PlasmaComponents3.Label { text: i18n("Memory:"); font: Kirigami.Theme.smallFont; opacity: 0.6 }
                                    PlasmaComponents3.Label { text: st ? st.memUsed : ""; font: Kirigami.Theme.smallFont; Layout.fillWidth: true }
                                }
                                
                                // Built-in Logs Viewer
                                Rectangle {
                                    Layout.fillWidth: true; Layout.preferredHeight: Kirigami.Units.gridUnit * 6
                                    color: Kirigami.ColorUtils.tintWithAlpha(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.05)
                                    border.color: sepColor; border.width: 1; radius: 4
                                    visible: delegateCard.expanded && run
                                    PlasmaComponents3.ScrollView {
                                        anchors.fill: parent; anchors.margins: Kirigami.Units.smallSpacing
                                        PlasmaComponents3.Label {
                                            id: inlineLogLabel
                                            text: i18n("Loading logs...")
                                            font.family: "monospace"; font.pixelSize: Kirigami.Theme.smallFont.pixelSize * 0.9
                                            wrapMode: Text.Wrap
                                        }
                                    }
                                    Plasma5Support.DataSource {
                                        id: inlineLogSource
                                        engine: "executable"
                                        connectedSources: []
                                        onNewData: function(source, data) {
                                            var stdout = data["stdout"];
                                            if (stdout !== undefined) {
                                                var txt = stdout.trim();
                                                inlineLogLabel.text = txt.length > 0 ? txt : i18n("No logs");
                                                disconnectSource(source);
                                            }
                                        }
                                    }
                                    Timer {
                                        interval: 5000; running: delegateCard.expanded && run; repeat: true; triggeredOnStart: true
                                        onTriggered: inlineLogSource.connectSource(root.dcmd + " logs --tail 20 " + cn + " 2>&1")
                                    }
                                }
                            }
                        }

                        }
                    }

                    PlasmaExtras.PlaceholderMessage {
                        anchors.centerIn:parent;width:parent.width-Kirigami.Units.gridUnit*4
                        visible:containerList.count===0;iconName:"edit-find"
                        text:searchFilter.length>0?i18n("No containers match \"%1\"",searchFilter):root.showAll?i18n("No containers found"):i18n("No running containers")
                    }
                }
            }
        } // End of Containers ColumnLayout

        // SECOND TAB: IMAGES
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true

            PlasmaComponents3.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                ListView {
                    id: imagesList
                    model: root.imagesListModel
                    clip: true
                    spacing: Kirigami.Units.smallSpacing
                    delegate: Kirigami.AbstractCard {
                        width: ListView.view.width - ListView.view.leftMargin - ListView.view.rightMargin
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Kirigami.Units.smallSpacing
                            Kirigami.Icon { source: "application-x-cd-image"; Layout.preferredWidth: Kirigami.Units.iconSizes.medium; Layout.preferredHeight: Kirigami.Units.iconSizes.medium }
                            ColumnLayout {
                                Layout.fillWidth: true
                                PlasmaComponents3.Label { text: modelData.repo + ":" + modelData.tag; font.weight: Font.Bold; elide: Text.ElideRight; Layout.fillWidth: true }
                                RowLayout {
                                    PlasmaComponents3.Label { text: "ID: " + modelData.id; font: Kirigami.Theme.smallFont; opacity: 0.6 }
                                    PlasmaComponents3.Label { text: "Size: " + modelData.size; font: Kirigami.Theme.smallFont; opacity: 0.8; Layout.alignment: Qt.AlignRight; Layout.fillWidth: true; horizontalAlignment: Text.AlignRight }
                                }
                            }
                            PlasmaComponents3.ToolButton {
                                icon.name: "edit-delete"
                                PlasmaComponents3.ToolTip { text: i18n("Remove Image") }
                                onClicked: actionSource.connectSource(root.dcmd + " rmi " + modelData.id)
                            }
                        }
                    }
                    PlasmaExtras.PlaceholderMessage {
                        anchors.centerIn: parent
                        width: parent.width - Kirigami.Units.gridUnit*4
                        visible: imagesList.count === 0
                        iconName: "edit-find"
                        text: i18n("No images found")
                    }
                }
            }
    }

    // ── Data Sources ────────────────────────────────────────────────────
    Plasma5Support.DataSource {
        id:containerInfoSource;engine:"executable";connectedSources:[]
        onNewData:function(source,data){
            var stdout=data["stdout"];
            if(stdout===undefined){containerInfoSource.disconnectSource(source);return;}
            var lines=stdout.trim().split("\n"),all=[],ns={},rc=0;
            for(var i=0;i<lines.length;i++){
                var p=lines[i].split("|");
                if(p.length>=4){
                var n=p[0].trim(),s=p[1].trim(),st=p[2].trim(),pt=p[3].trim();
                var labels = p.length>4 ? p[4].trim() : "";
                var prj = "";
                var match = labels.match(/com\.docker\.compose\.project=([^,]+)/);
                if (match) prj = match[1];
                if(n.length===0)continue;
                all.push({name:n,state:s,status:st,project:prj});
                    ns[n]=s;
                    root.containerPorts[n]=pt.replace(/,\s*/g,", ");
                    if(s==="running")rc++;
                }
            }
            if(root.initialized&&Plasmoid.configuration.enableNotifications){
                for(var n in ns){
                    if(root.previousStates[n]!==undefined&&root.previousStates[n]!==ns[n]){
                        var old=root.previousStates[n],cur=ns[n];
                        if(old==="running"&&cur!=="running") {
                            generalNotification.title = "OpsDash Alert"; generalNotification.text = "Container \"" + n + "\" " + cur; generalNotification.iconName = "dialog-warning"; generalNotification.sendEvent();
                        } else if(cur==="running"&&old!=="running") {
                            generalNotification.title = "OpsDash"; generalNotification.text = "Container \"" + n + "\" is now running"; generalNotification.iconName = "system-run"; generalNotification.sendEvent();
                        }
                    }
                }
                for(var n in root.previousStates){if(!ns[n]&&root.previousStates[n]==="running") {
                    generalNotification.title = "OpsDash Alert"; generalNotification.text = "Container \"" + n + "\" removed"; generalNotification.iconName = "dialog-warning"; generalNotification.sendEvent();
                }}
            }
            root.previousStates=ns;root.initialized=true;root.containerCount=rc.toString();
            all.sort(function(a,b){var o={running:0,restarting:1,paused:2,created:3,exited:4,dead:5};
                var oa=o[a.state]!==undefined?o[a.state]:6,ob=o[b.state]!==undefined?o[b.state]:6;
                if(oa!==ob)return oa-ob;return a.name.localeCompare(b.name);});
            if(!root.showAll)all=all.filter(function(c){return c.state==="running";});
            root.containers=all;containerInfoSource.disconnectSource(source);
        }
    }
    function runProjectAction(project, action) {
        var names = [];
        for (var i = 0; i < root.containers.length; i++) {
            if (root.containers[i].project === project) {
                names.push(root.containers[i].name);
            }
        }
        if (names.length > 0) {
            actionSource.connectSource(root.dcmd + " " + action + " " + names.join(" "));
        }
    }

    Plasma5Support.DataSource {
        id:statsSource;engine:"executable";connectedSources:[]
        onNewData:function(source,data){
            var stdout=data["stdout"];
            if(stdout===undefined||stdout.trim().length===0){statsSource.disconnectSource(source);return;}
            var lines=stdout.trim().split("\n"),ns={},nh={};
            for(var k in root.cpuHistory)nh[k]=root.cpuHistory[k].slice();
            for(var i=0;i<lines.length;i++){var p=lines[i].split("|");if(p.length>=5){
                var n=p[0].trim(),cpu=parseFloat(p[1])||0,mu=p[2].trim(),mp=parseFloat(p[3])||0,nio=p[4].trim();
                var mm=parseMemToMiB(mu),up=mu.split(" / ")[0].trim();
                ns[n]={cpu:cpu,memPerc:mp,memUsed:up,memMiB:mm,netIO:nio};
                if(!nh[n])nh[n]=[];nh[n]=nh[n].concat([cpu]);if(nh[n].length>root.historySize)nh[n]=nh[n].slice(-root.historySize);
                
                if (Plasmoid.configuration.enableResourceAlerts) {
                    if (cpu > Plasmoid.configuration.cpuAlertThreshold || mp > Plasmoid.configuration.memAlertThreshold) {
                        root.alertCount[n] = (root.alertCount[n] || 0) + 1;
                        if (root.alertCount[n] === 3) {
                            generalNotification.title = "OpsDash Resource Alert"; 
                            generalNotification.text = "Container \"" + n + "\" high usage (CPU: " + cpu.toFixed(1) + "%, Mem: " + mp.toFixed(1) + "%)"; 
                            generalNotification.iconName = "dialog-warning"; 
                            generalNotification.sendEvent();
                        }
                    } else {
                        root.alertCount[n] = 0;
                    }
                }
            }}
            for(var k in nh){if(!ns[k])delete nh[k];}
            root.containerStats=ns;root.cpuHistory=nh;
            if(root.sortMode===2||root.sortMode===3)root.updateDisplay();
            statsSource.disconnectSource(source);
            root.isFetching = false;
        }
    }
    Plasma5Support.DataSource {
        id:sysInfoSource;engine:"executable";connectedSources:[]
        onNewData:function(source,data){
            var stdout=data["stdout"];
            if(stdout!==undefined&&stdout.trim().length>0){var p=stdout.trim().split("|");
                if(p.length>=2)root.systemOverview={images:parseInt(p[0].trim())||0,totalContainers:parseInt(p[1].trim())||0};}
            sysInfoSource.disconnectSource(source);
        }
    }
    Plasma5Support.DataSource {
        id:actionSource;engine:"executable";connectedSources:[]
        onNewData:function(source,data){actionSource.disconnectSource(source);}
    }

    Timer {
        interval:Plasmoid.configuration.refreshInterval;running:true;repeat:true;triggeredOnStart:true
        onTriggered:{
            root.isFetching = true;
            containerInfoSource.connectSource(root.dcmd + " ps -a --format '{{.Names}}|{{.State}}|{{.Status}}|{{.Ports}}|{{.Labels}}'");
            statsSource.connectSource(root.dcmd + " stats --no-stream --format '{{.Name}}|{{.CPUPerc}}|{{.MemUsage}}|{{.MemPerc}}|{{.NetIO}}'");
            sysInfoSource.connectSource("echo \"$(" + root.dcmd + " images -q | wc -l)|$(" + root.dcmd + " ps -a -q | wc -l)\"");
            imageInfoSource.connectSource(root.dcmd + " images --format '{{.ID}}|{{.Repository}}|{{.Tag}}|{{.Size}}'");
        }
    }
    
    Plasma5Support.DataSource {
        id: imageInfoSource
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            var stdout = data["stdout"];
            if (stdout === undefined || stdout.trim().length === 0) {
                root.imagesListModel = [];
                disconnectSource(source);
                return;
            }
            var lines = stdout.trim().split("\n");
            var imgs = [];
            for (var i = 0; i < lines.length; i++) {
                var p = lines[i].split("|");
                if (p.length >= 4) {
                    imgs.push({ id: p[0], repo: p[1], tag: p[2], size: p[3] });
                }
            }
            root.imagesListModel = imgs;
            disconnectSource(source);
        }
    }
}
