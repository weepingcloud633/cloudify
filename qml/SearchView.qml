import QtQuick
import QtQuick.Controls.Basic

// Search: browse-by-genre tiles when empty; songs, albums, artists (and Spotify) for a query.
Flickable {
    id: r
    required property var app
    readonly property bool searchActive: sf.activeFocus
    function focusSearch() { sf.forceActiveFocus() }
    property string query: ""
    readonly property bool hasResults: query !== "" && app.found !== null
    contentHeight: col.height + 150
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { contentItem: Rectangle { implicitWidth: 6; radius: 3; color: Theme.outline; opacity: 0.6 } }

    function run(q) { query = q; sf.text = q; if (q !== "") app.searchAll(q) }

    component Heading: Row {
        property string label
        property string iconName
        width: parent.width; spacing: 12
        Rectangle { width: 36; height: 36; radius: 12; color: Theme.primaryContainer; anchors.verticalCenter: parent.verticalCenter
            Text { anchors.centerIn: parent; text: iconName; font.family: Theme.iconFont; renderType: Text.NativeRendering; font.pixelSize: 20; color: Theme.fgPrimaryContainer } }
        Text { id: ht; text: label; color: Theme.fg; font.family: Theme.headFont; font.pixelSize: 24; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
        Squiggle { width: parent.width - ht.width - 60; anchors.verticalCenter: parent.verticalCenter }
    }

    Column {
        id: col
        x: 26; y: 22
        width: r.width - 52
        spacing: 22

        TextField {
            id: sf
            width: parent.width; height: 56
            placeholderText: "Search songs, albums, artists…"
            color: Theme.fg; placeholderTextColor: Theme.fgVariant
            font.family: Theme.bodyFont; font.pixelSize: 17; leftPadding: 54; rightPadding: 54
            background: Rectangle {
                radius: 28; color: Theme.container
                border.width: sf.activeFocus ? 2 : 0; border.color: Theme.primary
                Behavior on border.width { NumberAnimation { duration: Theme.quick } }
                Text { x: 18; anchors.verticalCenter: parent.verticalCenter; text: "search"; color: sf.activeFocus ? Theme.primary : Theme.fgVariant; font.family: Theme.iconFont; renderType: Text.NativeRendering; font.pixelSize: 24 }
                Text { visible: sf.text !== ""; x: parent.width - 42; anchors.verticalCenter: parent.verticalCenter; text: "close"; color: Theme.fgVariant; font.family: Theme.iconFont; renderType: Text.NativeRendering; font.pixelSize: 22
                    MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: { sf.text = ""; r.query = ""; r.app.found = null } } }
            }
            onAccepted: { var t = text.trim(); if (t.length) r.run(t) }
        }

        // ---- browse genres ----
        Column {
            visible: !r.hasResults
            width: parent.width; spacing: 16
            Text { text: "Browse categories"; color: Theme.fg; font.family: Theme.headFont; font.pixelSize: 28; font.weight: Font.Bold }
            Flow {
                width: parent.width; spacing: 14
                Repeater {
                    model: [
                        {n: "Pop", q: "pop hits", i: "music_note", a: "#ff4d6d", b: "#ffa63d"},
                        {n: "Hip-Hop", q: "hip hop hits", i: "headphones", a: "#6a5cf2", b: "#c777f2"},
                        {n: "Electronic", q: "electronic dance", i: "graphic_eq", a: "#5ecbf7", b: "#4bd67a"},
                        {n: "Rock", q: "rock classics", i: "electric_bolt", a: "#d9423c", b: "#f08a3c"},
                        {n: "R&B", q: "r&b soul", i: "mic", a: "#ff4a2e", b: "#ffa23d"},
                        {n: "Indie", q: "indie", i: "auto_awesome", a: "#5eeadb", b: "#3cc4e3"},
                        {n: "Latin", q: "latin hits", i: "local_fire_department", a: "#ff7a3d", b: "#f2c23d"},
                        {n: "Chill", q: "chill lofi", i: "spa", a: "#3cc4e3", b: "#3d8bff"},
                        {n: "Dance", q: "dance party", i: "bolt", a: "#2f7bff", b: "#7a7af0"},
                        {n: "Jazz", q: "jazz", i: "piano", a: "#8f5cf2", b: "#e0518f"},
                        {n: "Classical", q: "classical music", i: "library_music", a: "#46b58a", b: "#2f8fd9"},
                        {n: "Workout", q: "workout motivation", i: "fitness_center", a: "#e0412e", b: "#f2913d"}
                    ]
                    delegate: Item {
                        id: tile
                        required property var modelData
                        width: Math.floor((col.width - 14 * 2) / 3); height: 112
                        scale: tma.pressed ? 0.97 : (tma.containsMouse ? 1.02 : 1)
                        Behavior on scale { NumberAnimation { duration: Theme.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } }
                        Rectangle {
                            anchors.fill: parent; radius: 22; clip: true
                            gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: tile.modelData.a } GradientStop { position: 1; color: tile.modelData.b } }
                            Text { x: parent.width - 96; y: -8; text: tile.modelData.i; font.family: Theme.iconFont; renderType: Text.NativeRendering; font.pixelSize: 100; color: "#33ffffff"; rotation: 14 }
                            Text { x: 16; y: parent.height - 38; text: tile.modelData.n; color: "white"; font.family: Theme.headFont; font.pixelSize: 21; font.weight: Font.Bold }
                        }
                        MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: r.run(tile.modelData.q) }
                    }
                }
            }
        }

        // ---- results ----
        Text { visible: r.hasResults && r.app.searching; text: "Searching…"; color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 15 }

        Column {
            visible: r.hasResults && r.app.found !== null && r.app.found.songs.length > 0
            width: parent.width; spacing: 8
            Heading { label: "Songs"; iconName: "music_note" }
            Repeater {
                model: r.app.found ? r.app.found.songs.slice(0, 7) : []
                delegate: SongRow { required property var modelData; required property int index; width: col.width; app: r.app; song: modelData; list: r.app.found.songs; idx: index }
            }
        }

        Column {
            visible: r.hasResults && r.app.found !== null && r.app.found.albums.length > 0
            width: parent.width; spacing: 12
            Heading { label: "Albums"; iconName: "album" }
            ListView {
                width: parent.width; height: 232; orientation: ListView.Horizontal; spacing: 16; clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: r.app.found ? r.app.found.albums : []
                delegate: Item {
                    id: al
                    required property var modelData
                    width: 168; height: 228
                    scale: ama.pressed ? 0.97 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.quick } }
                    Cover { width: 168; height: 168; radius: 22; source: al.modelData.thumb }
                    Text { y: 176; width: parent.width; text: al.modelData.title; color: Theme.fg; font.family: Theme.bodyFont; font.pixelSize: 15; font.weight: Font.DemiBold; elide: Text.ElideRight }
                    Text { y: 198; width: parent.width; text: al.modelData.sub.replace(/^Album\s*•\s*/, ""); color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 13; elide: Text.ElideRight }
                    MouseArea { id: ama; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: r.app.openAlbum(al.modelData) }
                }
            }
        }

        Column {
            visible: r.hasResults && r.app.found !== null && r.app.found.artists.length > 0
            width: parent.width; spacing: 12
            Heading { label: "Artists"; iconName: "person" }
            ListView {
                width: parent.width; height: 200; orientation: ListView.Horizontal; spacing: 20; clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: r.app.found ? r.app.found.artists : []
                delegate: Item {
                    id: ar
                    required property var modelData
                    width: 140; height: 196
                    scale: arma.pressed ? 0.97 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.quick } }
                    Cover { width: 140; height: 140; radius: 70; source: ar.modelData.thumb }
                    Text { y: 150; width: parent.width; text: ar.modelData.title; horizontalAlignment: Text.AlignHCenter; color: Theme.fg; font.family: Theme.bodyFont; font.pixelSize: 15; font.weight: Font.DemiBold; elide: Text.ElideRight }
                    MouseArea { id: arma; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: r.run(ar.modelData.title) }
                }
            }
        }

        Column {
            visible: r.hasResults && r.app.found !== null && r.app.found.spotify !== undefined && r.app.found.spotify.length > 0
            width: parent.width; spacing: 8
            Heading { label: "On Spotify"; iconName: "graphic_eq" }
            Repeater {
                model: r.app.found && r.app.found.spotify ? r.app.found.spotify.slice(0, 6) : []
                delegate: SongRow { required property var modelData; width: col.width; app: r.app; song: modelData; spotify: true }
            }
        }
        Text {
            visible: r.hasResults && r.app.found !== null && r.app.found.spotifyError !== undefined
            text: r.app.found && r.app.found.spotifyError ? "Spotify: " + r.app.found.spotifyError : ""
            color: Theme.error; font.family: Theme.bodyFont; font.pixelSize: 13
        }
        Text {
            visible: r.hasResults && !r.app.searching && r.app.found !== null && r.app.found.songs.length === 0 && r.app.found.albums.length === 0
            text: "Nothing found for “" + r.query + "”"; color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 16
        }
    }
}
