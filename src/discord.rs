//! Discord Rich Presence over Discord's local pipe (`\\.\pipe\discord-ipc-N`).
//! It needs the Application ID of a Discord application the user created.
use serde_json::{json, Value};
use std::fs::{File, OpenOptions};
use std::io::{Read, Write};
use std::sync::mpsc::{channel, Sender};
use std::sync::{Mutex, OnceLock};
use std::time::Duration;

pub struct Presence {
    pub app_id: String,
    pub title: String,
    pub artist: String,
    pub start_unix: u64,
    pub end_unix: u64,
    pub clear: bool,
}

fn tx() -> &'static Mutex<Sender<Presence>> {
    static T: OnceLock<Mutex<Sender<Presence>>> = OnceLock::new();
    T.get_or_init(|| {
        let (tx, rx) = channel::<Presence>();
        std::thread::Builder::new()
            .name("discord".into())
            .spawn(move || {
                let mut pipe: Option<(File, String)> = None;
                let mut next_try = std::time::Instant::now();
                while let Ok(mut p) = rx.recv() {
                    // only the latest update matters
                    while let Ok(newer) = rx.try_recv() {
                        p = newer;
                    }
                    if p.app_id.is_empty() {
                        pipe = None;
                        continue;
                    }
                    if pipe.as_ref().map(|(_, id)| id != &p.app_id).unwrap_or(true) && std::time::Instant::now() >= next_try {
                        pipe = connect(&p.app_id).map(|f| (f, p.app_id.clone()));
                        if pipe.is_none() {
                            next_try = std::time::Instant::now() + Duration::from_secs(15);
                        }
                    }
                    if let Some((f, _)) = pipe.as_mut() {
                        if send(f, &p).is_err() {
                            pipe = None;
                        }
                    }
                }
            })
            .expect("discord thread");
        Mutex::new(tx)
    })
}

fn frame(op: u32, v: &Value) -> Vec<u8> {
    let body = v.to_string();
    let mut out = Vec::with_capacity(8 + body.len());
    out.extend_from_slice(&op.to_le_bytes());
    out.extend_from_slice(&(body.len() as u32).to_le_bytes());
    out.extend_from_slice(body.as_bytes());
    out
}

fn connect(app_id: &str) -> Option<File> {
    for n in 0..10 {
        let Ok(mut f) = OpenOptions::new().read(true).write(true).open(format!(r"\\.\pipe\discord-ipc-{n}")) else { continue };
        if f.write_all(&frame(0, &json!({"v": 1, "client_id": app_id}))).is_err() {
            continue;
        }
        // Discord answers the handshake; a reader thread then keeps the pipe drained
        let mut head = [0u8; 8];
        if f.read_exact(&mut head).is_err() {
            continue;
        }
        let len = u32::from_le_bytes([head[4], head[5], head[6], head[7]]) as usize;
        let mut body = vec![0u8; len.min(65536)];
        let _ = f.read_exact(&mut body);
        if let Ok(mut r) = f.try_clone() {
            std::thread::spawn(move || {
                let mut buf = [0u8; 4096];
                while r.read(&mut buf).map(|n| n > 0).unwrap_or(false) {}
            });
        }
        return Some(f);
    }
    None
}

fn send(f: &mut File, p: &Presence) -> std::io::Result<()> {
    let activity = if p.clear {
        Value::Null
    } else {
        let mut a = json!({"type": 2, "details": p.title.chars().take(120).collect::<String>(), "state": p.artist.chars().take(120).collect::<String>(), "assets": {"large_image": "cloudify", "large_text": "Cloudify"}});
        if p.start_unix > 0 {
            a["timestamps"] = if p.end_unix > 0 { json!({"start": p.start_unix, "end": p.end_unix}) } else { json!({"start": p.start_unix}) };
        }
        a
    };
    let nonce = format!("{:x}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_nanos()).unwrap_or(0));
    f.write_all(&frame(1, &json!({"cmd": "SET_ACTIVITY", "args": {"pid": std::process::id(), "activity": activity}, "nonce": nonce})))
}

static STARTED: std::sync::atomic::AtomicBool = std::sync::atomic::AtomicBool::new(false);

pub fn update(p: Presence) {
    // nothing to do (and no thread to start) while Rich Presence is off
    if p.app_id.is_empty() && !STARTED.load(std::sync::atomic::Ordering::Relaxed) {
        return;
    }
    STARTED.store(true, std::sync::atomic::Ordering::Relaxed);
    let _ = tx().lock().unwrap().send(p);
}
