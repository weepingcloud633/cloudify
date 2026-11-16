import QtQuick
import QtQuick.Controls.Basic

// Liked songs, the playlist grid and a single playlist or album (Swiftify's playlist section):
// a hero with the cover, kind chip, title, facts and the page's buttons, then the songs.
Item {
    id: r
    required property var app
    readonly property string page: app.page
    readonly property bool isGrid: page === "playlists"
    readonly property bool isLiked: page === "liked"
    readonly property bool isArtist: page === "artist" && app.artist !== null
    readonly property bool isSongs: page === "songs"
    readonly property bool isLocal: page === "local"
    readonly property bool iconHero: isLiked || isSongs || isLocal
    readonly property var dupes: isPlaylist && livePl ? app.findDupes(livePl.tracks) : []
    readonly property string heroIcon: isLiked ? "favorite" : (isSongs ? "music_note" : "folder")
    readonly property bool isPlaylist: page === "playlist" && app.shownPlaylist !== null && !app.shownPlaylist.temp
    readonly property var livePl: {
        if (!isPlaylist) return null
        for (var i = 0; i < app.lib.playlists.length; i++) if (app.lib.playlists[i].id === app.shownPlaylist.id) return app.lib.playlists[i]
        return app.shownPlaylist
    }
    property bool showHidden: false
    readonly property var hiddenIds: isPlaylist && livePl ? (livePl.hidden || []) : []
    onLivePlChanged: if (!livePl) showHidden = false
    readonly property var tracks: isArtist ? app.artist.songs : isLiked ? app.lib.liked : isSongs ? app.allSongs : isLocal ? app.localTracks : (isPlaylist ? (livePl ? (showHidden || hiddenIds.length === 0 ? livePl.tracks : livePl.tracks.filter(function(x) { return hiddenIds.indexOf(x.id) < 0 })) : []) : (app.shownPlaylist ? app.shownPlaylist.tracks : []))
    readonly property bool pinned: livePl !== null && livePl.pinned === true
    readonly property real totalSecs: { var t = 0; for (var i = 0; i < tracks.length; i++) t += tracks[i].dur || 0; return t }
    function durText(s) { var m = Math.round(s / 60); return m >= 60 ? Math.floor(m / 60) + " " + Tr.t("hr") + " " + (m % 60) + " " + Tr.t("min") : m + " " + Tr.t("min") }
    readonly property string heroTitle: isArtist ? app.artist.name : isLiked ? "Liked songs" : isSongs ? "Songs" : isLocal ? "Local Files" : (app.shownPlaylist ? app.shownPlaylist.name : "")
    readonly property string kind: isArtist ? "ARTIST" : isLiked ? "FAVOURITES" : isSongs ? "YOUR SONGS" : isLocal ? "LOCAL FILES" : (isPlaylist ? "PLAYLIST" : "ALBUM")

    // a different page starts at its top
    Connections {
        target: r.app
        function onPageChanged() { Qt.callLater(list.positionViewAtBeginning) }
        function onShownPlaylistChanged() { Qt.callLater(list.positionViewAtBeginning) }
        function onArtistChanged() { Qt.callLater(list.positionViewAtBeginning) }
    }

    // ---------------- the playlist grid ----------------
    GridView {
        id: grid
        visible: r.isGrid
        anchors.fill: parent
        readonly property real margin: 28
        readonly property real available: width - 2 * margin + 20
        readonly property int columns: Math.max(1, Math.floor(available / 200))
        readonly property real tile: available / columns - 20
        leftMargin: margin - 10; rightMargin: margin - 10
        topMargin: 14; bottomMargin: 130
        cellWidth: available / columns; cellHeight: tile + 70
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ScrollBar.vertical: ScrollBar { contentItem: Rectangle { implicitWidth: 6; radius: 3; color: Theme.outline; opacity: 0.6 } }
        model: r.isGrid ? r.app.lib.playlists.length + 1 : 0

        header: Item {
            width: grid.available; height: 84
            Repeater {
                model: [{x: 0.62, y: -10, s: 110, a: 0.07}, {x: 0.78, y: 18, s: 70, a: 0.06}, {x: 0.9, y: -22, s: 90, a: 0.05}]
                delegate: ShaderEffect {
                    required property var modelData
                    x: parent.width * modelData.x; y: modelData.y; width: modelData.s; height: modelData.s
                    property size itemSize: Qt.size(width, height)
                    property color color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, modelData.a * 2)
                    property real amplitude: 5; property real wavelength: 22; property real phase: modelData.x * 6; property real cornerRadius: width * 0.45
                    fragmentShader: "qrc:/shaders/wavy_pill.frag.qsb"
                }
            }
            Text { id: gridTitle; x: 10; anchors.verticalCenter: parent.verticalCenter; text: Tr.t("My Playlists"); color: Theme.fg; font.family: Theme.headFont; font.pixelSize: 38; font.weight: Font.Bold; font.letterSpacing: -0.5 }
            PillButton { x: gridTitle.x + gridTitle.width + 18; anchors.verticalCenter: parent.verticalCenter; text: Tr.t("Import playlist"); icon: "file_download"; variant: "filled"; onClicked: r.app.openImport() }
        }

        delegate: Item {
            id: cell
            required property int index
            readonly property bool isNew: index === 0
            readonly property var pl: isNew ? null : r.app.lib.playlists[index - 1]
            width: grid.cellWidth; height: grid.cellHeight
            Item {
                x: 10; width: grid.tile; height: grid.tile + 56
                scale: cma.pressed ? 0.97 : (cma.containsMouse ? 1.015 : 1)
                Behavior on scale { NumberAnimation { duration: Theme.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } }
                // the tile that starts a new playlist
                Rectangle {
                    visible: cell.isNew
                    width: grid.tile; height: grid.tile; radius: 22
                    color: cma.containsMouse ? Theme.container : Theme.containerHigh
                    Behavior on color { ColorAnimation { duration: Theme.quick } }
                    Column {
                        anchors.centerIn: parent; spacing: 10
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter; width: 44; height: 44; radius: 22; color: Theme.primaryContainer
                            Text { anchors.centerIn: parent; text: "add"; color: Theme.fgPrimaryContainer; font.family: Theme.iconFont; renderType: Text.NativeRendering; font.pixelSize: 26 }
                        }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: Tr.t("New Playlist"); color: Theme.fg; font.family: Theme.bodyFont; font.pixelSize: 15; font.weight: Font.DemiBold }
                    }
                }
                PlaylistArt { visible: !cell.isNew; width: grid.tile; height: grid.tile; radius: 22; pl: cell.pl }
                Rectangle {
                    visible: !cell.isNew && cell.pl && cell.pl.pinned === true
                    x: grid.tile - 36; y: 8; width: 28; height: 28; radius: 14; color: "#8c000000"
                    Text { anchors.centerIn: parent; text: "push_pin"; color: "white"; font.family: Theme.iconFont; renderType: Text.NativeRendering; font.pixelSize: 15 }
                }
                Text { visible: !cell.isNew; y: grid.tile + 10; width: grid.tile; text: cell.pl ? cell.pl.name : ""; color: Theme.fg; font.family: Theme.bodyFont; font.pixelSize: 15; font.weight: Font.DemiBold; elide: Text.ElideRight }
                Text { visible: !cell.isNew; y: grid.tile + 32; text: cell.pl ? cell.pl.tracks.length + " " + (cell.pl.tracks.length === 1 ? Tr.t("song") : Tr.t("songs")) : ""; color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 13 }
                MouseArea {
                    id: cma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: m => {
                        if (cell.isNew) r.app.openEditor(null)
                        else if (m.button === Qt.RightButton) r.app.playlistMenuFor(cell.pl)
                        else r.app.openPlaylist(cell.pl)
                    }
                }
            }
        }
    }

    // ---------------- liked songs, a playlist or an album ----------------
    TrackList {
        id: list
        visible: !r.isGrid
        anchors.fill: parent
        anchors.leftMargin: 18; anchors.rightMargin: 8
        app: r.app
        tracks: r.isGrid ? [] : r.tracks
        header: heroComponent
        Text {
            visible: r.tracks.length === 0
            x: 14; y: 330
            color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 15
            text: r.isLiked ? Tr.t("Tap ♥ on a song to keep it here") : r.isSongs ? Tr.t("Songs you like, record in playlists or play will show up here") : r.isLocal ? (r.app.scanning ? Tr.t("Looking for music files…") : Tr.t("No music files found. Use Add folder to point Cloudify at yours.")) : Tr.t("This playlist is empty. Add songs from Search with the ⋯ button.")
        }
    }

    Component {
        id: heroComponent
        Item {
            id: hero
            width: list.width - 10
            readonly property real art: Math.min(220, Math.max(120, width * 0.28))
            height: art + 96 + (r.isArtist && r.app.artist.albums.length > 0 ? 262 : 0)
            // faint scalloped shapes behind it all
            Repeater {
                model: [{x: 0.55, y: 8, s: 150, a: 0.07}, {x: 0.8, y: 60, s: 100, a: 0.06}, {x: 0.35, y: 110, s: 80, a: 0.05}]
                delegate: ShaderEffect {
                    required property var modelData
                    x: hero.width * modelData.x; y: modelData.y; width: modelData.s; height: modelData.s
                    property size itemSize: Qt.size(width, height)
                    property color color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, modelData.a * 2)
                    property real amplitude: 7; property real wavelength: 30; property real phase: modelData.x * 5; property real cornerRadius: width * 0.45
                    fragmentShader: "qrc:/shaders/wavy_pill.frag.qsb"
                }
            }
            // the cover, on a soft glow in its colour
            Item {
                id: artBox
                x: 10; y: 36; width: hero.art; height: hero.art
                ShaderEffect {
                    anchors.centerIn: parent; width: parent.width * 1.3; height: width
                    property color color: Theme.primary
                    property real intensity: 0.2
                    fragmentShader: "qrc:/shaders/glow.frag.qsb"
                }
                Cover { visible: r.isArtist; anchors.fill: parent; radius: width / 2; source: r.isArtist ? r.app.artist.thumb : "" }
                PlaylistArt {
                    anchors.fill: parent; radius: 22
                    visible: !r.iconHero && !r.isArtist
                    pl: r.isPlaylist ? r.livePl : r.app.shownPlaylist
                }
                Rectangle {
                    visible: r.iconHero
                    anchors.fill: parent; radius: 22
                    gradient: Gradient { GradientStop { position: 0; color: Theme.primary } GradientStop { position: 1; color: Theme.primaryContainer } }
                    Text { anchors.centerIn: parent; text: r.heroIcon; color: Theme.fgPrimary; font.family: Theme.iconFont; renderType: Text.NativeRendering; font.pixelSize: hero.art * 0.42 }
                }
            }
            // the artist's albums
            Column {
                visible: r.isArtist && r.app.artist.albums.length > 0
                x: 10; y: hero.art + 70; width: hero.width - 20; spacing: 10
                Text { text: Tr.t("Albums"); color: Theme.fg; font.family: Theme.headFont; font.pixelSize: 22; font.weight: Font.Bold }
                ListView {
                    width: parent.width; height: 208; orientation: ListView.Horizontal; spacing: 16; clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: r.isArtist ? r.app.artist.albums : []
                    delegate: Item {
                        id: alb
                        required property var modelData
                        width: 150; height: 204
                        scale: alma.pressed ? 0.97 : 1
                        Behavior on scale { NumberAnimation { duration: Theme.quick } }
                        Cover { width: 150; height: 150; radius: 20; source: alb.modelData.thumb }
                        Text { y: 158; width: parent.width; text: alb.modelData.title; elide: Text.ElideRight; color: Theme.fg; font.family: Theme.bodyFont; font.pixelSize: 14; font.weight: Font.DemiBold }
                        Text { y: 179; width: parent.width; text: alb.modelData.sub.replace(/^Album\s*\u2022\s*/, ""); elide: Text.ElideRight; color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 12 }
                        MouseArea { id: alma; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: r.app.openAlbum(alb.modelData) }
                    }
                }
            }
            Column {
                x: artBox.x + artBox.width + 24; y: 36 + Math.max(0, artBox.height - implicitHeight)
                width: hero.width - x - 10
                spacing: 9
                Rectangle {
                    width: kindRow.implicitWidth + 20; height: 26; radius: 13; color: Theme.primaryContainer
                    Row {
                        id: kindRow; anchors.centerIn: parent; spacing: 5
                        Text { anchors.verticalCenter: parent.verticalCenter; text: r.kind === "ALBUM" ? "album" : (r.iconHero ? r.heroIcon : "queue_music"); color: Theme.fgPrimaryContainer; font.family: Theme.iconFont; renderType: Text.NativeRendering; font.pixelSize: 15 }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: r.kind; color: Theme.fgPrimaryContainer; font.family: Theme.bodyFont; font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 0.8 }
                    }
                }
                Text { width: parent.width; text: r.heroTitle; color: Theme.fg; font.family: Theme.headFont; font.pixelSize: 34; font.weight: Font.Bold; font.letterSpacing: -0.4; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight }
                Text { visible: r.isArtist && r.app.artist.desc !== ""; width: parent.width; text: r.isArtist ? r.app.artist.desc : ""; color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 14; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight }
                Text { visible: r.isPlaylist && r.livePl && r.livePl.desc !== ""; width: parent.width; text: r.livePl ? r.livePl.desc : ""; color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 14; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight }
                Row {
                    spacing: 6
                    Repeater {
                        model: [r.app.profile && r.isPlaylist ? r.app.profile.name : "", r.tracks.length + " " + (r.tracks.length === 1 ? Tr.t("song") : Tr.t("songs")), r.totalSecs > 0 ? r.durText(r.totalSecs) : ""]
                        delegate: Rectangle {
                            required property string modelData
                            visible: modelData !== ""
                            width: ft.implicitWidth + 18; height: 24; radius: 12; color: Theme.containerHigh
                            Text { id: ft; anchors.centerIn: parent; text: modelData; color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 12 }
                        }
                    }
                }
                Flow {
                    width: parent.width; spacing: 8
                    PillButton { text: Tr.t("Play"); icon: "play_arrow"; variant: "filled"; enabled: r.tracks.length > 0; onClicked: r.app.playList(r.tracks, 0) }
                    PillButton { text: Tr.t("Shuffle"); icon: "shuffle"; enabled: r.tracks.length > 0; onClicked: { var i = Math.floor(Math.random() * r.tracks.length); r.app.shuffle = true; r.app.playList(r.tracks, i) } }
                    PillButton { visible: r.isLocal; text: Tr.t("Add folder"); icon: "create_new_folder"; onClicked: r.app.pickFolder() }
                    PillButton { visible: r.isLocal; text: r.app.scanning ? Tr.t("Scanning…") : Tr.t("Rescan"); icon: "refresh"; onClicked: r.app.scanLocal() }
                    PillButton { visible: r.isArtist; text: Tr.t("Radio"); icon: Theme.radio; onClicked: if (r.tracks.length) r.app.startRadio(r.tracks[0]) }
                    PillButton { visible: r.isPlaylist && r.dupes.length > 0; text: Tr.t("Duplicates (") + r.dupes.length + ")"; icon: "content_copy"; onClicked: r.app.openDupes(r.livePl) }
                    PillButton { visible: r.isPlaylist && r.hiddenIds.length > 0; text: r.showHidden ? Tr.t("Hide hidden") : Tr.t("Show hidden (") + r.hiddenIds.length + ")"; icon: r.showHidden ? "visibility_off" : "visibility"; onClicked: r.showHidden = !r.showHidden }
                    PillButton { visible: r.isPlaylist; text: Tr.t("Edit"); icon: "edit"; onClicked: r.app.openEditor(r.livePl) }
                    PillButton { visible: r.isPlaylist; text: r.pinned ? Tr.t("Unpin") : Tr.t("Pin"); icon: "push_pin"; onClicked: r.app.togglePin(r.livePl) }
                    PillButton { visible: r.tracks.length > 0 && !r.isLocal; text: Tr.t("Download"); icon: Theme.download; onClicked: r.app.download(r.tracks) }
                    PillButton { visible: r.isPlaylist; text: Tr.t("Share"); icon: "ios_share"; onClicked: r.app.copyShareCode() }
                    PillButton { visible: r.isPlaylist; text: Tr.t("Save file"); icon: "save"; onClicked: r.app.saveShareFile() }
                    PillButton { visible: r.isPlaylist; text: Tr.t("Delete"); icon: "delete"; onClicked: r.app.askDelete(r.livePl) }
                }
            }
        }
    }
}
