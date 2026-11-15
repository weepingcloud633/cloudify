import QtQuick

// The immersive player's backdrop: the cover's own palette poured into a slow fluid that swells
// with the bass (Swiftify's liquid field, shaders/liquid_backdrop.frag). Drawn small and stretched
// up, which blurs it for free. It ignores the app theme on purpose: it is the song's colour.
Item {
    id: r
    property vector4d energy: Qt.vector4d(0.1, 0.1, 0.1, 0.1)
    property real time: 37
    Timer {
        running: r.visible && Theme.windowActive && Theme.motion
        interval: 33; repeat: true
        onTriggered: r.time += 0.033
    }
    function shade(i) {
        var s = Theme.swatches
        if (s.length > 0) {
            var c = Qt.color(s[i % s.length])
            // a grey cover gives a grey backdrop: no hue, no added colour
            if (c.hslSaturation < 0.1) return Qt.hsla(0, 0, Math.max(0.08, Math.min(0.5, c.hslLightness * 0.9)), 1)
            return Qt.hsla(c.hslHue, Math.min(0.9, c.hslSaturation * 1.1 + 0.08), Math.max(0.2, Math.min(0.56, c.hslLightness)), 1)
        }
        var b = Theme.seed
        if (b.hslSaturation < 0.1) return Qt.hsla(0, 0, 0.14 + 0.06 * (i % 3), 1)
        return Qt.hsla((b.hslHue + i * 0.045) % 1, 0.45, 0.25 + 0.07 * (i % 3), 1)
    }
    Rectangle { anchors.fill: parent; color: "#020203" }
    ShaderEffect {
        id: field
        anchors.fill: parent
        property size itemSize: Qt.size(width, height)
        property real time: r.time
        property vector4d energy: r.energy
        property real lead: 0
        property color c0: r.shade(0)
        property color c1: r.shade(1)
        property color c2: r.shade(2)
        property color c3: r.shade(3)
        property color c4: r.shade(4)
        fragmentShader: "qrc:/shaders/liquid_backdrop.frag.qsb"
    }
    readonly property real sigma: 28
    readonly property real scale: Math.max(1 / 8, 2 / sigma)
    readonly property size tex: Qt.size(Math.max(1, Math.ceil(width * scale)), Math.max(1, Math.ceil(height * scale)))
    ShaderEffectSource { id: fieldTex; anchors.fill: parent; sourceItem: field; hideSource: true; visible: false; smooth: true; textureSize: r.tex }
    ShaderEffect {
        id: across
        anchors.fill: parent
        property variant source: fieldTex
        property vector2d texelStep: Qt.vector2d(1 / r.tex.width, 0)
        property real sigma: r.sigma * r.scale
        fragmentShader: "qrc:/shaders/backdrop_blur.frag.qsb"
    }
    ShaderEffectSource { id: acrossTex; anchors.fill: parent; sourceItem: across; hideSource: true; visible: false; smooth: true; textureSize: r.tex }
    ShaderEffect {
        id: down
        anchors.fill: parent
        property variant source: acrossTex
        property vector2d texelStep: Qt.vector2d(0, 1 / r.tex.height)
        property real sigma: r.sigma * r.scale
        fragmentShader: "qrc:/shaders/backdrop_blur.frag.qsb"
    }
    ShaderEffectSource { id: blurTex; anchors.fill: parent; sourceItem: down; hideSource: true; visible: false; smooth: true; textureSize: r.tex }
    ShaderEffect {
        anchors.fill: parent
        property variant source: blurTex
        fragmentShader: "qrc:/shaders/backdrop_composite.frag.qsb"
    }
}
