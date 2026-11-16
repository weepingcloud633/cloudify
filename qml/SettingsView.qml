import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtCore

Flickable {
    id: r
    required property var app
    contentHeight: col.height + 150
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { contentItem: Rectangle { implicitWidth: 6; radius: 3; color: Theme.outline; opacity: 0.6 } }

    property var cache: ({bytes: 0, files: 0})
    function refreshCache() { cache = JSON.parse(app.api.cacheInfo()) }
    function size(b) { return b > 1073741824 ? (b / 1073741824).toFixed(1) + " GB" : Math.round(b / 1048576) + " MB" }
    onVisibleChanged: if (visible) refreshCache()

    component Card: Rectangle {
        default property alias content: inner.data
        property string heading
        width: col.width
        height: inner.implicitHeight + 50
        radius: Theme.radiusLarge
        color: Theme.container
        border.width: 1
        border.color: Theme.outlineVariant
        Column {
            id: inner
            x: 22; y: 18; width: parent.width - 44
            spacing: 14
            Text { text: parent.parent.heading; color: Theme.primary; font.family: Theme.bodyFont; font.pixelSize: 13; font.weight: Font.Bold; font.letterSpacing: 1.2 }
        }
    }

    // label + hint on the left, a control on the right
    component Row2: Item {
        default property alias control: slot.data
        property string title
        property string hint
        width: parent.width
        height: Math.max(44, txt.implicitHeight)
        Column {
            id: txt
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - slot.width - 20
            spacing: 2
            Text { text: title; color: Theme.fg; font.family: Theme.bodyFont; font.pixelSize: 15; font.weight: Font.DemiBold }
            Text { visible: hint !== ""; text: hint; color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 13; wrapMode: Text.Wrap; width: parent.width }
        }
        Item { id: slot; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: childrenRect.width; height: childrenRect.height }
    }

    component Toggle: Item {
        id: t
        property bool on: false
        signal flipped(bool value)
        width: 56; height: 32
        Rectangle { anchors.fill: parent; radius: 16; color: t.on ? Theme.primary : Theme.containerHighest; border.width: t.on ? 0 : 2; border.color: Theme.outline
            Behavior on color { ColorAnimation { duration: Theme.quick } } }
        Rectangle {
            width: t.on ? 24 : 16; height: width; radius: width / 2
            x: t.on ? parent.width - width - 4 : 8; anchors.verticalCenter: parent.verticalCenter
            color: t.on ? Theme.fgPrimary : Theme.outline
            Behavior on x { NumberAnimation { duration: Theme.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } }
            Behavior on width { NumberAnimation { duration: Theme.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: t.flipped(!t.on) }
    }

    property var devices: []
    Popup {
        id: langMenu
        anchors.centerIn: Overlay.overlay
        modal: true; padding: 10; width: 320
        enter: Transition { ParallelAnimation { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 170 } NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: 260; easing.type: Easing.OutCubic } } }
        exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 120 } }
        background: Rectangle { color: Theme.containerHighest; radius: Theme.radiusLarge }
        Overlay.modal: Rectangle { color: "#99000000" }
        contentItem: Column {
            spacing: 2
            Text { text: Tr.t("Language"); color: Theme.fg; font.family: Theme.headFont; font.pixelSize: 18; font.weight: Font.Bold; leftPadding: 8; topPadding: 4; bottomPadding: 8 }
            NavItem { width: 300; icon: "translate"; text: Tr.t("Automatic"); selected: r.app.settings.language === "auto"; onClicked: { r.app.setSetting("language", "auto"); langMenu.close() } }
            Repeater {
                model: Tr.names
                delegate: NavItem {
                    required property var modelData
                    width: 300; icon: "translate"; text: modelData.name; selected: r.app.settings.language === modelData.code
                    onClicked: { r.app.setSetting("language", modelData.code); langMenu.close() }
                }
            }
        }
    }
    Popup {
        id: devMenu
        anchors.centerIn: Overlay.overlay
        modal: true; padding: 10; width: 360
        enter: Transition { ParallelAnimation { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 170 } NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: 260; easing.type: Easing.OutCubic } } }
        exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 120 } }
        background: Rectangle { color: Theme.containerHighest; radius: Theme.radiusLarge }
        Overlay.modal: Rectangle { color: "#99000000" }
        contentItem: Column {
            spacing: 2
            Text { text: Tr.t("Output device"); color: Theme.fg; font.family: Theme.headFont; font.pixelSize: 18; font.weight: Font.Bold; leftPadding: 8; topPadding: 4; bottomPadding: 8 }
            Repeater {
                model: r.devices
                delegate: NavItem {
                    required property var modelData
                    required property int index
                    width: 340; icon: "speaker"; text: index === 0 ? modelData + " (default)" : modelData
                    selected: (r.app.settings.outputDevice === "" && index === 0) || r.app.settings.outputDevice === modelData
                    onClicked: { r.app.setSetting("outputDevice", index === 0 ? "" : modelData); r.app.api.audioDevice(index === 0 ? "" : modelData); devMenu.close() }
                }
            }
        }
    }

    component Segmented: Row {
        id: s
        property var options: []        // [{v, t}]
        property var current
        signal picked(var value)
        spacing: 4
        Repeater {
            model: s.options
            delegate: Item {
                required property var modelData
                width: lbl.implicitWidth + 28; height: 36
                scale: sma.pressed ? 0.97 : 1
                Behavior on scale { NumberAnimation { duration: Theme.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } }
                Rectangle { anchors.fill: parent; radius: 18; color: s.current === modelData.v ? Theme.primaryContainer : Theme.containerHighest }
                Text { id: lbl; anchors.centerIn: parent; text: modelData.t; color: s.current === modelData.v ? Theme.fgPrimaryContainer : Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 14; font.weight: Font.DemiBold }
                MouseArea { id: sma; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: s.picked(parent.modelData.v) }
            }
        }
    }

    Column {
        id: col
        x: 28; y: 26
        width: r.width - 56
        spacing: 18

        Text { text: Tr.t("Settings"); color: Theme.fg; font.family: Theme.headFont; font.pixelSize: 36; font.weight: Font.Bold }

        Card {
            heading: Tr.t("PROFILE")
            Row {
                spacing: 18
                Item {
                    width: 84; height: 84
                    Rectangle { anchors.fill: parent; radius: 42; color: r.app.profile ? r.app.profile.color : Theme.primary
                        Text { anchors.centerIn: parent; text: r.app.profile ? r.app.profile.name.charAt(0).toUpperCase() : "?"; color: "#141414"; font.family: Theme.headFont; font.pixelSize: 36; font.weight: Font.Bold } }
                    Cover { anchors.fill: parent; radius: 42; visible: r.app.profile !== null && r.app.profile.avatar !== ""; source: r.app.profile ? r.app.profile.avatar : "" }
                }
                Column {
                    spacing: 10
                    TextField {
                        id: nameEdit
                        width: 260; height: 46
                        text: r.app.profile ? r.app.profile.name : ""
                        placeholderText: Tr.t("Your name"); color: Theme.fg; placeholderTextColor: Theme.fgVariant
                        font.family: Theme.bodyFont; font.pixelSize: 16; leftPadding: 18; maximumLength: 24
                        background: Rectangle { radius: 23; color: Theme.containerHigh; border.width: nameEdit.activeFocus ? 2 : 0; border.color: Theme.primary }
                        onEditingFinished: r.app.saveProfile(text, r.app.profile.color)
                    }
                    Row {
                        spacing: 8
                        PillButton { text: Tr.t("Choose picture"); icon: "image"; onClicked: r.app.pickImage() }
                        PillButton { text: Tr.t("Remove"); variant: "text"; visible: r.app.profile !== null && r.app.profile.avatar !== ""; onClicked: r.app.clearAvatar() }
                    }
                }
            }
            Row2 {
                title: Tr.t("Profile color"); hint: Tr.t("Used when you have no picture.")
                Row {
                    spacing: 8
                    Repeater {
                        model: ["#8fb8ff", "#b69df8", "#f29fc8", "#f4a98a", "#e6c35c", "#7fd6a7"]
                        delegate: Rectangle {
                            required property string modelData
                            width: 30; height: 30; radius: 15; color: modelData
                            border.width: r.app.profile && r.app.profile.color === modelData ? 3 : 0; border.color: Theme.fg
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: r.app.saveProfile(nameEdit.text, parent.modelData) }
                        }
                    }
                }
            }
        }

        Card {
            heading: Tr.t("THEME")
            Row2 {
                title: Tr.t("Mode")
                Segmented { options: [{v: "dark", t: Tr.t("Dark")}, {v: "light", t: Tr.t("Light")}, {v: "amoled", t: Tr.t("AMOLED")}]; current: r.app.settings.themeMode; onPicked: v => r.app.setSetting("themeMode", v) }
            }
            Row2 {
                title: Tr.t("Themes"); hint: Tr.t("Color themes: they follow the Dark / Light mode above.")
                Item { width: 1; height: 1 }
            }
            Flow {
                width: parent.width; spacing: 12
                Repeater {
                    model: Themes.families
                    delegate: Item {
                        id: th
                        required property var modelData
                        readonly property var p: Theme.dark ? modelData.dark : modelData.light
                        width: 124; height: 104
                        scale: thma.pressed ? 0.95 : (thma.containsMouse ? 1.04 : 1)
                        Behavior on scale { NumberAnimation { duration: Theme.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } }
                        Rectangle {
                            width: parent.width; height: 76; radius: 16; color: th.p[0]
                            border.width: r.app.settings.themeId === th.modelData.id ? 3 : 1; border.color: r.app.settings.themeId === th.modelData.id ? th.p[9] : Qt.rgba(1, 1, 1, 0.15)
                            Rectangle { x: 10; y: 10; width: parent.width - 20; height: 34; radius: 10; color: th.p[2]
                                Rectangle { x: 8; y: 9; width: 40; height: 6; radius: 3; color: th.p[6] }
                                Rectangle { x: 8; y: 20; width: 26; height: 5; radius: 2.5; color: th.p[7] } }
                            Row { x: 12; y: 52; spacing: 6
                                Repeater { model: [9, 10, 11]; delegate: Rectangle { required property int modelData; width: 14; height: 14; radius: 7; color: th.p[modelData] } } }
                        }
                        Text { y: 82; width: parent.width; text: th.modelData.name; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 12 }
                        MouseArea { id: thma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: r.app.setSetting("themeId", th.modelData.id) }
                    }
                }
            }
            Row2 {
                title: Tr.t("Accent color"); hint: Tr.t("Pick one, or let the colors follow the playing album art.")
                PillButton { text: Tr.t("Follow album art"); variant: r.app.settings.accent === "" ? "filled" : "tonal"; onClicked: { r.app.setSetting("themeId", ""); r.app.setSetting("accent", "") } }
            }
            Flow {
                width: parent.width; spacing: 10
                Repeater {
                    model: [["Lavender", "#b8a4f0"], ["Ocean", "#6cb4ff"], ["Mint", "#6fd6a8"], ["Rose", "#f48fb1"], ["Amber", "#f2b45c"], ["Coral", "#ff8a6b"], ["Slate", "#9fb3c8"], ["Lime", "#b5d96a"]]
                    delegate: Item {
                        required property var modelData
                        width: 84; height: 64
                        scale: tma.pressed ? 0.96 : 1
                        Behavior on scale { NumberAnimation { duration: Theme.quick } }
                        Rectangle { x: 14; width: 56; height: 40; radius: 14; color: modelData[1]
                            border.width: r.app.settings.accent === modelData[1] ? 3 : 0; border.color: Theme.fg }
                        Text { y: 44; width: parent.width; text: modelData[0]; horizontalAlignment: Text.AlignHCenter; color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 12 }
                        MouseArea { id: tma; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { r.app.setSetting("themeId", ""); r.app.setSetting("accent", parent.modelData[1]) } }
                    }
                }
            }
        }

        Card {
            heading: Tr.t("PLAYBACK")
            Row2 {
                title: Tr.t("Audio quality"); hint: "Data saver streams about 70 kbps. Songs already cached keep their quality; clear the cache to re-fetch."
                Segmented { options: [{v: "high", t: Tr.t("High")}, {v: "low", t: Tr.t("Data saver")}]; current: r.app.settings.quality; onPicked: v => r.app.setSetting("quality", v) }
            }
            Row2 {
                title: Tr.t("Keep the music going"); hint: Tr.t("When the queue ends, start a radio from the last song.")
                Toggle { on: r.app.settings.autoRadio; onFlipped: v => r.app.setSetting("autoRadio", v) }
            }
        }

        Card {
            heading: Tr.t("SPOTIFY SEARCH")
            Row2 {
                title: Tr.t("Developer keys"); hint: "Optional. Create a free app at developer.spotify.com, then paste its Client ID and Secret to show Spotify results in search. Songs still play from YouTube Music."
                Item { width: 1; height: 1 }
            }
            TextField {
                id: spId; width: parent.width; height: 44; text: r.app.settings.spotifyId; placeholderText: Tr.t("Client ID"); color: Theme.fg; placeholderTextColor: Theme.fgVariant
                font.family: Theme.bodyFont; font.pixelSize: 14; leftPadding: 18
                background: Rectangle { radius: 22; color: Theme.containerHigh; border.width: spId.activeFocus ? 2 : 0; border.color: Theme.primary }
                onEditingFinished: r.app.setSetting("spotifyId", text.trim())
            }
            TextField {
                id: spSecret; width: parent.width; height: 44; text: r.app.settings.spotifySecret; placeholderText: Tr.t("Client Secret"); echoMode: TextInput.Password; color: Theme.fg; placeholderTextColor: Theme.fgVariant
                font.family: Theme.bodyFont; font.pixelSize: 14; leftPadding: 18
                background: Rectangle { radius: 22; color: Theme.containerHigh; border.width: spSecret.activeFocus ? 2 : 0; border.color: Theme.primary }
                onEditingFinished: r.app.setSetting("spotifySecret", text.trim())
            }
        }

        Card {
            heading: Tr.t("GRAPHICS")
            Row2 {
                title: Tr.t("Graphics API"); hint: "If the mouse pointer stutters over the app, try another one. Restart the app after changing."
                Segmented { options: [{v: "auto", t: Tr.t("Auto")}, {v: "d3d12", t: Tr.t("Direct3D 12")}, {v: "opengl", t: Tr.t("OpenGL")}]; current: r.app.settings.graphics; onPicked: v => r.app.setSetting("graphics", v) }
            }
        }

        Card {
            heading: Tr.t("APPEARANCE")
            Row2 {
                title: Tr.t("Language"); hint: r.app.settings.language === "auto" ? Tr.t("Automatic") : Tr.names.filter(function(n) { return n.code === r.app.settings.language })[0].name
                PillButton { text: Tr.t("Choose"); icon: "translate"; onClicked: langMenu.open() }
            }
            Row2 {
                title: Tr.t("Colors follow the album art"); hint: Tr.t("Off keeps the default lavender theme.")
                Toggle { on: r.app.settings.dynamicColor; onFlipped: v => r.app.setSetting("dynamicColor", v) }
            }
            Row2 {
                title: Tr.t("Reduce motion"); hint: Tr.t("Stops the waves, the scallops that turn and the flowing backdrop. Presses and fades stay.")
                Toggle { on: r.app.settings.reduceMotion; onFlipped: v => r.app.setSetting("reduceMotion", v) }
            }
        }

        Card {
            heading: Tr.t("STORAGE")
            Row2 {
                title: Tr.t("Song cache"); hint: r.size(r.cache.bytes) + " in " + r.cache.files + " files. The oldest songs go first when the limit is reached."
                PillButton { text: Tr.t("Clear"); onClicked: { var c = JSON.parse(r.app.api.clearCache()); r.cache = c; r.app.note = Tr.t("Freed ") + r.size(c.freed) } }
            }
            Row2 {
                title: Tr.t("Cache limit")
                Segmented { options: [{v: 1024, t: Tr.t("1 GB")}, {v: 2048, t: Tr.t("2 GB")}, {v: 5120, t: Tr.t("5 GB")}, {v: 10240, t: Tr.t("10 GB")}]; current: r.app.settings.cacheLimitMB; onPicked: v => r.app.setSetting("cacheLimitMB", v) }
            }
            Row2 {
                title: Tr.t("Downloads"); hint: "Music\\Cloudify, with title, artist and album tags."
                PillButton { text: Tr.t("Open folder"); onClicked: Qt.openUrlExternally(StandardPaths.writableLocation(StandardPaths.MusicLocation) + "/Cloudify") }
            }
        }

        Card {
            heading: Tr.t("ENGINE")
            Row2 {
                title: Tr.t("yt-dlp"); hint: (r.app.engine.version ? Tr.t("Version ") + r.app.engine.version + ". " : "") + (r.app.engine.message || Tr.t("Checking…"))
                PillButton { text: Tr.t("Check for updates"); onClicked: { r.app.engine = {version: r.app.engine.version, message: "Checking…"}; r.app.api.checkEngine(true) } }
            }
        }

        Card {
            heading: Tr.t("PLAYBACK")
            Row2 {
                title: Tr.t("Crossfade"); hint: Tr.t("Songs fade into each other. Off still plays them back to back with no gap.")
                Segmented { options: [{v: 0, t: Tr.t("Off")}, {v: 3, t: "3 s"}, {v: 6, t: "6 s"}, {v: 9, t: "9 s"}, {v: 12, t: "12 s"}]; current: r.app.settings.crossfade; onPicked: v => r.app.setSetting("crossfade", v) }
            }
            Row2 {
                title: Tr.t("Normalize volume"); hint: Tr.t("Evens out loud and quiet songs.")
                Toggle { on: r.app.settings.normalize === true; onFlipped: v => r.app.setSetting("normalize", v) }
            }
            Row2 {
                title: Tr.t("Offline mode"); hint: Tr.t("Plays only songs that are downloaded or on this computer, and turns search off.")
                Toggle { on: r.app.settings.offline === true; onFlipped: v => { r.app.setSetting("offline", v); if (v) r.app.refreshCached() } }
            }
            Row2 {
                title: Tr.t("Output device"); hint: r.app.settings.outputDevice !== "" ? r.app.settings.outputDevice : Tr.t("System default")
                PillButton { text: Tr.t("Choose"); icon: "speaker"; onClicked: { r.devices = JSON.parse(r.app.api.audioDevices()); devMenu.open() } }
            }
        }

        Card {
            heading: Tr.t("TASTE PROFILE")
            Row2 {
                title: Tr.t("Disliked songs"); hint: (r.app.lib.disliked || []).length + " songs are never recommended or put in your daily mixes."
                PillButton { text: Tr.t("Clear"); enabled: (r.app.lib.disliked || []).length > 0; onClicked: r.app.clearFlags("disliked") }
            }
            Row2 {
                title: Tr.t("Excluded from taste"); hint: (r.app.lib.excluded || []).length + " songs do not count when Cloudify works out what you like."
                PillButton { text: Tr.t("Clear"); enabled: (r.app.lib.excluded || []).length > 0; onClicked: r.app.clearFlags("excluded") }
            }
        }

        Card {
            heading: Tr.t("DISCORD")
            Row2 {
                title: Tr.t("Show what I'm listening to"); hint: "Rich Presence on your Discord profile. You need your own Discord application (discord.com/developers): paste its Application ID below and upload an image named cloudify."
                Toggle { on: r.app.settings.discordPresence === true; onFlipped: v => { r.app.setSetting("discordPresence", v); r.app.pushPresence() } }
            }
            TextField {
                id: discordId
                width: parent.width; height: 46
                placeholderText: Tr.t("Application ID (numbers)"); color: Theme.fg; placeholderTextColor: Theme.fgVariant
                font.family: Theme.bodyFont; font.pixelSize: 14; leftPadding: 18; maximumLength: 24
                text: r.app.settings.discordAppId
                inputMethodHints: Qt.ImhDigitsOnly
                background: Rectangle { radius: 23; color: Theme.container; border.width: discordId.activeFocus ? 2 : 0; border.color: Theme.primary }
                onEditingFinished: { r.app.setSetting("discordAppId", text.trim()); r.app.pushPresence() }
            }
        }

        Card {
            heading: Tr.t("STARTUP")
            Row2 {
                title: Tr.t("Open when Windows starts"); hint: Tr.t("Starts Cloudify in the notification area so the music is ready.")
                Toggle { on: r.app.settings.autostart === true; onFlipped: v => { r.app.setSetting("autostart", v); r.app.api.setAutostart(v) } }
            }
            Row2 {
                title: Tr.t("Keep playing in the tray"); hint: Tr.t("The close button hides Cloudify to the notification area. Quit is in the tray menu.")
                Toggle { on: r.app.settings.closeToTray === true; onFlipped: v => r.app.setSetting("closeToTray", v) }
            }
        }

        Card {
            heading: Tr.t("UPDATES")
            Row2 {
                title: "Cloudify " + r.app.version
                hint: r.app.updatePct >= 0 ? Tr.t("Downloading… ") + r.app.updatePct + "%" : (r.app.update.available === true ? Tr.t("Version ") + r.app.update.latest + " is available" : (r.app.updateMsg !== "" ? r.app.updateMsg : Tr.t("Updates come from GitHub releases")))
                PillButton { visible: r.app.update.available === true && r.app.update.installable === true; enabled: r.app.updatePct < 0; text: Tr.t("Update now"); variant: "filled"; icon: "download"; onClicked: r.app.installUpdate() }
                PillButton { visible: !(r.app.update.available === true && r.app.update.installable === true); text: Tr.t("Check for updates"); onClicked: r.app.checkUpdate(true) }
            }
            Column {
                visible: r.app.update.available === true && (r.app.update.notes || "") !== ""
                width: parent.width; spacing: 6
                Text { text: Tr.t("What's new in ") + (r.app.update.latest || ""); color: Theme.fg; font.family: Theme.bodyFont; font.pixelSize: 14; font.weight: Font.DemiBold }
                Text { width: parent.width; text: r.app.update.notes || ""; color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 13; wrapMode: Text.Wrap; maximumLineCount: 12; elide: Text.ElideRight }
            }
            Row2 {
                title: Tr.t("Check automatically"); hint: Tr.t("Looks for a new version when Cloudify starts.")
                Toggle { on: r.app.settings.autoUpdate === true; onFlipped: v => r.app.setSetting("autoUpdate", v) }
            }
        }

        Card {
            heading: Tr.t("SHORTCUTS")
            Repeater {
                model: [["Play / pause", "Ctrl+Alt+Shift+P  or the media key"], ["Next / previous", "Ctrl+Alt+Shift+Right / Left"], ["Volume", "Ctrl+Alt+Shift+Up / Down"], ["Like", "Ctrl+Alt+Shift+L"], ["Play / pause in the app", "Space"]]
                delegate: Item {
                    required property var modelData
                    width: parent.width; height: 28
                    Text { text: modelData[0]; color: Theme.fg; font.family: Theme.bodyFont; font.pixelSize: 14 }
                    Text { anchors.right: parent.right; text: modelData[1]; color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 14 }
                }
            }
        }

        Card {
            heading: Tr.t("ABOUT")
            Text { text: "Cloudify " + r.app.version + ", by weepingcloud"; color: Theme.fg; font.family: Theme.bodyFont; font.pixelSize: 15; font.weight: Font.DemiBold }
            Text {
                width: parent.width; wrapMode: Text.Wrap; color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 13
                text: "Free software under the GPL-3.0. The design and shaders come from Swiftify by shred0s (GPL-3.0). Songs come from YouTube Music through yt-dlp; lyrics from lrclib.net."
            }
        }
    }
}
