import QtQuick
import QtQuick.Layouts

// The floating pill player bar.
Item {
    id: r
    required property var app
    signal expand()

    width: Math.min(parent.width - 24, 1040)
    height: 76

    Rectangle {
        id: bar
        anchors.fill: parent
        radius: 30
        color: Theme.containerHigh
        border.width: 1
        border.color: Theme.outlineVariant
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 16
        spacing: 4

        IconButton { visible: r.width > 820; icon: "shuffle"; iconSize: 19; active: r.app.shuffle; onClicked: r.app.shuffle = !r.app.shuffle }
        IconButton { icon: Theme.prev; iconSize: 17; onClicked: r.app.prev() }
        WavyButton { Layout.preferredWidth: 52; Layout.preferredHeight: 52; icon: r.app.playing ? Theme.pause : Theme.play; onClicked: r.app.toggle() }
        IconButton { icon: Theme.next; iconSize: 17; onClicked: r.app.next() }
        IconButton { visible: r.width > 820; icon: r.app.repeat ? "repeat_one" : "repeat"; iconSize: 19; active: r.app.repeat; onClicked: r.app.repeat = !r.app.repeat }
        Item { Layout.preferredWidth: 10 }

        // track info opens the immersive player
        Item {
            Layout.preferredWidth: 190
            Layout.minimumWidth: 130
            Layout.fillHeight: true
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: r.expand() }
            RowLayout {
                anchors.fill: parent
                spacing: 12
                Cover { Layout.preferredWidth: 48; Layout.preferredHeight: 48; radius: 14; source: r.app.cur ? r.app.cur.thumb : "" }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text { Layout.fillWidth: true; text: r.app.cur ? r.app.cur.title : Tr.t("Nothing playing"); color: Theme.fg; font.family: Theme.bodyFont; font.pixelSize: 15; font.weight: Font.DemiBold; elide: Text.ElideRight }
                    Text { Layout.fillWidth: true; text: r.app.note !== "" ? r.app.note : (r.app.cur ? r.app.cur.artist : ""); color: r.app.note !== "" ? Theme.primary : Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 13; elide: Text.ElideRight }
                }
            }
        }

        Text { text: r.app.fmt(r.app.position / 1000); color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 12; Layout.preferredWidth: 36; horizontalAlignment: Text.AlignRight }
        WaveSeek {
            Layout.fillWidth: true
            Layout.minimumWidth: 60
            position: r.app.position; duration: r.app.duration; playing: r.app.playing
            onSeeked: ms => r.app.seek(ms)
        }
        Text { text: r.app.fmt(r.app.duration / 1000); color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 12; Layout.preferredWidth: 36 }

        IconButton {
            readonly property bool liked: r.app.cur !== null && r.app.isLiked(r.app.cur.id)
            icon: liked ? Theme.heartFill : Theme.heart
            active: liked
            onClicked: if (r.app.cur) r.app.toggleLike(r.app.cur)
        }
        IconButton { visible: r.width > 700; icon: "lyrics"; onClicked: r.app.openPanel("lyrics") }
        IconButton { visible: r.width > 700; icon: "queue_music"; onClicked: r.app.openPanel("queue") }
        IconButton { visible: r.width > 700; icon: "bedtime"; active: r.app.sleepOn; onClicked: r.app.openSleep() }

        RowLayout {
            visible: r.width > 860
            Layout.preferredWidth: 96
            spacing: 6
            Text { text: r.app.volume < 0.01 ? Theme.volumeMute : Theme.volume; color: Theme.fgVariant; font.family: Theme.iconFont; renderType: Text.NativeRendering; font.pixelSize: 17 }
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                Rectangle {
                    y: parent.height / 2 - 2; width: parent.width; height: 4; radius: 2; color: Theme.secondaryContainer
                    Rectangle { width: parent.width * r.app.volume; height: parent.height; radius: 2; color: Theme.primary }
                }
                Rectangle { x: Math.min(parent.width - 4, Math.max(0, parent.width * r.app.volume - 2)); y: parent.height / 2 - 9; width: 4; height: 18; radius: 2; color: Theme.primary }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onPressed: m => r.app.volume = Math.min(1, Math.max(0, m.x / width))
                    onPositionChanged: m => { if (pressed) r.app.volume = Math.min(1, Math.max(0, m.x / width)) }
                }
            }
        }
        IconButton { visible: r.width > 760; icon: Theme.expand; onClicked: r.expand() }
    }
}
