use crate::{library, stream, ytm};
use core::pin::Pin;
use cxx_qt::Threading;
use cxx_qt_lib::QString;
use serde_json::{json, Value};
use std::sync::{Mutex, OnceLock};

#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    extern "RustQt" {
        #[qobject]
        #[qml_element]
        type Backend = super::BackendRust;

        #[qinvokable]
        fn search(self: Pin<&mut Backend>, q: &QString);
        #[qinvokable]
        fn play(self: Pin<&mut Backend>, vid: &QString);
        #[qinvokable]
        fn palette(self: Pin<&mut Backend>, url: &QString);
        #[qinvokable]
        #[cxx_name = "streamUrl"]
        fn stream_url(self: &Backend, vid: &QString) -> QString;
        #[qinvokable]
        fn library(self: &Backend) -> QString;
        #[qinvokable]
        #[cxx_name = "createPlaylist"]
        fn create_playlist(self: &Backend, name: &QString) -> QString;
        #[qinvokable]
        #[cxx_name = "addToPlaylist"]
        fn add_to_playlist(self: &Backend, id: &QString, track: &QString);
        #[qinvokable]
        #[cxx_name = "deletePlaylist"]
        fn delete_playlist(self: &Backend, id: &QString);
        #[qinvokable]
        #[cxx_name = "audioPreload"]
        fn audio_preload(self: &Backend, vid: &QString);
        #[qinvokable]
        #[cxx_name = "setFx"]
        fn set_fx(self: &Backend, json: &QString);
        #[qinvokable]
        #[cxx_name = "audioDevices"]
        fn audio_devices(self: &Backend) -> QString;
        #[qinvokable]
        #[cxx_name = "audioDevice"]
        fn audio_device(self: &Backend, name: &QString);
        #[qinvokable]
        #[cxx_name = "artistPage"]
        fn artist_page(self: Pin<&mut Backend>, browse_id: &QString, name: &QString, thumb: &QString);
        #[qsignal]
        #[cxx_name = "artistReady"]
        fn artist_ready(self: Pin<&mut Backend>, json: QString);
        #[qinvokable]
        fn suggest(self: Pin<&mut Backend>, query: &QString);
        #[qsignal]
        #[cxx_name = "suggestionsReady"]
        fn suggestions_ready(self: Pin<&mut Backend>, query: QString, json: QString);
        #[qinvokable]
        #[cxx_name = "logPlay"]
        fn log_play(self: &Backend, track: &QString, secs: i32);
        #[qinvokable]
        fn stats(self: &Backend) -> QString;
        #[qinvokable]
        #[cxx_name = "cachedIds"]
        fn cached_ids(self: &Backend) -> QString;
        #[qinvokable]
        #[cxx_name = "discordUpdate"]
        fn discord_update(self: &Backend, title: &QString, artist: &QString, position_ms: i32, duration_ms: i32, playing: bool);
        #[qinvokable]
        #[cxx_name = "startMediaOverlay"]
        fn start_media_overlay(self: Pin<&mut Backend>);
        #[qinvokable]
        #[cxx_name = "overlayUpdate"]
        fn overlay_update(self: &Backend, title: &QString, artist: &QString, thumb: &QString, playing: bool);
        #[qinvokable]
        fn languages(self: &Backend) -> QString;
        #[qinvokable]
        #[cxx_name = "setFullscreen"]
        fn set_fullscreen(self: &Backend, on: bool) -> bool;
        #[qinvokable]
        #[cxx_name = "startTray"]
        fn start_tray(self: Pin<&mut Backend>);
        #[qinvokable]
        #[cxx_name = "trayTip"]
        fn tray_tip(self: &Backend, text: &QString);
        #[qinvokable]
        #[cxx_name = "setAutostart"]
        fn set_autostart(self: &Backend, on: bool) -> bool;
        #[qinvokable]
        #[cxx_name = "autostartOn"]
        fn autostart_on(self: &Backend) -> bool;
        #[qinvokable]
        #[cxx_name = "checkUpdate"]
        fn check_update(self: Pin<&mut Backend>);
        #[qsignal]
        #[cxx_name = "updateChecked"]
        fn update_checked(self: Pin<&mut Backend>, json: QString);
        #[qinvokable]
        #[cxx_name = "installUpdate"]
        fn install_update(self: Pin<&mut Backend>);
        #[qsignal]
        #[cxx_name = "updateProgress"]
        fn update_progress(self: Pin<&mut Backend>, percent: i32);
        #[qsignal]
        #[cxx_name = "updateDownloaded"]
        fn update_downloaded(self: Pin<&mut Backend>, json: QString);
        #[qinvokable]
        #[cxx_name = "launchInstaller"]
        fn launch_installer(self: &Backend) -> bool;
        #[qinvokable]
        #[cxx_name = "appVersion"]
        fn app_version(self: &Backend) -> QString;
        #[qinvokable]
        #[cxx_name = "scanLocal"]
        fn scan_local(self: Pin<&mut Backend>);
        #[qsignal]
        #[cxx_name = "localReady"]
        fn local_ready(self: Pin<&mut Backend>, json: QString);
        #[qinvokable]
        #[cxx_name = "addLocalFolder"]
        fn add_local_folder(self: &Backend, path: &QString) -> QString;
        #[qinvokable]
        #[cxx_name = "savePlaylist"]
        fn save_playlist(self: &Backend, id: &QString, name: &QString, desc: &QString, cover: &QString) -> QString;
        #[qinvokable]
        #[cxx_name = "setEq"]
        fn set_eq(self: &Backend, gains: &QString);
        #[qinvokable]
        #[cxx_name = "setFlag"]
        fn set_flag(self: &Backend, kind: &QString, id: &QString, on: bool);
        #[qinvokable]
        #[cxx_name = "hideInPlaylist"]
        fn hide_in_playlist(self: &Backend, playlist: &QString, song: &QString, on: bool);
        #[qinvokable]
        #[cxx_name = "removeFromPlaylist"]
        fn remove_from_playlist(self: &Backend, id: &QString, song: &QString);
        #[qinvokable]
        #[cxx_name = "togglePin"]
        fn toggle_pin(self: &Backend, id: &QString);
        #[qinvokable]
        #[cxx_name = "toggleLike"]
        fn toggle_like(self: &Backend, track: &QString) -> bool;
        #[qinvokable]
        #[cxx_name = "importText"]
        fn import_text(self: Pin<&mut Backend>, text: &QString, name: &QString);
        #[qinvokable]
        #[cxx_name = "importFile"]
        fn import_file(self: Pin<&mut Backend>, path: &QString);
        #[qinvokable]
        #[cxx_name = "importCode"]
        fn import_code(self: &Backend, text: &QString) -> QString;
        #[qinvokable]
        #[cxx_name = "exportCode"]
        fn export_code(self: &Backend, id: &QString) -> QString;
        #[qinvokable]
        #[cxx_name = "exportFile"]
        fn export_file(self: &Backend, id: &QString, path: &QString) -> bool;
        #[qinvokable]
        fn lyrics(self: Pin<&mut Backend>, track: &QString);
        #[qinvokable]
        #[cxx_name = "startHotkeys"]
        fn start_hotkeys(self: Pin<&mut Backend>);
        #[qinvokable]
        #[cxx_name = "downloadTracks"]
        fn download_tracks(self: Pin<&mut Backend>, tracks: &QString);

        #[qinvokable]
        #[cxx_name = "importLink"]
        fn import_link(self: Pin<&mut Backend>, url: &QString, name: &QString);
        #[qinvokable]
        #[cxx_name = "checkEngine"]
        fn check_engine(self: Pin<&mut Backend>, force: bool);
        #[qsignal]
        #[cxx_name = "engineStatus"]
        fn engine_status(self: Pin<&mut Backend>, json: QString);
        #[qinvokable]
        #[cxx_name = "audioLoad"]
        fn audio_load(self: &Backend, vid: &QString);
        #[qinvokable]
        #[cxx_name = "audioPlay"]
        fn audio_play(self: &Backend);
        #[qinvokable]
        #[cxx_name = "audioPause"]
        fn audio_pause(self: &Backend);
        #[qinvokable]
        #[cxx_name = "audioStop"]
        fn audio_stop(self: &Backend);
        #[qinvokable]
        #[cxx_name = "audioSeek"]
        fn audio_seek(self: &Backend, ms: i32);
        #[qinvokable]
        #[cxx_name = "audioVolume"]
        fn audio_volume(self: &Backend, v: f64);
        #[qinvokable]
        #[cxx_name = "audioPoll"]
        fn audio_poll(self: &Backend) -> QString;
        #[qinvokable]
        #[cxx_name = "importSpotify"]
        fn import_spotify(self: Pin<&mut Backend>, url: &QString, name: &QString);
        #[qinvokable]
        #[cxx_name = "makeMixes"]
        fn make_mixes(self: Pin<&mut Backend>, force: bool);
        #[qsignal]
        #[cxx_name = "mixesReady"]
        fn mixes_ready(self: Pin<&mut Backend>, json: QString);
        #[qinvokable]
        #[cxx_name = "exportifyOpen"]
        fn exportify_open(self: Pin<&mut Backend>);
        #[qsignal]
        #[cxx_name = "exportifyFiles"]
        fn exportify_files(self: Pin<&mut Backend>, json: QString);
        #[qinvokable]
        #[cxx_name = "exportifyStart"]
        fn exportify_start(self: &Backend);
        #[qinvokable]
        #[cxx_name = "exportifyPoll"]
        fn exportify_poll(self: &Backend) -> QString;
        #[qinvokable]
        #[cxx_name = "searchAll"]
        fn search_all(self: Pin<&mut Backend>, q: &QString);
        #[qsignal]
        #[cxx_name = "searchedAll"]
        fn searched_all(self: Pin<&mut Backend>, query: QString, json: QString);
        #[qinvokable]
        #[cxx_name = "albumTracks"]
        fn album_tracks(self: Pin<&mut Backend>, browse_id: &QString, album: &QString, artist: &QString, thumb: &QString);
        #[qsignal]
        #[cxx_name = "albumReady"]
        fn album_ready(self: Pin<&mut Backend>, json: QString);
        #[qinvokable]
        #[cxx_name = "matchTrack"]
        fn match_track(self: Pin<&mut Backend>, track: &QString);
        #[qsignal]
        fn matched(self: Pin<&mut Backend>, json: QString);
        #[qinvokable]
        #[cxx_name = "profileInfo"]
        fn profile_info(self: &Backend) -> QString;
        #[qinvokable]
        #[cxx_name = "saveProfile"]
        fn save_profile(self: &Backend, name: &QString, color: &QString) -> QString;
        #[qinvokable]
        #[cxx_name = "setAvatar"]
        fn set_avatar(self: &Backend, path: &QString) -> QString;
        #[qinvokable]
        #[cxx_name = "clearAvatar"]
        fn clear_avatar(self: &Backend) -> QString;
        #[qinvokable]
        fn prefetch(self: &Backend, vid: &QString);
        #[qinvokable]
        #[cxx_name = "loadSession"]
        fn load_session(self: &Backend) -> QString;
        #[qinvokable]
        #[cxx_name = "saveSession"]
        fn save_session(self: &Backend, json: &QString);
        #[qinvokable]
        #[cxx_name = "styleWindow"]
        fn style_window(self: &Backend);
        #[qinvokable]
        #[cxx_name = "trimMemory"]
        fn trim_memory(self: &Backend);
        #[qinvokable]
        fn settings(self: &Backend) -> QString;
        #[qinvokable]
        #[cxx_name = "saveSettings"]
        fn save_settings(self: &Backend, patch: &QString) -> QString;
        #[qinvokable]
        #[cxx_name = "cacheInfo"]
        fn cache_info(self: &Backend) -> QString;
        #[qinvokable]
        #[cxx_name = "clearCache"]
        fn clear_cache(self: &Backend) -> QString;
        #[qinvokable]
        fn bands(self: &Backend, vid: &QString, ms: i32) -> QString;
        #[qinvokable]
        fn profiles(self: &Backend) -> QString;
        #[qinvokable]
        #[cxx_name = "createProfile"]
        fn create_profile(self: &Backend, name: &QString, color: &QString, pin: &QString) -> QString;
        #[qinvokable]
        #[cxx_name = "deleteProfile"]
        fn delete_profile(self: &Backend, id: &QString, pin: &QString) -> QString;
        #[qinvokable]
        #[cxx_name = "selectProfile"]
        fn select_profile(self: &Backend, id: &QString, pin: &QString) -> bool;
        #[qinvokable]
        fn radio(self: Pin<&mut Backend>, vid: &QString);
        #[qsignal]
        #[cxx_name = "radioReady"]
        fn radio_ready(self: Pin<&mut Backend>, vid: QString, json: QString);

        #[qsignal]
        #[cxx_name = "lyricsReady"]
        fn lyrics_ready(self: Pin<&mut Backend>, vid: QString, json: QString);
        #[qsignal]
        fn hotkey(self: Pin<&mut Backend>, action: QString);
        #[qsignal]
        #[cxx_name = "downloadProgress"]
        fn download_progress(self: Pin<&mut Backend>, done: i32, total: i32, message: QString);

        #[qsignal]
        fn searched(self: Pin<&mut Backend>, json: QString);
        #[qsignal]
        #[cxx_name = "swatchesReady"]
        fn swatches_ready(self: Pin<&mut Backend>, url: QString, json: QString);
        #[qsignal]
        #[cxx_name = "paletteReady"]
        fn palette_ready(self: Pin<&mut Backend>, url: QString, color: QString);
        #[qsignal]
        #[cxx_name = "playReady"]
        fn play_ready(self: Pin<&mut Backend>, vid: QString, url: QString);
        #[qsignal]
        #[cxx_name = "playFailed"]
        fn play_failed(self: Pin<&mut Backend>, vid: QString, message: QString);
        #[qsignal]
        #[cxx_name = "importProgress"]
        fn import_progress(self: Pin<&mut Backend>, done: i32, total: i32);
        #[qsignal]
        #[cxx_name = "importDone"]
        fn import_done(self: Pin<&mut Backend>, json: QString);
    }

    impl cxx_qt::Threading for Backend {}
}

#[derive(Default)]
pub struct BackendRust;

fn port() -> u16 {
    static P: OnceLock<u16> = OnceLock::new();
    *P.get_or_init(stream::serve)
}

fn q(s: &str) -> QString {
    QString::from(s)
}

fn parse(s: &QString) -> Value {
    serde_json::from_str(&s.to_string()).unwrap_or(Value::Null)
}

/// The handle of this app's visible top-level window (0 before it exists).
pub fn main_hwnd() -> isize {
    use windows_sys::Win32::UI::WindowsAndMessaging::{EnumWindows, GetWindowThreadProcessId, IsWindowVisible};
    unsafe extern "system" fn each(hwnd: windows_sys::Win32::Foundation::HWND, out: isize) -> i32 {
        let mut pid = 0u32;
        GetWindowThreadProcessId(hwnd, &mut pid);
        if pid == std::process::id() && IsWindowVisible(hwnd) != 0 {
            *(out as *mut isize) = hwnd as isize;
            return 0;
        }
        1
    }
    let mut found: isize = 0;
    unsafe {
        EnumWindows(Some(each), &mut found as *mut isize as isize);
    }
    found
}

static INSTALLER: Mutex<Option<std::path::PathBuf>> = Mutex::new(None);

impl qobject::Backend {
    pub fn search(self: Pin<&mut Self>, query: &QString) {
        let query = query.to_string();
        let qt = self.qt_thread();
        std::thread::spawn(move || {
            let out = match ytm::search_songs(&query) {
                Ok(v) => json!({"ok": true, "items": v}),
                Err(e) => json!({"ok": false, "error": e}),
            };
            let _ = qt.queue(move |mut b| b.as_mut().searched(q(&out.to_string())));
        });
    }

    pub fn play(self: Pin<&mut Self>, vid: &QString) {
        let vid = vid.to_string();
        let qt = self.qt_thread();
        if vid.starts_with("local:") {
            let _ = qt.queue(move |mut b| b.as_mut().play_ready(q(&vid), q("")));
            return;
        }
        std::thread::spawn(move || {
            let res = stream::prepare(&vid);
            if let Ok(t) = &res {
                // analyse the spectrum once the file is fully cached
                let (t, v) = (t.clone(), vid.clone());
                std::thread::spawn(move || {
                    if let Ok((p, _)) = stream::wait_done(&t) {
                        crate::spectrum::ensure(&v, &p);
                    }
                });
            }
            let _ = qt.queue(move |mut b| match res {
                Ok(_) => {
                    let url = format!("http://127.0.0.1:{}/s/{}", port(), vid);
                    b.as_mut().play_ready(q(&vid), q(&url));
                }
                Err(e) => b.as_mut().play_failed(q(&vid), q(&e)),
            });
        });
    }

    pub fn palette(self: Pin<&mut Self>, url: &QString) {
        let url = url.to_string();
        let qt = self.qt_thread();
        std::thread::spawn(move || {
            match crate::palette::analyse(&url) {
                Ok((hex, sw)) => {
                    let _ = qt.queue(move |mut b| {
                        b.as_mut().swatches_ready(q(&url), q(&json!(sw).to_string()));
                        b.as_mut().palette_ready(q(&url), q(&hex));
                    });
                }
                Err(e) => crate::paths::log(&format!("palette failed for {url}: {e}")),
            }
        });
    }

    pub fn import_link(self: Pin<&mut Self>, url: &QString, name: &QString) {
        let (url, name) = (url.to_string().trim().to_string(), name.to_string());
        let qt = self.qt_thread();
        std::thread::spawn(move || {
            let out = match crate::ytdlp::playlist(&url) {
                Ok((title, tracks)) => {
                    let n = tracks.len();
                    let pname = if name.trim().is_empty() { title } else { name };
                    let pl = library::create_playlist(&pname, tracks, &format!("Imported from a link · {n} songs"));
                    json!({"ok": true, "playlist": pl, "found": n, "total": n})
                }
                Err(e) => json!({"ok": false, "error": e}),
            };
            let _ = qt.queue(move |mut b| b.as_mut().import_done(q(&out.to_string())));
        });
    }

    pub fn check_engine(self: Pin<&mut Self>, force: bool) {
        let qt = self.qt_thread();
        std::thread::spawn(move || {
            let res = crate::ytdlp::update(force);
            let version = crate::ytdlp::version();
            let out = match res {
                Ok(m) => json!({"ok": true, "message": m, "version": version}),
                Err(e) => json!({"ok": false, "message": e, "version": version}),
            };
            let _ = qt.queue(move |mut b| b.as_mut().engine_status(q(&out.to_string())));
        });
    }

    pub fn audio_load(&self, vid: &QString) {
        crate::audio::load(&vid.to_string());
    }
    pub fn audio_play(&self) {
        crate::audio::play();
    }
    pub fn audio_pause(&self) {
        crate::audio::pause();
    }
    pub fn audio_stop(&self) {
        crate::audio::stop();
    }
    pub fn audio_seek(&self, ms: i32) {
        crate::audio::seek(ms.max(0) as u64);
    }
    pub fn audio_volume(&self, v: f64) {
        crate::audio::volume(v as f32);
    }
    pub fn audio_poll(&self) -> QString {
        q(&crate::audio::poll())
    }

    /// A Spotify playlist, album or song link: read its songs, then match each on YouTube Music.
    pub fn import_spotify(self: Pin<&mut Self>, url: &QString, name: &QString) {
        let url = url.to_string().trim().to_string();
        let st = crate::settings::get();
        let (id, secret) = (st["spotifyId"].as_str().unwrap_or("").to_string(), st["spotifySecret"].as_str().unwrap_or("").to_string());
        let name = name.to_string();
        let title = std::sync::Arc::new(Mutex::new(String::new()));
        let t2 = title.clone();
        let loader: Loader = Box::new(move || {
            let (n, songs) = crate::ytm_more::spotify_link(&url, &id, &secret)?;
            *t2.lock().unwrap() = n.clone();
            Ok(library::Parsed { name: n, songs })
        });
        run_import_with(self, String::new(), name, Some(loader));
    }

    /// Today's six mixes: from disk when they are fresh, otherwise built in the background.
    pub fn make_mixes(self: Pin<&mut Self>, force: bool) {
        let qt = self.qt_thread();
        std::thread::spawn(move || {
            let out = match crate::mixes::generate(force) {
                Ok(v) => json!({"ok": true, "mixes": v["mixes"]}),
                Err(e) => json!({"ok": false, "error": e}),
            };
            let _ = qt.queue(move |mut b| b.as_mut().mixes_ready(q(&out.to_string())));
        });
    }

    pub fn exportify_open(self: Pin<&mut Self>) {
        let qt = self.qt_thread();
        crate::exportify::open(move |files| {
            let list: Vec<String> = files.iter().map(|f| f.to_string_lossy().into_owned()).collect();
            let _ = qt.queue(move |mut b| b.as_mut().exportify_files(q(&json!(list).to_string())));
        });
    }

    pub fn exportify_start(&self) {
        crate::ytm_more::watch_start();
    }

    pub fn exportify_poll(&self) -> QString {
        q(&crate::ytm_more::watch_poll().to_string())
    }

    /// Songs, albums and artists from YouTube Music, plus Spotify when keys are set.
    pub fn search_all(self: Pin<&mut Self>, query: &QString) {
        let query = query.to_string();
        let qt = self.qt_thread();
        std::thread::spawn(move || {
            let st = crate::settings::get();
            let (id, secret) = (st["spotifyId"].as_str().unwrap_or("").to_string(), st["spotifySecret"].as_str().unwrap_or("").to_string());
            let q2 = query.clone();
            let sp = (!id.is_empty() && !secret.is_empty()).then(|| std::thread::spawn(move || crate::ytm_more::spotify_search(&q2, &id, &secret)));
            let mut out = crate::ytm_more::search_all(&query);
            if let Some(h) = sp {
                match h.join() {
                    Ok(Ok(items)) => out["spotify"] = items,
                    Ok(Err(e)) => out["spotifyError"] = json!(e),
                    Err(_) => {}
                }
            }
            let _ = qt.queue(move |mut b| b.as_mut().searched_all(q(&query), q(&out.to_string())));
        });
    }

    pub fn album_tracks(self: Pin<&mut Self>, browse_id: &QString, album: &QString, artist: &QString, thumb: &QString) {
        let (b, a, ar, t) = (browse_id.to_string(), album.to_string(), artist.to_string(), thumb.to_string());
        let qt = self.qt_thread();
        std::thread::spawn(move || {
            let out = match crate::ytm_more::album_tracks(&b, &a, &ar, &t) {
                Ok(v) => json!({"ok": true, "title": a, "tracks": v}),
                Err(e) => json!({"ok": false, "error": e}),
            };
            let _ = qt.queue(move |mut bk| bk.as_mut().album_ready(q(&out.to_string())));
        });
    }

    /// Find the YouTube Music song for a Spotify result (title, artist and length).
    pub fn match_track(self: Pin<&mut Self>, track: &QString) {
        let t = parse(track);
        let qt = self.qt_thread();
        std::thread::spawn(move || {
            let w = library::Wanted {
                title: t["title"].as_str().unwrap_or("").into(),
                artist: t["artist"].as_str().unwrap_or("").split(',').next().unwrap_or("").trim().into(),
                dur: t["dur"].as_u64().unwrap_or(0) as u32,
                raw: String::new(),
            };
            let out = match library::match_song(&w) {
                Some(m) => json!({"ok": true, "track": m}),
                None => json!({"ok": false, "error": "Could not find that song on YouTube Music"}),
            };
            let _ = qt.queue(move |mut b| b.as_mut().matched(q(&out.to_string())));
        });
    }

    pub fn profile_info(&self) -> QString {
        q(&crate::profiles::current().to_string())
    }
    pub fn save_profile(&self, name: &QString, color: &QString) -> QString {
        q(&crate::profiles::save_profile(&name.to_string(), &color.to_string()).to_string())
    }
    pub fn set_avatar(&self, path: &QString) -> QString {
        q(&match crate::profiles::set_avatar(&path.to_string()) {
            Ok(p) => json!({"ok": true, "profile": p}),
            Err(e) => json!({"ok": false, "error": e}),
        }
        .to_string())
    }
    pub fn clear_avatar(&self) -> QString {
        q(&crate::profiles::clear_avatar().to_string())
    }

    pub fn prefetch(&self, vid: &QString) {
        stream::prefetch(&vid.to_string());
    }

    /// What was playing when the app closed: `{queue, qi, pos}` (empty object if none).
    pub fn load_session(&self) -> QString {
        let f = crate::profiles::dir().join("session.json");
        q(&std::fs::read_to_string(f).unwrap_or_else(|_| "{}".into()))
    }

    pub fn save_session(&self, json: &QString) {
        let f = crate::profiles::dir().join("session.json");
        let tmp = f.with_extension("tmp");
        if std::fs::write(&tmp, json.to_string()).is_ok() {
            let _ = std::fs::rename(&tmp, f);
        }
    }

    /// Give the frameless window Windows 11's rounded corners and a drop shadow.
    pub fn style_window(&self) {
        use windows_sys::Win32::Graphics::Dwm::{DwmExtendFrameIntoClientArea, DwmSetWindowAttribute};
        use windows_sys::Win32::UI::Controls::MARGINS;
        use windows_sys::Win32::UI::WindowsAndMessaging::{EnumWindows, GetWindowThreadProcessId, IsWindowVisible};
        unsafe extern "system" fn each(hwnd: windows_sys::Win32::Foundation::HWND, out: isize) -> i32 {
            let mut pid = 0u32;
            GetWindowThreadProcessId(hwnd, &mut pid);
            if pid == std::process::id() && IsWindowVisible(hwnd) != 0 {
                *(out as *mut isize) = hwnd as isize;
                return 0;
            }
            1
        }
        unsafe {
            let mut found: isize = 0;
            EnumWindows(Some(each), &mut found as *mut isize as isize);
            if found != 0 {
                let h = found as windows_sys::Win32::Foundation::HWND;
                let round: i32 = 2; // DWMWCP_ROUND
                DwmSetWindowAttribute(h, 33, &round as *const i32 as *const _, 4);
                let m = MARGINS { cxLeftWidth: 0, cxRightWidth: 0, cyTopHeight: 0, cyBottomHeight: 1 };
                DwmExtendFrameIntoClientArea(h, &m);
                // the taskbar button, its hover preview and Alt+Tab take the icon from here
                use windows_sys::Win32::System::LibraryLoader::GetModuleHandleW;
                use windows_sys::Win32::UI::WindowsAndMessaging::{GetSystemMetrics, LoadImageW, SendMessageW, ICON_BIG, ICON_SMALL, IMAGE_ICON, SM_CXICON, SM_CXSMICON, WM_SETICON};
                let module = GetModuleHandleW(std::ptr::null());
                for (kind, metric) in [(ICON_SMALL, SM_CXSMICON), (ICON_BIG, SM_CXICON)] {
                    let px = GetSystemMetrics(metric);
                    // resource id 1 is the cloud (assets/app.rc)
                    let icon = LoadImageW(module, 1 as *const u16, IMAGE_ICON, px, px, 0);
                    if !icon.is_null() {
                        SendMessageW(h, WM_SETICON, kind as usize, icon as isize);
                    }
                }
            }
        }
    }

    /// Hand unused pages back to Windows. They fault in again only if touched.
    pub fn trim_memory(&self) {
        use windows_sys::Win32::System::{ProcessStatus::EmptyWorkingSet, Threading::GetCurrentProcess};
        unsafe {
            EmptyWorkingSet(GetCurrentProcess());
        }
    }

    pub fn settings(&self) -> QString {
        q(&crate::settings::get().to_string())
    }

    pub fn save_settings(&self, patch: &QString) -> QString {
        q(&crate::settings::patch(&parse(patch)).to_string())
    }

    pub fn cache_info(&self) -> QString {
        let (bytes, files) = stream::cache_usage();
        q(&json!({"bytes": bytes, "files": files}).to_string())
    }

    pub fn clear_cache(&self) -> QString {
        let freed = stream::clear_cache();
        let (bytes, files) = stream::cache_usage();
        q(&json!({"freed": freed, "bytes": bytes, "files": files}).to_string())
    }

    /// Comma-separated 0..255 band levels at `ms`, or "" before the analysis is ready.
    pub fn bands(&self, vid: &QString, ms: i32) -> QString {
        match crate::spectrum::at(&vid.to_string(), ms as i64) {
            Some(r) => q(&r.iter().map(|b| b.to_string()).collect::<Vec<_>>().join(",")),
            None => q(""),
        }
    }

    pub fn profiles(&self) -> QString {
        q(&crate::profiles::list().to_string())
    }

    pub fn create_profile(&self, name: &QString, color: &QString, pin: &QString) -> QString {
        q(&match crate::profiles::create(&name.to_string(), &color.to_string(), &pin.to_string()) {
            Ok(l) => json!({"ok": true, "profiles": l}),
            Err(e) => json!({"ok": false, "error": e}),
        }
        .to_string())
    }

    pub fn delete_profile(&self, id: &QString, pin: &QString) -> QString {
        q(&match crate::profiles::delete(&id.to_string(), &pin.to_string()) {
            Ok(l) => json!({"ok": true, "profiles": l}),
            Err(e) => json!({"ok": false, "error": e}),
        }
        .to_string())
    }

    pub fn select_profile(&self, id: &QString, pin: &QString) -> bool {
        crate::profiles::select(&id.to_string(), &pin.to_string())
    }

    pub fn radio(self: Pin<&mut Self>, vid: &QString) {
        let vid = vid.to_string();
        let qt = self.qt_thread();
        std::thread::spawn(move || {
            let out = match ytm::radio(&vid) {
                Ok(v) => json!({"ok": true, "items": v}),
                Err(e) => json!({"ok": false, "error": e}),
            };
            let _ = qt.queue(move |mut b| b.as_mut().radio_ready(q(&vid), q(&out.to_string())));
        });
    }

    pub fn lyrics(self: Pin<&mut Self>, track: &QString) {
        let t = parse(track);
        let qt = self.qt_thread();
        std::thread::spawn(move || {
            let vid = t["id"].as_str().unwrap_or("").to_string();
            let out = crate::lyrics::fetch(
                &vid,
                t["title"].as_str().unwrap_or(""),
                t["artist"].as_str().unwrap_or(""),
                t["album"].as_str().unwrap_or(""),
                t["dur"].as_u64().unwrap_or(0),
            );
            let _ = qt.queue(move |mut b| b.as_mut().lyrics_ready(q(&vid), q(&out.to_string())));
        });
    }

    pub fn start_hotkeys(self: Pin<&mut Self>) {
        static ONCE: std::sync::Once = std::sync::Once::new();
        let qt = self.qt_thread();
        ONCE.call_once(move || {
            crate::hotkeys::start(move |action| {
                let _ = qt.queue(move |mut b| b.as_mut().hotkey(q(action)));
            });
        });
    }

    pub fn download_tracks(self: Pin<&mut Self>, tracks: &QString) {
        let list = parse(tracks).as_array().cloned().unwrap_or_default();
        let qt = self.qt_thread();
        std::thread::spawn(move || {
            let total = list.len() as i32;
            let mut fails = 0;
            for (i, t) in list.iter().enumerate() {
                let msg = match crate::download::save(t) {
                    Ok(p) => format!("Saved {}", p.file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_default()),
                    Err(e) => {
                        fails += 1;
                        format!("{}: {e}", t["title"].as_str().unwrap_or("Track"))
                    }
                };
                let done = i as i32 + 1;
                let msg = if done == total && total > 1 {
                    format!("Downloaded {} of {} songs to Music\\Cloudify", total - fails, total)
                } else {
                    msg
                };
                let _ = qt.queue(move |mut b| b.as_mut().download_progress(done, total, q(&msg)));
            }
        });
    }

    pub fn stream_url(&self, vid: &QString) -> QString {
        q(&format!("http://127.0.0.1:{}/s/{}", port(), vid))
    }

    pub fn library(&self) -> QString {
        q(&library::snapshot().to_string())
    }

    pub fn create_playlist(&self, name: &QString) -> QString {
        q(&library::create_playlist(&name.to_string(), vec![], "").to_string())
    }

    pub fn add_to_playlist(&self, id: &QString, track: &QString) {
        library::add_to_playlist(&id.to_string(), &parse(track));
    }

    pub fn audio_preload(&self, vid: &QString) {
        crate::audio::preload(&vid.to_string());
    }

    /// `{speed, pitch, normalize, crossfade, preamp}`
    pub fn set_fx(&self, json: &QString) {
        let v = parse(json);
        crate::fx::set_speed(v["speed"].as_f64().unwrap_or(1.0) as f32);
        crate::fx::set_pitch(v["pitch"].as_f64().unwrap_or(0.0) as f32);
        crate::fx::set_normalize(v["normalize"].as_bool().unwrap_or(false));
        crate::audio::set_crossfade(v["crossfade"].as_f64().unwrap_or(0.0) as f32);
        crate::eq::set_preamp(v["preamp"].as_f64().unwrap_or(0.0) as f32);
    }

    pub fn audio_devices(&self) -> QString {
        q(&json!(crate::audio::devices()).to_string())
    }

    pub fn audio_device(&self, name: &QString) {
        crate::audio::device(&name.to_string());
    }

    pub fn artist_page(self: Pin<&mut Self>, browse_id: &QString, name: &QString, thumb: &QString) {
        let (id, n, t) = (browse_id.to_string(), name.to_string(), thumb.to_string());
        let qt = self.qt_thread();
        std::thread::spawn(move || {
            let out = match crate::ytm_more::artist_page(&id, &n, &t) {
                Ok(v) => json!({"ok": true, "artist": v}),
                Err(e) => json!({"ok": false, "error": e}),
            };
            let _ = qt.queue(move |mut b| b.as_mut().artist_ready(q(&out.to_string())));
        });
    }

    pub fn suggest(self: Pin<&mut Self>, query: &QString) {
        let query = query.to_string();
        let qt = self.qt_thread();
        std::thread::spawn(move || {
            let list = crate::ytm_more::suggest(&query);
            let _ = qt.queue(move |mut b| b.as_mut().suggestions_ready(q(&query), q(&json!(list).to_string())));
        });
    }

    pub fn log_play(&self, track: &QString, secs: i32) {
        crate::stats::log_play(&parse(track), secs.max(0) as u64);
    }

    pub fn stats(&self) -> QString {
        q(&crate::stats::summary().to_string())
    }

    pub fn cached_ids(&self) -> QString {
        q(&json!(stream::cached_ids()).to_string())
    }

    /// Show what is playing on Discord. Needs the user's own Discord Application ID.
    pub fn discord_update(&self, title: &QString, artist: &QString, position_ms: i32, duration_ms: i32, playing: bool) {
        let st = crate::settings::get();
        let id = st["discordAppId"].as_str().unwrap_or("").to_string();
        let on = st["discordPresence"].as_bool().unwrap_or(false) && !id.is_empty();
        let now = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0);
        let start = now.saturating_sub((position_ms.max(0) / 1000) as u64);
        crate::discord::update(crate::discord::Presence {
            app_id: if on { id } else { String::new() },
            title: title.to_string(),
            artist: artist.to_string(),
            start_unix: if playing { start } else { 0 },
            end_unix: if playing && duration_ms > 0 { start + (duration_ms / 1000) as u64 } else { 0 },
            clear: !playing || title.is_empty(),
        });
    }

    pub fn start_media_overlay(self: Pin<&mut Self>) {
        let qt = self.qt_thread();
        let hwnd = main_hwnd();
        if hwnd == 0 {
            crate::paths::log("media overlay: no window yet");
            return;
        }
        match crate::smtc::start(hwnd, move |action| {
            let qt = qt.clone();
            let _ = qt.queue(move |mut b| b.as_mut().hotkey(q(action)));
        }) {
            Ok(()) => crate::paths::log("media overlay: ready"),
            Err(e) => crate::paths::log(&format!("media overlay: {e}")),
        }
    }

    pub fn overlay_update(&self, title: &QString, artist: &QString, thumb: &QString, playing: bool) {
        crate::smtc::update(&title.to_string(), &artist.to_string(), &thumb.to_string(), playing);
    }

    /// The interface translations (langs/tables.json), compiled in.
    pub fn languages(&self) -> QString {
        q(include_str!("../langs/tables.json"))
    }

    /// Real fullscreen: no frame, no rounded corners, over the whole monitor and above the taskbar.
    pub fn set_fullscreen(&self, on: bool) -> bool {
        crate::fullscreen::set(main_hwnd(), on)
    }

    pub fn start_tray(self: Pin<&mut Self>) {
        let qt = self.qt_thread();
        crate::tray::start(move |action| {
            let qt = qt.clone();
            let _ = qt.queue(move |mut b| b.as_mut().hotkey(q(action)));
        });
    }

    pub fn tray_tip(&self, text: &QString) {
        crate::tray::set_tip(&text.to_string());
    }

    pub fn set_autostart(&self, on: bool) -> bool {
        crate::startup::set(on)
    }

    pub fn autostart_on(&self) -> bool {
        crate::startup::enabled()
    }

    pub fn check_update(self: Pin<&mut Self>) {
        let qt = self.qt_thread();
        std::thread::spawn(move || {
            let out = crate::update::check();
            let _ = qt.queue(move |mut b| b.as_mut().update_checked(q(&out.to_string())));
        });
    }

    pub fn install_update(self: Pin<&mut Self>) {
        let qt = self.qt_thread();
        std::thread::spawn(move || {
            let last = std::sync::atomic::AtomicI32::new(-1);
            let qt2 = qt.clone();
            let res = crate::update::download(|done, total| {
                let pct = if total > 0 { (done * 100 / total) as i32 } else { 0 };
                if last.swap(pct, std::sync::atomic::Ordering::Relaxed) != pct {
                    let _ = qt2.queue(move |mut b| b.as_mut().update_progress(pct));
                }
            });
            *INSTALLER.lock().unwrap() = res.as_ref().ok().cloned();
            let out = match res {
                Ok(_) => json!({"ok": true}),
                Err(e) => json!({"ok": false, "error": e}),
            };
            let _ = qt.queue(move |mut b| b.as_mut().update_downloaded(q(&out.to_string())));
        });
    }

    /// Start the downloaded installer; the caller then quits the app.
    pub fn launch_installer(&self) -> bool {
        INSTALLER.lock().unwrap().take().is_some_and(|p| crate::update::launch(&p))
    }

    pub fn app_version(&self) -> QString {
        q(crate::update::current())
    }

    /// Scan the music folders in the background.
    pub fn scan_local(self: Pin<&mut Self>) {
        let qt = self.qt_thread();
        std::thread::spawn(move || {
            let tracks = crate::local::scan(&crate::local::folders());
            let out = json!({"folders": crate::local::folders(), "tracks": tracks});
            let _ = qt.queue(move |mut b| b.as_mut().local_ready(q(&out.to_string())));
        });
    }

    /// Remember another folder; returns the settings.
    pub fn add_local_folder(&self, path: &QString) -> QString {
        let p = path.to_string();
        let p = p.strip_prefix("file:///").unwrap_or(&p).to_string();
        let mut list = crate::local::folders();
        if !list.contains(&p) && std::path::Path::new(&p).is_dir() {
            list.push(p);
        }
        q(&crate::settings::patch(&json!({"localFolders": list})).to_string())
    }

    pub fn save_playlist(&self, id: &QString, name: &QString, desc: &QString, cover: &QString) -> QString {
        q(&match library::save_playlist(&id.to_string(), &name.to_string(), &desc.to_string(), &cover.to_string()) {
            Ok(pl) => json!({"ok": true, "playlist": pl}),
            Err(e) => json!({"ok": false, "error": e}),
        }
        .to_string())
    }

    /// `[g1..g6]` in dB; applied to the playing track at once.
    pub fn set_eq(&self, gains: &QString) {
        if let Ok(v) = serde_json::from_str::<Vec<f32>>(&gains.to_string()) {
            crate::eq::set(&v);
        }
    }

    pub fn set_flag(&self, kind: &QString, id: &QString, on: bool) {
        library::set_flag(&kind.to_string(), &id.to_string(), on);
    }

    pub fn hide_in_playlist(&self, playlist: &QString, song: &QString, on: bool) {
        library::hide_in_playlist(&playlist.to_string(), &song.to_string(), on);
    }

    pub fn remove_from_playlist(&self, id: &QString, song: &QString) {
        library::remove_from_playlist(&id.to_string(), &song.to_string());
    }

    pub fn toggle_pin(&self, id: &QString) {
        library::toggle_pin(&id.to_string());
    }

    pub fn delete_playlist(&self, id: &QString) {
        library::delete_playlist(&id.to_string());
    }

    pub fn toggle_like(&self, track: &QString) -> bool {
        library::toggle_like(&parse(track))
    }

    pub fn import_text(self: Pin<&mut Self>, text: &QString, name: &QString) {
        run_import(self, text.to_string(), name.to_string());
    }

    pub fn import_file(self: Pin<&mut Self>, path: &QString) {
        let path = path.to_string();
        let path = path.strip_prefix("file:///").unwrap_or(&path).to_string();
        let name = std::path::Path::new(&path).file_stem().map(|s| s.to_string_lossy().into_owned()).unwrap_or_default();
        match std::fs::read_to_string(&path) {
            Ok(text) => {
                // A Cloudify share file is JSON; anything else is a song list.
                if let Ok(obj) = library::decode(&text) {
                    let res = library::import_payload(&obj);
                    let out = match res {
                        Ok(pl) => json!({"ok": true, "playlist": pl, "found": 0, "total": 0}),
                        Err(e) => json!({"ok": false, "error": e}),
                    };
                    self.import_done(q(&out.to_string()));
                } else {
                    run_import(self, text, name);
                }
            }
            Err(e) => self.import_done(q(&json!({"ok": false, "error": e.to_string()}).to_string())),
        }
    }

    pub fn import_code(&self, text: &QString) -> QString {
        let out = library::decode(&text.to_string()).and_then(|o| library::import_payload(&o));
        q(&match out {
            Ok(pl) => json!({"ok": true, "playlist": pl}),
            Err(e) => json!({"ok": false, "error": e}),
        }
        .to_string())
    }

    pub fn export_code(&self, id: &QString) -> QString {
        match library::playlist_payload(&id.to_string(), "weepingcloud") {
            Some(o) => q(&library::encode(&o, true)),
            None => q(""),
        }
    }

    pub fn export_file(&self, id: &QString, path: &QString) -> bool {
        let path = path.to_string();
        let path = path.strip_prefix("file:///").unwrap_or(&path);
        library::playlist_payload(&id.to_string(), "weepingcloud")
            .map(|o| std::fs::write(path, serde_json::to_vec(&o).unwrap_or_default()).is_ok())
            .unwrap_or(false)
    }
}

/// Match each wanted song with four parallel workers, then save the playlist.
fn run_import(this: Pin<&mut qobject::Backend>, text: String, name: String) {
    run_import_with(this, text, name, None)
}

type Loader = Box<dyn FnOnce() -> Result<library::Parsed, String> + Send>;

fn run_import_with(this: Pin<&mut qobject::Backend>, text: String, name: String, pre: Option<Loader>) {
    let qt = this.qt_thread();
    std::thread::spawn(move || {
        let fail = |msg: &str| {
            let out = json!({"ok": false, "error": msg}).to_string();
            let _ = qt.queue(move |mut b| b.as_mut().import_done(q(&out)));
        };
        let list = match pre {
            Some(load) => match load() {
                Ok(p) => p,
                Err(e) => return fail(&e),
            },
            None => {
                let first = text.lines().next().unwrap_or("");
                let mut list = if first.contains([',', ';', '\t']) { library::from_csv(&text) } else { None };
                if list.as_ref().map_or(true, |l| l.songs.is_empty()) {
                    list = Some(library::from_lines(&text));
                }
                list.unwrap()
            }
        };
        if list.songs.is_empty() {
            return fail("No songs found in that");
        }
        let songs: Vec<_> = list.songs.into_iter().take(3000).collect();
        let total = songs.len();
        let next = std::sync::atomic::AtomicUsize::new(0);
        let done = std::sync::atomic::AtomicUsize::new(0);
        let found: std::sync::Mutex<Vec<Option<Value>>> = std::sync::Mutex::new(vec![None; total]);
        std::thread::scope(|s| {
            for _ in 0..4 {
                s.spawn(|| loop {
                    let i = next.fetch_add(1, std::sync::atomic::Ordering::SeqCst);
                    if i >= total {
                        break;
                    }
                    let m = library::match_song(&songs[i]);
                    found.lock().unwrap()[i] = m;
                    let d = done.fetch_add(1, std::sync::atomic::Ordering::SeqCst) + 1;
                    let _ = qt.queue(move |mut b| b.as_mut().import_progress(d as i32, total as i32));
                });
            }
        });
        let mut seen = std::collections::HashSet::new();
        let tracks: Vec<Value> = found
            .into_inner()
            .unwrap()
            .into_iter()
            .flatten()
            .filter(|t| seen.insert(t["id"].as_str().unwrap_or("").to_string()))
            .collect();
        if tracks.is_empty() {
            return fail("None of those songs were found");
        }
        let n = tracks.len();
        let pname = [name.as_str(), list.name.as_str(), "Imported playlist"].into_iter().find(|s| !s.trim().is_empty()).unwrap();
        let pl = library::create_playlist(pname, tracks, &format!("Imported · {n} of {total} songs found"));
        let out = json!({"ok": true, "playlist": pl, "found": n, "total": total}).to_string();
        let _ = qt.queue(move |mut b| b.as_mut().import_done(q(&out)));
    });
}
