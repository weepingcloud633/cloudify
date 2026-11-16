import QtQuick

// Album art with rounded or scalloped edges (Swiftify's rounded_image.frag).
Item {
    id: r
    property string source: ""
    property real radius: 16
    property real waviness: 0          // scallop depth in px; 0 = plain rounded
    property real ringWaves: 0         // >0 makes the edge a wavy circle
    property real ringAmplitude: 0
    property color ringColor: Theme.primary
    property real spin: 0
    readonly property bool ready: img.status === Image.Ready
    // ask for a size that suits where it is shown: music thumbnails come in whatever size the list used
    readonly property int px: Math.min(1024, Math.max(256, Math.ceil(Math.max(width, height) * 2 / 256) * 256))
    function sharp(u) {
        if (u.indexOf("googleusercontent.com") >= 0 || u.indexOf("ggpht.com") >= 0)
            return u.replace(/=w\d+-h\d+/, "=w" + px + "-h" + px).replace(/=s\d+/, "=s" + px)
        if (u.indexOf("i.ytimg.com") >= 0) return u.replace(/\/(default|mqdefault)\.jpg/, "/hqdefault.jpg")
        return u
    }

    Image {
        id: img
        visible: false
        source: r.sharp(r.source)
        sourceSize.width: Math.max(64, Math.ceil(r.width * Screen.devicePixelRatio / 64) * 64)
        sourceSize.height: Math.max(64, Math.ceil(r.height * Screen.devicePixelRatio / 64) * 64)
        asynchronous: true
        cache: true
    }
    Rectangle { anchors.fill: parent; radius: r.radius; color: Theme.containerHigh; visible: !r.ready }
    ShaderEffect {
        anchors.fill: parent
        visible: r.ready
        opacity: r.ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.normal; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curve } }
        property var source: img
        property size itemSize: Qt.size(width, height)
        property real radius: r.radius
        property real borderWidth: 0
        property color borderColor: "transparent"
        property size uvScale: r.source.indexOf("i.ytimg.com") >= 0 ? Qt.size(0.5625, 0.75) : Qt.size(1, 1)
        property size uvOffset: r.source.indexOf("i.ytimg.com") >= 0 ? Qt.size(0.21875, 0.125) : Qt.size(0, 0)
        property real waviness: r.waviness
        property real wavelength: 14
        property real phase: r.spin
        property real ringWaves: r.ringWaves
        property real ringAmplitude: r.ringAmplitude
        property real ringThickness: 0
        property real ringPhase: r.spin
        property color ringColor: r.ringColor
        property real reveal: 1
        fragmentShader: "qrc:/shaders/rounded_image.frag.qsb"
    }
}
