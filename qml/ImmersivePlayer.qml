import QtQuick
import QtQuick.Controls.Basic

// The immersive player, laid out as Swiftify's: the cover colours poured over the window, the song
// in the middle (cover inside its spectrum ring, title, seek line, transport, volume) and, picked
// from the switch at the top right, lyrics / up next / the sleep timer sliding in beside it while
// the song moves aside to make room.
Item {
    id: r
    required property var app
    property bool shown: false
    property alias panelHost: host
    signal close()
    Component.onCompleted: { shown = true; if (app.wantPanel !== "") { swapPanel(app.wantPanel); app.wantPanel = "" } }

    // ---- layout (ImmersiveLayout.cpp / ImmersivePlayer.qml) ----
    readonly property real topBarH: 84
    readonly property real bottomPad: 18
    readonly property real contentH: Math.max(0, height - topBarH - bottomPad)
    readonly property bool compact: contentH < 460
    readonly property real contentSpacing: compact ? 12 : 20
    readonly property real titleH: compact ? 64 : 72
    readonly property real titleSize: compact ? 26 : 30
    readonly property real chrome: compact ? 274 : 318

    property string panel: ""             // what the layout makes room for: "" | lyrics | queue | sleep
    property string shownPanel: ""        // what the panel area draws (the one still sliding away, too)
    property real panelOpacity: 1
    property real panelShift: 0
    property bool layoutMoving: false
    readonly property var panels: ["", "lyrics", "queue", "sleep", "sound"]

    readonly property real metadataWidth: Math.max(300, Math.min(400, width * 0.32))
    readonly property real hPad: Math.max(28, Math.min(64, width * 0.05))
    readonly property real rowSpace: Math.min(1250, width - 2 * hPad)
    readonly property real gap: Math.max(32, Math.min(72, width * 0.055))
    readonly property bool sideBySide: panel !== "" && rowSpace >= 900
    readonly property bool panelOnly: panel !== "" && !sideBySide
    readonly property real panelWidth: sideBySide ? Math.min(540, (rowSpace - gap) / 2) : rowSpace
    readonly property real nowWidth: sideBySide ? Math.min(500, rowSpace - gap - panelWidth) : Math.min(620, rowSpace)
    readonly property real rowWidth: sideBySide ? nowWidth + gap + panelWidth : nowWidth
    readonly property real panelHeight: Math.min(520, contentH)
    readonly property real panelX: sideBySide ? (width - rowWidth) / 2 + nowWidth + gap : (width - panelWidth) / 2
    readonly property real panelSlide: Math.min(140, panelWidth * 0.3)
    readonly property real artSize: Math.max(0, Math.min(500, width * (sideBySide ? 0.34 : 0.48), height * (sideBySide ? 0.42 : 0.5), contentH - chrome))

    readonly property bool grey: Theme.neutralSeed
    readonly property color accent: grey ? Qt.rgba(0.92, 0.92, 0.92, 1) : Qt.hsla(Theme.hue, 0.72, 0.82, 1)
    // fullscreen: the controls fade away after five quiet seconds and come back with the mouse
    readonly property bool fullscreen: r.app.nativeFull
    property bool chromeHidden: false
    property real chromeA: chromeHidden && fullscreen ? 0 : 1
    Behavior on chromeA { NumberAnimation { duration: chromeHidden ? 400 : 180; easing.type: Easing.OutCubic } }
    Timer { id: idle; interval: 5000; running: r.fullscreen && !r.chromeHidden; onTriggered: r.chromeHidden = true }
    onFullscreenChanged: { chromeHidden = false; idle.restart() }
    property real lastX: -1
    property real lastY: -1
    HoverHandler {
        cursorShape: r.fullscreen && r.chromeHidden ? Qt.BlankCursor : Qt.ArrowCursor
        onPointChanged: {
            var x = point.position.x, y = point.position.y
            if (Math.abs(x - r.lastX) > 2 || Math.abs(y - r.lastY) > 2) { r.lastX = x; r.lastY = y; r.chromeHidden = false; idle.restart() }
        }
    }
    readonly property color faint: Qt.rgba(1, 1, 1, 0.62)

    component Move: NumberAnimation { duration: r.mo(500); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve }
    function mo(ms) { return Theme.motion ? ms : 0 }

    function swapPanel(next) {
        if (next === panel) return
        swap.stop(); enterPanel.stop(); leavePanel.stop()
        pendingPanel = next
        if (next !== "" && panel === "") {
            layoutMoving = true; settle.restart()
            panel = next; shownPanel = next; panelOpacity = 0; panelShift = 1
            enterPanel.start()
        } else if (next === "") {
            layoutMoving = true; settle.restart()
            panel = ""
            leavePanel.start()
        } else swap.start()
    }
    property string pendingPanel: ""
    ParallelAnimation {
        id: enterPanel
        Move { target: r; property: "panelShift"; to: 0 }
        NumberAnimation { target: r; property: "panelOpacity"; to: 1; duration: r.mo(320); easing.type: Easing.OutCubic }
    }
    SequentialAnimation {
        id: leavePanel
        ParallelAnimation {
            Move { target: r; property: "panelShift"; to: 1 }
            NumberAnimation { target: r; property: "panelOpacity"; to: 0; duration: r.mo(260); easing.type: Easing.OutQuad }
        }
        ScriptAction { script: if (r.panel === "") r.shownPanel = "" }
    }
    SequentialAnimation {
        id: swap
        NumberAnimation { target: r; property: "panelOpacity"; to: 0; duration: r.mo(160); easing.type: Easing.OutQuad }
        ScriptAction { script: { r.panel = r.pendingPanel; r.shownPanel = r.pendingPanel; r.panelShift = 0 } }
        NumberAnimation { target: r; property: "panelOpacity"; to: 1; duration: r.mo(380); easing.type: Easing.OutCubic }
    }
    Timer { id: settle; interval: 520; onTriggered: r.layoutMoving = false }

    LiquidBackdrop { anchors.fill: parent; energy: r.app.energy }

    // big soft scalloped shapes drifting behind everything (Swiftify's flowers)
    component Blob: ShaderEffect {
        property real spin: 0
        property size itemSize: Qt.size(width, height)
        property color color: "#0fffffff"
        property real amplitude: 16
        property real wavelength: 70
        property real phase: spin
        property real cornerRadius: width * 0.45
        Timer { running: r.visible && Theme.motion && Theme.windowActive; interval: 66; repeat: true; onTriggered: parent.spin += 0.0065 }
        fragmentShader: "qrc:/shaders/wavy_pill.frag.qsb"
    }
    Blob { x: -120; y: -100; width: 460; height: 460; spin: 0.5 }
    Blob { x: parent.width - 330; y: -140; width: 520; height: 520; spin: 2; color: "#0cffffff" }
    Blob { x: parent.width * 0.42; y: parent.height - 260; width: 440; height: 440; spin: 4; color: "#0affffff" }

    // ---------------- top bar ----------------
    component Glass: Item {
        id: g
        property string icon
        property bool on: false
        property int size: 34
        signal clicked()
        width: size; height: size
        scale: gma.pressed ? 0.92 : 1
        Behavior on scale { NumberAnimation { duration: Theme.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } }
        Rectangle {
            anchors.fill: parent; radius: width / 2
            color: Qt.rgba(1, 1, 1, g.on ? 0.24 : (gma.containsMouse ? 0.2 : 0.12))
            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.14)
            Behavior on color { ColorAnimation { duration: Theme.quick } }
        }
        Text { anchors.centerIn: parent; text: g.icon; color: "white"; font.family: Theme.iconFont; renderType: Text.NativeRendering; font.pixelSize: 18 }
        MouseArea { id: gma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: g.clicked() }
    }
    Glass { x: 24; y: 44; icon: "close"; opacity: r.chromeA; enabled: r.chromeA > 0.5; onClicked: r.close() }
    Glass {
        x: 66; y: 44; opacity: r.chromeA; enabled: r.chromeA > 0.5
        icon: r.app.nativeFull ? "fullscreen_exit" : "fullscreen"
        on: r.app.nativeFull
        onClicked: r.app.setFull(!r.app.nativeFull)
    }

    // segmented switch: artwork / lyrics / up next / sleep
    Item {
        id: sw
        readonly property var icons: ["image", "lyrics", "queue_music", "bedtime", "tune"]
        readonly property real segW: 19 + 24
        anchors.right: parent.right; anchors.rightMargin: 24; y: 44; opacity: r.chromeA; enabled: r.chromeA > 0.5
        width: segW * icons.length + 8; height: 34
        Rectangle { anchors.fill: parent; radius: height / 2; color: Qt.rgba(1, 1, 1, 0.12); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.1) }
        Rectangle {
            id: ind
            y: 2; height: parent.height - 4; width: sw.segW; radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.92)
            x: 4 + Math.max(0, r.panels.indexOf(r.panel)) * sw.segW
            Behavior on x { NumberAnimation { duration: r.mo(380); easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
        }
        Repeater {
            model: sw.icons
            delegate: Item {
                required property string modelData
                required property int index
                x: 4 + index * sw.segW; width: sw.segW; height: sw.height
                enabled: index !== 1 || r.app.lyr.state !== "none"
                opacity: enabled ? 1 : 0.35
                Text {
                    anchors.centerIn: parent; text: modelData; font.family: Theme.iconFont; renderType: Text.NativeRendering; font.pixelSize: 19
                    color: r.panels.indexOf(r.panel) === index ? "#141414" : Qt.rgba(1, 1, 1, 0.86)
                    Behavior on color { ColorAnimation { duration: Theme.quick } }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: r.swapPanel(r.panels[index]) }
            }
        }
    }

    // ---------------- content ----------------
    Item {
        id: content
        y: r.topBarH; width: parent.width; height: r.contentH

        // ---- the song ----
        Item {
            id: now
            width: r.nowWidth
            x: (content.width - r.rowWidth) / 2
            height: art.height + r.contentSpacing + details.implicitHeight
            anchors.verticalCenter: parent.verticalCenter
            opacity: r.panelOnly ? 0 : 1
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: r.mo(260); easing.type: Easing.OutCubic } }
            Behavior on x { enabled: r.layoutMoving; Move {} }
            Behavior on width { enabled: r.layoutMoving; Move {} }

            Item {
                id: art
                width: now.width; height: r.artSize
                Behavior on height { enabled: r.layoutMoving; Move {} }
                // a new song's cover pops in on a spring
                property real pop: 1
                transform: Scale { origin.x: art.width / 2; origin.y: art.height / 2; xScale: art.pop; yScale: art.pop }
                NumberAnimation { id: popIn; target: art; property: "pop"; from: 0.9; to: 1; duration: r.mo(640); easing.type: Easing.OutBack; easing.overshoot: 2 }
                Connections { target: r.app; function onCurChanged() { popIn.restart() } }

                // glow in the cover's colour
                ShaderEffect {
                    anchors.centerIn: parent
                    width: ring.width * 1.28; height: width
                    property color color: r.accent
                    property real intensity: 0.34 + r.app.energy.y * 0.25
                    fragmentShader: "qrc:/shaders/glow.frag.qsb"
                }
                // radial spectrum: 56 rounded bars around the scalloped cover
                Item {
                    id: ring
                    anchors.centerIn: parent
                    width: r.artSize; height: r.artSize
                    readonly property real d: height * 0.68
                    opacity: r.app.bands.length === 48 ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 500 } }
                    Repeater {
                        model: 64
                        delegate: Item {
                            id: bar
                            required property int index
                            readonly property real level: r.app.bands.length === 48 ? r.app.bands[Math.min(47, Math.floor(Math.abs(index - 31.5) * 1.5))] : 0
                            width: 7; height: ring.height / 2
                            x: ring.height / 2 - 3.5; y: 0
                            transformOrigin: Item.Bottom
                            rotation: (index + 0.5) * (360 / 64)
                            Rectangle {
                                width: parent.width; radius: 3.5
                                y: ring.height / 2 - ring.d / 2 - 7 - h
                                readonly property real h: 8 + bar.level * ring.height * 0.13
                                height: h
                                color: r.grey ? Qt.hsla(0, 0, 0.92 - bar.index / 64 * 0.3, 1) : Qt.hsla(Theme.hue, 0.65, 0.80 - bar.index / 64 * 0.28, 1)
                                opacity: 0.55 + bar.level * 0.45
                                Behavior on height { NumberAnimation { duration: 70 } }
                            }
                        }
                    }
                }
                Cover {
                    anchors.centerIn: parent
                    width: ring.d; height: ring.d
                    radius: width / 2
                    ringWaves: 14; ringAmplitude: 5
                    ringColor: r.accent
                    source: r.app.cur ? r.app.cur.thumb : ""
                    scale: 1 + (Theme.motion ? r.app.energy.y * 0.03 : 0)
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }
                }
            }

            Column {
                id: details
                y: art.height + r.contentSpacing
                width: now.width
                spacing: r.contentSpacing

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(r.metadataWidth, parent.width)
                    spacing: r.compact ? 2 : 5
                    Text {
                        width: parent.width; height: r.titleH
                        text: r.app.cur ? r.app.cur.title : Tr.t("Nothing playing")
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                        color: "white"; font.family: Theme.headFont; font.pixelSize: r.titleSize; font.weight: Font.Bold; font.letterSpacing: -0.3
                    }
                    Text {
                        width: parent.width
                        text: r.app.cur ? r.app.cur.artist : ""
                        horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                        color: r.faint; font.family: Theme.bodyFont; font.pixelSize: 17; font.weight: Font.Medium
                    }
                    Text {
                        width: parent.width; visible: r.app.cur !== null && (r.app.cur.album || "") !== ""
                        text: r.app.cur && r.app.cur.album ? r.app.cur.album : ""
                        horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                        color: Qt.rgba(1, 1, 1, 0.4); font.family: Theme.bodyFont; font.pixelSize: 13
                    }
                }

                Item {
                    id: progress
                    opacity: r.chromeA
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(details.width, r.compact ? details.width : Math.max(320, r.artSize + 80))
                    height: 18
                    Text { id: el; width: 42; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter; text: r.app.fmt(r.app.position / 1000); color: Qt.rgba(1, 1, 1, 0.78); font.family: Theme.bodyFont; font.pixelSize: 12; font.weight: Font.Medium }
                    WaveSeek {
                        anchors.left: el.right; anchors.leftMargin: 12; anchors.right: rem.left; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                        height: 18
                        activeColor: r.accent; trackColor: Qt.rgba(1, 1, 1, 0.2)
                        position: r.app.position; duration: r.app.duration; playing: r.app.playing
                        onSeeked: ms => r.app.seek(ms)
                    }
                    Text { id: rem; width: 48; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "−" + r.app.fmt(Math.max(r.app.duration - r.app.position, 0) / 1000); color: Qt.rgba(1, 1, 1, 0.78); font.family: Theme.bodyFont; font.pixelSize: 12; font.weight: Font.Medium }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: r.compact ? Math.max(8, Math.min(28, (details.width - 196) / 4)) : 28
                    opacity: r.chromeA
                    IconButton { anchors.verticalCenter: parent.verticalCenter; icon: "shuffle"; ink: r.app.shuffle ? r.accent : "white"; size: 40; iconSize: 24; onClicked: r.app.shuffle = !r.app.shuffle }
                    IconButton { anchors.verticalCenter: parent.verticalCenter; icon: "skip_previous"; ink: "white"; size: 40; iconSize: 30; onClicked: r.app.prev() }
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: r.compact ? 52 : 60; height: width
                        WavyButton { anchors.fill: parent; fill: "white"; ink: "black"; iconSize: 32; icon: r.app.playing ? "pause" : "play_arrow"; onClicked: r.app.toggle() }
                    }
                    IconButton { anchors.verticalCenter: parent.verticalCenter; icon: "skip_next"; ink: "white"; size: 40; iconSize: 30; onClicked: r.app.next() }
                    IconButton { anchors.verticalCenter: parent.verticalCenter; icon: r.app.repeat ? "repeat_one" : "repeat"; ink: r.app.repeat ? r.accent : "white"; size: 40; iconSize: 24; onClicked: r.app.repeat = !r.app.repeat }
                }

                // the speaker mutes
                Row {
                    id: vol
                    opacity: r.chromeA
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: -15
                    spacing: 10
                    property real before: 0.8
                    IconButton {
                        id: mute
                        anchors.verticalCenter: parent.verticalCenter
                        icon: r.app.volume <= 0.01 ? "volume_off" : (r.app.volume <= 0.5 ? "volume_down" : "volume_up")
                        ink: Qt.rgba(1, 1, 1, 0.78); size: 30; iconSize: 20
                        onClicked: { if (r.app.volume > 0.01) { vol.before = r.app.volume; r.app.volume = 0 } else r.app.volume = vol.before }
                    }
                    Item {
                        id: vs
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(0, Math.min(Math.max(0, progress.width - 40), 300) - 30); height: 30
                        readonly property bool big: vma.pressed || vma.containsMouse
                        Rectangle { y: parent.height / 2 - height / 2; width: parent.width; height: vs.big ? 8 : 6; radius: height / 2; color: Qt.rgba(1, 1, 1, 0.2); Behavior on height { NumberAnimation { duration: Theme.quick } } }
                        Rectangle { y: parent.height / 2 - height / 2; width: Math.max(height, parent.width * r.app.volume); height: vs.big ? 8 : 6; radius: height / 2; color: "white"; Behavior on height { NumberAnimation { duration: Theme.quick } } }
                        Rectangle { x: Math.min(parent.width - 2, Math.max(0, parent.width * r.app.volume - 2)); y: parent.height / 2 - 10; width: 4; height: 20; radius: 2; color: "white"; opacity: vs.big ? 1 : 0; Behavior on opacity { NumberAnimation { duration: Theme.quick } } }
                        MouseArea {
                            id: vma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onPressed: m => r.app.volume = Math.min(1, Math.max(0, m.x / width))
                            onPositionChanged: m => { if (pressed) r.app.volume = Math.min(1, Math.max(0, m.x / width)) }
                        }
                    }
                }
            }
        }

        // ---- the panel ----
        Loader {
            id: host
            x: r.panelX + r.panelShift * r.panelSlide
            width: r.panelWidth; height: r.panelHeight
            anchors.verticalCenter: parent.verticalCenter
            opacity: r.panelOpacity
            visible: r.shownPanel !== "" && opacity > 0
            active: r.shownPanel !== ""
            sourceComponent: r.shownPanel === "lyrics" ? lyricsPanel : (r.shownPanel === "queue" ? queuePanel : (r.shownPanel === "sound" ? soundPanel : sleepPanel))
        }
    }

    // ---------------- lyrics ----------------
    Component {
        id: lyricsPanel
        Item {
            id: lp
            Text {
                visible: r.app.lyr.state !== "ready"
                anchors.centerIn: parent
                text: !r.app.cur ? Tr.t("Play a song to see its lyrics") : r.app.lyr.state === "loading" ? Tr.t("Loading lyrics…") : Tr.t("Lyrics unavailable")
                color: Qt.rgba(1, 1, 1, 0.7); font.family: Theme.bodyFont; font.pixelSize: 16
            }
            ListView {
                id: list
                visible: r.app.lyr.state === "ready"
                anchors.fill: parent
                model: r.app.lyr.lines
                spacing: 26; topMargin: 30; bottomMargin: 30; leftMargin: 8; rightMargin: 8
                clip: true; cacheBuffer: 1200
                boundsBehavior: Flickable.DragAndOvershootBounds
                layer.enabled: visible
                layer.effect: ShaderEffect { property variant source; property real edge: 0.08; fragmentShader: "qrc:/shaders/edge_fade.frag.qsb" }
                signal stepped(real delta)
                function follow(animated) {
                    var index = r.app.lyrIdx
                    if (index < 0) return
                    var item = list.itemAtIndex(index)
                    if (!item) { list.positionViewAtIndex(index, ListView.Center); return }
                    var target = Math.max(list.originY - list.topMargin, Math.min(item.y + item.height / 2 - list.height / 2, list.contentHeight + list.originY - list.height + list.bottomMargin))
                    var delta = target - list.contentY
                    list.contentY = target
                    if (animated && Theme.motion) list.stepped(delta)
                }
                Connections { target: r.app; function onLyrIdxChanged() { list.follow(true) } }
                Component.onCompleted: Qt.callLater(list.follow, false)
                delegate: Item {
                    id: ln
                    required property var modelData
                    required property int index
                    readonly property bool active: !r.app.lyr.synced || r.app.lyrIdx === index
                    property bool flashed: false
                    width: list.width - list.leftMargin - list.rightMargin
                    height: lt.implicitHeight + 16
                    property real lag: 0
                    transform: Translate { y: ln.lag }
                    Connections { target: list; function onStepped(delta) { ln.lag += delta; rip.restart() } }
                    SequentialAnimation {
                        id: rip
                        PauseAnimation { duration: Math.min(Math.abs(ln.index - r.app.lyrIdx), 8) * 16 }
                        NumberAnimation { target: ln; property: "lag"; to: 0; duration: 560; easing.type: Easing.OutBack; easing.overshoot: 0.6 }
                    }
                    property real springing: active ? 1 : 0.96
                    scale: springing
                    transformOrigin: Item.Left
                    Behavior on springing { NumberAnimation { duration: r.mo(420); easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
                    // the sung line sits on a scalloped pill
                    ShaderEffect {
                        anchors.fill: parent
                        property size itemSize: Qt.size(width, height)
                        property color color: Qt.rgba(1, 1, 1, ln.active && r.app.lyr.synced ? 0.07 : 0)
                        property real amplitude: 3
                        property real wavelength: 40
                        property real phase: 0
                        property real cornerRadius: 32
                        Behavior on color { ColorAnimation { duration: r.mo(320); easing.type: Easing.InOutQuad } }
                        fragmentShader: "qrc:/shaders/wavy_pill.frag.qsb"
                    }
                    Rectangle { anchors.fill: parent; radius: 20; color: Qt.rgba(1, 1, 1, ln.flashed ? 0.13 : 0); Behavior on color { ColorAnimation { duration: 180 } } }
                    Text {
                        id: lt
                        y: 8; width: parent.width
                        leftPadding: 24; rightPadding: 24; topPadding: 14; bottomPadding: 14
                        text: ln.modelData.text === "" ? "♪" : ln.modelData.text
                        wrapMode: Text.Wrap; color: "white"
                        font.family: Theme.headFont; font.pixelSize: 30; font.weight: Font.Bold
                        opacity: ln.active ? 1 : 0.28
                        Behavior on opacity { NumberAnimation { duration: r.mo(320); easing.type: Easing.InOutQuad } }
                    }
                    Timer { id: fl; interval: 80; onTriggered: ln.flashed = false }
                    MouseArea { anchors.fill: parent; enabled: r.app.lyr.synced; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: { ln.flashed = true; fl.restart(); r.app.seek(ln.modelData.t) } }
                }
                footer: Text { leftPadding: 18; topPadding: 46; text: Tr.t("Lyrics provided by lrclib.net"); color: Qt.rgba(1, 1, 1, 0.4); font.family: Theme.bodyFont; font.pixelSize: 12 }
            }
        }
    }

    // ---------------- up next ----------------
    Component {
        id: queuePanel
        Item {
            Text { visible: !r.app.cur; anchors.horizontalCenter: parent.horizontalCenter; y: 80; text: Tr.t("Queue empty"); color: Qt.rgba(1, 1, 1, 0.7); font.family: Theme.bodyFont; font.pixelSize: 16 }
            ListView {
                id: ql
                anchors.fill: parent
                visible: r.app.cur !== null
                model: r.app.queue.slice(r.app.qi + 1)
                spacing: 10; topMargin: 30; bottomMargin: 30; leftMargin: 8; rightMargin: 8
                clip: true; boundsBehavior: Flickable.StopAtBounds
                layer.enabled: visible
                layer.effect: ShaderEffect { property variant source; property real edge: 0.08; fragmentShader: "qrc:/shaders/edge_fade.frag.qsb" }
                header: Item {
                    width: ql.width - ql.leftMargin - ql.rightMargin
                    height: 70 + ql.spacing
                    QueueRow { width: parent.width; song: r.app.cur; current: true }
                }
                delegate: QueueRow {
                    required property var modelData
                    required property int index
                    width: ql.width - ql.leftMargin - ql.rightMargin
                    song: modelData
                    onClicked: { r.app.qi = r.app.qi + 1 + index; r.app.startCurrent() }
                    onRemoved: r.app.removeFromQueue(r.app.qi + 1 + index)
                }
                displaced: Transition {
                    SequentialAnimation {
                        PauseAnimation { duration: Math.min(Math.max(ViewTransition.index, 0), 12) * 30 }
                        NumberAnimation { property: "y"; duration: r.mo(420); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve }
                    }
                }
                add: Transition {
                    SequentialAnimation {
                        PauseAnimation { duration: Math.min(Math.max(ViewTransition.index, 0), 12) * 30 }
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: r.mo(420); easing.type: Easing.OutCubic }
                    }
                }
                remove: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 180; easing.type: Easing.OutCubic } }
            }
        }
    }
    component QueueRow: Item {
        id: qr
        property var song
        property bool current: false
        signal clicked()
        signal removed()
        height: 70
        Rectangle { anchors.fill: parent; radius: 14; color: Qt.rgba(1, 1, 1, qr.current ? 0.07 : (qma.pressed ? 0.08 : (qma.containsMouse ? 0.04 : 0))); Behavior on color { ColorAnimation { duration: Theme.quick } } }
        MouseArea { id: qma; anchors.fill: parent; hoverEnabled: true; enabled: !qr.current; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: qr.clicked() }
        Cover { id: qa; x: 12; anchors.verticalCenter: parent.verticalCenter; width: 54; height: 54; radius: 8; source: qr.song ? (qr.song.thumb || "") : "" }
        Column {
            anchors.left: qa.right; anchors.leftMargin: 13; anchors.right: parent.right; anchors.rightMargin: 44; anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Text { width: parent.width; text: qr.song ? qr.song.title : ""; elide: Text.ElideRight; color: qr.current ? "white" : Qt.rgba(1, 1, 1, 0.84); font.family: Theme.bodyFont; font.pixelSize: 15; font.weight: qr.current ? Font.Bold : Font.DemiBold }
            Text { width: parent.width; text: qr.song ? qr.song.artist : ""; elide: Text.ElideRight; color: Qt.rgba(1, 1, 1, 0.6); font.family: Theme.bodyFont; font.pixelSize: 13 }
        }
        Text { visible: qr.current; anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; text: "volume_up"; color: r.accent; font.family: Theme.iconFont; renderType: Text.NativeRendering; font.pixelSize: 20 }
        Text {
            visible: !qr.current; opacity: qma.containsMouse ? 0.9 : 0
            anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
            text: "close"; color: "white"; font.family: Theme.iconFont; renderType: Text.NativeRendering; font.pixelSize: 20
            Behavior on opacity { NumberAnimation { duration: Theme.quick } }
            MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: qr.removed() }
        }
    }


    component HSlider: Item {
        id: hs
        property real from: 0
        property real to: 1
        property real step: 0.1
        property real value: 0
        signal moved(real v)
        height: 30
        readonly property real frac: Math.max(0, Math.min(1, (value - from) / (to - from)))
        readonly property bool big: hma.pressed || hma.containsMouse
        Rectangle { y: parent.height / 2 - height / 2; width: parent.width; height: hs.big ? 10 : 8; radius: height / 2; color: Qt.rgba(1, 1, 1, 0.16); Behavior on height { NumberAnimation { duration: Theme.quick } } }
        Rectangle { y: parent.height / 2 - height / 2; width: Math.max(height, parent.width * hs.frac); height: hs.big ? 10 : 8; radius: height / 2; color: r.accent; Behavior on height { NumberAnimation { duration: Theme.quick } } }
        Rectangle { x: Math.min(parent.width - 3, Math.max(0, parent.width * hs.frac - 1.5)); y: parent.height / 2 - 10; width: 4; height: 20; radius: 2; color: "white" }
        MouseArea {
            id: hma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            function setFrom(mx) {
                var f = Math.max(0, Math.min(1, mx / width))
                var v = Math.round((hs.from + f * (hs.to - hs.from)) / hs.step) * hs.step
                hs.moved(Math.max(hs.from, Math.min(hs.to, v)))
            }
            onPressed: m => setFrom(m.x)
            onPositionChanged: m => { if (pressed) setFrom(m.x) }
        }
    }

    // ---------------- sound: the equalizer ----------------
    Component {
        id: soundPanel
        Flickable {
            id: sf
            contentHeight: col.implicitHeight + 24
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            Column {
                id: col
                y: 12
                width: Math.min(sf.width, 460)
                spacing: 14

                Rectangle {
                    width: parent.width; radius: 20; color: Qt.rgba(1, 1, 1, 0.07)
                    implicitHeight: card.implicitHeight + 30
                    height: implicitHeight
                    Column {
                        id: card
                        x: 16; y: 15; width: parent.width - 32; spacing: 14
                        Item {
                            width: parent.width; height: 40
                            Text { anchors.verticalCenter: parent.verticalCenter; text: Tr.t("Equalizer"); color: "white"; font.family: Theme.headFont; font.pixelSize: 20; font.weight: Font.Bold }
                            Row {
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                                Item {
                                    id: presetBtn
                                    width: pl.implicitWidth + 52; height: 36
                                    scale: pma.pressed ? 0.97 : 1
                                    Behavior on scale { NumberAnimation { duration: Theme.quick } }
                                    Rectangle { anchors.fill: parent; radius: 18; color: Qt.rgba(1, 1, 1, pma.containsMouse ? 0.16 : 0.1); Behavior on color { ColorAnimation { duration: Theme.quick } } }
                                    Text { id: pl; x: 16; anchors.verticalCenter: parent.verticalCenter; text: r.app.eqName; color: "white"; font.family: Theme.bodyFont; font.pixelSize: 14; font.weight: Font.DemiBold }
                                    Text { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: "expand_more"; color: "white"; font.family: Theme.iconFont; renderType: Text.NativeRendering; font.pixelSize: 20 }
                                    MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: presetMenu.open() }
                                }
                                Item {
                                    width: 36; height: 36
                                    opacity: r.app.eqName === "Custom" ? 1 : 0.4
                                    Rectangle { anchors.fill: parent; radius: 18; color: Qt.rgba(1, 1, 1, sma2.containsMouse ? 0.16 : 0.1) }
                                    Text { anchors.centerIn: parent; text: "bookmark_add"; color: "white"; font.family: Theme.iconFont; renderType: Text.NativeRendering; font.pixelSize: 20 }
                                    MouseArea { id: sma2; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: r.app.eqName === "Custom"; onClicked: { presetName.text = ""; savePopup.open(); presetName.forceActiveFocus() } }
                                }
                                Item {
                                    width: 36; height: 36
                                    opacity: r.app.eqName === "Flat" ? 0.4 : 1
                                    Rectangle { anchors.fill: parent; radius: 18; color: Qt.rgba(1, 1, 1, rma.containsMouse ? 0.16 : 0.1) }
                                    Text { anchors.centerIn: parent; text: "restart_alt"; color: "white"; font.family: Theme.iconFont; renderType: Text.NativeRendering; font.pixelSize: 20 }
                                    MouseArea { id: rma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: r.app.setEq([0, 0, 0, 0, 0, 0]) }
                                }
                            }
                        }

                        // the response curve: each band a gaussian bump, summed
                        Canvas {
                            id: curve
                            width: parent.width; height: 110
                            property var g: r.app.eqGains
                            onGChanged: requestPaint()
                            onWidthChanged: requestPaint()
                            function level(p) {
                                var t = 0, sp = 1 / 5, w = sp * 0.85
                                for (var b = 0; b < 6; b++) { var d = (p - b * sp) / w; t += g[b] * Math.exp(-d * d) }
                                return t
                            }
                            onPaint: {
                                var c = getContext("2d"); c.reset()
                                var mid = height / 2, reach = height / 2 - 8
                                c.strokeStyle = "rgba(255,255,255,0.16)"; c.lineWidth = 1
                                c.beginPath(); c.moveTo(0, mid); c.lineTo(width, mid); c.stroke()
                                var pts = []
                                for (var p = 0; p <= 1.0001; p += 0.02) pts.push([p * width, mid - Math.max(-1, Math.min(1, level(p) / 16)) * reach])
                                c.beginPath(); c.moveTo(pts[0][0], mid)
                                for (var i = 0; i < pts.length; i++) c.lineTo(pts[i][0], pts[i][1])
                                c.lineTo(width, mid); c.closePath()
                                c.fillStyle = Qt.rgba(r.accent.r, r.accent.g, r.accent.b, 0.16); c.fill()
                                c.beginPath(); c.moveTo(pts[0][0], pts[0][1])
                                for (var j = 1; j < pts.length; j++) c.lineTo(pts[j][0], pts[j][1])
                                c.strokeStyle = Qt.rgba(r.accent.r, r.accent.g, r.accent.b, 1); c.lineWidth = 3; c.lineJoin = "round"; c.stroke()
                            }
                        }

                        Row {
                            width: parent.width
                            Repeater {
                                model: [{f: "60", i: 0}, {f: "150", i: 1}, {f: "400", i: 2}, {f: "1k", i: 3}, {f: "2.4k", i: 4}, {f: "15k", i: 5}]
                                delegate: Item {
                                    id: band
                                    required property var modelData
                                    width: card.width / 6; height: 190
                                    readonly property real gv: r.app.eqGains[modelData.i]
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter; y: 0; height: 34; radius: 17
                                        width: Math.max(42, pt.implicitWidth + 16)
                                        color: Qt.rgba(1, 1, 1, Math.abs(band.gv) > 0.05 ? 0.16 : 0.08)
                                        Text { id: pt; anchors.centerIn: parent; text: (band.gv > 0 ? "+" : "") + band.gv.toFixed(1); color: "white"; font.family: Theme.bodyFont; font.pixelSize: 12; font.weight: Font.DemiBold }
                                    }
                                    Item {
                                        id: trackBox
                                        anchors.horizontalCenter: parent.horizontalCenter; y: 44; width: 30; height: 112
                                        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 10; height: parent.height; radius: 5; color: Qt.rgba(1, 1, 1, 0.16) }
                                        Rectangle {
                                            anchors.horizontalCenter: parent.horizontalCenter; width: 10; radius: 5; color: r.accent
                                            y: band.gv >= 0 ? handle.y + 4 : parent.height / 2
                                            height: Math.abs(handle.y + 4 - parent.height / 2)
                                        }
                                        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: parent.height / 2 - 1; width: 18; height: 2; radius: 1; color: Qt.rgba(1, 1, 1, 0.35) }
                                        Rectangle {
                                            id: handle
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: 28; height: 8; radius: 4; color: "white"
                                            y: (1 - (band.gv + 12) / 24) * (parent.height - 8)
                                            scale: bma.pressed ? 1.12 : 1
                                            Behavior on scale { NumberAnimation { duration: Theme.quick } }
                                        }
                                        MouseArea {
                                            id: bma; anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor
                                            function setFrom(my) {
                                                var f = Math.max(0, Math.min(1, (my - 6 - 4) / (trackBox.height - 8)))
                                                var v = Math.round((12 - f * 24) * 2) / 2
                                                var g = r.app.eqGains.slice(); g[band.modelData.i] = v; r.app.setEq(g)
                                            }
                                            onPressed: m => setFrom(m.y)
                                            onPositionChanged: m => { if (pressed) setFrom(m.y) }
                                            onDoubleClicked: { var g = r.app.eqGains.slice(); g[band.modelData.i] = 0; r.app.setEq(g) }
                                        }
                                    }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; y: 166; text: modelData.f + (modelData.i < 5 ? " Hz" : " Hz"); color: Qt.rgba(1, 1, 1, 0.6); font.family: Theme.bodyFont; font.pixelSize: 12 }
                                }
                            }
                        }
                    }
                }
                Rectangle {
                    width: parent.width; radius: 20; color: Qt.rgba(1, 1, 1, 0.07)
                    height: pbCol.implicitHeight + 30
                    Column {
                        id: pbCol
                        x: 16; y: 15; width: parent.width - 32; spacing: 12
                        Text { text: Tr.t("Playback"); color: "white"; font.family: Theme.headFont; font.pixelSize: 20; font.weight: Font.Bold }
                        // label, slider, value
                        Repeater {
                            model: [
                                {k: "preamp", t: Tr.t("Preamp"), from: -12, to: 12, step: 0.5, unit: " dB", def: 0},
                                {k: "speed", t: Tr.t("Speed"), from: 0.5, to: 2, step: 0.05, unit: "×", def: 1},
                                {k: "pitch", t: Tr.t("Pitch"), from: -12, to: 12, step: 1, unit: " st", def: 0}
                            ]
                            delegate: Item {
                                id: prow
                                required property var modelData
                                width: parent.width; height: 34
                                readonly property real val: r.app.settings[modelData.k]
                                Text { id: pl2; width: 64; anchors.verticalCenter: parent.verticalCenter; text: modelData.t; color: Qt.rgba(1, 1, 1, 0.75); font.family: Theme.bodyFont; font.pixelSize: 13 }
                                HSlider {
                                    anchors.left: pl2.right; anchors.right: pv.left; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                                    from: modelData.from; to: modelData.to; step: modelData.step; value: prow.val
                                    onMoved: v => r.app.setSetting(modelData.k, v)
                                }
                                Rectangle {
                                    id: pv
                                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                    width: 64; height: 26; radius: 13; color: Qt.rgba(1, 1, 1, Math.abs(prow.val - modelData.def) > 0.001 ? 0.18 : 0.08)
                                    Text { anchors.centerIn: parent; text: (prow.val > 0 && modelData.def === 0 ? "+" : "") + (modelData.k === "speed" ? prow.val.toFixed(2) : (modelData.k === "pitch" ? prow.val.toFixed(0) : prow.val.toFixed(1))) + modelData.unit; color: "white"; font.family: Theme.bodyFont; font.pixelSize: 12; font.weight: Font.DemiBold }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onDoubleClicked: r.app.setSetting(modelData.k, modelData.def) }
                                }
                            }
                        }
                        Item {
                            width: parent.width; height: 34
                            Text { anchors.verticalCenter: parent.verticalCenter; text: Tr.t("Normalize volume"); color: Qt.rgba(1, 1, 1, 0.75); font.family: Theme.bodyFont; font.pixelSize: 13 }
                            Rectangle {
                                id: nt
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                width: 52; height: 30; radius: 15; color: r.app.settings.normalize === true ? r.accent : Qt.rgba(1, 1, 1, 0.18)
                                Behavior on color { ColorAnimation { duration: Theme.quick } }
                                Rectangle { y: 3; x: r.app.settings.normalize === true ? parent.width - width - 3 : 3; width: 24; height: 24; radius: 12; color: r.app.settings.normalize === true ? "#141414" : "white"; Behavior on x { NumberAnimation { duration: Theme.quick; easing.type: Easing.OutCubic } } }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: r.app.setSetting("normalize", !(r.app.settings.normalize === true)) }
                            }
                        }
                        Item {
                            width: parent.width; height: 34
                            Text { id: cl; width: 64; anchors.verticalCenter: parent.verticalCenter; text: Tr.t("Crossfade"); color: Qt.rgba(1, 1, 1, 0.75); font.family: Theme.bodyFont; font.pixelSize: 13 }
                            HSlider {
                                anchors.left: cl.right; anchors.right: cv.left; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                                from: 0; to: 12; step: 1; value: r.app.settings.crossfade
                                onMoved: v => r.app.setSetting("crossfade", v)
                            }
                            Rectangle { id: cv; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 64; height: 26; radius: 13; color: Qt.rgba(1, 1, 1, r.app.settings.crossfade > 0 ? 0.18 : 0.08)
                                Text { anchors.centerIn: parent; text: r.app.settings.crossfade > 0 ? r.app.settings.crossfade + " s" : Tr.t("Off"); color: "white"; font.family: Theme.bodyFont; font.pixelSize: 12; font.weight: Font.DemiBold } }
                        }
                    }
                }
                Text { width: parent.width; wrapMode: Text.Wrap; text: Tr.t("Drag a band, or double-click it to reset. Changes apply to the song as it plays."); color: Qt.rgba(1, 1, 1, 0.45); font.family: Theme.bodyFont; font.pixelSize: 12 }
            }
        }
    }
    Popup {
        id: presetMenu
        anchors.centerIn: Overlay.overlay
        modal: true; padding: 10; width: 300; height: Math.min(460, r.height - 80)
        enter: Transition { ParallelAnimation { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 170 } NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: 260; easing.type: Easing.OutCubic } } }
        exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 120 } }
        background: Rectangle { color: Theme.containerHighest; radius: Theme.radiusLarge }
        Overlay.modal: Rectangle { color: "#99000000" }
        contentItem: ListView {
            clip: true; boundsBehavior: Flickable.StopAtBounds
            header: Text { text: Tr.t("Presets"); color: Theme.fg; font.family: Theme.headFont; font.pixelSize: 18; font.weight: Font.Bold; leftPadding: 8; topPadding: 4; bottomPadding: 8 }
            model: r.app.eqAll
            delegate: NavItem {
                required property var modelData
                required property int index
                width: ListView.view.width; height: 44
                icon: index >= r.app.eqPresets.length ? "bookmark" : "graphic_eq"; text: modelData.n; selected: r.app.eqName === modelData.n
                onClicked: { r.app.setEq(modelData.g); presetMenu.close() }
                onRightClicked: if (index >= r.app.eqPresets.length) r.app.deleteEqPreset(modelData.n)
            }
        }
    }

    Popup {
        id: savePopup
        anchors.centerIn: Overlay.overlay
        modal: true; padding: 22; width: 360
        enter: Transition { ParallelAnimation { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 170 } NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: 260; easing.type: Easing.OutCubic } } }
        exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 120 } }
        background: Rectangle { color: Theme.containerHighest; radius: Theme.radiusLarge }
        Overlay.modal: Rectangle { color: "#99000000" }
        contentItem: Column {
            spacing: 14
            Text { text: Tr.t("Save equalizer preset"); color: Theme.fg; font.family: Theme.headFont; font.pixelSize: 20; font.weight: Font.Bold }
            TextField {
                id: presetName
                width: parent.width; height: 46
                placeholderText: Tr.t("Preset name"); color: Theme.fg; placeholderTextColor: Theme.fgVariant
                font.family: Theme.bodyFont; font.pixelSize: 15; leftPadding: 18; maximumLength: 30
                background: Rectangle { radius: 23; color: Theme.container; border.width: presetName.activeFocus ? 2 : 0; border.color: Theme.primary }
                onAccepted: { r.app.saveEqPreset(presetName.text); savePopup.close() }
            }
            Row {
                layoutDirection: Qt.RightToLeft; width: parent.width; spacing: 8
                PillButton { text: Tr.t("Save"); variant: "filled"; enabled: presetName.text.trim().length > 0; onClicked: { r.app.saveEqPreset(presetName.text); savePopup.close() } }
                PillButton { text: Tr.t("Cancel"); variant: "text"; onClicked: savePopup.close() }
            }
        }
    }

    // ---------------- sleep timer ----------------
    Component {
        id: sleepPanel
        Item {
            Column {
                anchors.centerIn: parent
                width: Math.min(parent.width, 380); spacing: 10
                Text { text: Tr.t("Sleep timer"); color: "white"; font.family: Theme.headFont; font.pixelSize: 24; font.weight: Font.Bold }
                Text { text: r.app.sleepAtSongEnd ? Tr.t("Stops after this song") : (r.app.sleepEnd > 0 ? Tr.t("Pauses in ") + r.app.fmt(r.app.sleepLeft) : Tr.t("Music fades out and pauses by itself")); color: r.app.sleepOn ? r.accent : Qt.rgba(1, 1, 1, 0.6); font.family: Theme.bodyFont; font.pixelSize: 14; bottomPadding: 8 }
                Flow {
                    width: parent.width; spacing: 8
                    Repeater {
                        model: [{t: Tr.t("15 min"), m: 15}, {t: Tr.t("30 min"), m: 30}, {t: Tr.t("45 min"), m: 45}, {t: Tr.t("1 hour"), m: 60}, {t: Tr.t("2 hours"), m: 120}, {t: Tr.t("End of song"), m: -1}]
                        delegate: Item {
                            required property var modelData
                            width: sl.implicitWidth + 36; height: 40
                            scale: sma.pressed ? 0.97 : 1
                            Behavior on scale { NumberAnimation { duration: Theme.quick } }
                            Rectangle { anchors.fill: parent; radius: 20; color: Qt.rgba(1, 1, 1, sma.containsMouse ? 0.16 : 0.09); Behavior on color { ColorAnimation { duration: Theme.quick } } }
                            Text { id: sl; anchors.centerIn: parent; text: modelData.t; color: "white"; font.family: Theme.bodyFont; font.pixelSize: 14; font.weight: Font.DemiBold }
                            MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: modelData.m < 0 ? r.app.sleepAfterSong() : r.app.setSleep(modelData.m) }
                        }
                    }
                }
                PillButton { visible: r.app.sleepOn; text: Tr.t("Turn off"); icon: "close"; onClicked: r.app.setSleep(0) }
            }
        }
    }
}
