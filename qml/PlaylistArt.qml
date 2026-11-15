import QtQuick

// A playlist's picture: the cover the person picked, one of the generated designs, or, with neither,
// a collage of its first songs' covers.
Item {
    id: r
    property var pl: null
    property real radius: 22
    readonly property string cv: pl && pl.cover ? pl.cover : ""
    readonly property var designs: [["#7c5cff", "#3a2a9e"], ["#ff6b9d", "#9e2a5c"], ["#ffb347", "#b3541e"], ["#3ddc97", "#1b7a57"], ["#4cc9f0", "#2a5fa8"], ["#c77dff", "#5a2a8a"]]
    readonly property int designIndex: cv.indexOf("design:") === 0 ? parseInt(cv.substring(7)) % designs.length : -1
    readonly property var tracks: pl && pl.tracks ? pl.tracks : []

    // a picked photo
    Cover { visible: r.cv.indexOf("file:") === 0; anchors.fill: parent; radius: r.radius; source: r.cv.indexOf("file:") === 0 ? r.cv : "" }
    // a generated design: two colours and the playlist's first letter
    Rectangle {
        visible: r.designIndex >= 0
        anchors.fill: parent; radius: r.radius
        gradient: Gradient {
            GradientStop { position: 0; color: r.designIndex >= 0 ? r.designs[r.designIndex][0] : "#000" }
            GradientStop { position: 1; color: r.designIndex >= 0 ? r.designs[r.designIndex][1] : "#000" }
        }
        Text {
            anchors.centerIn: parent
            text: r.pl && r.pl.name ? r.pl.name.charAt(0).toUpperCase() : ""
            color: "#d9ffffff"; font.family: Theme.headFont; font.weight: Font.Bold
            font.pixelSize: r.height * 0.5
        }
    }
    // the first songs' covers
    Item {
        visible: r.cv === "" && r.tracks.length > 0
        anchors.fill: parent
        Grid {
            anchors.fill: parent; columns: 2; spacing: 3
            Repeater {
                model: 4
                delegate: Cover {
                    required property int index
                    width: (r.width - 3) / 2; height: (r.height - 3) / 2
                    radius: Math.max(6, r.radius * 0.55)
                    source: r.tracks.length ? (r.tracks[index % r.tracks.length].thumb || "") : ""
                }
            }
        }
    }
    // nothing in it yet
    Rectangle {
        visible: r.cv === "" && r.tracks.length === 0
        anchors.fill: parent; radius: r.radius; color: Theme.containerHigh
        Text { anchors.centerIn: parent; text: "queue_music"; color: Theme.fgVariant; font.family: Theme.iconFont; renderType: Text.NativeRendering; font.pixelSize: r.height * 0.34 }
    }
}
