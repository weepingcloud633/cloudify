pragma Singleton
import QtQuick

// Tonal dark palette derived from one seed colour (the playing album art).
// Roles follow Material 3 names, as in Swiftify's Theme.
QtObject {
    id: t

    property color seed: "#b8a4f0"
    property var swatches: []              // up to five colours from the cover, for the immersive backdrop
    Behavior on seed { ColorAnimation { duration: 450; easing.type: Easing.BezierSpline; easing.bezierCurve: t.curve } }

    readonly property bool neutralSeed: seed.hslSaturation < 0.1
    readonly property real hue: seed.hslHue < 0 ? (neutralSeed ? 0 : 0.72) : seed.hslHue
    readonly property real sat: neutralSeed ? 0.06 : Math.min(0.85, Math.max(0.5, seed.hslSaturation))
    function tone(s, l) { return Qt.hsla(hue, s, l, 1) }

    property string themeId: ""
    readonly property var pal: {
        if (themeId === "") return null
        for (var i = 0; i < Themes.families.length; i++) if (Themes.families[i].id === themeId) return dark ? Themes.families[i].dark : Themes.families[i].light
        return null
    }
    function c(i) { return Qt.color(pal[i]) }
    function mixc(a, b, t) { return Qt.rgba(a.r * (1 - t) + b.r * t, a.g * (1 - t) + b.g * t, a.b * (1 - t) + b.b * t, 1) }
    function ink(col) { return (0.2126 * col.r + 0.7152 * col.g + 0.0722 * col.b) > 0.5 ? "#101010" : "#ffffff" }
    property bool dark: true
    property bool amoled: false
    function pick(d, l) { return dark ? d : l }
    readonly property color background: pal ? (amoled ? "#000000" : c(0)) : amoled ? "#000000" : pick(tone(sat * 0.62, 0.085), tone(sat * 0.5, 0.955))
    readonly property color surface: pal ? (amoled ? c(0) : c(2)) : amoled ? tone(sat * 0.5, 0.05) : pick(tone(sat * 0.58, 0.118), tone(sat * 0.4, 0.98))
    readonly property color container: pal ? c(3) : amoled ? tone(sat * 0.5, 0.09) : pick(tone(sat * 0.55, 0.16), tone(sat * 0.4, 0.93))
    readonly property color containerHigh: pal ? c(4) : amoled ? tone(sat * 0.5, 0.13) : pick(tone(sat * 0.52, 0.205), tone(sat * 0.4, 0.90))
    readonly property color containerHighest: pal ? c(5) : amoled ? tone(sat * 0.5, 0.17) : pick(tone(sat * 0.5, 0.25), tone(sat * 0.4, 0.86))
    readonly property color fg: pal ? c(6) : pick(tone(0.12, 0.93), tone(0.25, 0.10))
    readonly property color fgVariant: pal ? c(7) : pick(tone(0.10, 0.70), tone(0.15, 0.36))
    readonly property color outline: pal ? c(8) : pick(tone(0.08, 0.45), tone(0.10, 0.52))
    readonly property color outlineVariant: pal ? mixc(c(8), c(0), 0.6) : pick(tone(sat * 0.3, 0.30), tone(sat * 0.3, 0.80))
    readonly property color primary: pal ? c(9) : pick(tone(sat, 0.78), tone(sat, 0.38))
    readonly property color fgPrimary: pal ? ink(c(9)) : pick(tone(0.50, 0.14), tone(0.30, 0.98))
    readonly property color primaryContainer: pal ? mixc(c(9), c(0), dark ? 0.72 : 0.8) : pick(tone(sat * 0.55, 0.30), tone(sat * 0.7, 0.85))
    readonly property color fgPrimaryContainer: pal ? c(6) : pick(tone(0.60, 0.90), tone(0.6, 0.15))
    readonly property color secondaryContainer: pal ? c(4) : pick(tone(sat * 0.5, 0.29), tone(sat * 0.5, 0.86))
    readonly property color fgSecondaryContainer: pal ? c(6) : pick(tone(0.20, 0.90), tone(0.3, 0.15))
    readonly property color error: pal ? c(12) : "#ffb4ab"

    // shape and motion tokens
    readonly property int radiusSmall: 12
    readonly property int radiusNormal: 18
    readonly property int radiusLarge: 28
    readonly property int quick: 140     // press / hover feedback
    readonly property int normal: 220    // panels, fades
    // bundled fonts: Google Sans Flex (UI text, OFL) and Material Icons Round (icons, Apache-2.0)
    readonly property FontLoader _text: FontLoader { source: "qrc:/fonts/GoogleSansFlex-Regular.ttf" }
    readonly property FontLoader _textMedium: FontLoader { source: "qrc:/fonts/GoogleSansFlex-Medium.ttf" }
    readonly property FontLoader _textSemi: FontLoader { source: "qrc:/fonts/GoogleSansFlex-SemiBold.ttf" }
    readonly property FontLoader _textBold: FontLoader { source: "qrc:/fonts/GoogleSansFlex-Bold.ttf" }
    readonly property FontLoader _icons: FontLoader { source: "qrc:/fonts/MaterialIconsRound.otf" }
    readonly property string iconFont: _icons.status === FontLoader.Ready ? _icons.name : "Material Icons Round"
    property bool reduceMotion: false
    property bool windowActive: true        // false while the window is minimized
    readonly property bool motion: !reduceMotion && windowActive
    // strong ease-out: quick to react, long soft landing
    readonly property var curve: [0.23, 1, 0.32, 1, 1, 1]
    readonly property var curveInOut: [0.77, 0, 0.175, 1, 1, 1]
    readonly property string settingsIcon: "settings"
    readonly property string trash: "delete"
    readonly property string radio: "radio"
    readonly property string home: "home"
    readonly property string search: "search"
    readonly property string library: "library_music"
    readonly property string import_: "file_download"
    readonly property string play: "play_arrow"
    readonly property string pause: "pause"
    readonly property string prev: "skip_previous"
    readonly property string next: "skip_next"
    readonly property string volume: "volume_up"
    readonly property string volumeMute: "volume_off"
    readonly property string expand: "open_in_full"
    readonly property string download: "file_download"
    readonly property string add: "add"
    readonly property string heart:"favorite_border"
    readonly property string heartFill: "favorite"
    readonly property string headFont: _text.status === FontLoader.Ready ? _text.name : "Segoe UI"
    readonly property string bodyFont: headFont
}
