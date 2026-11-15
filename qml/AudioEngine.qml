import QtQuick

// Thin wrapper over the Rust audio thread. Polls its state: 4 times a second normally,
// 20 times a second while something needs fine timing (lyrics, visualizer).
Item {
    id: e
    required property var api
    property real volume: 0.8
    property bool fast: false
    property bool playing: false
    property real position: 0
    property real duration: 0
    signal ended()
    signal failed(string message)

    function load(vid) { position = 0; duration = 0; api.audioLoad(vid) }
    function play() { api.audioPlay() }
    function pause() { api.audioPause() }
    function stop() { api.audioStop(); playing = false; position = 0 }
    function seekTo(ms) { position = ms; api.audioSeek(ms) }
    onVolumeChanged: api.audioVolume(volume)
    Component.onCompleted: api.audioVolume(volume)

    Timer {
        running: true; repeat: true; interval: e.fast ? 50 : 250
        onTriggered: {
            var s = JSON.parse(e.api.audioPoll())
            if (e.playing !== s.playing) e.playing = s.playing
            if (e.position !== s.pos) e.position = s.pos
            if (e.duration !== s.dur) e.duration = s.dur
            if (s.event === "ended") e.ended()
            else if (s.event !== "") e.failed(s.event.replace(/^error:\s*/, ""))
        }
    }
}
