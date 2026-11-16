import QtQuick
import QtQuick.Controls.Basic

Flickable {
    id: r
    required property var app
    contentHeight: col.height + 140
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { contentItem: Rectangle { implicitWidth: 6; radius: 3; color: Theme.outline; opacity: 0.6 } }

    readonly property string greetIcon: { var h = new Date().getHours(); return h < 5 ? "bedtime" : h < 12 ? "wb_twilight" : h < 18 ? "wb_sunny" : "nights_stay" }
    // a section title: a scalloped icon, the name, a squiggle and an optional button
    component SectionHead: Row {
        id: sh
        property string icon
        property string title
        property string button: ""
        property string buttonIcon: "arrow_forward"
        property string button2: ""
        property string button2Icon: "file_download"
        signal pressed()
        signal pressed2()
        width: parent.width; spacing: 14
        Item {
            width: 38; height: 38; anchors.verticalCenter: parent.verticalCenter
            ShaderEffect {
                anchors.fill: parent
                property size itemSize: Qt.size(width, height)
                property color color: Theme.primaryContainer
                property real amplitude: 2.2
                property real wavelength: 14
                property real phase: 0
                property real cornerRadius: 19
                fragmentShader: "qrc:/shaders/wavy_pill.frag.qsb"
            }
            Text { anchors.centerIn: parent; text: sh.icon; color: Theme.fgPrimaryContainer; font.family: Theme.iconFont; renderType: Text.NativeRendering; font.pixelSize: 20 }
        }
        Text { id: shT; text: sh.title; color: Theme.fg; font.family: Theme.headFont; font.pixelSize: 24; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
        Squiggle { width: Math.max(0, sh.width - 38 - shT.width - (shB.visible ? shB.width + 14 : 0) - (shB2.visible ? shB2.width + 14 : 0) - 28); anchors.verticalCenter: parent.verticalCenter }
        PillButton { id: shB2; visible: sh.button2 !== ""; text: sh.button2; icon: sh.button2Icon; onClicked: sh.pressed2() }
        PillButton { id: shB; visible: sh.button !== ""; text: sh.button; icon: sh.buttonIcon; onClicked: sh.pressed() }
    }
    readonly property string greeting: {
        var h = new Date().getHours()
        return h < 5 ? Tr.t("Up late…") : h < 12 ? Tr.t("Good morning") : h < 18 ? Tr.t("Good afternoon") : Tr.t("Good evening")
    }

    // big soft scalloped shapes drifting behind the top of the page (Swiftify's flowers)
    Repeater {
        model: [{x: 0.05, y: -90, s: 300, a: 0.07, p: 0.4}, {x: 0.55, y: -120, s: 340, a: 0.06, p: 2.0}, {x: 0.82, y: 40, s: 220, a: 0.05, p: 4.1}]
        delegate: ShaderEffect {
            required property var modelData
            x: r.width * modelData.x; y: modelData.y; width: modelData.s; height: modelData.s
            z: -1
            property size itemSize: Qt.size(width, height)
            property color color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, modelData.a)
            property real amplitude: 14
            property real wavelength: 64
            property real phase: modelData.p
            property real cornerRadius: width * 0.45
            Timer { running: r.visible && Theme.motion && Theme.windowActive; interval: 50; repeat: true; onTriggered: parent.phase += 0.004 }
            fragmentShader: "qrc:/shaders/wavy_pill.frag.qsb"
        }
    }

    Column {
        id: col
        x: 28
        y: 26
        width: r.width - 56
        spacing: 22

        Column {
            spacing: 8
            Text { text: Tr.t("Cloudify"); color: Theme.primary; font.family: Theme.headFont; font.pixelSize: 46; font.weight: Font.Bold; font.letterSpacing: -0.6 }
            Row {
                spacing: 12
                Rectangle {
                    width: 34; height: 34; radius: 17; color: Theme.secondaryContainer; anchors.verticalCenter: parent.verticalCenter
                    Text { anchors.centerIn: parent; text: r.greetIcon; color: Theme.fgSecondaryContainer; font.family: Theme.iconFont; renderType: Text.NativeRendering; font.pixelSize: 20 }
                }
                Text { text: r.greeting + (r.app.profile ? ", " + r.app.profile.name : ""); color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter }
            }
        }

        // ---- an update is waiting ----
        Rectangle {
            visible: r.app.update.available === true
            width: parent.width; height: 64; radius: Theme.radiusNormal; color: Theme.primaryContainer
            Row {
                anchors.fill: parent; anchors.margins: 14; spacing: 14
                Text { anchors.verticalCenter: parent.verticalCenter; text: "system_update"; color: Theme.fgPrimaryContainer; font.family: Theme.iconFont; renderType: Text.NativeRendering; font.pixelSize: 28 }
                Column {
                    anchors.verticalCenter: parent.verticalCenter; width: parent.width - 330
                    Text { text: "Cloudify " + (r.app.update.latest || "") + " is available"; color: Theme.fgPrimaryContainer; font.family: Theme.bodyFont; font.pixelSize: 15; font.weight: Font.DemiBold; elide: Text.ElideRight; width: parent.width }
                    Text { text: r.app.updatePct >= 0 ? Tr.t("Downloading… ") + r.app.updatePct + "%" : (r.app.updateMsg !== "" ? r.app.updateMsg : (r.app.update.notes ? r.app.update.notes.split("
")[0] : "You have " + r.app.update.current)); color: Theme.fgPrimaryContainer; opacity: 0.8; font.family: Theme.bodyFont; font.pixelSize: 13; elide: Text.ElideRight; width: parent.width }
                }
            }
            PillButton {
                anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                variant: "filled"; enabled: r.app.updatePct < 0
                text: r.app.update.installable ? Tr.t("Update now") : Tr.t("Open download page"); icon: r.app.update.installable ? "download" : "open_in_new"
                onClicked: r.app.update.installable ? r.app.installUpdate() : Qt.openUrlExternally(r.app.update.page)
            }
        }

        // ---- now playing hero ----
        Rectangle {
            width: parent.width
            height: 252
            radius: Theme.radiusLarge
            color: Theme.container
            border.width: 1
            border.color: Theme.outlineVariant
            clip: true
            // the cover's colour washes in from the left
            Rectangle {
                anchors.fill: parent; radius: Theme.radiusLarge
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22) }
                    GradientStop { position: 0.7; color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.04) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            Row {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 24
                Cover {
                    width: parent.height; height: parent.height
                    radius: 22
                    source: r.app.cur ? r.app.cur.thumb : ""
                    MouseArea { anchors.fill: parent; enabled: r.app.cur !== null; cursorShape: Qt.PointingHandCursor; onClicked: r.app.immersive = true }
                }
                Column {
                    width: parent.width - parent.height - 24
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Text { text: r.app.cur ? Tr.t("NOW PLAYING") : Tr.t("NOTHING PLAYING"); color: Theme.primary; font.family: Theme.bodyFont; font.pixelSize: 12; font.weight: Font.Bold; font.letterSpacing: 1.4 }
                    Text {
                        text: r.app.cur ? r.app.cur.title : Tr.t("Search for a song")
                        color: Theme.fg; font.family: Theme.headFont; font.pixelSize: 32; font.weight: Font.Bold
                        elide: Text.ElideRight; width: parent.width
                    }
                    Text { text: r.app.cur ? r.app.cur.artist : Tr.t("Your next favourite is a search away"); color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 17; elide: Text.ElideRight; width: parent.width }
                    Text { visible: r.app.cur !== null && (r.app.cur.album || "") !== ""; text: r.app.cur && r.app.cur.album ? r.app.cur.album : ""; color: Qt.rgba(Theme.fgVariant.r, Theme.fgVariant.g, Theme.fgVariant.b, 0.6); font.family: Theme.bodyFont; font.pixelSize: 14; elide: Text.ElideRight; width: parent.width }
                    Item { width: 1; height: 8 }
                    Row {
                        spacing: 14
                        WavyButton {
                            width: 56; height: 56
                            icon: r.app.playing ? "pause" : "play_arrow"
                            onClicked: r.app.toggle()
                        }
                        Text { text: r.app.note !== "" ? r.app.note : (r.app.playing ? Tr.t("Pause") : Tr.t("Play")); color: Theme.fg; font.family: Theme.bodyFont; font.pixelSize: 15; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; width: Math.min(implicitWidth, 260) }
                        PillButton { visible: r.app.cur !== null; text: Tr.t("Start radio"); icon: Theme.radio; anchors.verticalCenter: parent.verticalCenter; onClicked: r.app.startRadio(r.app.cur) }
                        IconButton { visible: r.app.cur !== null; icon: "more_horiz"; anchors.verticalCenter: parent.verticalCenter; onClicked: r.app.songMenuFor(r.app.cur) }
                    }
                    WaveSeek {
                        width: parent.width
                        position: r.app.position; duration: r.app.duration; playing: r.app.playing
                        onSeeked: ms => r.app.seek(ms)
                    }
                }
            }
        }

        // ---- quick cards ----
        Row {
            width: parent.width
            spacing: 16
            Repeater {
                model: [
                    {t: Tr.t("Liked songs"), s: r.app.lib.liked.length + " " + Tr.t("liked"), i: "favorite", go: "liked"},
                    {t: Tr.t("Your playlists"), s: r.app.lib.playlists.length + (" " + (r.app.lib.playlists.length === 1 ? Tr.t("collection") : Tr.t("collections"))), i: "library_music", go: "playlists"}
                ]
                delegate: Item {
                    id: card
                    required property var modelData
                    width: (col.width - 16) / 2
                    height: 84
                    scale: ma.pressed ? 0.98 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } }
                    Rectangle { anchors.fill: parent; radius: Theme.radiusNormal; color: Theme.containerHigh; Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.fg; opacity: ma.containsMouse ? 0.06 : 0 } }
                    Row {
                        anchors.fill: parent; anchors.margins: 14; spacing: 14
                        Item {
                            width: 56; height: 56
                            Rectangle { anchors.fill: parent; radius: 18; color: Theme.primaryContainer }
                            Text { anchors.centerIn: parent; text: card.modelData.i; color: Theme.fgPrimaryContainer; font.family: Theme.iconFont; renderType: Text.NativeRendering; font.pixelSize: 24 }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: card.modelData.t; color: Theme.fg; font.family: Theme.bodyFont; font.pixelSize: 16; font.weight: Font.DemiBold }
                            Text { text: card.modelData.s; color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 13 }
                        }
                    }
                    Text { anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter; text: "chevron_right"; color: Theme.fgVariant; font.family: Theme.iconFont; renderType: Text.NativeRendering; font.pixelSize: 24; x: 0; opacity: ma.containsMouse ? 1 : 0.7 }
                    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: r.app.openPage(card.modelData.go) }
                }
            }
        }

        // ---- daily mixes ----
        Column {
            visible: r.app.mixes.length > 0 || r.app.mixNote !== ""
            width: parent.width; spacing: 12
            SectionHead { icon: "auto_awesome"; title: Tr.t("Daily mixes"); button: r.app.mixes.length > 0 ? (r.app.mixBusy ? Tr.t("Mixing…") : Tr.t("Remix")) : ""; buttonIcon: "shuffle"; onPressed: if (!r.app.mixBusy) r.app.remix(true) }
            Text { visible: r.app.mixes.length === 0; text: r.app.mixNote; color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 14 }
            ListView {
                visible: r.app.mixes.length > 0
                width: parent.width; height: 232
                orientation: ListView.Horizontal; spacing: 16; clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: r.app.mixes
                delegate: Item {
                    id: mc
                    required property var modelData
                    width: 176; height: 232
                    scale: mma.pressed ? 0.97 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } }
                    Rectangle {
                        width: 176; height: 176; radius: 22; color: Theme.containerHigh; clip: true
                        Grid {
                            anchors.fill: parent; columns: 2
                            Repeater {
                                model: 4
                                delegate: Cover { required property int index; width: 88; height: 88; radius: 0; source: mc.modelData.tracks.length > index ? (mc.modelData.tracks[index].thumb || "") : "" }
                            }
                        }
                        Rectangle { anchors.fill: parent; color: "#33000000"; opacity: mma.containsMouse ? 1 : 0; Behavior on opacity { NumberAnimation { duration: Theme.quick } } }
                    }
                    Text { y: 184; text: mc.modelData.name; color: Theme.fg; font.family: Theme.bodyFont; font.pixelSize: 15; font.weight: Font.DemiBold; elide: Text.ElideRight; width: parent.width }
                    Text { y: 205; text: mc.modelData.desc; color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 12; elide: Text.ElideRight; width: parent.width }
                    MouseArea { id: mma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: r.app.openMix(mc.modelData) }
                }
            }
        }

        // ---- because you listened to ----
        Column {
            visible: r.app.similarItems.length > 0
            width: parent.width; spacing: 12
            SectionHead { icon: "radio"; title: Tr.t("Because you listened to ") + r.app.similarArtist }
            ListView {
                width: parent.width; height: 214
                orientation: ListView.Horizontal; spacing: 16; clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: r.app.similarItems
                delegate: Item {
                    id: sc
                    required property var modelData
                    required property int index
                    width: 150; height: 214
                    scale: sma.pressed ? 0.97 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } }
                    Cover { width: 150; height: 150; radius: 22; source: sc.modelData.thumb || "" }
                    Text { y: 158; text: sc.modelData.title; color: Theme.fg; font.family: Theme.bodyFont; font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideRight; width: parent.width }
                    Text { y: 179; text: sc.modelData.artist; color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 12; elide: Text.ElideRight; width: parent.width }
                    MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: r.app.playList(r.app.similarItems, sc.index) }
                }
            }
        }

        // ---- recently played ----
        Column {
            visible: r.app.recent.length > 0
            width: parent.width; spacing: 12
            SectionHead { icon: "history"; title: Tr.t("Recently played") }
            ListView {
                width: parent.width; height: 214
                orientation: ListView.Horizontal; spacing: 16; clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: r.app.recent
                delegate: Item {
                    id: rc
                    required property var modelData
                    required property int index
                    width: 150; height: 214
                    scale: rma.pressed ? 0.97 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } }
                    Cover { width: 150; height: 150; radius: 22; source: rc.modelData.thumb || "" }
                    Text { y: 158; text: rc.modelData.title; color: Theme.fg; font.family: Theme.bodyFont; font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideRight; width: parent.width }
                    Text { y: 179; text: rc.modelData.artist; color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 12; elide: Text.ElideRight; width: parent.width }
                    MouseArea { id: rma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: r.app.playList(r.app.recent, rc.index) }
                }
            }
        }

        // ---- playlists ----
        SectionHead {
            icon: r.app.pinnedList.length > 0 ? "push_pin" : "library_music"
            title: r.app.pinnedList.length > 0 ? Tr.t("Pinned playlists") : Tr.t("Playlists")
            button: r.app.lib.playlists.length > 0 ? Tr.t("See All") : Tr.t("Import")
            buttonIcon: r.app.lib.playlists.length > 0 ? "arrow_forward" : "file_download"
            button2: r.app.lib.playlists.length > 0 ? Tr.t("Import") : ""
            onPressed2: r.app.openImport()
            onPressed: r.app.lib.playlists.length > 0 ? r.app.openPage("playlists") : r.app.openImport()
        }
        Flow {
            width: parent.width
            spacing: 16
            Repeater {
                model: r.app.pinnedList.length > 0 ? r.app.pinnedList : r.app.lib.playlists
                delegate: Item {
                    id: pc
                    required property var modelData
                    width: 176; height: 224
                    scale: pma.pressed ? 0.98 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } }
                    PlaylistArt { width: 176; height: 176; radius: 22; pl: pc.modelData }
                    Text { y: 184; text: pc.modelData.name; color: Theme.fg; font.family: Theme.bodyFont; font.pixelSize: 15; font.weight: Font.DemiBold; elide: Text.ElideRight; width: parent.width }
                    Text { y: 205; text: pc.modelData.tracks.length + " " + Tr.t("songs"); color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 13 }
                    MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: m => m.button === Qt.RightButton ? r.app.playlistMenuFor(pc.modelData) : r.app.openPlaylist(pc.modelData) }
                }
            }
            Text {
                visible: r.app.lib.playlists.length === 0
                text: Tr.t("No playlists yet. Create one with ＋ in the sidebar, or import one.")
                color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 14
            }
        }
    }
}
