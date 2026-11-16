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

    property string filter: "all"        // all | songs | albums | artists
    function run(q) { query = q; sf.text = q; filter = "all"; r.app.suggestions = []; if (q !== "") { app.rememberSearch(q); app.searchAll(q) } }
    Timer { id: sugg; interval: 220; onTriggered: if (sf.text.trim().length >= 2) r.app.api.suggest(sf.text.trim()) }

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
            placeholderText: Tr.t("Search songs, albums, artists…")
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
            onTextEdited: { if (text.trim().length >= 2) sugg.restart(); else r.app.suggestions = [] }
        }

        Item {
            width: parent.width; height: 0; z: 20
            Rectangle {
                visible: sf.activeFocus && r.app.suggestions.length > 0 && r.app.suggestionsFor === sf.text.trim() && !r.hasResults
                y: -16; width: parent.width; height: sgCol.height + 12; radius: 24; color: Theme.containerHighest
                Column {
                    id: sgCol; y: 6; width: parent.width
                    Repeater {
                        model: r.app.suggestions
                        delegate: Item {
                            required property string modelData
                            width: sgCol.width; height: 44
                            Rectangle { anchors.fill: parent; anchors.margins: 4; radius: 18; color: Theme.fg; opacity: sma.containsMouse ? 0.08 : 0 }
                            Text { x: 22; anchors.verticalCenter: parent.verticalCenter; text: "search"; color: Theme.fgVariant; font.family: Theme.iconFont; renderType: Text.NativeRendering; font.pixelSize: 20 }
                            Text { x: 56; width: parent.width - 80; anchors.verticalCenter: parent.verticalCenter; text: modelData; elide: Text.ElideRight; color: Theme.fg; font.family: Theme.bodyFont; font.pixelSize: 15 }
                            MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: r.run(modelData) }
                        }
                    }
                }
            }
        }

        // ---- recent searches ----
        Column {
            visible: !r.hasResults && r.app.settings.searchHistory && r.app.settings.searchHistory.length > 0
            width: parent.width; spacing: 10
            Text { text: Tr.t("Recent searches"); color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 14; font.weight: Font.DemiBold }
            Flow {
                width: parent.width; spacing: 8
                Repeater {
                    model: r.app.settings.searchHistory || []
                    delegate: Item {
                        required property string modelData
                        width: hl.implicitWidth + 56; height: 36
                        Rectangle { anchors.fill: parent; radius: 18; color: hma.containsMouse ? Theme.secondaryContainer : Theme.container; Behavior on color { ColorAnimation { duration: Theme.quick } } }
                        Text { x: 14; anchors.verticalCenter: parent.verticalCenter; text: "history"; color: Theme.fgVariant; font.family: Theme.iconFont; renderType: Text.NativeRendering; font.pixelSize: 16 }
                        Text { id: hl; x: 38; anchors.verticalCenter: parent.verticalCenter; text: modelData; color: Theme.fg; font.family: Theme.bodyFont; font.pixelSize: 14 }
                        MouseArea { id: hma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: r.run(modelData) }
                        Text { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: "close"; color: Theme.fgVariant; font.family: Theme.iconFont; renderType: Text.NativeRendering; font.pixelSize: 16
                            MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: r.app.forgetSearch(modelData) } }
                    }
                }
            }
        }

        // ---- filter chips ----
        Row {
            visible: r.hasResults
            spacing: 8
            Repeater {
                model: [{k: "all", t: Tr.t("All")}, {k: "songs", t: Tr.t("Songs")}, {k: "albums", t: Tr.t("Albums")}, {k: "artists", t: Tr.t("Artists")}]
                delegate: Item {
                    required property var modelData
                    width: cl.implicitWidth + 34; height: 36
                    scale: cma.pressed ? 0.97 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.quick } }
                    Rectangle { anchors.fill: parent; radius: 18; color: r.filter === modelData.k ? Theme.primary : (cma.containsMouse ? Theme.secondaryContainer : Theme.container); Behavior on color { ColorAnimation { duration: Theme.quick } } }
                    Text { id: cl; anchors.centerIn: parent; text: modelData.t; color: r.filter === modelData.k ? Theme.fgPrimary : Theme.fg; font.family: Theme.bodyFont; font.pixelSize: 14; font.weight: Font.DemiBold }
                    MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: r.filter = modelData.k }
                }
            }
        }

        // ---- browse genres ----
        Column {
            visible: !r.hasResults
            width: parent.width; spacing: 16
            Text { text: Tr.t("Browse categories"); color: Theme.fg; font.family: Theme.headFont; font.pixelSize: 28; font.weight: Font.Bold }
            Flow {
                width: parent.width; spacing: 14
                Repeater {
                    model: [
                        {n: Tr.t("Pop"), q: "pop hits", i: "music_note", a: "#ff4d6d", b: "#ffa63d"},
                        {n: Tr.t("Hip-Hop"), q: "hip hop hits", i: "headphones", a: "#6a5cf2", b: "#c777f2"},
                        {n: Tr.t("Electronic"), q: "electronic dance", i: "graphic_eq", a: "#5ecbf7", b: "#4bd67a"},
                        {n: Tr.t("Rock"), q: "rock classics", i: "electric_bolt", a: "#d9423c", b: "#f08a3c"},
                        {n: "R&B", q: "r&b soul", i: "mic", a: "#ff4a2e", b: "#ffa23d"},
                        {n: Tr.t("Indie"), q: "indie", i: "auto_awesome", a: "#5eeadb", b: "#3cc4e3"},
                        {n: Tr.t("Latin"), q: "latin hits", i: "local_fire_department", a: "#ff7a3d", b: "#f2c23d"},
                        {n: Tr.t("Chill"), q: "chill lofi", i: "spa", a: "#3cc4e3", b: "#3d8bff"},
                        {n: Tr.t("Dance"), q: "dance party", i: "bolt", a: "#2f7bff", b: "#7a7af0"},
                        {n: Tr.t("Jazz"), q: "jazz", i: "piano", a: "#8f5cf2", b: "#e0518f"},
                        {n: Tr.t("Classical"), q: "classical music", i: "library_music", a: "#46b58a", b: "#2f8fd9"},
                        {n: Tr.t("Workout"), q: "workout motivation", i: "fitness_center", a: "#e0412e", b: "#f2913d"}
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
        Text { visible: r.hasResults && r.app.searching; text: Tr.t("Searching…"); color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 15 }

        Column {
            visible: r.hasResults && (r.filter === "all" || r.filter === "songs") && r.app.found !== null && r.app.found.songs.length > 0
            width: parent.width; spacing: 8
            Heading { label: Tr.t("Songs"); iconName: "music_note" }
            Repeater {
                model: r.app.found ? r.app.found.songs.slice(0, r.filter === "songs" ? 25 : 7) : []
                delegate: SongRow { required property var modelData; required property int index; width: col.width; app: r.app; song: modelData; list: r.app.found.songs; idx: index }
            }
        }

        Column {
            visible: r.hasResults && (r.filter === "all" || r.filter === "albums") && r.app.found !== null && r.app.found.albums.length > 0
            width: parent.width; spacing: 12
            Heading { label: Tr.t("Albums"); iconName: "album" }
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
            visible: r.hasResults && (r.filter === "all" || r.filter === "artists") && r.app.found !== null && r.app.found.artists.length > 0
            width: parent.width; spacing: 12
            Heading { label: Tr.t("Artists"); iconName: "person" }
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
                    MouseArea { id: arma; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: r.app.openArtist(ar.modelData) }
                }
            }
        }

        Column {
            visible: r.hasResults && r.app.found !== null && r.app.found.spotify !== undefined && r.app.found.spotify.length > 0
            width: parent.width; spacing: 8
            Heading { label: Tr.t("On Spotify"); iconName: "graphic_eq" }
            Repeater {
                model: r.app.found && r.app.found.spotify ? r.app.found.spotify.slice(0, 6) : []
                delegate: SongRow { required property var modelData; width: col.width; app: r.app; song: modelData; spotify: true }
            }
        }
        Text {
            visible: r.hasResults && r.app.found !== null && r.app.found.spotifyError !== undefined
            text: r.app.found && r.app.found.spotifyError ? Tr.t("Spotify: ") + r.app.found.spotifyError : ""
            color: Theme.error; font.family: Theme.bodyFont; font.pixelSize: 13
        }
        Text {
            visible: r.hasResults && !r.app.searching && r.app.found !== null && r.app.found.songs.length === 0 && r.app.found.albums.length === 0
            text: Tr.t("Nothing found for “") + r.query + "”"; color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 16
        }
    }
}
