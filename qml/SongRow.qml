import QtQuick
import QtQuick.Layouts

// One song in a search result. `spotify` rows have no YouTube id yet: playing one finds a match first.
Item {
    id: row
    required property var app
    required property var song
    property var list: []
    property int idx: 0
    property bool spotify: false
    readonly property bool current: app.cur !== null && song.id !== "" && app.cur.id === song.id
    readonly property bool liked: song.id !== "" && app.isLiked(song.id)
    height: 64

    Rectangle {
        anchors.fill: parent; radius: Theme.radiusNormal
        color: row.current ? Theme.secondaryContainer : Theme.fg
        opacity: row.current ? 1 : (ma.containsMouse ? 0.07 : 0)
        Behavior on opacity { NumberAnimation { duration: Theme.quick } }
    }
    MouseArea {
        id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: m => {
            if (m.button === Qt.RightButton) { if (!row.spotify) row.app.songMenuFor(row.song) }
            else row.spotify ? row.app.playSpotify(row.song) : row.app.playList(row.list, row.idx)
        }
    }
    Timer { running: ma.containsMouse && row.song.id !== ""; interval: 250; onTriggered: row.app.api.prefetch(row.song.id) }

    RowLayout {
        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 6; spacing: 14
        Cover { Layout.preferredWidth: 46; Layout.preferredHeight: 46; radius: 12; source: row.song.thumb || "" }
        ColumnLayout {
            Layout.fillWidth: true; spacing: 2
            Text { Layout.fillWidth: true; text: row.song.title; color: row.current ? Theme.primary : Theme.fg; font.family: Theme.bodyFont; font.pixelSize: 15; font.weight: Font.DemiBold; elide: Text.ElideRight }
            Text { Layout.fillWidth: true; text: row.song.artist + (row.song.album ? "  ·  " + row.song.album : ""); color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 13; elide: Text.ElideRight }
        }
        Text { text: row.app.fmt(row.song.dur); color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 13; Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight }
        IconButton { visible: !row.spotify; icon: row.liked ? Theme.heartFill : Theme.heart; active: row.liked; onClicked: row.app.toggleLike(row.song) }
        IconButton { visible: !row.spotify; icon: Theme.download; onClicked: row.app.download([row.song]) }
        IconButton { visible: !row.spotify; icon: "more_horiz"; onClicked: row.app.songMenuFor(row.song) }
    }
}
