import QtQuick
import QtQuick.Dialogs

// Native file pickers, loaded only when the user asks for one.
Item {
    id: f
    signal importPicked(string path)
    signal savePicked(string path)
    function pickImport() { openDialog.open() }
    function pickSave() { saveDialog.open() }
    function pickImage() { imageDialog.open() }
    function pickFolder() { folderDialog.open() }
    signal imagePicked(string path)
    signal folderPicked(string path)

    FileDialog {
        id: openDialog
        nameFilters: ["Playlists (*.csv *.txt *.cloud *.json)", "All files (*)"]
        onAccepted: f.importPicked(selectedFile.toString())
    }
    FileDialog {
        id: imageDialog
        nameFilters: ["Pictures (*.png *.jpg *.jpeg *.webp *.bmp *.gif)"]
        onAccepted: f.imagePicked(selectedFile.toString())
    }
    FolderDialog { id: folderDialog; onAccepted: f.folderPicked(selectedFolder.toString()) }
    FileDialog {
        id: saveDialog
        fileMode: FileDialog.SaveFile
        defaultSuffix: "cloud"
        nameFilters: ["Cloudify playlist (*.cloud)"]
        onAccepted: f.savePicked(selectedFile.toString())
    }
}
