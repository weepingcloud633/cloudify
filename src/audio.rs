//! Playback: a dedicated audio thread decodes the cached file (symphonia, through rodio) and
//! plays it on WASAPI (cpal). No media framework, no web view: about 1% CPU while playing.
//!
//! The next song is opened ahead of time. With no crossfade it is queued on the same sink, so one
//! follows the other without a gap; with a crossfade it starts on a second sink while the first
//! fades out.
use crate::decoder::SymSource;
use crate::eq::Eq;
use crate::fx::{Counted, Norm, Stretch};
use crate::stream;
use rodio::cpal::traits::{DeviceTrait, HostTrait};
use rodio::{OutputStream, OutputStreamHandle, Sink, Source};
use std::sync::atomic::{AtomicBool, AtomicU32, AtomicU64, Ordering};
use std::sync::mpsc::{channel, RecvTimeoutError, Sender};
use std::sync::{Arc, Mutex, OnceLock};
use std::time::{Duration, Instant};

type Chain = Norm<Eq<Stretch<Counted<SymSource>>>>;

struct Opened {
    src: Chain,
    frames: Arc<AtomicU64>,
    dur: u64,
    rate: u32,
}

enum Cmd {
    Load(String),
    Preload(String),
    Preloaded(String, Result<Opened, String>),
    Loaded(u64, String, Result<Opened, String>),
    Play,
    Pause,
    Stop,
    Seek(u64),
    Volume(f32),
    Device(String),
}

struct Shared {
    position_ms: AtomicU64,
    duration_ms: AtomicU64,
    playing: AtomicBool,
    event: Mutex<String>, // "ended", "advanced:<id>" or "error: ..." until the UI reads it
}

static CROSSFADE_MS: AtomicU32 = AtomicU32::new(0);

fn shared() -> &'static Shared {
    static S: OnceLock<Shared> = OnceLock::new();
    S.get_or_init(|| Shared { position_ms: AtomicU64::new(0), duration_ms: AtomicU64::new(0), playing: AtomicBool::new(false), event: Mutex::new(String::new()) })
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
pub fn preload(vid: &str) {
    send(Cmd::Preload(vid.to_string()));
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
pub fn device(name: &str) {
    send(Cmd::Device(name.to_string()));
}
/// Seconds of overlap between songs; 0 turns the crossfade off (songs still follow without a gap).
pub fn set_crossfade(secs: f32) {
    CROSSFADE_MS.store((secs.clamp(0.0, 12.0) * 1000.0) as u32, Ordering::Relaxed);
}

/// Names of the output devices, default first.
pub fn devices() -> Vec<String> {
    let host = rodio::cpal::default_host();
    let mut v: Vec<String> = host.output_devices().map(|d| d.filter_map(|x| x.name().ok()).collect()).unwrap_or_default();
    if let Some(def) = host.default_output_device().and_then(|d| d.name().ok()) {
        v.retain(|n| *n != def);
        v.insert(0, def);
    }
    v
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

fn open(vid: &str) -> Result<Opened, String> {
    let track = match vid.strip_prefix("local:") {
        Some(path) => stream::local(path)?,
        None => stream::prepare(vid)?,
    };
    let src = SymSource::open(&track)?;
    let dur = src.total_duration().map(|d| d.as_millis() as u64).unwrap_or(0);
    let rate = src.sample_rate();
    let frames = Arc::new(AtomicU64::new(0));
    let chain = Norm::new(Eq::new(Stretch::new(Counted::new(src, frames.clone()))));
    Ok(Opened { src: chain, frames, dur, rate })
}

fn open_output(device: &str) -> Result<(OutputStream, OutputStreamHandle), String> {
    if !device.is_empty() {
        let host = rodio::cpal::default_host();
        if let Some(d) = host.output_devices().ok().and_then(|mut it| it.find(|d| d.name().map(|n| n == device).unwrap_or(false))) {
            if let Ok(o) = OutputStream::try_from_device(&d) {
                return Ok(o);
            }
        }
    }
    OutputStream::try_default().map_err(|e| format!("error: no audio device ({e})"))
}

/// What is playing on the main sink.
struct Playing {
    sink: Sink,
    vid: String,
    frames: Arc<AtomicU64>,
    dur: u64,
    rate: u32,
}

struct Queued {
    vid: String,
    frames: Arc<AtomicU64>,
    dur: u64,
    rate: u32,
}

struct Fade {
    old: Sink,
    started: Instant,
    ms: u64,
}

fn event(e: String) {
    *shared().event.lock().unwrap() = e;
}

fn run(rx: std::sync::mpsc::Receiver<Cmd>) {
    let s = shared();
    let mut dev = crate::settings::get()["outputDevice"].as_str().unwrap_or("").to_string();
    let mut out: Option<(OutputStream, OutputStreamHandle)> = None;
    let mut cur: Option<Playing> = None;
    let mut queued: Option<Queued> = None; // already appended to cur's sink
    let mut next: Option<(String, Opened)> = None; // opened, waiting for its moment
    let mut want_next = String::new();
    let mut fade: Option<Fade> = None;
    let mut vol = 0.8f32;
    let mut paused = false;
    let mut reported_end = false;
    let mut load_gen = 0u64;
    let tx_self = tx().lock().unwrap().clone();
    // unplugged / switched output devices: watch the device list, and a sink that stops consuming
    let mut snap = devices();
    let mut last_check = Instant::now();
    let mut last_frames = 0u64;
    let mut last_move = Instant::now();

    loop {
        // wake more often right before a hand-over so a gapless one stays gapless
        let near_end = cur.as_ref().is_some_and(|p| p.dur > 0 && p.dur.saturating_sub(p.frames.load(Ordering::Relaxed) * 1000 / p.rate.max(1) as u64) < 1500);
        match rx.recv_timeout(Duration::from_millis(if near_end { 12 } else { 50 })) {
            Ok(Cmd::Load(vid)) => {
                if let Some(old) = cur.take() {
                    old.sink.stop();
                }
                if let Some(f) = fade.take() {
                    f.old.stop();
                }
                queued = None;
                s.position_ms.store(0, Ordering::Relaxed);
                s.playing.store(false, Ordering::Relaxed);
                reported_end = false;
                paused = false;
                if out.is_none() {
                    match open_output(&dev) {
                        Ok(o) => out = Some(o),
                        Err(e) => {
                            event(e);
                            continue;
                        }
                    }
                }
                // opened off this thread: a slow or stuck lookup must not freeze next/previous/pause
                load_gen += 1;
                let gen = load_gen;
                match next.take() {
                    Some((v, o)) if v == vid => {
                        let _ = tx_self.send(Cmd::Loaded(gen, vid, Ok(o)));
                    }
                    other => {
                        next = other;
                        let tx2 = tx_self.clone();
                        std::thread::spawn(move || {
                            let r = open(&vid);
                            let _ = tx2.send(Cmd::Loaded(gen, vid, r));
                        });
                    }
                }
            }
            Ok(Cmd::Loaded(gen, vid, res)) => {
                if gen != load_gen {
                    continue; // a newer Load or a Stop came in meanwhile
                }
                match res {
                    Ok(o) => match Sink::try_new(&out.as_ref().unwrap().1) {
                        Ok(sk) => {
                            sk.set_volume(vol);
                            sk.append(o.src);
                            s.duration_ms.store(o.dur, Ordering::Relaxed);
                            cur = Some(Playing { sink: sk, vid, frames: o.frames, dur: o.dur, rate: o.rate });
                        }
                        Err(e) => event(format!("error: {e}")),
                    },
                    Err(e) => event(if e.starts_with("error") { e } else { format!("error: {e}") }),
                }
            }
            Ok(Cmd::Preload(vid)) => {
                if want_next != vid {
                    want_next = vid.clone();
                    next = None;
                    let tx2 = tx_self.clone();
                    std::thread::spawn(move || {
                        let r = open(&vid);
                        let _ = tx2.send(Cmd::Preloaded(vid, r));
                    });
                }
            }
            Ok(Cmd::Preloaded(vid, res)) => {
                if vid == want_next {
                    if let Ok(o) = res {
                        next = Some((vid, o));
                    }
                }
            }
            Ok(Cmd::Play) => {
                paused = false;
                if let Some(p) = &cur {
                    p.sink.play();
                }
                if let Some(f) = &fade {
                    f.old.play();
                }
            }
            Ok(Cmd::Pause) => {
                paused = true;
                if let Some(p) = &cur {
                    p.sink.pause();
                }
                if let Some(f) = &fade {
                    f.old.pause();
                }
            }
            Ok(Cmd::Stop) => {
                load_gen += 1;
                if let Some(p) = cur.take() {
                    p.sink.stop();
                }
                if let Some(f) = fade.take() {
                    f.old.stop();
                }
                queued = None;
                s.playing.store(false, Ordering::Relaxed);
                s.position_ms.store(0, Ordering::Relaxed);
            }
            Ok(Cmd::Seek(ms)) => {
                if let Some(p) = &cur {
                    let r = p.sink.try_seek(Duration::from_millis(ms));
                    if r.is_ok() {
                        s.position_ms.store(ms, Ordering::Relaxed);
                        reported_end = false;
                    }
                }
            }
            Ok(Cmd::Volume(v)) => {
                vol = v.clamp(0.0, 1.0);
                if let (Some(p), None) = (&cur, &fade) {
                    p.sink.set_volume(vol);
                }
            }
            Ok(Cmd::Device(name)) => {
                dev = name;
                // reopen the output and carry on from where the song was
                if let Some(p) = cur.take() {
                    let pos = p.frames.load(Ordering::Relaxed) * 1000 / p.rate.max(1) as u64;
                    let vid = p.vid.clone();
                    p.sink.stop();
                    if let Some(f) = fade.take() {
                        f.old.stop();
                    }
                    queued = None;
                    out = None;
                    let opened_out = open_output(&dev);
                    if let Err(e) = &opened_out {
                        event(e.clone());
                    }
                    if let Ok(o) = opened_out {
                        out = Some(o);
                        if let Ok(o2) = open(&vid) {
                            if let Ok(sk) = Sink::try_new(&out.as_ref().unwrap().1) {
                                sk.set_volume(vol);
                                sk.append(o2.src);
                                let _ = sk.try_seek(Duration::from_millis(pos));
                                if paused {
                                    sk.pause();
                                }
                                cur = Some(Playing { sink: sk, vid, frames: o2.frames, dur: o2.dur, rate: o2.rate });
                            }
                        }
                    }
                } else {
                    out = None;
                }
            }
            Err(RecvTimeoutError::Timeout) => {}
            Err(RecvTimeoutError::Disconnected) => break,
        }

        // ---- output device watch ----
        if last_check.elapsed() >= Duration::from_secs(2) {
            last_check = Instant::now();
            let list = devices();
            let gone = !dev.is_empty() && snap.contains(&dev) && !list.contains(&dev);
            let back = !dev.is_empty() && !snap.contains(&dev) && list.contains(&dev);
            let new_default = dev.is_empty() && list.first() != snap.first();
            snap = list;
            if (gone || back || new_default) && out.is_some() {
                let _ = tx_self.send(Cmd::Device(dev.clone()));
            }
        }
        if let Some(p) = &cur {
            let f = p.frames.load(Ordering::Relaxed);
            if f != last_frames || paused || p.sink.empty() {
                last_frames = f;
                last_move = Instant::now();
            } else if last_move.elapsed() >= Duration::from_secs(4) {
                // the sink is not consuming audio (device gone without a notice): reopen the output
                last_move = Instant::now();
                let _ = tx_self.send(Cmd::Device(dev.clone()));
            }
        }

        // ---- the crossfade in progress ----
        if let Some(f) = &fade {
            let t = (f.started.elapsed().as_millis() as f32 / f.ms.max(1) as f32).min(1.0);
            let (fin, fout) = ((t * std::f32::consts::FRAC_PI_2).sin(), (t * std::f32::consts::FRAC_PI_2).cos());
            f.old.set_volume(vol * fout);
            if let Some(p) = &cur {
                p.sink.set_volume(vol * fin);
            }
            if t >= 1.0 {
                if let Some(f) = fade.take() {
                    f.old.stop();
                }
                if let Some(p) = &cur {
                    p.sink.set_volume(vol);
                }
            }
        }

        if let Some(p) = &cur {
            let pos = p.frames.load(Ordering::Relaxed) * 1000 / p.rate.max(1) as u64;
            s.position_ms.store(pos, Ordering::Relaxed);

            // a follow-up queued on this sink has started
            if queued.is_some() {
                if p.sink.len() < 2 {
                    let q = queued.take().unwrap();
                    event(format!("advanced:{}", q.vid));
                    s.duration_ms.store(q.dur, Ordering::Relaxed);
                    if let Some(pl) = cur.as_mut() {
                        pl.vid = q.vid;
                        pl.frames = q.frames;
                        pl.dur = q.dur;
                        pl.rate = q.rate;
                    }
                    reported_end = false;
                    continue;
                }
            }

            // the next song is ready: queue it, or start the crossfade when its time comes
            if queued.is_none() && fade.is_none() {
                let xf = CROSSFADE_MS.load(Ordering::Relaxed) as u64;
                let remaining = p.dur.saturating_sub(pos);
                if next.as_ref().is_some_and(|(v, _)| *v == want_next) {
                    if xf == 0 || p.dur < xf * 2 + 1000 {
                        // queued only in the last few seconds, so a change of mind (the queue was edited) still counts
                        if remaining > 5000 && p.dur > 0 {
                            // not yet
                        } else if let Some((vid, o)) = next.take() {
                            p.sink.append(o.src);
                            queued = Some(Queued { vid, frames: o.frames, dur: o.dur, rate: o.rate });
                        }
                    } else if remaining <= xf && p.dur > 0 && !paused {
                        if let (Some((vid, o)), Some((_, handle))) = (next.take(), out.as_ref()) {
                            if let Ok(sk) = Sink::try_new(handle) {
                                sk.set_volume(0.0);
                                sk.append(o.src);
                                s.duration_ms.store(o.dur, Ordering::Relaxed);
                                event(format!("advanced:{vid}"));
                                let old = std::mem::replace(&mut cur, Some(Playing { sink: sk, vid, frames: o.frames, dur: o.dur, rate: o.rate })).unwrap();
                                fade = Some(Fade { old: old.sink, started: Instant::now(), ms: xf });
                                reported_end = false;
                                continue;
                            }
                        }
                    }
                }
            }

            s.playing.store(!p.sink.empty() && !p.sink.is_paused(), Ordering::Relaxed);
            if p.sink.empty() && !reported_end && queued.is_none() && fade.is_none() {
                reported_end = true;
                event("ended".into());
            }
        }
    }
}
