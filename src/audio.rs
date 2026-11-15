//! Playback: a dedicated audio thread decodes the cached file (symphonia, through rodio) and
//! plays it on WASAPI (cpal). No media framework, no web view: about 1% CPU while playing.
use crate::decoder::SymSource;
use crate::stream;
use rodio::{OutputStream, OutputStreamHandle, Sink, Source};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::mpsc::{channel, RecvTimeoutError, Sender};
use std::sync::{Mutex, OnceLock};
use std::time::Duration;

enum Cmd {
    Load(String),
    Play,
    Pause,
    Stop,
    Seek(u64),
    Volume(f32),
}

struct Shared {
    position_ms: AtomicU64,
    duration_ms: AtomicU64,
    playing: AtomicBool,
    event: Mutex<String>, // "ended" or "error: ..." until the UI reads it
}

fn shared() -> &'static Shared {
    static S: OnceLock<Shared> = OnceLock::new();
    S.get_or_init(|| Shared {
        position_ms: AtomicU64::new(0),
        duration_ms: AtomicU64::new(0),
        playing: AtomicBool::new(false),
        event: Mutex::new(String::new()),
    })
}

fn tx() -> &'static Mutex<Sender<Cmd>> {
    static T: OnceLock<Mutex<Sender<Cmd>>> = OnceLock::new();
    T.get_or_init(|| {
        let (tx, rx) = channel();
        std::thread::Builder::new().name("audio".into()).spawn(move || run(rx)).expect("audio thread");
        Mutex::new(tx)
    })
}

fn send(c: Cmd) {
    let _ = tx().lock().unwrap().send(c);
}

pub fn load(vid: &str) {
    send(Cmd::Load(vid.to_string()));
}
pub fn play() {
    send(Cmd::Play);
}
pub fn pause() {
    send(Cmd::Pause);
}
pub fn stop() {
    send(Cmd::Stop);
}
pub fn seek(ms: u64) {
    send(Cmd::Seek(ms));
}
pub fn volume(v: f32) {
    send(Cmd::Volume(v));
}

/// `{"pos": ms, "dur": ms, "playing": bool, "event": ""}`; an event is reported once.
pub fn poll() -> String {
    let s = shared();
    let ev = std::mem::take(&mut *s.event.lock().unwrap());
    format!(
        "{{\"pos\":{},\"dur\":{},\"playing\":{},\"event\":{}}}",
        s.position_ms.load(Ordering::Relaxed),
        s.duration_ms.load(Ordering::Relaxed),
        s.playing.load(Ordering::Relaxed),
        serde_json::Value::String(ev)
    )
}

fn open(vid: &str) -> Result<(crate::eq::Eq<SymSource>, u64), String> {
    let track = match vid.strip_prefix("local:") {
        Some(path) => stream::local(path)?,
        None => stream::prepare(vid)?,
    };
    let src = SymSource::open(&track)?;
    let dur = src.total_duration().map(|d| d.as_millis() as u64).unwrap_or(0);
    Ok((crate::eq::Eq::new(src), dur))
}

fn run(rx: std::sync::mpsc::Receiver<Cmd>) {
    let s = shared();
    let mut out: Option<(OutputStream, OutputStreamHandle)> = None;
    let mut sink: Option<Sink> = None;
    let mut vol = 0.8f32;
    let mut loaded = false;
    let mut reported_end = false;

    loop {
        match rx.recv_timeout(Duration::from_millis(60)) {
            Ok(Cmd::Load(vid)) => {
                if let Some(old) = sink.take() {
                    old.stop();
                }
                s.position_ms.store(0, Ordering::Relaxed);
                s.playing.store(false, Ordering::Relaxed);
                loaded = false;
                reported_end = false;
                if out.is_none() {
                    match OutputStream::try_default() {
                        Ok(o) => out = Some(o),
                        Err(e) => {
                            *s.event.lock().unwrap() = format!("error: no audio device ({e})");
                            continue;
                        }
                    }
                }
                match open(&vid) {
                    Ok((dec, dur)) => {
                        let handle = &out.as_ref().unwrap().1;
                        match Sink::try_new(handle) {
                            Ok(sk) => {
                                sk.set_volume(vol);
                                sk.append(dec);
                                s.duration_ms.store(dur, Ordering::Relaxed);
                                sink = Some(sk);
                                loaded = true;
                            }
                            Err(e) => *s.event.lock().unwrap() = format!("error: {e}"),
                        }
                    }
                    Err(e) => *s.event.lock().unwrap() = if e.starts_with("error") { e } else { format!("error: {e}") },
                }
            }
            Ok(Cmd::Play) => {
                if let Some(sk) = &sink {
                    sk.play();
                }
            }
            Ok(Cmd::Pause) => {
                if let Some(sk) = &sink {
                    sk.pause();
                }
            }
            Ok(Cmd::Stop) => {
                if let Some(sk) = sink.take() {
                    sk.stop();
                }
                loaded = false;
                s.playing.store(false, Ordering::Relaxed);
                s.position_ms.store(0, Ordering::Relaxed);
            }
            Ok(Cmd::Seek(ms)) => {
                if let Some(sk) = &sink {
                    if sk.try_seek(Duration::from_millis(ms)).is_ok() {
                        s.position_ms.store(ms, Ordering::Relaxed);
                        reported_end = false;
                    }
                }
            }
            Ok(Cmd::Volume(v)) => {
                vol = v.clamp(0.0, 1.0);
                if let Some(sk) = &sink {
                    sk.set_volume(vol);
                }
            }
            Err(RecvTimeoutError::Timeout) => {}
            Err(RecvTimeoutError::Disconnected) => break,
        }

        if let Some(sk) = &sink {
            s.position_ms.store(sk.get_pos().as_millis() as u64, Ordering::Relaxed);
            let empty = sk.empty();
            s.playing.store(loaded && !empty && !sk.is_paused(), Ordering::Relaxed);
            if loaded && empty && !reported_end {
                reported_end = true;
                *s.event.lock().unwrap() = "ended".into();
            }
        }
    }
}
