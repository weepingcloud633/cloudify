import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// Rows of tracks. Click plays the list from that row.
ListView {
    id: r
    required property var app
    property var tracks: []
    property int bottomPad: 110
    clip: true
    model: tracks
    bottomMargin: bottomPad
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
        contentItem: Rectangle { implicitWidth: 6; radius: 3; color: Theme.outline; opacity: 0.6 }
    }

    // rows rise in one after another (first few only, so long lists stay instant)
    populate: Transition {
        SequentialAnimation {
            PropertyAction { property: "opacity"; value: 0 }
            PauseAnimation { duration: Theme.motion ? Math.max(0, Math.min(ViewTransition.index, 9)) * 28 : 0 }
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.motion ? 280 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve }
                NumberAnimation { property: "y"; from: ViewTransition.destination.y + (Theme.motion ? 16 : 0); duration: Theme.motion ? 320 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve }
            }
        }
    }

    delegate: Item {
        id: row
        required property var modelData
        required property int index
        readonly property bool current: r.app.cur && r.app.cur.id === modelData.id
        readonly property bool liked: r.app.isLiked(modelData.id)
        width: ListView.view.width - 10
        height: 64

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusNormal
            color: row.current ? Theme.secondaryContainer : Theme.fg
            opacity: row.current ? 1 : (ma.containsMouse ? 0.07 : 0)
            Behavior on opacity { NumberAnimation { duration: Theme.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } }
        }
        MouseArea {
            id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: m => m.button === Qt.RightButton ? r.app.songMenuFor(row.modelData) : r.app.playList(r.tracks, row.index)
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 6
            spacing: 14
            Cover { Layout.preferredWidth: 46; Layout.preferredHeight: 46; radius: 12; source: row.modelData.thumb || "" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    text: row.modelData.title
                    color: row.current ? Theme.primary : Theme.fg
                    font.family: Theme.bodyFont; font.pixelSize: 15; font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: row.modelData.artist + (row.modelData.album ? "  ·  " + row.modelData.album : "")
                    color: Theme.fgVariant
                    font.family: Theme.bodyFont; font.pixelSize: 13
                    elide: Text.ElideRight
                }
            }
            Text {
                text: r.app.fmt(row.modelData.dur)
                color: Theme.fgVariant
                font.family: Theme.bodyFont; font.pixelSize: 13
                Layout.preferredWidth: 48
                horizontalAlignment: Text.AlignRight
            }
            IconButton { icon: row.liked ? Theme.heartFill : Theme.heart; active: row.liked; onClicked: r.app.toggleLike(row.modelData) }
            IconButton { visible: row.modelData.id.indexOf("local:") !== 0; icon: Theme.download; onClicked: r.app.download([row.modelData]) }
            IconButton { icon: "more_horiz"; onClicked: r.app.songMenuFor(row.modelData) }
        }
    }
}
