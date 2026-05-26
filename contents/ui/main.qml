import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

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
    property bool initialized: false
    property bool showAll: Plasmoid.configuration.showAllContainers
    property string searchFilter: ""
    property int sortMode: 0
    readonly property int historySize: 30
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

    // ── Feature 9: Warning badge ────────────────────────────────────────
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
    component UsageBar : Item {
        property real value: 0.0
        implicitWidth: 40; implicitHeight: Kirigami.Units.smallSpacing
        Rectangle { anchors.fill:parent; radius:height/2; color:Kirigami.ColorUtils.tintWithAlpha(Kirigami.Theme.backgroundColor,Kirigami.Theme.textColor,0.88) }
        Rectangle { height:parent.height; radius:height/2; width:Math.max(radius*2,parent.width*Math.min(value,100)/100);
            color:value<60?Kirigami.Theme.positiveTextColor:value<85?"#f67400":Kirigami.Theme.negativeTextColor }
    }
    component Sparkline : Canvas {
        property var points:[]; property color lc:Kirigami.Theme.positiveTextColor
        implicitWidth:44; implicitHeight:12
        onPointsChanged:requestPaint()
        onPaint:{var c=getContext('2d');c.clearRect(0,0,width,height);if(points.length<2)return;
            var mx=0;for(var i=0;i<points.length;i++)if(points[i]>mx)mx=points[i];if(mx<=0)mx=1;
            c.beginPath();c.strokeStyle=lc.toString();c.lineWidth=1.2;
            for(var i=0;i<points.length;i++){var x=(i/(points.length-1))*width;var y=height-(points[i]/mx)*(height*0.8)-height*0.1;
            if(i===0)c.moveTo(x,y);else c.lineTo(x,y);}c.stroke();}
    }

    // ── Plasmoid metadata ───────────────────────────────────────────────
    Plasmoid.title: "OpsDash"
    Plasmoid.icon: "docker"
    toolTipMainText: "OpsDash"
    toolTipSubText: i18n("%1/%2 up \u00B7 CPU %3% \u00B7 Mem %4",
        containerCount, systemOverview.totalContainers,
        totalCpu.toFixed(1), formatMem(totalMem))

    // ═════════════════════════════════════════════════════════════════════
    // PANEL STRIP (with Feature 9: warning badge)
    // ═════════════════════════════════════════════════════════════════════
    compactRepresentation: MouseArea {
        anchors.fill: parent; hoverEnabled: true
        property bool we: false
        onPressed: mouse => { we = root.expanded; }
        onClicked: mouse => { root.expanded = !we; }
        RowLayout {
            anchors.fill: parent; spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon {
                source: Qt.resolvedUrl("icons/docker.svg")
                Layout.preferredHeight: Plasmoid.configuration.panelIconSize
                Layout.preferredWidth: Plasmoid.configuration.panelIconSize
                Layout.alignment: Qt.AlignVCenter
            }
            PlasmaComponents3.Label {
                text: root.containerCount
                font.weight: Font.Bold
                font.pixelSize: Plasmoid.configuration.panelFontSize
                color: root.panelColor
                Layout.alignment: Qt.AlignVCenter
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                Layout.minimumWidth: implicitWidth
                Layout.preferredWidth: implicitWidth
            }
            // Feature 9: warning badge
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
                Kirigami.Icon {
                    source: "view-visible"
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    opacity: 0.5; color: root.showAll?Kirigami.Theme.highlightColor:Kirigami.Theme.textColor
                    Layout.alignment: Qt.AlignVCenter
                    PlasmaComponents3.ToolTip { text: root.showAll?i18n("Showing all"):i18n("Running only"); delay: Kirigami.Units.toolTipDelay }
                    MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked:{root.showAll=!root.showAll;Plasmoid.configuration.showAllContainers=root.showAll;Plasmoid.configuration.showAllContainersChanged();} }
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
                        UsageBar{value:root.totalCpu}
                        PlasmaComponents3.Label{text:root.totalCpu.toFixed(1)+"%";font:Kirigami.Theme.smallFont}
                        Rectangle{Layout.preferredWidth:1;Layout.preferredHeight:10;color:sepColor}
                        PlasmaComponents3.Label{text:"Mem";font:Kirigami.Theme.smallFont;opacity:0.4}
                        PlasmaComponents3.Label{text:formatMem(root.totalMem);font:Kirigami.Theme.smallFont}
                    }
                    RowLayout {
                        Layout.fillWidth:true;spacing:Kirigami.Units.smallSpacing
                        PlasmaComponents3.Label{text:i18n("Quick:");font:Kirigami.Theme.smallFont;opacity:0.4}
                        Kirigami.Icon{source:"media-playback-start";Layout.preferredHeight:Kirigami.Units.iconSizes.tiny;Layout.preferredWidth:Kirigami.Units.iconSizes.tiny;opacity:0.5;MouseArea{anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:actionSource.connectSource("bash -c \"docker start $(docker ps -a -q -f status=exited -f status=created)\"")} PlasmaComponents3.ToolTip{text:i18n("Start All");delay:Kirigami.Units.toolTipDelay}}
                        Kirigami.Icon{source:"process-stop";Layout.preferredHeight:Kirigami.Units.iconSizes.tiny;Layout.preferredWidth:Kirigami.Units.iconSizes.tiny;opacity:0.5;MouseArea{anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:actionSource.connectSource("bash -c \"docker stop $(docker ps -q)\"")} PlasmaComponents3.ToolTip{text:i18n("Stop All");delay:Kirigami.Units.toolTipDelay}}
                        Kirigami.Icon{source:"view-refresh";Layout.preferredHeight:Kirigami.Units.iconSizes.tiny;Layout.preferredWidth:Kirigami.Units.iconSizes.tiny;opacity:0.5;MouseArea{anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:actionSource.connectSource("bash -c \"docker restart $(docker ps -q)\"")} PlasmaComponents3.ToolTip{text:i18n("Restart All");delay:Kirigami.Units.toolTipDelay}}
                        Item{Layout.fillWidth:true}
                    }
                }
            }

            Kirigami.Separator{Layout.fillWidth:true}

            // Search
            RowLayout {
                Layout.fillWidth:true;spacing:Kirigami.Units.smallSpacing
                Kirigami.Icon{source:"edit-find";Layout.preferredHeight:Kirigami.Units.iconSizes.small;Layout.preferredWidth:Kirigami.Units.iconSizes.small;opacity:0.4}
                QQC2.TextField {
                    Layout.fillWidth:true;placeholderText:i18n("Search containers...")
                    font:Kirigami.Theme.smallFont;topPadding:2;bottomPadding:2
                    onTextChanged:root.searchFilter=text
                }
            }

            // Sort buttons
            RowLayout {
                Layout.fillWidth:true;spacing:4
                PlasmaComponents3.Label{text:i18n("Sort:");font:Kirigami.Theme.smallFont;opacity:0.35;Layout.alignment:Qt.AlignVCenter}
                Rectangle {
                    radius:3;implicitWidth:sN.implicitWidth+8;implicitHeight:sN.implicitHeight+4;Layout.alignment:Qt.AlignVCenter
                    property bool active:root.sortMode===0
                    color:active?Kirigami.ColorUtils.tintWithAlpha(Kirigami.Theme.positiveTextColor,Kirigami.Theme.backgroundColor,0.7):"transparent"
                    border.color:active?Kirigami.Theme.positiveTextColor:"transparent";border.width:active?1:0
                    PlasmaComponents3.Label{id:sN;anchors.centerIn:parent;text:i18n("Name");font.pixelSize:Kirigami.Theme.defaultFont.pixelSize;color:parent.active?Kirigami.Theme.positiveTextColor:Kirigami.Theme.textColor;opacity:parent.active?1.0:0.4}
                    MouseArea{anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:root.sortMode=0}
                }
                Rectangle {
                    radius:3;implicitWidth:sS.implicitWidth+8;implicitHeight:sS.implicitHeight+4;Layout.alignment:Qt.AlignVCenter
                    property bool active:root.sortMode===1
                    color:active?Kirigami.ColorUtils.tintWithAlpha(Kirigami.Theme.positiveTextColor,Kirigami.Theme.backgroundColor,0.7):"transparent"
                    border.color:active?Kirigami.Theme.positiveTextColor:"transparent";border.width:active?1:0
                    PlasmaComponents3.Label{id:sS;anchors.centerIn:parent;text:i18n("State");font.pixelSize:Kirigami.Theme.defaultFont.pixelSize;color:parent.active?Kirigami.Theme.positiveTextColor:Kirigami.Theme.textColor;opacity:parent.active?1.0:0.4}
                    MouseArea{anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:root.sortMode=1}
                }
                Rectangle {
                    radius:3;implicitWidth:sC.implicitWidth+8;implicitHeight:sC.implicitHeight+4;Layout.alignment:Qt.AlignVCenter
                    property bool active:root.sortMode===2
                    color:active?Kirigami.ColorUtils.tintWithAlpha(Kirigami.Theme.positiveTextColor,Kirigami.Theme.backgroundColor,0.7):"transparent"
                    border.color:active?Kirigami.Theme.positiveTextColor:"transparent";border.width:active?1:0
                    PlasmaComponents3.Label{id:sC;anchors.centerIn:parent;text:i18n("CPU");font.pixelSize:Kirigami.Theme.defaultFont.pixelSize;color:parent.active?Kirigami.Theme.positiveTextColor:Kirigami.Theme.textColor;opacity:parent.active?1.0:0.4}
                    MouseArea{anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:root.sortMode=2}
                }
                Rectangle {
                    radius:3;implicitWidth:sM.implicitWidth+8;implicitHeight:sM.implicitHeight+4;Layout.alignment:Qt.AlignVCenter
                    property bool active:root.sortMode===3
                    color:active?Kirigami.ColorUtils.tintWithAlpha(Kirigami.Theme.positiveTextColor,Kirigami.Theme.backgroundColor,0.7):"transparent"
                    border.color:active?Kirigami.Theme.positiveTextColor:"transparent";border.width:active?1:0
                    PlasmaComponents3.Label{id:sM;anchors.centerIn:parent;text:i18n("Mem");font.pixelSize:Kirigami.Theme.defaultFont.pixelSize;color:parent.active?Kirigami.Theme.positiveTextColor:Kirigami.Theme.textColor;opacity:parent.active?1.0:0.4}
                    MouseArea{anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:root.sortMode=3}
                }
                Item{Layout.fillWidth:true}
                PlasmaComponents3.Label{text:(root.showAll?i18n("All"):i18n("Running"))+" ("+containerList.count+")";font:Kirigami.Theme.smallFont;opacity:0.35;Layout.alignment:Qt.AlignVCenter}
            }

            // Container List
            PlasmaComponents3.ScrollView {
                Layout.fillWidth:true;Layout.fillHeight:true;Layout.minimumHeight:Kirigami.Units.gridUnit*6
                ListView {
                    id:containerList;model:root.displayContainers;spacing:3;clip:true

                    delegate: Kirigami.AbstractCard {
                        width:ListView.view.width-ListView.view.leftMargin-ListView.view.rightMargin
                        readonly property string cn:modelData.name
                        readonly property string cs:modelData.state
                        readonly property string cst:modelData.status
                        readonly property var st:root.containerStats[cn]||null
                        readonly property var ch:root.cpuHistory[cn]||[]
                        readonly property string ports:root.containerPorts[cn]||""
                        readonly property bool run:cs==="running"

                        background:Rectangle {
                            radius:4
                            color:Kirigami.ColorUtils.tintWithAlpha(Kirigami.Theme.backgroundColor,Kirigami.Theme.textColor,run?0.03:0.06)
                            border.color:Kirigami.ColorUtils.tintWithAlpha(stateColor(cs),Kirigami.Theme.backgroundColor,0.55)
                            border.width:Plasmoid.configuration.borderThickness;opacity:run?1.0:0.75
                        }

                        contentItem: ColumnLayout {
                            spacing:2

                            // Row 1: dot + icon + name + uptime
                            RowLayout {
                                Layout.fillWidth:true;spacing:Kirigami.Units.smallSpacing
                                Rectangle{Layout.preferredWidth:4;Layout.fillHeight:true;Layout.topMargin:2;Layout.bottomMargin:2;radius:2;color:stateColor(cs)}
                                Kirigami.Icon{source:Qt.resolvedUrl("../icons/docker.svg");Layout.preferredHeight:Plasmoid.configuration.popupCardFontSize>0?Plasmoid.configuration.popupCardFontSize*1.45:Kirigami.Units.iconSizes.small;Layout.preferredWidth:Plasmoid.configuration.popupCardFontSize>0?Plasmoid.configuration.popupCardFontSize*1.45:Kirigami.Units.iconSizes.small;Layout.alignment:Qt.AlignVCenter;opacity:run?1.0:0.5}
                                PlasmaComponents3.Label{text:cn;font.weight:Font.Bold;font.pixelSize:Plasmoid.configuration.popupCardFontSize>0?Plasmoid.configuration.popupCardFontSize:Kirigami.Theme.smallFont.pixelSize;color:Plasmoid.configuration.popupCardFontColor.length>0?Plasmoid.configuration.popupCardFontColor:Kirigami.Theme.textColor;Layout.fillWidth:true;Layout.alignment:Qt.AlignVCenter;elide:Text.ElideRight;opacity:run?1.0:0.6}
                                PlasmaComponents3.Label{visible:run;text:fmtUptime(cst);font:Kirigami.Theme.smallFont;opacity:0.4;Layout.alignment:Qt.AlignVCenter}

                                // Inline actions
                                RowLayout{
                                    spacing:2;Layout.alignment:Qt.AlignVCenter

                                    Item {
                                        visible: cs==="exited"||cs==="created"||cs==="paused"
                                        width:16; height:16
                                        Kirigami.Icon{anchors.fill:parent;source:"media-playback-start";opacity:0.5}
                                        MouseArea{anchors.fill:parent;cursorShape:Qt.PointingHandCursor
                                            onClicked:actionSource.connectSource("bash -c \"docker start "+cn+"\"")}
                                        PlasmaComponents3.ToolTip{text:i18n("Start");delay:Kirigami.Units.toolTipDelay}
                                    }

                                    Item {
                                        visible: run; width:16; height:16
                                        Kirigami.Icon{anchors.fill:parent;source:"process-stop";opacity:0.5}
                                        MouseArea{anchors.fill:parent;cursorShape:Qt.PointingHandCursor
                                            onClicked:actionSource.connectSource("bash -c \"docker stop "+cn+"\"")}
                                        PlasmaComponents3.ToolTip{text:i18n("Stop");delay:Kirigami.Units.toolTipDelay}
                                    }

                                    Item {
                                        visible: run; width:16; height:16
                                        Kirigami.Icon{anchors.fill:parent;source:"view-refresh";opacity:0.5}
                                        MouseArea{anchors.fill:parent;cursorShape:Qt.PointingHandCursor
                                            onClicked:actionSource.connectSource("bash -c \"docker restart "+cn+"\"")}
                                        PlasmaComponents3.ToolTip{text:i18n("Restart");delay:Kirigami.Units.toolTipDelay}
                                    }

                                    Item {
                                        visible: run; width:16; height:16
                                        Kirigami.Icon{anchors.fill:parent;source:"utilities-terminal";opacity:0.5}
                                        MouseArea{anchors.fill:parent;cursorShape:Qt.PointingHandCursor
                                            onClicked:actionSource.connectSource("bash -c \"konsole -e bash -c 'docker logs --tail 50 -f "+cn+"'\"")}
                                        PlasmaComponents3.ToolTip{text:i18n("Logs");delay:Kirigami.Units.toolTipDelay}
                                    }

                                    Item {
                                        visible: !run; width:16; height:16
                                        Kirigami.Icon{anchors.fill:parent;source:"edit-delete-remove";opacity:0.5}
                                        MouseArea{anchors.fill:parent;cursorShape:Qt.PointingHandCursor
                                            onClicked:actionSource.connectSource("bash -c \"docker rm "+cn+"\"")}
                                        PlasmaComponents3.ToolTip{text:i18n("Remove");delay:Kirigami.Units.toolTipDelay}
                                    }
                                }
                            }

                            // Row 2a: Stats (running) — clean, no inline buttons
                            RowLayout {
                                Layout.fillWidth:true;spacing:Kirigami.Units.smallSpacing;visible:run&&st!==null
                                Item{Layout.preferredWidth:4}Item{Layout.preferredWidth:Kirigami.Units.iconSizes.small}Item{Layout.preferredWidth:Kirigami.Units.smallSpacing}
                                PlasmaComponents3.Label{text:"CPU";font:Kirigami.Theme.smallFont;opacity:0.35}
                                UsageBar{value:st?st.cpu:0}
                                PlasmaComponents3.Label{text:st?st.cpu.toFixed(1)+"%":"";font:Kirigami.Theme.smallFont;color:st&&st.cpu>=85?Kirigami.Theme.negativeTextColor:st&&st.cpu>=60?"#f67400":Kirigami.Theme.textColor;Layout.preferredWidth:Kirigami.Units.gridUnit*2}
                                Sparkline{points:ch;lc:st&&st.cpu>=85?Kirigami.Theme.negativeTextColor:st&&st.cpu>=60?"#f67400":Kirigami.Theme.positiveTextColor}
                                Rectangle{Layout.preferredWidth:1;Layout.preferredHeight:10;color:sepColor}
                                PlasmaComponents3.Label{text:st?st.memUsed:"";font:Kirigami.Theme.smallFont;color:st&&st.memPerc>=85?Kirigami.Theme.negativeTextColor:st&&st.memPerc>=60?"#f67400":Kirigami.Theme.textColor}
                                Rectangle{Layout.preferredWidth:1;Layout.preferredHeight:10;color:sepColor}
                                Kirigami.Icon{source:"network-wireless-symbolic";Layout.preferredHeight:Kirigami.Units.iconSizes.tiny;Layout.preferredWidth:Kirigami.Units.iconSizes.tiny;opacity:0.4}
                                PlasmaComponents3.Label{text:st?fmtNet(st.netIO):"";font:Kirigami.Theme.smallFont;opacity:0.55;Layout.fillWidth:true;elide:Text.ElideRight}
                            }

                            // Row 2b: Status (stopped)
                            RowLayout {
                                Layout.fillWidth:true;spacing:4;visible:!run
                                Item{Layout.preferredWidth:4}Item{Layout.preferredWidth:Kirigami.Units.iconSizes.small}Item{Layout.preferredWidth:Kirigami.Units.smallSpacing}
                                Kirigami.Icon{source:stateIcon(cs);Layout.preferredHeight:Kirigami.Units.iconSizes.tiny;Layout.preferredWidth:Kirigami.Units.iconSizes.tiny;opacity:0.35}
                                PlasmaComponents3.Label{text:cst;font:Kirigami.Theme.smallFont;opacity:0.35;Layout.fillWidth:true;elide:Text.ElideRight}
                            }

                            // Row 3: Port info (Feature 12)
                            RowLayout {
                                Layout.fillWidth:true;spacing:4;visible:ports.length>0
                                Item{Layout.preferredWidth:4}Item{Layout.preferredWidth:Kirigami.Units.iconSizes.small}Item{Layout.preferredWidth:Kirigami.Units.smallSpacing}
                                Kirigami.Icon{source:"network-server";Layout.preferredHeight:Kirigami.Units.iconSizes.tiny;Layout.preferredWidth:Kirigami.Units.iconSizes.tiny;opacity:0.3}
                                PlasmaComponents3.Label{text:ports;font:Kirigami.Theme.smallFont;opacity:0.3;Layout.fillWidth:true;elide:Text.ElideRight}
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
                    if(n.length===0)continue;
                    all.push({name:n,state:s,status:st});
                    ns[n]=s;
                    root.containerPorts[n]=pt.replace(/,\s*/g,", ");
                    if(s==="running")rc++;
                }
            }
            if(root.initialized&&Plasmoid.configuration.enableNotifications){
                for(var n in ns){
                    if(root.previousStates[n]!==undefined&&root.previousStates[n]!==ns[n]){
                        var old=root.previousStates[n],cur=ns[n];
                        if(old==="running"&&cur!=="running")
                            actionSource.connectSource("notify-send -a OpsDash -i dialog-warning 'OpsDash Alert' 'Container \\\""+n+"\\\" "+cur+"'");
                        else if(cur==="running"&&old!=="running")
                            actionSource.connectSource("notify-send -a OpsDash -i system-run 'OpsDash' 'Container \\\""+n+"\\\" is now running'");
                    }
                }
                for(var n in root.previousStates){if(!ns[n]&&root.previousStates[n]==="running")
                    actionSource.connectSource("notify-send -a OpsDash -i dialog-warning 'OpsDash Alert' 'Container \\\""+n+"\\\" removed'");}
            }
            root.previousStates=ns;root.initialized=true;root.containerCount=rc.toString();
            all.sort(function(a,b){var o={running:0,restarting:1,paused:2,created:3,exited:4,dead:5};
                var oa=o[a.state]!==undefined?o[a.state]:6,ob=o[b.state]!==undefined?o[b.state]:6;
                if(oa!==ob)return oa-ob;return a.name.localeCompare(b.name);});
            if(!root.showAll)all=all.filter(function(c){return c.state==="running";});
            root.containers=all;containerInfoSource.disconnectSource(source);
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
            }}
            for(var k in nh){if(!ns[k])delete nh[k];}
            root.containerStats=ns;root.cpuHistory=nh;
            if(root.sortMode===2||root.sortMode===3)root.updateDisplay();
            statsSource.disconnectSource(source);
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
            containerInfoSource.connectSource("docker ps -a --format '{{.Names}}|{{.State}}|{{.Status}}|{{.Ports}}'");
            statsSource.connectSource("docker stats --no-stream --format '{{.Name}}|{{.CPUPerc}}|{{.MemUsage}}|{{.MemPerc}}|{{.NetIO}}'");
            sysInfoSource.connectSource("echo \"$(docker images -q | wc -l)|$(docker ps -a -q | wc -l)\"");
        }
    }
}
