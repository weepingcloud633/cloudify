import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import CloudMusic

ApplicationWindow {
    id: win
    visible: true
    width: 1180
    height: 760
    minimumWidth: 860
    minimumHeight: 560
    title: "Cloudify"
    color: Theme.background
    flags: Qt.Window | Qt.FramelessWindowHint

    // our own title bar (above everything, also over the immersive player) and resize edges
    TitleBar { z: 100; host: win;  anchors.left: parent.left; anchors.right: parent.right; ink: win.immersive ? "white" : Theme.fgVariant }
    Repeater {
        model: [
            {e: Qt.LeftEdge, c: Qt.SizeHorCursor}, {e: Qt.RightEdge, c: Qt.SizeHorCursor},
            {e: Qt.TopEdge, c: Qt.SizeVerCursor}, {e: Qt.BottomEdge, c: Qt.SizeVerCursor},
            {e: Qt.LeftEdge | Qt.TopEdge, c: Qt.SizeFDiagCursor}, {e: Qt.RightEdge | Qt.BottomEdge, c: Qt.SizeFDiagCursor},
            {e: Qt.RightEdge | Qt.TopEdge, c: Qt.SizeBDiagCursor}, {e: Qt.LeftEdge | Qt.BottomEdge, c: Qt.SizeBDiagCursor}
        ]
        delegate: MouseArea {
            required property var modelData
            z: 101
            visible: win.visibility !== Window.Maximized
            readonly property bool l: (modelData.e & Qt.LeftEdge) !== 0
            readonly property bool rt: (modelData.e & Qt.RightEdge) !== 0
            readonly property bool tp: (modelData.e & Qt.TopEdge) !== 0
            readonly property bool bt: (modelData.e & Qt.BottomEdge) !== 0
            x: l ? 0 : (rt ? win.width - 6 : 6)
            y: tp ? 0 : (bt ? win.height - 6 : 6)
            width: (l || rt) ? 6 : win.width - 12
            height: (tp || bt) ? 6 : win.height - 12
            cursorShape: modelData.c
            onPressed: win.startSystemResize(modelData.e)
        }
    }

    // ---- state ----
    property var results: []
    property var found: null
    property bool searching: false
    property var lib: ({liked: [], playlists: []})
    property string page: "home"            // home | search | liked | playlists | playlist
    property var shownPlaylist: null
    property var queue: []
    property int qi: -1
    property string note: ""
    property real importFrac: -1
    property bool shuffle: false
    property bool repeat: false
    property real volume: 0.8
    property bool immersive: false
    property bool settingsSeen: false
    property var lyr: ({vid: "", state: "idle", synced: false, lines: []})
    property var profiles: []
    property var profile: null
    property bool gate: false
    property var bands: []
    property vector4d energy: Qt.vector4d(0.1, 0.08, 0.07, 0.09)
    readonly property int lyrIdx: {
        var p = (immersive ? rawPosition : position) + 200, L = lyr.lines
        if (!lyr.synced || !L.length || p < L[0].t) return -1
        var lo = 0, hi = L.length - 1
        while (lo < hi) { var mid = (lo + hi + 1) >> 1; if (L[mid].t <= p) lo = mid; else hi = mid - 1 }
        return lo
    }
    readonly property var cur: qi >= 0 && qi < queue.length ? queue[qi] : null
    readonly property var audio: eng.item
    readonly property bool playing: audio ? audio.playing : false
    readonly property real position: audio ? audio.position : resumeAt
    readonly property real rawPosition: position
    readonly property real duration: audio ? audio.duration : (cur ? cur.dur * 1000 : 0)
    // Swiftify's opening: a scalloped shape bounces out of the middle, turns, then bursts over the window
    property real immReveal: 0
    property real revealReach: 0
    property real revealSpin: 0
    property real revealSpinStart: 0
    property real immFade: 1
    property string revealShape: "cookie9"
    readonly property bool immActive: immReveal > 0
    readonly property var revealShapes: ["cookie9", "cookie6", "clover4", "clover8", "sunny", "verySunny", "softBurst", "burst", "flower", "puffy", "pentagon", "gem"]
    function shapeParams(n) {
        switch (n) {
        case "cookie6": return Qt.vector4d(6, 0.1, 1, 0)
        case "cookie9": return Qt.vector4d(9, 0.09, 1, 0)
        case "clover4": return Qt.vector4d(4, 0.42, 0.55, 0)
        case "clover8": return Qt.vector4d(8, 0.28, 0.6, 0)
        case "sunny": return Qt.vector4d(8, 0.14, 2.2, 0)
        case "verySunny": return Qt.vector4d(8, 0.26, 2.6, 0)
        case "softBurst": return Qt.vector4d(10, 0.16, 1.5, 0)
        case "burst": return Qt.vector4d(12, 0.24, 2.8, 0)
        case "flower": return Qt.vector4d(8, 0.32, 0.45, 0)
        case "puffy": return Qt.vector4d(6, 0.18, 0.5, 0)
        case "pentagon": return Qt.vector4d(5, 0.12, 3, 0)
        case "gem": return Qt.vector4d(6, 0.08, 4, 0)
        default: return Qt.vector4d(0, 0, 1, 0)
        }
    }
    function mo(ms) { return Theme.motion ? ms : 0 }
    onImmersiveChanged: {
        if (immersive) revealShape = revealShapes[Math.floor(Math.random() * revealShapes.length)]
        openMotion.stop(); closeMotion.stop()
        revealSpinStart = revealSpin % (2 * Math.PI); revealSpin = revealSpinStart
        if (immersive) openMotion.start(); else closeMotion.start()
    }
    SequentialAnimation {
        id: openMotion
        PropertyAction { target: win; property: "immFade"; value: Theme.motion ? 1 : 0 }
        PropertyAction { target: win; property: "immReveal"; value: 0.01 }
        ParallelAnimation {
            NumberAnimation { target: win; property: "revealSpin"; to: win.revealSpinStart + 1.6 * Math.PI; duration: win.mo(600) }
            SequentialAnimation {
                NumberAnimation { target: win; property: "revealReach"; to: 0.2; duration: win.mo(260); easing.type: Easing.OutBack; easing.overshoot: 2.4 }
                PauseAnimation { duration: win.mo(60) }
                NumberAnimation { target: win; property: "revealReach"; to: 1; duration: win.mo(280); easing.type: Easing.InBack; easing.overshoot: 1.2 }
            }
        }
        PropertyAction { target: win; property: "immReveal"; value: 1 }
        NumberAnimation { target: win; property: "immFade"; to: 1; duration: Theme.motion ? 0 : 240 }
    }
    SequentialAnimation {
        id: closeMotion
        PropertyAction { target: win; property: "immReveal"; value: Math.min(win.immReveal, 0.99) }
        NumberAnimation { target: win; property: "immFade"; to: Theme.motion ? 1 : 0; duration: Theme.motion ? 0 : 200 }
        ParallelAnimation {
            NumberAnimation { target: win; property: "immReveal"; to: 0; duration: win.mo(520); easing.type: Easing.OutCubic }
            NumberAnimation { target: win; property: "revealReach"; to: 0; duration: win.mo(520); easing.type: Easing.OutCubic }
            NumberAnimation { target: win; property: "revealSpin"; to: win.revealSpinStart + 1.4; duration: win.mo(520); easing.type: Easing.OutCubic }
        }
        PropertyAction { target: win; property: "immReveal"; value: 0 }
        ScriptAction { script: backend.trimMemory() }
    }
    onPageChanged: { if (page === "settings") settingsSeen = true; if (page === "local" && !localSeen) { localSeen = true; scanLocal() } }
    onVisibilityChanged: (v) => {
        Theme.windowActive = v !== Window.Minimized && v !== Window.Hidden
        if (!Theme.windowActive) backend.trimMemory()
    }
    // give memory back: shortly after start, and every half minute when nothing is moving
    Timer { running: true; interval: 400; onTriggered: backend.styleWindow() }
    Timer { running: true; interval: 4000; onTriggered: backend.trimMemory() }
    Timer { running: !win.immersive; interval: 30000; repeat: true; onTriggered: backend.trimMemory() }

    function fmt(s) { s = Math.max(0, Math.floor(s)); return Math.floor(s / 60) + ":" + ("0" + (s % 60)).slice(-2) }
    function reload() { lib = JSON.parse(backend.library()) }
    function isLiked(id) { for (var i = 0; i < lib.liked.length; i++) if (lib.liked[i].id === id) return true; return false }
    function toggleLike(t) { backend.toggleLike(JSON.stringify(t)); reload() }
    function addTo(t) { addMenu.track = t; addMenu.open() }
    function openPage(p) { page = p }
    property bool pinnedOpen: true
    property bool allOpen: false
    readonly property var pinnedList: lib.playlists.filter(function(p) { return p.pinned === true })
    function togglePin(pl) { backend.togglePin(pl.id); reload(); note = pl.pinned ? "Unpinned" : "Pinned to the sidebar" }
    function openPlaylist(pl) { shownPlaylist = pl; page = "playlist" }
    function openImport() { importPopup.open() }
    function playList(tracks, i) { queue = tracks; qi = i; startCurrent() }
    // ---- queue ----
    function playNext(t) {
        if (!cur) { playList([t], 0); return }
        var q = queue.slice(); q.splice(qi + 1, 0, t); queue = q; note = "Playing next"
    }
    function enqueue(t) {
        if (!cur) { playList([t], 0); return }
        queue = queue.concat([t]); note = "Added to queue"
    }
    function removeFromQueue(i) {
        if (i === qi || i < 0 || i >= queue.length) return
        var q = queue.slice(); q.splice(i, 1); queue = q
        if (i < qi) qi--
    }
    function clearUpNext() { if (cur) { queue = queue.slice(0, qi + 1); note = "Queue cleared" } }
    function openSleep() { sleepMenu.open() }
    function songMenuFor(t) { songMenu.track = t; songMenu.open() }
    // open the immersive player on a panel ("lyrics" | "queue" | "sleep")
    property string wantPanel: ""
    function openPanel(p) { if (immersive && imm.item) imm.item.swapPanel(p); else { wantPanel = p; immersive = true } }
    // ---- equalizer (Sound panel) ----
    readonly property var eqPresets: [{"n": "Flat", "g": [0, 0, 0, 0, 0, 0]}, {"n": "Bass Booster", "g": [7, 5.5, 2.5, 0, 0, 0]}, {"n": "Bass Reducer", "g": [-7, -5.5, -2.5, 0, 0, 0]}, {"n": "Treble Booster", "g": [0, 0, 0, 2.5, 5, 7]}, {"n": "Treble Reducer", "g": [0, 0, 0, -2.5, -5, -7]}, {"n": "Vocal Booster", "g": [-2.5, -3, 2.5, 5, 3.5, -1.5]}, {"n": "Acoustic", "g": [4.5, 3.5, 1.5, 2, 3, 3.5]}, {"n": "Classical", "g": [4.5, 3.5, 2, 0, -1.5, 3]}, {"n": "Dance", "g": [6, 4.5, 1, -1, 2, 3.5]}, {"n": "Deep", "g": [6, 4, 1.5, 1, -2, -4.5]}, {"n": "Electronic", "g": [5, 3.5, -0.5, 1, 2, 5]}, {"n": "Hip-Hop", "g": [6, 4.5, 1.5, 1.5, -1, 2]}, {"n": "Jazz", "g": [4, 3, 1, 2, 2, 3]}, {"n": "Latin", "g": [5, 2.5, 0, 0, 2.5, 5]}, {"n": "Loudness", "g": [6.5, 4, 0, 1, -2.5, 5]}, {"n": "Lounge", "g": [-3, 0.5, 2.5, 3, 1, -1.5]}, {"n": "Piano", "g": [3, 1.5, 0, 2, 3, 3]}, {"n": "Pop", "g": [-1.5, 1, 3.5, 3.5, 1, -1.5]}, {"n": "R&B", "g": [5, 5.5, 2, -1.5, 2, 3.5]}, {"n": "Rock", "g": [5, 3.5, 1, -1, 2.5, 4.5]}, {"n": "Small Speakers", "g": [5.5, 4, 2, 0, -1, -3]}, {"n": "Spoken Word", "g": [-3, -1, 3, 4.5, 3, 0]}]
    property var eqGains: [0, 0, 0, 0, 0, 0]
    readonly property string eqName: {
        for (var i = 0; i < eqPresets.length; i++) {
            var ok = true
            for (var k = 0; k < 6; k++) if (Math.abs(eqPresets[i].g[k] - eqGains[k]) > 0.05) { ok = false; break }
            if (ok) return eqPresets[i].n
        }
        return "Custom"
    }
    function setEq(g) {
        eqGains = g
        backend.setEq(JSON.stringify(g))
        eqSave.restart()
    }
    Timer { id: eqSave; interval: 600; onTriggered: win.settings = JSON.parse(backend.saveSettings(JSON.stringify({eq: win.eqGains, eqPreset: win.eqName}))) }
    // ---- daily mixes ----
    property var mixes: []
    property string mixNote: ""
    property bool mixBusy: false
    function remix(force) { mixBusy = true; backend.makeMixes(force) }
    Timer { running: !win.autotest && !win.playOnly; interval: 2500; onTriggered: win.remix(false) }
    function openMix(m) { openPlaylist({id: "", temp: true, name: m.name, tracks: m.tracks}) }
    // ---- recently played ----
    property var recent: []
    function pushRecent(t) {
        var r = [t]
        for (var i = 0; i < recent.length && r.length < 24; i++) if (recent[i].id !== t.id) r.push(recent[i])
        recent = r
        if (!autotest && !playOnly) backend.saveSettings(JSON.stringify({recent: r}))
    }
    // ---- sleep timer ----
    property real sleepEnd: 0                // ms since epoch, 0 = off
    property bool sleepAtSongEnd: false
    property real sleepFade: 1
    property int sleepLeft: 0                // seconds, for display
    readonly property bool sleepOn: sleepEnd > 0 || sleepAtSongEnd
    function setSleep(minutes) {
        sleepAtSongEnd = false; sleepFade = 1; sleepAnim.stop()
        sleepEnd = minutes > 0 ? Date.now() + minutes * 60000 : 0
        sleepLeft = minutes * 60
        note = minutes > 0 ? "Sleep timer: " + minutes + " min" : "Sleep timer off"
    }
    function sleepAfterSong() { sleepEnd = 0; sleepFade = 1; sleepAtSongEnd = true; note = "Stopping after this song" }
    NumberAnimation { id: sleepAnim; target: win; property: "sleepFade"; to: 0; duration: 12000; easing.type: Easing.InQuad }
    Timer {
        running: win.sleepEnd > 0; interval: 1000; repeat: true
        onTriggered: {
            win.sleepLeft = Math.max(0, Math.round((win.sleepEnd - Date.now()) / 1000))
            if (win.sleepLeft <= 12 && !sleepAnim.running && win.sleepFade === 1) { sleepAnim.duration = Math.max(1, win.sleepLeft) * 1000; sleepAnim.start() }
            if (win.sleepLeft <= 0) { sleepAnim.stop(); if (win.audio) win.audio.pause(); win.sleepEnd = 0; win.sleepFade = 1; win.note = "Sleep timer: paused" }
        }
    }
    function startCurrent() {
        if (qi < 0 || qi >= queue.length) return
        pushRecent(queue[qi])
        note = "Loading…"
        if (audio) audio.stop()
        backend.play(queue[qi].id)
        backend.palette(queue[qi].thumb)
        lyr = {vid: queue[qi].id, state: "loading", synced: false, lines: []}
        backend.lyrics(JSON.stringify(queue[qi]))
        if (qi + 1 < queue.length) backend.prefetch(queue[qi + 1].id)
        saveSession()
    }
    property real resumeAt: 0
    function saveSession() {
        if (!cur || autotest || playOnly) return
        var from = Math.max(0, qi - 10), to = Math.min(queue.length, qi + 90)
        backend.saveSession(JSON.stringify({queue: queue.slice(from, to), qi: qi - from, pos: position}))
    }
    Timer { running: win.playing; interval: 15000; repeat: true; onTriggered: win.saveSession() }
    onClosing: (close) => saveSession()
    function download(tracks) { if (tracks.length) { note = "Downloading…"; backend.downloadTracks(JSON.stringify(tracks)) } }
    function toggle() { if (!cur) return; if (!audio) { startCurrent(); return } playing ? audio.pause() : audio.play() }
    function seek(ms) { if (audio) audio.seekTo(ms) }
    function next() {
        if (queue.length === 0) return
        if (sleepAtSongEnd) { sleepAtSongEnd = false; note = "Sleep timer: stopped"; return }
        if (shuffle && queue.length > 1) { var n; do { n = Math.floor(Math.random() * queue.length) } while (n === qi); qi = n; startCurrent() }
        else if (qi + 1 < queue.length) { qi++; startCurrent() }
        else if (repeat) { qi = 0; startCurrent() }
        else if (settings.autoRadio && cur) startRadio(cur)
    }
    function prev() { if (position > 3000) seek(0); else if (qi > 0) { qi--; startCurrent() } }

    readonly property var api: backend
    property var settings: ({quality: "high", autoRadio: true, dynamicColor: true, reduceMotion: false, cacheLimitMB: 2048, volume: 0.8})
    property var engine: ({version: "", message: ""})
    function setSetting(k, v) {
        var p = {}; p[k] = v
        settings = JSON.parse(backend.saveSettings(JSON.stringify(p)))
        applySettings()
    }
    function applySettings() {
        Theme.reduceMotion = settings.reduceMotion
        Theme.dark = settings.themeMode !== "light"
        Theme.amoled = settings.themeMode === "amoled"
        Theme.themeId = settings.themeId
        if (settings.themeId !== "" && Theme.pal) Theme.seed = Theme.c(9)
        else if (settings.accent !== "") Theme.seed = settings.accent
        else if (!settings.dynamicColor) Theme.seed = "#b8a4f0"
        else if (cur) backend.palette(cur.thumb)
    }
    onVolumeChanged: volSave.restart()
    Timer { id: volSave; interval: 700; onTriggered: if (Math.abs(win.settings.volume - win.volume) > 0.001) win.settings = JSON.parse(backend.saveSettings(JSON.stringify({volume: win.volume}))) }
    function searchAll(q) { searching = true; found = null; backend.searchAll(q) }
    function openAlbum(a) { note = "Opening album…"; backend.albumTracks(a.browseId, a.title, a.sub.replace(/^Albums*•s*/, "").split(" • ")[0], a.thumb) }
    function playSpotify(t) { note = "Finding it on YouTube Music…"; backend.matchTrack(JSON.stringify(t)) }
    function startRadio(t) {
        if (!t) return
        if (t.id.indexOf("local:") === 0) { note = "Radio needs a song from YouTube Music"; return }
        note = "Starting radio…"; backend.radio(t.id)
    }
    function enterProfile(p, pin) {
        if (!backend.selectProfile(p.id, pin)) return false
        profile = p; reload(); if (audio) audio.stop(); queue = []; qi = -1; page = "home"; gate = false
        return true
    }
    function saveProfile(name, color) { profile = JSON.parse(backend.saveProfile(name, color)) }
    function setAvatar(path) { var r = JSON.parse(backend.setAvatar(path)); if (r.ok) profile = r.profile; else note = r.error }
    function clearAvatar() { profile = JSON.parse(backend.clearAvatar()) }
    function pickImage() { fd.active = true; fd.item.pickImage() }
    function addProfile(name, color, pin) { var r = JSON.parse(backend.createProfile(name, color, pin)); if (!r.ok) return r.error; profiles = r.profiles; return "" }
    function removeProfile(p, pin) { var r = JSON.parse(backend.deleteProfile(p.id, pin)); if (!r.ok) return r.error; profiles = r.profiles; return "" }

    Component.onCompleted: {
        settings = JSON.parse(backend.settings())
        volume = settings.volume
        recent = settings.recent || []
        if (settings.eq && settings.eq.length === 6) { eqGains = settings.eq; backend.setEq(JSON.stringify(settings.eq)) }
        Theme.reduceMotion = settings.reduceMotion
        if (!autotest) backend.checkEngine(false)
        applySettings()
        profile = JSON.parse(backend.profileInfo())
        reload()
        if (!autotest && !playOnly) {
            var s = JSON.parse(backend.loadSession())
            if (s.queue && s.queue.length > 0 && s.qi >= 0 && s.qi < s.queue.length) {
                queue = s.queue; qi = s.qi; resumeAt = s.pos || 0
                if (settings.accent === "" && settings.dynamicColor) backend.palette(cur.thumb)
            }
        }
        backend.startHotkeys()
    }

    // visualizer: poll the analysed spectrum at the playback position while the immersive player is open
    Timer {
        interval: 33; repeat: true
        running: win.immersive && win.playing && win.cur !== null
        onTriggered: {
            var s = backend.bands(win.cur.id, win.rawPosition)
            if (s === "") return
            var a = s.split(","), b = win.bands.length === 48 ? win.bands.slice() : new Array(48).fill(0)
            for (var i = 0; i < 48; i++) b[i] = Math.max(a[i] / 255, b[i] * 0.85)
            win.bands = b
            function avg(lo, hi) { var t = 0; for (var k = lo; k < hi; k++) t += b[k]; return t / (hi - lo) }
            win.energy = Qt.vector4d(avg(0, 5), avg(5, 11), avg(11, 17), avg(17, 32))
        }
    }
    onNoteChanged: if (note !== "" && note !== "Loading…") noteTimer.restart()
    Timer { id: noteTimer; interval: 4000; onTriggered: if (win.note !== "Loading…") win.note = "" }

    Backend {
        id: backend
        onSearched: json => {
            var r = JSON.parse(json)
            if (r.ok) { results = r.items; for (var i = 0; i < Math.min(3, r.items.length); i++) backend.prefetch(r.items[i].id) } else note = r.error
        }
        onPlayReady: (vid, url) => { if (cur && cur.id === vid) { eng.active = true; eng.item.load(vid); note = ""; if (resumeAt > 0) { eng.item.seekTo(resumeAt); resumeAt = 0 } } }
        onPlayFailed: (vid, message) => { if (cur && cur.id === vid) note = message }
        onSearchedAll: (query, json) => { searching = false; found = JSON.parse(json); var s = found.songs; for (var i = 0; i < Math.min(3, s.length); i++) backend.prefetch(s[i].id) }
        onAlbumReady: json => { var r = JSON.parse(json); note = ""; if (!r.ok) { note = r.error; return } shownPlaylist = {id: "", temp: true, name: r.title, tracks: r.tracks}; page = "playlist" }
        onMatched: json => { var r = JSON.parse(json); if (r.ok) { note = ""; playList([r.track], 0) } else note = r.error }
        onRadioReady: (vid, json) => {
            var r = JSON.parse(json)
            if (!r.ok || r.items.length === 0) { note = r.error || "No radio for this song"; return }
            var items = r.items
            if (cur && cur.id === items[0].id) { queue = items; qi = 0; note = "Radio" }
            else { playList(items, 0); note = "Radio" }
        }
        onLyricsReady: (vid, json) => {
            if (!cur || cur.id !== vid) return
            var r = JSON.parse(json)
            lyr = {vid: vid, state: r.lines.length ? "ready" : "none", synced: r.synced, lines: r.lines}
        }
        onHotkey: action => {
            if (action === "playpause") toggle()
            else if (action === "next") next()
            else if (action === "prev") prev()
            else if (action === "volup") volume = Math.min(1, volume + 0.05)
            else if (action === "voldown") volume = Math.max(0, volume - 0.05)
            else if (action === "like" && cur) toggleLike(cur)
        }
        onDownloadProgress: (done, total, message) => note = message
        onPaletteReady: (url, color) => {
            
            if (win.settings.dynamicColor && win.settings.accent === "" && win.settings.themeId === "" && cur && cur.thumb === url) Theme.seed = color
        }
        onSwatchesReady: (url, json) => { if (autotest) console.log("AUTOTEST swatches " + json); if (cur && cur.thumb === url) Theme.swatches = JSON.parse(json) }
        onExportifyFiles: json => { var f = JSON.parse(json); note = "Importing " + f.length + (f.length === 1 ? " playlist" : " playlists") + "…"; for (var i = 0; i < f.length; i++) backend.importFile(f[i]) }
        onMixesReady: json => { var r = JSON.parse(json); mixBusy = false; if (r.ok) { mixes = r.mixes; mixNote = "" } else mixNote = r.error }
        onLocalReady: json => { var r = JSON.parse(json); localTracks = r.tracks; scanning = false; if (r.tracks.length) note = r.tracks.length + " local songs" }
        onUpdateChecked: json => {
            var r = JSON.parse(json); update = r; if (autotest) console.log("AUTOTEST update " + json)
            updateMsg = !r.ok ? r.error : (r.available ? "" : (r.none ? "No releases have been published yet" : "You are up to date (" + r.current + ")"))
        }
        onUpdateProgress: pct => updatePct = pct
        onUpdateDownloaded: json => {
            var r = JSON.parse(json); updatePct = -1
            if (r.ok) { if (backend.launchInstaller()) Qt.quit(); else updateMsg = "Could not start the installer" }
            else updateMsg = r.error
        }
        onEngineStatus: json => engine = JSON.parse(json)
        onImportProgress: (done, total) => importFrac = done / total
        onImportDone: json => {
            importFrac = -1
            var r = JSON.parse(json)
            if (r.ok) {
                reload()
                note = r.total ? "Imported " + r.found + " of " + r.total + " songs" : "Imported"
                if (r.playlist && r.playlist.id) openPlaylist(r.playlist)
                importPopup.close()
            } else note = r.error
        }
    }

    // the media stack is loaded on the first play
    Loader { id: eng; active: false; sourceComponent: Component { AudioEngine { api: backend; fast: win.immersive } } }
    Binding { target: eng.item; property: "volume"; value: win.volume * win.sleepFade; when: eng.item !== null }
    Connections {
        target: eng.item
        function onEnded() { if (win.repeat && win.queue.length === 1) { win.seek(0); win.audio.play() } else win.next() }
        function onFailed(message) { win.note = "Playback error: " + message }
    }

    // native file pickers, created on demand
    Loader { id: fd; source: "FileDialogs.qml"; active: false }
    Connections {
        target: fd.item
        function onImportPicked(path) { backend.importFile(path) }
        function onImagePicked(path) { if (win.imageFor === "cover") { win.edCover = path; win.imageFor = "avatar" } else win.setAvatar(path) }
        function onFolderPicked(path) { var s = JSON.parse(backend.addLocalFolder(path)); win.scanLocal() }
        function onSavePicked(path) { win.note = backend.exportFile(win.shownPlaylist.id, path) ? "Saved" : "Could not save" }
    }
    function pickImport() { fd.active = true; fd.item.pickImport() }
    function saveShareFile() { fd.active = true; fd.item.pickSave() }

    TextEdit { id: clip; visible: false }

    // ---- shell ----
    Item {
        id: shell
        anchors.fill: parent; anchors.topMargin: 36
        Rectangle { anchors.fill: parent; color: Theme.background }

        // sidebar
        Column {
            id: side
            x: 14; y: 14
            width: 262
            height: parent.height - 28
            spacing: 4

            NavItem { width: parent.width; icon: Theme.home; text: "Home"; selected: win.page === "home"; onClicked: win.page = "home" }
            NavItem { width: parent.width; icon: Theme.search; text: "Search"; selected: win.page === "search"; onClicked: { win.page = "search"; searchView.focusSearch() } }
            Item { width: 1; height: 8 }
            RowLayout {
                width: parent.width; spacing: 10
                Item { Layout.preferredWidth: 2 }
                Text { text: "Library"; color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 13; font.weight: Font.DemiBold }
                Squiggle { Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter }
                Item { Layout.preferredWidth: 10 }
            }
            NavItem { width: parent.width; icon: "music_note"; text: "Songs"; selected: win.page === "songs"; onClicked: win.page = "songs" }
            NavItem { width: parent.width; icon: "folder_open"; text: "Local Files"; selected: win.page === "local"; onClicked: win.page = "local" }
            NavItem { width: parent.width; icon: Theme.heart; text: "Liked songs"; trailing: win.lib.liked.length; selected: win.page === "liked"; onClicked: win.page = "liked" }
            Item { width: 1; height: 8 }
            RowLayout {
                width: parent.width; spacing: 6
                Item { Layout.preferredWidth: 2 }
                Text { text: "Playlists"; color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 13; font.weight: Font.DemiBold }
                Squiggle { Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter }
                IconButton { icon: Theme.add; size: 32; iconSize: 15; ink: Theme.primary; onClicked: win.openEditor(null) }
                IconButton { icon: Theme.import_; size: 32; iconSize: 15; ink: Theme.primary; onClicked: importPopup.open() }
                Item { Layout.preferredWidth: 4 }
            }
            NavItem { width: parent.width; icon: "file_download"; text: "Import playlist"; onClicked: importPopup.open() }
            // pinned playlists, folded away with the chevron
            NavItem {
                width: parent.width; icon: "push_pin"; text: "Pinned playlists"; chevron: true; open: win.pinnedOpen
                onClicked: win.pinnedOpen = !win.pinnedOpen
            }
            Item {
                width: parent.width
                height: win.pinnedOpen ? Math.max(win.pinnedList.length, 1) * 52 > 156 ? 156 : Math.max(win.pinnedList.length, 1) * 52 : 0
                Behavior on height { NumberAnimation { duration: Theme.normal; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } }
                opacity: win.pinnedOpen ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.quick } }
                clip: true
                Text { visible: win.pinnedList.length === 0; x: 16; y: 14; text: "Right-click a playlist to pin it"; color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 13 }
                ListView {
                    anchors.fill: parent
                    model: win.pinnedList
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: NavItem {
                        required property var modelData
                        width: ListView.view.width; height: 48
                        icon: ""; text: modelData.name; pinned: true
                        selected: win.page === "playlist" && win.shownPlaylist && win.shownPlaylist.id === modelData.id
                        onClicked: win.openPlaylist(modelData)
                        onRightClicked: win.playlistMenuFor(modelData)
                        PlaylistArt { x: 14; anchors.verticalCenter: parent.verticalCenter; width: 32; height: 32; radius: 9; pl: modelData }
                    }
                }
            }
            NavItem {
                width: parent.width; icon: "grid_view"; text: "All playlists"
                chevron: true; open: win.allOpen
                selected: win.page === "playlists"
                onClicked: { win.page = "playlists"; win.allOpen = !win.allOpen }
            }
            ListView {
                id: allView
                width: parent.width
                height: win.allOpen ? Math.max(0, Math.min(win.lib.playlists.length * 52, side.height - y - 150)) : 0
                Behavior on height { NumberAnimation { duration: Theme.normal; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } }
                opacity: win.allOpen ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.quick } }
                clip: true
                model: win.lib.playlists
                boundsBehavior: Flickable.StopAtBounds
                delegate: NavItem {
                    required property var modelData
                    width: ListView.view.width; height: 48
                    icon: ""; text: modelData.name; pinned: modelData.pinned === true
                    selected: win.page === "playlist" && win.shownPlaylist && win.shownPlaylist.id === modelData.id
                    onClicked: win.openPlaylist(modelData)
                    onRightClicked: win.playlistMenuFor(modelData)
                    PlaylistArt { x: 14; anchors.verticalCenter: parent.verticalCenter; width: 32; height: 32; radius: 9; pl: modelData }
                }
            }
        }

        // content card
        Rectangle {
            id: card
            x: side.x + side.width + 6
            y: 12
            width: parent.width - x - 12
            height: parent.height - 24
            radius: Theme.radiusLarge + 4
            color: Theme.surface
            clip: true

            // each page fades and rises into place; a hidden page costs nothing to draw
            component Page: Item {
                property bool active: false
                anchors.fill: parent
                opacity: active ? 1 : 0
                visible: opacity > 0.01
                enabled: active
                transform: Translate { y: active || !Theme.motion ? 0 : 14; Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } } }
                Behavior on opacity { NumberAnimation { duration: active ? 240 : 120; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } }
            }
            Page { active: win.page === "home"; HomeView { anchors.fill: parent; app: win } }
            Page { active: win.page === "search"; SearchView { id: searchView; anchors.fill: parent; app: win } }
            Page { active: win.page !== "home" && win.page !== "settings" && win.page !== "search"; TracksPage { id: tracksPage; anchors.fill: parent; app: win } }
            Page {
                active: win.page === "settings"
                Loader { anchors.fill: parent; active: win.settingsSeen; sourceComponent: Component { SettingsView { app: win } } }
            }
            // content fades out behind the floating player bar
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: 120
                gradient: Gradient { GradientStop { position: 0; color: "transparent" } GradientStop { position: 0.75; color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.92) } GradientStop { position: 1; color: Theme.surface } }
            }
        }

        NavItem {
            x: side.x; width: side.width
            y: parent.height - 14 - 56 - 4 - height
            icon: Theme.settingsIcon; text: "Settings"; selected: win.page === "settings"
            onClicked: win.page = "settings"
        }

        // current profile: tap to switch
        Item {
            x: side.x; width: side.width; height: 56
            y: parent.height - height - 14
            scale: chipMa.pressed ? 0.98 : 1
            Behavior on scale { NumberAnimation { duration: Theme.quick; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } }
            Rectangle { anchors.fill: parent; radius: 28; color: Theme.fg; opacity: chipMa.containsMouse ? 0.08 : 0; Behavior on opacity { NumberAnimation { duration: Theme.quick } } }
            Row {
                anchors.verticalCenter: parent.verticalCenter; x: 8; spacing: 12
                Rectangle {
                    width: 40; height: 40; radius: 20; color: win.profile ? win.profile.color : Theme.primary
                    Text { anchors.centerIn: parent; text: win.profile ? win.profile.name.charAt(0).toUpperCase() : "?"; color: "#141414"; font.family: Theme.headFont; font.pixelSize: 18; font.weight: Font.Bold }
                    Cover { anchors.fill: parent; radius: 20; visible: win.profile !== null && win.profile.avatar !== ""; source: win.profile ? win.profile.avatar : "" }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: win.profile ? win.profile.name : ""; color: Theme.fg; font.family: Theme.bodyFont; font.pixelSize: 15; font.weight: Font.DemiBold }
                    Text { text: "Your profile"; color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 12 }
                }
            }
            MouseArea { id: chipMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.page = "settings" }
        }

        PlayerBar {
            app: win
            width: Math.min(card.width - 28, 1040)
            anchors.horizontalCenter: card.horizontalCenter
            y: parent.height - height - 22
            onExpand: win.immersive = true
        }
    }

    // ---- profile picker ----
    Loader { id: gateLoader; anchors.fill: parent; z: 50; active: win.gate; sourceComponent: Component { ProfileGate { app: win; Component.onCompleted: reset() } } }

    // ---- immersive player (created when opened, destroyed after it fades out) ----
    Loader {
        id: imm
        anchors.fill: parent
        active: win.immActive
        asynchronous: true
        opacity: win.immFade
        // only while the shape moves: a window-sized layer is costly to keep
        layer.enabled: win.immReveal > 0 && win.immReveal < 1
        layer.effect: ShaderEffect {
            property variant source
            property size itemSize: Qt.size(width, height)
            property vector4d shape: { var p = win.shapeParams(win.revealShape); return Qt.vector4d(Math.min(p.x, 5 + 7), p.y, p.z, p.w) }
            property real reach: Math.max(0, win.revealReach) * Math.hypot(width, height) / 2 / (shape.w > 0.5 ? 1 : 1 - shape.y) + 2
            property real spin: win.revealSpin
            fragmentShader: "qrc:/shaders/shape_mask.frag.qsb"
        }
        sourceComponent: Component { ImmersivePlayer { app: win; onClose: win.immersive = false } }
    }
    Shortcut { sequence: "Escape"; enabled: win.immersive; onActivated: win.immersive = false }
    Shortcut { sequence: "Left"; enabled: win.immersive; onActivated: win.seek(Math.max(0, win.position - 10000)) }
    Shortcut { sequence: "Right"; enabled: win.immersive; onActivated: win.seek(win.position + 10000) }
    Shortcut { sequence: "Up"; enabled: win.immersive; onActivated: win.volume = Math.min(1, win.volume + 0.05) }
    Shortcut { sequence: "Down"; enabled: win.immersive; onActivated: win.volume = Math.max(0, win.volume - 0.05) }
    Shortcut { sequence: "Space"; enabled: !searchView.searchActive &&!edName.activeFocus && !importText.activeFocus; onActivated: win.toggle() }

    // ---- song actions ----
    Popup {
        id: songMenu
        property var track: null
        anchors.centerIn: Overlay.overlay
        modal: true; padding: 10
        enter: Transition { ParallelAnimation { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 170; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } } }
        exit: Transition { ParallelAnimation { NumberAnimation { property: "opacity"; to: 0; duration: 130; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } NumberAnimation { property: "scale"; to: 0.97; duration: 130; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } } }
        background: Rectangle { color: Theme.containerHighest; radius: Theme.radiusLarge }
        Overlay.modal: Rectangle { color: "#99000000" }
        contentItem: Column {
            spacing: 2
            Text { text: songMenu.track ? songMenu.track.title : ""; color: Theme.fg; font.family: Theme.headFont; font.pixelSize: 18; font.weight: Font.Bold; leftPadding: 8; bottomPadding: 8; topPadding: 4; elide: Text.ElideRight; width: 300 }
            NavItem { width: 300; icon: "skip_next"; text: "Play next"; onClicked: { win.playNext(songMenu.track); songMenu.close() } }
            NavItem { width: 300; icon: "queue_music"; text: "Add to queue"; onClicked: { win.enqueue(songMenu.track); songMenu.close() } }
            NavItem { visible: win.page === "playlist" && win.shownPlaylist !== null && !win.shownPlaylist.temp; height: visible ? 48 : 0; width: 300; icon: "playlist_remove"; text: "Remove from this playlist"; onClicked: { songMenu.close(); backend.removeFromPlaylist(win.shownPlaylist.id, songMenu.track.id); win.reload(); win.note = "Removed" } }
            NavItem { width: 300; icon: "library_add"; text: "Add to playlist"; onClicked: { songMenu.close(); win.addTo(songMenu.track) } }
            NavItem { width: 300; icon: Theme.radio; text: "Start radio"; onClicked: { win.startRadio(songMenu.track); songMenu.close() } }
        }
    }

    // ---- sleep timer ----
    Popup {
        id: sleepMenu
        anchors.centerIn: Overlay.overlay
        modal: true; padding: 10
        enter: Transition { ParallelAnimation { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 170; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } } }
        exit: Transition { ParallelAnimation { NumberAnimation { property: "opacity"; to: 0; duration: 130; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } NumberAnimation { property: "scale"; to: 0.97; duration: 130; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } } }
        background: Rectangle { color: Theme.containerHighest; radius: Theme.radiusLarge }
        Overlay.modal: Rectangle { color: "#99000000" }
        contentItem: Column {
            spacing: 2
            Text { text: "Sleep timer"; color: Theme.fg; font.family: Theme.headFont; font.pixelSize: 18; font.weight: Font.Bold; leftPadding: 8; topPadding: 4; bottomPadding: win.sleepOn ? 0 : 8 }
            Text { visible: win.sleepOn; text: win.sleepAtSongEnd ? "Stops after this song" : "Pauses in " + win.fmt(win.sleepLeft); color: Theme.primary; font.family: Theme.bodyFont; font.pixelSize: 13; leftPadding: 8; bottomPadding: 8 }
            Repeater {
                model: [{t: "15 minutes", m: 15}, {t: "30 minutes", m: 30}, {t: "45 minutes", m: 45}, {t: "1 hour", m: 60}, {t: "2 hours", m: 120}]
                delegate: NavItem { required property var modelData; width: 300; icon: "bedtime"; text: modelData.t; onClicked: { win.setSleep(modelData.m); sleepMenu.close() } }
            }
            NavItem { width: 300; icon: "music_note"; text: "End of this song"; onClicked: { win.sleepAfterSong(); sleepMenu.close() } }
            NavItem { visible: win.sleepOn; width: 300; icon: "close"; text: "Turn off"; onClicked: { win.setSleep(0); sleepMenu.close() } }
        }
    }

    // ---- add to playlist ----
    Popup {
        id: addMenu
        property var track: null
        anchors.centerIn: Overlay.overlay
        modal: true; padding: 10
        enter: Transition { ParallelAnimation { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 170; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } } }
        exit: Transition { ParallelAnimation { NumberAnimation { property: "opacity"; to: 0; duration: 130; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } NumberAnimation { property: "scale"; to: 0.97; duration: 130; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } } }
        background: Rectangle { color: Theme.containerHighest; radius: Theme.radiusLarge }
        Overlay.modal: Rectangle { color: "#99000000" }
        contentItem: Column {
            spacing: 2
            Text { text: "Add to playlist"; color: Theme.fg; font.family: Theme.headFont; font.pixelSize: 18; font.weight: Font.Bold; leftPadding: 8; bottomPadding: 8; topPadding: 4 }
            Text { visible: win.lib.playlists.length === 0; text: "Create a playlist first (ï¼‹ in the sidebar)"; color: Theme.fgVariant; font.family: Theme.bodyFont; leftPadding: 8; bottomPadding: 6 }
            Repeater {
                model: win.lib.playlists
                delegate: NavItem {
                    required property var modelData
                    width: 300
                    icon: "library_music"; text: modelData.name; trailing: modelData.tracks.length
                    onClicked: { backend.addToPlaylist(modelData.id, JSON.stringify(addMenu.track)); win.reload(); win.note = "Added to " + modelData.name; addMenu.close() }
                }
            }
        }
    }

    // ---- updates (GitHub releases) ----
    readonly property string version: backend.appVersion()
    property var update: ({available: false})
    property int updatePct: -1               // -1 idle, 0..100 downloading
    property string updateMsg: ""
    function checkUpdate(manual) { updateMsg = manual ? "Checking…" : ""; backend.checkUpdate() }
    function installUpdate() { updatePct = 0; updateMsg = ""; backend.installUpdate() }
    Timer { running: !win.autotest && !win.playOnly && win.settings.autoUpdate === true; interval: 8000; onTriggered: win.checkUpdate(false) }
    // ---- songs and local files ----
    property var localTracks: []
    property bool scanning: false
    property bool localSeen: false
    function scanLocal() { scanning = true; backend.scanLocal() }
    function pickFolder() { fd.active = true; fd.item.pickFolder() }
    readonly property var allSongs: {
        var seen = {}, out = []
        function add(t) { if (t && t.id && !seen[t.id]) { seen[t.id] = true; out.push(t) } }
        for (var i = 0; i < lib.liked.length; i++) add(lib.liked[i])
        for (var p = 0; p < lib.playlists.length; p++) for (var k = 0; k < lib.playlists[p].tracks.length; k++) add(lib.playlists[p].tracks[k])
        for (var r2 = 0; r2 < recent.length; r2++) add(recent[r2])
        return out
    }
    // ---- create / edit a playlist (Swiftify's PlaylistEditor) ----
    property string edId: ""
    property string edCover: ""          // "" keep | "none" | "design:N" | an image path
    property var edPlaylist: null
    property string imageFor: "avatar"
    readonly property var designColors: [["#7c5cff", "#3a2a9e"], ["#ff6b9d", "#9e2a5c"], ["#ffb347", "#b3541e"], ["#3ddc97", "#1b7a57"], ["#4cc9f0", "#2a5fa8"], ["#c77dff", "#5a2a8a"]]
    function openEditor(pl) {
        edPlaylist = pl; edId = pl ? pl.id : ""; edCover = ""
        edName.text = pl ? pl.name : ""; edDesc.text = pl ? (pl.desc || "") : ""
        playlistEditor.open(); edName.forceActiveFocus()
    }
    function saveEditor() {
        var name = edName.text.trim()
        if (!name) { edName.forceActiveFocus(); return }
        var r = JSON.parse(backend.savePlaylist(edId, name, edDesc.text, edCover))
        if (!r.ok) { note = r.error; return }
        var creating = edId === ""
        reload(); playlistEditor.close()
        if (creating) openPlaylist(r.playlist)
        else if (shownPlaylist && shownPlaylist.id === r.playlist.id) shownPlaylist = r.playlist
    }
    function pickCover() { imageFor = "cover"; pickImage() }
    Popup {
        id: playlistEditor
        anchors.centerIn: Overlay.overlay
        modal: true; padding: 24; width: 460
        enter: Transition { ParallelAnimation { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 170; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } } }
        exit: Transition { ParallelAnimation { NumberAnimation { property: "opacity"; to: 0; duration: 130 } NumberAnimation { property: "scale"; to: 0.97; duration: 130 } } }
        background: Rectangle { color: Theme.containerHighest; radius: Theme.radiusLarge }
        Overlay.modal: Rectangle { color: "#99000000" }
        contentItem: Column {
            spacing: 14
            Row {
                spacing: 12
                Rectangle {
                    width: 44; height: 44; radius: 22; color: Theme.primaryContainer
                    Text { anchors.centerIn: parent; text: "queue_music"; color: Theme.fgPrimaryContainer; font.family: Theme.iconFont; renderType: Text.NativeRendering; font.pixelSize: 24 }
                }
                Text { anchors.verticalCenter: parent.verticalCenter; text: win.edId === "" ? "New Playlist" : "Edit Playlist"; color: Theme.fg; font.family: Theme.headFont; font.pixelSize: 24; font.weight: Font.Bold }
            }
            // cover: a photo, or one of the designs
            ListView {
                id: covers
                width: parent.width; height: 96
                orientation: ListView.Horizontal; spacing: 12; clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: 7
                delegate: Item {
                    id: tile
                    required property int index
                    readonly property bool picked: index === 0 ? (win.edCover !== "" && win.edCover.indexOf("design:") !== 0 && win.edCover !== "none") : win.edCover === "design:" + (index - 1)
                    width: 96; height: 96
                    scale: tma.pressed ? 0.96 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.quick } }
                    Rectangle {
                        anchors.fill: parent; radius: 12
                        color: Theme.container
                        gradient: tile.index > 0 ? designGrad : null
                        Gradient { id: designGrad; GradientStop { position: 0; color: tile.index > 0 ? win.designColors[tile.index - 1][0] : "#000" } GradientStop { position: 1; color: tile.index > 0 ? win.designColors[tile.index - 1][1] : "#000" } }
                        Column {
                            visible: tile.index === 0 && !tile.picked
                            anchors.centerIn: parent; spacing: 4
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "add_photo_alternate"; color: Theme.fgVariant; font.family: Theme.iconFont; renderType: Text.NativeRendering; font.pixelSize: 26 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Photo"; color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 12 }
                        }
                        Cover { visible: tile.index === 0 && tile.picked; anchors.fill: parent; radius: 12; source: tile.index === 0 && tile.picked ? win.edCover : "" }
                        Text { visible: tile.index > 0; anchors.centerIn: parent; text: edName.text.trim() ? edName.text.trim().charAt(0).toUpperCase() : "♪"; color: "#d9ffffff"; font.family: Theme.headFont; font.weight: Font.Bold; font.pixelSize: 44 }
                    }
                    Rectangle { anchors.fill: parent; radius: 12; color: "transparent"; border.width: 3; border.color: tile.picked ? Theme.primary : "transparent"; Behavior on border.color { ColorAnimation { duration: Theme.quick } } }
                    MouseArea { id: tma; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (tile.index === 0) win.pickCover(); else win.edCover = "design:" + (tile.index - 1) } }
                }
            }
            TextField {
                id: edName
                width: parent.width; height: 48
                placeholderText: "Name"; color: Theme.fg; placeholderTextColor: Theme.fgVariant
                font.family: Theme.bodyFont; font.pixelSize: 15; leftPadding: 18; maximumLength: 80
                background: Rectangle { radius: 24; color: Theme.container; border.width: edName.activeFocus ? 2 : 0; border.color: Theme.primary }
                onAccepted: win.saveEditor()
            }
            TextField {
                id: edDesc
                width: parent.width; height: 48
                placeholderText: "Description (optional)"; color: Theme.fg; placeholderTextColor: Theme.fgVariant
                font.family: Theme.bodyFont; font.pixelSize: 15; leftPadding: 18; maximumLength: 300
                background: Rectangle { radius: 24; color: Theme.container; border.width: edDesc.activeFocus ? 2 : 0; border.color: Theme.primary }
                onAccepted: win.saveEditor()
            }
            Row {
                layoutDirection: Qt.RightToLeft; width: parent.width; spacing: 8
                PillButton { text: win.edId === "" ? "Create" : "Save"; variant: "filled"; enabled: edName.text.trim().length > 0; onClicked: win.saveEditor() }
                PillButton { text: "Cancel"; variant: "text"; onClicked: playlistEditor.close() }
            }
        }
    }

    // ---- delete a playlist ----
    property var delPlaylist: null
    function askDelete(pl) { delPlaylist = pl; deletePopup.open() }
    Popup {
        id: deletePopup
        anchors.centerIn: Overlay.overlay
        modal: true; padding: 24; width: 400
        enter: Transition { ParallelAnimation { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 170 } NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: 260; easing.type: Easing.OutCubic } } }
        exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 120 } }
        background: Rectangle { color: Theme.containerHighest; radius: Theme.radiusLarge }
        Overlay.modal: Rectangle { color: "#99000000" }
        contentItem: Column {
            spacing: 14
            Rectangle { width: 48; height: 48; radius: 24; color: Theme.primaryContainer; Text { anchors.centerIn: parent; text: "delete"; color: Theme.fgPrimaryContainer; font.family: Theme.iconFont; renderType: Text.NativeRendering; font.pixelSize: 26 } }
            Text { width: parent.width; text: "Delete \u201c" + (win.delPlaylist ? win.delPlaylist.name : "") + "\u201d?"; color: Theme.fg; font.family: Theme.headFont; font.pixelSize: 22; font.weight: Font.Bold; wrapMode: Text.Wrap }
            Text { width: parent.width; text: "This deletes the playlist from Cloudify. The songs themselves are not touched."; color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 14; wrapMode: Text.Wrap }
            Row {
                layoutDirection: Qt.RightToLeft; width: parent.width; spacing: 8
                PillButton {
                    text: "Delete Playlist"; variant: "filled"
                    onClicked: {
                        backend.deletePlaylist(win.delPlaylist.id); win.reload()
                        if (win.shownPlaylist && win.shownPlaylist.id === win.delPlaylist.id) { win.shownPlaylist = null; win.page = "playlists" }
                        deletePopup.close(); win.note = "Playlist deleted"
                    }
                }
                PillButton { text: "Cancel"; variant: "text"; onClicked: deletePopup.close() }
            }
        }
    }

    // ---- right-click menu of a playlist ----
    property var menuPl: null
    function playlistMenuFor(pl) { menuPl = pl; plMenu.open() }
    Popup {
        id: plMenu
        anchors.centerIn: Overlay.overlay
        modal: true; padding: 10
        enter: Transition { ParallelAnimation { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 170 } NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: 260; easing.type: Easing.OutCubic } } }
        exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 110 } }
        background: Rectangle { color: Theme.containerHighest; radius: Theme.radiusLarge }
        Overlay.modal: Rectangle { color: "#99000000" }
        contentItem: Column {
            spacing: 2
            Text { text: win.menuPl ? win.menuPl.name : ""; color: Theme.fg; font.family: Theme.headFont; font.pixelSize: 18; font.weight: Font.Bold; leftPadding: 8; bottomPadding: 8; topPadding: 4; elide: Text.ElideRight; width: 280 }
            NavItem { width: 280; icon: "push_pin"; text: win.menuPl && win.menuPl.pinned === true ? "Unpin Playlist" : "Pin Playlist"; onClicked: { plMenu.close(); win.togglePin(win.menuPl) } }
            NavItem { width: 280; icon: "edit"; text: "Edit Playlist"; onClicked: { plMenu.close(); win.openEditor(win.menuPl) } }
            NavItem { width: 280; icon: "delete"; text: "Delete Playlist"; onClicked: { plMenu.close(); win.askDelete(win.menuPl) } }
        }
    }

    // ---- Exportify opens in its own in-app window; what it exports is imported by itself ----
    Popup {
        id: importPopup
        anchors.centerIn: Overlay.overlay
        modal: true; padding: 22; width: 520
        enter: Transition { ParallelAnimation { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 170; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } } }
        exit: Transition { ParallelAnimation { NumberAnimation { property: "opacity"; to: 0; duration: 130; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } NumberAnimation { property: "scale"; to: 0.97; duration: 130; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } } }
        background: Rectangle { color: Theme.containerHighest; radius: Theme.radiusLarge }
        Overlay.modal: Rectangle { color: "#99000000" }
        contentItem: Column {
            spacing: 12
            Text { text: "Import a playlist"; color: Theme.fg; font.family: Theme.headFont; font.pixelSize: 22; font.weight: Font.Bold }
            Text { text: "Paste a share code, a YouTube or Spotify playlist link, or songs (one per line: Artist - Title). Or choose a CSV or a .cloud / .silva file."; color: Theme.fgVariant; font.family: Theme.bodyFont; font.pixelSize: 14; wrapMode: Text.Wrap; width: parent.width }
            ScrollView {
                width: parent.width; height: 130
                TextArea {
                    id: importText
                    wrapMode: TextEdit.Wrap; color: Theme.fg; placeholderText: "Paste here"; placeholderTextColor: Theme.fgVariant
                    font.family: Theme.bodyFont; font.pixelSize: 14; padding: 14
                    background: Rectangle { radius: 18; color: Theme.container; border.width: importText.activeFocus ? 2 : 0; border.color: Theme.primary }
                }
            }
            TextField {
                id: importName
                width: parent.width; height: 44
                placeholderText: "Playlist name (optional)"; color: Theme.fg; placeholderTextColor: Theme.fgVariant
                font.family: Theme.bodyFont; font.pixelSize: 14; leftPadding: 18
                background: Rectangle { radius: 22; color: Theme.container; border.width: importName.activeFocus ? 2 : 0; border.color: Theme.primary }
            }
            Rectangle { visible: win.importFrac >= 0; width: parent.width; height: 6; radius: 3; color: Theme.secondaryContainer
                Rectangle { width: parent.width * Math.max(0, win.importFrac); height: parent.height; radius: 3; color: Theme.primary } }
            // the way in from elsewhere on the left, the decision on the right
            Item {
                width: parent.width; height: 48
                Row {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                    PillButton { text: "Choose file"; icon: "folder_open"; onClicked: win.pickImport() }
                    PillButton { text: "Spotify"; icon: "graphic_eq"; onClicked: { importPopup.close(); backend.exportifyOpen(); win.note = "Log in, then press Export All" } }
                }
                Row {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                    PillButton { text: "Cancel"; variant: "text"; onClicked: importPopup.close() }
                    PillButton {
                        implicitWidth: 120
                        text: win.importFrac >= 0 ? "Importing…" : "Import"; icon: "file_download"; variant: "filled"; enabled: win.importFrac < 0 && importText.text.trim().length > 0
                    onClicked: {
                        var t = importText.text.trim()
                        if (!t) return
                        if (t.indexOf("CLOUD-") >= 0 || t.indexOf("SILVA-") >= 0) {
                            var r = JSON.parse(backend.importCode(t))
                            if (r.ok) { win.reload(); win.openPlaylist(r.playlist); importPopup.close(); win.note = "Imported" } else win.note = r.error
                        } else if (/(youtube\.com|youtu\.be)\//i.test(t)) { importFrac = 0; backend.importLink(t.split(/\s+/)[0], importName.text) }
                        else if (/spotify\.com\//i.test(t) && t.indexOf("\n") < 0) { importFrac = 0; backend.importSpotify(t.split(/\s+/)[0], importName.text) }
                        else backend.importText(t, importName.text)
                    }
                    }
                }
            }
        }
    }

    function copyShareCode() { clip.text = backend.exportCode(shownPlaylist.id); clip.selectAll(); clip.copy(); note = "Share code copied" }
    function search(q) { backend.search(q) }

    // `cloud-music --autotest [--shots=prefix]`: search, play, grab screenshots, report, quit
    property var testLiked: []
    readonly property bool autotest: Qt.application.arguments.indexOf("--autotest") >= 0
    // `--play` : search, play the first hit and keep running (for memory measurements)
    readonly property bool playOnly: Qt.application.arguments.indexOf("--play") >= 0
    Timer { running: playOnly; interval: 800; onTriggered: backend.search("daft punk get lucky") }
    Connections {
        target: backend
        enabled: playOnly
        function onSearched(json) { var r = JSON.parse(json); if (r.ok && r.items.length) win.playList(r.items, 0) }
    }
    readonly property string shots: { var a = Qt.application.arguments; for (var i = 0; i < a.length; i++) if (a[i].indexOf("--shots=") === 0) return a[i].substring(8); return "" }
    function shot(name) { if (shots) ((name.indexOf("immersive") === 0 || name === "reveal") ? imm : shell).grabToImage(function(r) { r.saveToFile(shots + name + ".png") }) }
    Timer { running: autotest; interval: 600; onTriggered: { backend.search("daft punk get lucky"); var pa = Qt.application.arguments.filter(function(a) { return a.indexOf("--palette=") === 0 })[0]; if (pa) backend.palette(pa.substring(10)) } }
    Timer { id: t1; interval: 9000; onTriggered: { win.shot("home"); t2.start() } }
    Timer { id: t2; interval: 1200; onTriggered: { win.page = "search"; searchView.run("drake"); t3.interval = 5000; t3.start() } }
    Timer { id: t3; interval: 900; onTriggered: { win.shot("search"); win.immersive = true; revealShot.start(); t4.start() } }
    Timer { id: revealShot; interval: 330; onTriggered: { console.log("AUTOTEST reveal=" + win.immReveal + " reach=" + win.revealReach + " anim=" + openMotion.running); win.shot("reveal") } }
    Timer { id: t4; interval: 1500; onTriggered: { win.shot("immersive"); if (imm.item) imm.item.swapPanel("lyrics"); p1.start() } }
    Timer { id: p1; interval: 1500; onTriggered: { win.shot("immersive_lyrics"); if (imm.item) imm.item.swapPanel("queue"); p2.start() } }
    Timer { id: p2; interval: 1300; onTriggered: { win.shot("immersive_queue"); p2b.start() } }
    Timer { id: p2b; interval: 600; onTriggered: { if (imm.item) imm.item.swapPanel("sound"); win.setEq(win.eqPresets[19].g); p3.start() } }
    Timer { id: p3; interval: 1300; onTriggered: { console.log("AUTOTEST eq name=" + win.eqName + " gains=" + win.eqGains.join(",")); win.shot("immersive_sound"); p3b.start() } }
    Timer { id: p3b; interval: 600; onTriggered: { win.setEq([0, 0, 0, 0, 0, 0]); if (imm.item) imm.item.swapPanel(""); t5.start() } }
    Timer { id: updTest; running: win.autotest; interval: 3000; onTriggered: win.checkUpdate(true) }
    Timer { id: t5; interval: 800; onTriggered: { win.download([win.cur]); win.pinSetup(); t6.start() } }
    function pinSetup() {
        var cr = JSON.parse(backend.savePlaylist("", "Road Trip", "Songs for long drives with the windows down", "design:2")); reload()
        var pl = lib.playlists.filter(function(p) { return p.name === "Road Trip" })[0]
        if (!pl) return
        backend.savePlaylist("", "Late Night", "", ""); reload()
        for (var i = 0; i < 3 && i < queue.length; i++) backend.addToPlaylist(pl.id, JSON.stringify(queue[i]))
        backend.togglePin(pl.id); reload()
        immersive = false; page = "home"; allOpen = true; homeShot.start()
    }
    Timer { id: homeShot; interval: 1800; onTriggered: { win.shot("home2"); win.page = "playlists"; gridShot.start() } }
    Timer { id: gridShot; interval: 1200; onTriggered: { win.shot("grid"); gridNav.start() } }
    Timer { id: gridNav; interval: 500; onTriggered: { win.openPlaylist(win.lib.playlists.filter(function(p) { return p.name === "Road Trip" })[0]); plShot.start() } }
    Timer { id: plShot; interval: 1500; onTriggered: { win.shot("playlist"); win.openEditor(win.shownPlaylist); edShot.start() } }
    Timer { id: edShot; interval: 700; onTriggered: { win.shot("editor"); playlistEditor.close(); win.page = "local"; localShot.start() } }
    Timer { id: localShot; interval: 3500; onTriggered: { win.shot("local"); console.log("AUTOTEST local tracks=" + win.localTracks.length + " first=" + (win.localTracks.length ? win.localTracks[0].title + " / " + win.localTracks[0].artist : "")); win.page = "songs"; songsShot.start() } }
    Timer { id: songsShot; interval: 900; onTriggered: { win.shot("songs"); win.page = "playlists"; importPopup.open(); impShot.start() } }
    Timer { id: impShot; interval: 900; onTriggered: { if (win.shots) importPopup.contentItem.parent.grabToImage(function(r) { r.saveToFile(win.shots + "import.png") }); impClose.start() } }
    Timer { id: impClose; interval: 500; onTriggered: { importPopup.close(); win.page = "home" } }
    Timer {
        id: t6; interval: 7000
        onTriggered: {
            var b = backend.bands(win.cur.id, 20000).split(",")
            console.log("AUTOTEST bands=" + b.length + " sample=" + b.slice(0, 12).join(" ") + " max=" + Math.max.apply(null, b.map(Number)))
            var c = JSON.parse(backend.createProfile("Test", "#ffffff", "1234"))
            var id = c.profiles[c.profiles.length - 1].id
            console.log("AUTOTEST profile created=" + c.ok + " count=" + c.profiles.length + " locked=" + c.profiles[c.profiles.length - 1].locked)
            console.log("AUTOTEST wrongPin=" + backend.selectProfile(id, "0000") + " rightPin=" + backend.selectProfile(id, "1234"))
            console.log("AUTOTEST deleteWrong=" + JSON.parse(backend.deleteProfile(id, "0000")).ok + " deleteRight=" + JSON.parse(backend.deleteProfile(id, "1234")).ok)
            backend.selectProfile(win.profile.id, "")
            backend.radio(win.cur.id)
            t7.start()
        }
    }
    Timer {
        id: t7; interval: 5000
        onTriggered: {
            console.log("AUTOTEST queue=" + queue.length + " note=" + note + " pos=" + position + " state=" + playing + " seed=" + Theme.seed + " settings=" + JSON.stringify(settings))
            var q0 = queue.length, t0 = queue[qi + 2]
            playNext({id: "zzz1", title: "NextTest", artist: "a", dur: 1, thumb: ""}); enqueue({id: "zzz2", title: "EndTest", artist: "a", dur: 1, thumb: ""})
            console.log("AUTOTEST queue add: len " + q0 + "->" + queue.length + " next=" + queue[qi + 1].id + " last=" + queue[queue.length - 1].id)
            removeFromQueue(qi + 1); console.log("AUTOTEST queue remove: len=" + queue.length + " next=" + (queue[qi + 1].id !== "zzz1"))
            setSleep(15); console.log("AUTOTEST sleep on=" + sleepOn + " left=" + sleepLeft); setSleep(0); console.log("AUTOTEST sleep off=" + !sleepOn)
            console.log("AUTOTEST recent=" + recent.length + " first=" + (recent.length ? recent[0].title : ""))
            testLiked = []; for (var li = 0; li < 4 && li < queue.length; li++) if (!isLiked(queue[li].id)) { testLiked.push(queue[li]); toggleLike(queue[li]) }
            remix(true)
            if (shots !== "") backend.exportifyOpen()
            setSetting("quality", "low"); console.log("AUTOTEST quality=" + settings.quality); setSetting("quality", "high")
            setSetting("cacheLimitMB", 1); console.log("AUTOTEST limitClamped=" + settings.cacheLimitMB); setSetting("cacheLimitMB", 2048)
            console.log("AUTOTEST cache=" + backend.cacheInfo())
            backend.importLink("https://www.youtube.com/playlist?list=PLFgquLnL59alCl_2TQvOiD5Vgm1hCaGSI", "Link test")
            backend.checkEngine(true)
            seek(150000)
            setSetting("themeId", "tokyonight"); themeBack.start()
            backend.importSpotify("https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M", "Spotify test")
            win.immersive = false; win.page = "settings"; settingsShot.start()
            t8.start()
        }
    }
    Timer { id: themeBack; interval: 2500; onTriggered: win.setSetting("themeId", "") }
    Timer { id: settingsShot; interval: 1500; onTriggered: win.shot("settings") }
    Timer {
        id: t8; interval: 30000
        onTriggered: {
            reload()
            lib.playlists.filter(function(p) { return p.name === "Road Trip" || p.name === "Late Night" }).forEach(function(p) { backend.deletePlaylist(p.id) }); reload()
            var pls = lib.playlists.filter(function(p) { return p.name === "Link test" })
            console.log("AUTOTEST link playlists=" + pls.length + " tracks=" + (pls.length ? pls[0].tracks.length : 0) + " first=" + (pls.length ? pls[0].tracks[0].title + " / " + pls[0].tracks[0].artist + " / " + pls[0].tracks[0].thumb : ""))
            if (pls.length) backend.deletePlaylist(pls[0].id)
            var sp = lib.playlists.filter(function(p) { return p.name === "Spotify test" || p.name.indexOf("Top") >= 0 })
            console.log("AUTOTEST spotify playlists=" + sp.length + " tracks=" + (sp.length ? sp[0].tracks.length : 0) + " name=" + (sp.length ? sp[0].name : "") + " first=" + (sp.length ? sp[0].tracks[0].title + " / " + sp[0].tracks[0].artist : "") + " note=" + note)
            for (var k = 0; k < sp.length; k++) backend.deletePlaylist(sp[k].id)
            console.log("AUTOTEST afterSeek pos=" + position + " dur=" + duration + " playing=" + playing)
            console.log("AUTOTEST engine=" + JSON.stringify(engine) + " seed=" + Theme.seed + " cur=" + (cur ? cur.thumb : ""))
            for (var ui = 0; ui < testLiked.length; ui++) if (isLiked(testLiked[ui].id)) toggleLike(testLiked[ui])
            Qt.quit()
        }
    }
    Connections {
        target: backend
        enabled: autotest
        function onMixesReady(json) { var r = JSON.parse(json); console.log("AUTOTEST mixes ok=" + r.ok + (r.ok ? " n=" + r.mixes.length + " sizes=" + r.mixes.map(function(m) { return m.tracks.length }).join(",") + " first=" + r.mixes[0].name + " / " + r.mixes[0].desc : " err=" + r.error)) }
        function onSearched(json) { var r = JSON.parse(json); console.log("AUTOTEST results=" + r.items.length); win.playList(r.items, 0); t1.start() }
    }
}
