use cxx_qt_build::{CxxQtBuilder, QmlFile, QmlModule};

fn main() {
    embed_resource::compile("assets/app.rc", embed_resource::NONE);
    let files: Vec<QmlFile> = [
        "Main", "HomeView", "TracksPage", "TrackList", "PlayerBar", "ImmersivePlayer", "WavyButton", "WaveSeek",
        "Squiggle", "Cover", "PlaylistArt", "LiquidBackdrop", "IconButton", "PillButton", "NavItem", "ProfileGate", "SettingsView", "AudioEngine", "FileDialogs", "TitleBar", "SearchView", "SongRow",
    ]
    .iter()
    .map(|n| QmlFile::from(format!("qml/{n}.qml")))
    .chain(std::iter::once(QmlFile::from("qml/Theme.qml").singleton(true)))
    .chain(std::iter::once(QmlFile::from("qml/Themes.qml").singleton(true)))
    .collect();

    println!("cargo:rerun-if-changed=shaders.qrc");
    CxxQtBuilder::new_qml_module(QmlModule::new("CloudMusic").qml_files(files))
        .qt_module("Quick")
        .qrc("shaders.qrc")
        .file("src/backend.rs")
        .build();
}
