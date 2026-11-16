pragma Singleton
import QtQuick

// Interface language: t("English text") gives the text in the chosen language, or the English.
// The translations live in langs/tables.json (UTF-8), read once at start.
QtObject {
    id: tr
    property string lang: "en"
    property var tables: ({})
    property var names: [{code: "en", name: "English"}]
    property var dict: ({})
    readonly property bool rtl: lang === "ar"
    function t(s) { var v = dict[s]; return v !== undefined ? v : s }
    function set(code) {
        var c = code
        if (c === "auto" || c === "" || c === undefined) c = Qt.locale().name.substring(0, 2)
        lang = tables[c] !== undefined ? c : "en"
        dict = tables[lang] || ({})
    }
}
