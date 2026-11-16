import QtQuick
import QtQuick.Controls.Basic

// What you listen to: time, the last two weeks, top songs and top artists.
Flickable {
    id: r
    required property var app
    property var s: ({totalSecs: 0, plays: 0, weekSecs: 0, songs: [], artists: [], days: []})
    contentHeight: col.height + 150
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { contentItem: Rectangle { implicitWidth: 6; radius: 3; color: Theme.outline; opacity: 0.6 } }

    function load() { s = JSON.parse(app.api.stats()) }
    Component.onCompleted: load()
    onVisibleChanged: if (visible) load()

    function dur(secs) {
        var m = Math.round(secs / 60)
        if (m < 60) return m + " " + Tr.t("min")
        return Math.floor(m / 60) + " " + Tr.t("h") + " " + (m % 60) + " " + Tr.t("min")
    }

    Column {
        id: col
        x: 28; y: 26
        width: r.width - 56
        spacing: 22

        Text { text: Tr.t("Your stats"); color: Theme.fg; font.family: Theme.headFont; font.pixelSize: 38; font.weight: Font.Bold; font.letterSpacing: -0.5 }

        Row {
            spacing: 16
            Repeater {
                model: [
                    {t: Tr.t("Listening time"), v: r.dur(r.s.totalSecs), i: "schedule"},
                    {t: Tr.t("Past 7 days"), v: r.dur(r.s.weekSecs), i: "calendar_month"},
                    {t: Tr.t("Songs played"), v: r.s.plays + "", i: "music_note"}
                ]
                delegate: Rectangle {
                    required property var modelData
                    width: (col.width - 32) / 3; height: 96; radius: Theme.radiusNormal; color: Theme.containerHigh
                    Row {
                        anchors.fill: parent; anchors.margins: 16; spacing: 14
                        Rectangle { width: 48; height: 48; radius: 16; color: Theme.primaryContainer; anchors.verticalCenter: parent.verticalCenter
                            Text { anchors.centerIn: parent; text: modelData.i; color: Theme.fgPrimaryContainer; font.family: Theme.iconFont; renderType: Text.NativeRendering; font.pixelSize: 24 } }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: modelData.v; color: Theme.fg; font.family: Theme.headFont; font.pixelSize: 24; font.weight: Font.Bold }
                            Text { text: modelData.t; color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 13 }
                        }
                    }
                }
            }
        }

        // the last 14 days
        Rectangle {
            width: parent.width; height: 190; radius: Theme.radiusNormal; color: Theme.containerHigh
            readonly property real peak: Math.max(60, Math.max.apply(null, r.s.days.length ? r.s.days : [0]))
            Text { x: 18; y: 14; text: Tr.t("Last 14 days"); color: Theme.fg; font.family: Theme.bodyFont; font.pixelSize: 15; font.weight: Font.DemiBold }
            Row {
                x: 18; y: 44; width: parent.width - 36; height: 110; spacing: 8
                Repeater {
                    model: r.s.days
                    delegate: Item {
                        required property real modelData
                        required property int index
                        width: (parent.width - 13 * 8) / 14; height: 110
                        Rectangle {
                            anchors.bottom: parent.bottom; width: parent.width; radius: 6
                            height: Math.max(6, parent.height * (modelData / parent.parent.peak))
                            color: index === 13 ? Theme.primary : Theme.primaryContainer
                            Behavior on height { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
                        }
                    }
                }
            }
            Text { x: 18; y: 160; text: Tr.t("14 days ago"); color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 12 }
            Text { anchors.right: parent.right; anchors.rightMargin: 18; y: 160; text: Tr.t("Today"); color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 12 }
        }

        Row {
            width: parent.width; spacing: 16
            Column {
                width: (parent.width - 16) / 2; spacing: 8
                Text { text: Tr.t("Top songs"); color: Theme.fg; font.family: Theme.headFont; font.pixelSize: 22; font.weight: Font.Bold; bottomPadding: 4 }
                Text { visible: r.s.songs.length === 0; text: Tr.t("Play some music and it shows up here."); color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 14 }
                Repeater {
                    model: r.s.songs
                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: parent.width; height: 56
                        Rectangle { anchors.fill: parent; radius: 14; color: Theme.fg; opacity: sma.containsMouse ? 0.07 : 0; Behavior on opacity { NumberAnimation { duration: Theme.quick } } }
                        Text { id: rk; x: 10; anchors.verticalCenter: parent.verticalCenter; width: 22; text: (index + 1) + ""; color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 14; font.weight: Font.DemiBold }
                        Cover { id: sc; x: 38; anchors.verticalCenter: parent.verticalCenter; width: 40; height: 40; radius: 10; source: modelData.thumb || "" }
                        Column {
                            anchors.left: sc.right; anchors.leftMargin: 12; anchors.right: pc.left; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                            Text { width: parent.width; text: modelData.title; elide: Text.ElideRight; color: Theme.fg; font.family: Theme.bodyFont; font.pixelSize: 14; font.weight: Font.DemiBold }
                            Text { width: parent.width; text: modelData.artist; elide: Text.ElideRight; color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 12 }
                        }
                        Text { id: pc; anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: modelData.plays + "×"; color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 13 }
                        MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: r.app.playList(r.s.songs, index) }
                    }
                }
            }
            Column {
                width: (parent.width - 16) / 2; spacing: 8
                Text { text: Tr.t("Top artists"); color: Theme.fg; font.family: Theme.headFont; font.pixelSize: 22; font.weight: Font.Bold; bottomPadding: 4 }
                Text { visible: r.s.artists.length === 0; text: Tr.t("Your most played artists show up here."); color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 14 }
                Repeater {
                    model: r.s.artists
                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: parent.width; height: 52
                        readonly property real topSecs: r.s.artists.length ? r.s.artists[0].secs : 1
                        Text { x: 10; anchors.verticalCenter: parent.verticalCenter; width: 22; text: (index + 1) + ""; color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 14; font.weight: Font.DemiBold }
                        Column {
                            x: 38; width: parent.width - 48; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                            Row {
                                width: parent.width
                                Text { width: parent.width - 80; text: modelData.name; elide: Text.ElideRight; color: Theme.fg; font.family: Theme.bodyFont; font.pixelSize: 14; font.weight: Font.DemiBold }
                                Text { width: 80; horizontalAlignment: Text.AlignRight; text: r.dur(modelData.secs); color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 12 }
                            }
                            Rectangle { width: parent.width; height: 6; radius: 3; color: Theme.secondaryContainer
                                Rectangle { width: Math.max(6, parent.width * modelData.secs / topSecs); height: 6; radius: 3; color: Theme.primary } }
                        }
                    }
                }
            }
        }
    }
}
