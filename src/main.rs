// a GUI app: no console window when it is opened
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod audio;
mod backend;
mod decoder;
mod download;
mod eq;
mod exportify;
mod hotkeys;
mod lyrics;
mod mixes;
mod library;
mod local;
mod palette;
mod paths;
mod profiles;
mod spectrum;
mod settings;
mod stream;
mod update;
mod ytdlp;
mod ytm;
mod ytm_more;

use cxx_qt_lib::{QGuiApplication, QQmlApplicationEngine, QUrl};

fn selftest() {
    let r = ytm::search_songs("daft punk get lucky").expect("search");
    let a = r.as_array().unwrap();
    println!("results: {}", a.len());
    for t in a.iter().take(3) {
        println!("  {} | {} | {} | {}s", t["id"], t["title"], t["artist"], t["dur"]);
    }
    let id = a[0]["id"].as_str().unwrap().to_string();
    let port = stream::serve();
    let t0 = std::time::Instant::now();
    stream::prepare(&id).expect("prepare");
    println!("prepared in {:?}", t0.elapsed());
    let resp = ureq::get(&format!("http://127.0.0.1:{port}/s/{id}"))
        .set("Range", "bytes=0-65535")
        .call()
        .expect("serve");
    let mut buf = Vec::new();
    std::io::Read::read_to_end(&mut resp.into_reader(), &mut buf).unwrap();
    println!("served {} bytes, header {:02x?}", buf.len(), &buf[4..12.min(buf.len())]);
}

extern "C" {
    fn _putenv_s(name: *const std::ffi::c_char, value: *const std::ffi::c_char) -> i32;
}

fn set_qt_env(name: &str, value: &str) {
    // a variable the user already set wins
    if std::env::var_os(name).is_some() {
        return;
    }
    let (n, v) = (std::ffi::CString::new(name).unwrap(), std::ffi::CString::new(value).unwrap());
    unsafe {
        _putenv_s(n.as_ptr(), v.as_ptr());
    }
}

fn main() {
    if std::env::args().any(|a| a == "--selftest") {
        selftest();
        return;
    }
    // Qt reads its settings through the C runtime's environment, which std::env::set_var does
    // not touch on Windows, so set them with _putenv_s.
    // basic render loop: draws on the UI thread with no thread hand-offs, about half the CPU of the
    // default threaded loop for this app; Basic is the lightest Quick Controls style.
    // threaded loop (Qt's default): drawing waits for the screen refresh on its own thread, so
    // mouse and hover handling on the UI thread never block on it
    set_qt_env("QT_QUICK_CONTROLS_STYLE", "Basic");
    // a graphics API other than the default can fix pointer stutter on some drivers (Settings, restart needed)
    match settings::get()["graphics"].as_str() {
        Some("d3d12") => set_qt_env("QSG_RHI_BACKEND", "d3d12"),
        Some("opengl") => set_qt_env("QSG_RHI_BACKEND", "opengl"),
        _ => {}
    }
    let mut app = QGuiApplication::new();
    let mut engine = QQmlApplicationEngine::new();
    if let Some(engine) = engine.as_mut() {
        engine.load(&QUrl::from("qrc:/qt/qml/CloudMusic/qml/Main.qml"));
    }
    if let Some(app) = app.as_mut() {
        app.exec();
    }
}
