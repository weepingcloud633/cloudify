//! Resolve a track, download it into the cache while it plays, and serve byte ranges
//! out of the growing file on 127.0.0.1 (same design as Silva Music).
use crate::{paths, ytdlp};
use std::collections::HashMap;
use std::fs::{self, File};
use std::io::{Read, Seek, SeekFrom, Write};
use std::path::PathBuf;
use std::sync::{Arc, Condvar, Mutex, OnceLock};
use std::time::{Duration, Instant};

const CHUNK: u64 = 4 * 1024 * 1024;
/// (bytes, files) of audio in the cache.
pub fn cache_usage() -> (u64, usize) {
    let Ok(rd) = fs::read_dir(audio_dir()) else { return (0, 0) };
    rd.flatten()
        .filter(|e| e.path().extension().is_some_and(|x| x != "ok"))
        .filter_map(|e| e.metadata().ok())
        .fold((0, 0), |(b, n), m| (b + m.len(), n + 1))
}

/// Delete cached audio that is not being played right now; returns the bytes freed.
pub fn clear_cache() -> u64 {
    let Ok(rd) = fs::read_dir(audio_dir()) else { return 0 };
    let mut freed = 0;
    for e in rd.flatten() {
        let p = e.path();
        let busy = tracks().lock().unwrap().values().any(|t| {
            let tp = t.path.lock().unwrap().clone();
            p == tp || p == PathBuf::from(format!("{}.ok", tp.display()))
        });
        if busy {
            continue;
        }
        freed += e.metadata().map(|m| m.len()).unwrap_or(0);
        let _ = fs::remove_file(&p);
    }
    // forget finished entries so a cleared track is fetched again
    tracks().lock().unwrap().retain(|_, t| !t.st.lock().unwrap().done || fs::metadata(&*t.path.lock().unwrap()).is_ok());
    freed
}

#[derive(Default)]
struct State {
    url: String,
    headers: Vec<(String, String)>,
    size: u64,
    ext: String,
    have: u64,
    done: bool,
    started: bool,
    err: Option<String>,
}

pub struct Track {
    vid: String,
    path: Mutex<PathBuf>,
    st: Mutex<State>,
    cv: Condvar,
}

fn tracks() -> &'static Mutex<HashMap<String, Arc<Track>>> {
    static T: OnceLock<Mutex<HashMap<String, Arc<Track>>>> = OnceLock::new();
    T.get_or_init(Default::default)
}

fn audio_dir() -> PathBuf {
    paths::dir("cache/audio")
}

fn mime(ext: &str) -> &'static str {
    match ext {
        "webm" => "audio/webm",
        "opus" => "audio/ogg",
        "mp3" => "audio/mpeg",
        _ => "audio/mp4",
    }
}

fn safe_id(v: &str) -> bool {
    !v.is_empty() && v.len() <= 20 && v.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'_' || b == b'-')
}

/// Get ready to play `vid`: use the cache, or resolve and start downloading.
/// A music file on this computer, as a finished track.
pub fn local(path: &str) -> Result<Arc<Track>, String> {
    let p = PathBuf::from(path);
    let md = fs::metadata(&p).map_err(|e| format!("error: cannot open the file ({e})"))?;
    let ext = p.extension().map(|e| e.to_string_lossy().to_lowercase()).unwrap_or_default();
    let mut st = State::default();
    st.size = md.len();
    st.have = md.len();
    st.done = true;
    st.ext = ext;
    Ok(Arc::new(Track { vid: "local".into(), path: Mutex::new(p), st: Mutex::new(st), cv: Condvar::new() }))
}

impl Track {
    /// The file extension, for the decoder's format hint.
    pub fn extension(&self) -> String {
        self.st.lock().unwrap().ext.clone()
    }
}

pub fn prepare(vid: &str) -> Result<Arc<Track>, String> {
    if !safe_id(vid) {
        return Err("bad id".into());
    }
    let t = {
        let mut map = tracks().lock().unwrap();
        map.entry(vid.to_string())
            .or_insert_with(|| {
                Arc::new(Track {
                    vid: vid.into(),
                    path: Mutex::new(PathBuf::new()),
                    st: Mutex::new(State::default()),
                    cv: Condvar::new(),
                })
            })
            .clone()
    };
    {
        let mut st = t.st.lock().unwrap();
        if st.done || st.started {
            return Ok(t.clone());
        }
        if let Some((p, ext)) = cached(vid) {
            st.size = fs::metadata(&p).map(|m| m.len()).unwrap_or(0);
            st.have = st.size;
            st.ext = ext;
            st.done = true;
            *t.path.lock().unwrap() = p;
            return Ok(t.clone());
        }
        st.started = true;
    }
    let fail = |t: &Arc<Track>, e: String| {
        t.st.lock().unwrap().started = false;
        e
    };
    let r = resolve_cached(vid).map_err(|e| fail(&t, e))?;
    // yt-dlp already reports the size; only ask the server when it did not
    let size = if r.size > 0 {
        r.size
    } else {
        let (size, code) = verify(&r).map_err(|e| fail(&t, e))?;
        if size == 0 {
            return Err(fail(&t, format!("Stream refused (HTTP {code})")));
        }
        size
    };
    let path = audio_dir().join(format!("{vid}.{}", r.ext));
    {
        let mut st = t.st.lock().unwrap();
        st.url = r.url;
        st.headers = r.headers;
        st.size = size;
        st.ext = r.ext;
        st.have = 0;
        st.err = None;
    }
    *t.path.lock().unwrap() = path;
    let t2 = t.clone();
    std::thread::spawn(move || download(t2));
    Ok(t)
}

fn cached(vid: &str) -> Option<(PathBuf, String)> {
    for ext in ["m4a", "webm", "mp4"] {
        let p = audio_dir().join(format!("{vid}.{ext}"));
        if p.is_file() && PathBuf::from(format!("{}.ok", p.display())).is_file() {
            return Some((p, ext.into()));
        }
    }
    None
}

fn req(url: &str, headers: &[(String, String)], range: (u64, u64)) -> Result<ureq::Response, String> {
    let mut r = ureq::get(url).timeout(Duration::from_secs(30));
    for (k, v) in headers {
        if !k.eq_ignore_ascii_case("range") {
            r = r.set(k, v);
        }
    }
    r.set("Range", &format!("bytes={}-{}", range.0, range.1))
        .call()
        .map_err(|e| e.to_string())
}

fn verify(r: &ytdlp::Resolved) -> Result<(u64, u16), String> {
    let resp = req(&r.url, &r.headers, (0, 1))?;
    let size = resp
        .header("Content-Range")
        .and_then(|c| c.rsplit('/').next())
        .and_then(|s| s.parse().ok())
        .unwrap_or(r.size);
    Ok((size, resp.status()))
}

fn download(t: Arc<Track>) {
    let (mut url, mut headers, size) = {
        let s = t.st.lock().unwrap();
        (s.url.clone(), s.headers.clone(), s.size)
    };
    let path = t.path.lock().unwrap().clone();
    let Ok(mut f) = File::create(&path) else { return };
    let mut pos = 0u64;
    let mut tries = 0u64;
    while pos < size {
        let end = (pos + CHUNK).min(size) - 1;
        let res = req(&url, &headers, (pos, end)).and_then(|resp| {
            let mut rd = resp.into_reader();
            let mut buf = [0u8; 65536];
            let mut got = 0u64;
            loop {
                let n = rd.read(&mut buf).map_err(|e| e.to_string())?;
                if n == 0 {
                    break;
                }
                f.write_all(&buf[..n]).map_err(|e| e.to_string())?;
                f.flush().ok();
                got += n as u64;
                pos += n as u64;
                t.st.lock().unwrap().have = pos;
                t.cv.notify_all();
            }
            if got == 0 {
                Err("empty reply".to_string())
            } else {
                Ok(())
            }
        });
        if let Err(e) = res {
            tries += 1;
            if tries > 4 {
                let mut st = t.st.lock().unwrap();
                st.err = Some(format!("Download failed: {e}"));
                st.started = false;
                t.cv.notify_all();
                let _ = fs::remove_file(&path);
                return;
            }
            std::thread::sleep(Duration::from_millis(600 * tries));
            if tries >= 1 {
                RESOLVED.lock().unwrap().as_mut().map(|m| m.remove(&t.vid));
                if let Ok(r) = resolve_cached(&t.vid) {
                    url = r.url;
                    headers = r.headers;
                }
            }
            let _ = f.seek(SeekFrom::Start(pos));
        }
    }
    let _ = fs::write(format!("{}.ok", path.display()), size.to_string());
    {
        let mut st = t.st.lock().unwrap();
        st.done = true;
        t.cv.notify_all();
    }
    trim();
}

/// Delete the oldest cached files when the cache grows past the limit.
fn trim() {
    let Ok(rd) = fs::read_dir(audio_dir()) else { return };
    let mut files: Vec<_> = rd
        .flatten()
        .filter(|e| e.path().extension().is_some_and(|x| x != "ok"))
        .filter_map(|e| {
            let m = e.metadata().ok()?;
            Some((m.accessed().or(m.modified()).ok()?, m.len(), e.path()))
        })
        .collect();
    let mut total: u64 = files.iter().map(|f| f.1).sum();
    files.sort();
    for (_, len, p) in files {
        if total <= crate::settings::cache_limit_bytes() {
            break;
        }
        let busy = tracks()
            .lock()
            .unwrap()
            .values()
            .any(|t| *t.path.lock().unwrap() == p && !t.st.lock().unwrap().done);
        if !busy {
            let _ = fs::remove_file(&p);
            let _ = fs::remove_file(format!("{}.ok", p.display()));
            total -= len;
        }
    }
}

struct Reader {
    t: Arc<Track>,
    file: File,
    pos: u64,
    end: u64,
}

impl Read for Reader {
    fn read(&mut self, out: &mut [u8]) -> std::io::Result<usize> {
        if self.pos > self.end {
            return Ok(0);
        }
        let want = ((self.end - self.pos + 1) as usize).min(out.len());
        let deadline = Instant::now() + Duration::from_secs(30);
        let mut st = self.t.st.lock().unwrap();
        while st.have <= self.pos && !st.done && st.err.is_none() {
            let (g, _) = self.t.cv.wait_timeout(st, Duration::from_millis(500)).unwrap();
            st = g;
            if Instant::now() > deadline {
                return Err(std::io::Error::new(std::io::ErrorKind::TimedOut, "stalled"));
            }
        }
        let avail = st.have.saturating_sub(self.pos) as usize;
        drop(st);
        if avail == 0 {
            return Ok(0);
        }
        self.file.seek(SeekFrom::Start(self.pos))?;
        let n = self.file.read(&mut out[..want.min(avail)])?;
        self.pos += n as u64;
        Ok(n)
    }
}

/// Start the local range server; returns its port.
pub fn serve() -> u16 {
    let server = tiny_http::Server::http("127.0.0.1:0").expect("local server");
    let port = server.server_addr().to_ip().map(|a| a.port()).unwrap_or(0);
    std::thread::spawn(move || {
        for rq in server.incoming_requests() {
            std::thread::spawn(move || handle(rq));
        }
    });
    port
}

fn handle(rq: tiny_http::Request) {
    let vid = rq.url().trim_start_matches("/s/").split('?').next().unwrap_or("").to_string();
    let Some(t) = tracks().lock().unwrap().get(&vid).cloned() else {
        let _ = rq.respond(tiny_http::Response::empty(404));
        return;
    };
    let (size, ext) = {
        let st = t.st.lock().unwrap();
        (st.size, st.ext.clone())
    };
    if size == 0 {
        let _ = rq.respond(tiny_http::Response::empty(404));
        return;
    }
    let range = rq
        .headers()
        .iter()
        .find(|h| h.field.equiv("Range"))
        .and_then(|h| h.value.as_str().strip_prefix("bytes=").map(String::from));
    let (start, end, partial) = match range.as_deref().and_then(|r| r.split_once('-')) {
        Some((a, b)) => (a.parse().unwrap_or(0u64), b.parse().unwrap_or(size - 1).min(size - 1), true),
        None => (0, size - 1, false),
    };
    if start > end {
        let _ = rq.respond(tiny_http::Response::empty(416));
        return;
    }
    let path = t.path.lock().unwrap().clone();
    let Ok(file) = File::open(path) else {
        let _ = rq.respond(tiny_http::Response::empty(404));
        return;
    };
    let len = (end - start + 1) as usize;
    let rd = Reader { t, file, pos: start, end };
    let hdr = |k: &str, v: String| tiny_http::Header::from_bytes(k.as_bytes(), v.as_bytes()).unwrap();
    let resp = tiny_http::Response::new(
        tiny_http::StatusCode(if partial { 206 } else { 200 }),
        vec![
            hdr("Content-Type", mime(&ext).into()),
            hdr("Accept-Ranges", "bytes".into()),
            hdr("Content-Range", format!("bytes {start}-{end}/{size}")),
        ],
        rd,
        Some(len),
        None,
    );
    let _ = rq.respond(resp);
}

/// A file that is still being downloaded, readable and seekable for the decoder: reads wait for
/// the bytes to arrive, seeks never wait.
pub struct GrowingFile {
    t: Arc<Track>,
    file: File,
    pos: u64,
    size: u64,
}

impl GrowingFile {
    pub fn len(&self) -> u64 {
        self.size
    }

    pub fn open(t: &Arc<Track>) -> Result<Self, String> {
        // the file exists as soon as the download thread creates it
        let deadline = Instant::now() + Duration::from_secs(20);
        loop {
            let path = t.path.lock().unwrap().clone();
            if path.is_file() {
                let size = t.st.lock().unwrap().size;
                let file = File::open(&path).map_err(|e| e.to_string())?;
                return Ok(GrowingFile { t: t.clone(), file, pos: 0, size });
            }
            if Instant::now() > deadline {
                return Err("The track did not start downloading".into());
            }
            std::thread::sleep(Duration::from_millis(50));
        }
    }
}

impl Read for GrowingFile {
    fn read(&mut self, out: &mut [u8]) -> std::io::Result<usize> {
        if self.pos >= self.size || out.is_empty() {
            return Ok(0);
        }
        let deadline = Instant::now() + Duration::from_secs(30);
        let mut st = self.t.st.lock().unwrap();
        while st.have <= self.pos && !st.done && st.err.is_none() {
            st = self.t.cv.wait_timeout(st, Duration::from_millis(300)).unwrap().0;
            if Instant::now() > deadline {
                return Err(std::io::Error::new(std::io::ErrorKind::TimedOut, "stalled"));
            }
        }
        let avail = st.have.saturating_sub(self.pos) as usize;
        drop(st);
        if avail == 0 {
            return Ok(0);
        }
        self.file.seek(SeekFrom::Start(self.pos))?;
        let take = out.len().min(avail);
        let n = self.file.read(&mut out[..take])?;
        self.pos += n as u64;
        Ok(n)
    }
}

impl Seek for GrowingFile {
    fn seek(&mut self, to: SeekFrom) -> std::io::Result<u64> {
        let p = match to {
            SeekFrom::Start(n) => n as i64,
            SeekFrom::End(n) => self.size as i64 + n,
            SeekFrom::Current(n) => self.pos as i64 + n,
        };
        if p < 0 {
            return Err(std::io::Error::new(std::io::ErrorKind::InvalidInput, "seek before start"));
        }
        self.pos = p as u64;
        Ok(self.pos)
    }
}

/// Block until the track is fully cached; returns its file and extension.
pub fn wait_done(t: &Arc<Track>) -> Result<(PathBuf, String), String> {
    let mut st = t.st.lock().unwrap();
    let deadline = Instant::now() + Duration::from_secs(600);
    while !st.done {
        if let Some(e) = &st.err {
            return Err(e.clone());
        }
        if Instant::now() > deadline {
            return Err("Download timed out".into());
        }
        st = t.cv.wait_timeout(st, Duration::from_millis(500)).unwrap().0;
    }
    Ok((t.path.lock().unwrap().clone(), st.ext.clone()))
}

// ---- resolved stream URLs, kept for 3 hours and fetched ahead of time ----

static RESOLVED: Mutex<Option<HashMap<String, (ytdlp::Resolved, Instant)>>> = Mutex::new(None);
static INFLIGHT: Mutex<Option<std::collections::HashSet<String>>> = Mutex::new(None);

fn cache_get(vid: &str) -> Option<ytdlp::Resolved> {
    let g = RESOLVED.lock().unwrap();
    g.as_ref()?.get(vid).filter(|(_, at)| at.elapsed() < Duration::from_secs(3 * 3600)).map(|(r, _)| r.clone())
}

/// Resolve once per track; concurrent callers wait for the first one.
fn resolve_cached(vid: &str) -> Result<ytdlp::Resolved, String> {
    loop {
        if let Some(r) = cache_get(vid) {
            return Ok(r);
        }
        let mine = INFLIGHT.lock().unwrap().get_or_insert_with(Default::default).insert(vid.to_string());
        if mine {
            let res = ytdlp::resolve(vid);
            INFLIGHT.lock().unwrap().as_mut().map(|s| s.remove(vid));
            if let Ok(r) = &res {
                let mut g = RESOLVED.lock().unwrap();
                let m = g.get_or_insert_with(Default::default);
                if m.len() > 200 {
                    m.clear();
                }
                m.insert(vid.to_string(), (r.clone(), Instant::now()));
            }
            return res;
        }
        std::thread::sleep(Duration::from_millis(40));
    }
}

/// Look up a track's stream in the background so playing it later starts at once.
pub fn prefetch(vid: &str) {
    if !safe_id(vid) || cached(vid).is_some() || cache_get(vid).is_some() {
        return;
    }
    let v = vid.to_string();
    std::thread::spawn(move || {
        let _ = resolve_cached(&v);
    });
}
