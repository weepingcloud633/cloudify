//! The yt-dlp helper: downloaded on first run (SHA-256 checked), then asked for direct audio URLs.
use crate::paths;
use serde_json::Value;
use sha2::{Digest, Sha256};
use std::io::Read;
use std::os::windows::process::CommandExt;
use std::path::PathBuf;
use std::process::Command;

const BASE: &str = "https://github.com/yt-dlp/yt-dlp/releases/latest/download/";
const NO_WINDOW: u32 = 0x0800_0000;

#[derive(Clone)]
pub struct Resolved {
    pub url: String,
    pub headers: Vec<(String, String)>,
    pub size: u64,
    pub ext: String,
}

fn exe() -> PathBuf {
    paths::dir("tools").join("yt-dlp.exe")
}

fn get_bytes(url: &str) -> Result<Vec<u8>, String> {
    let mut buf = Vec::new();
    ureq::get(url)
        .call()
        .map_err(|e| format!("download failed: {e}"))?
        .into_reader()
        .take(200 * 1024 * 1024)
        .read_to_end(&mut buf)
        .map_err(|e| e.to_string())?;
    Ok(buf)
}

/// Make sure yt-dlp.exe exists and matches the published checksum.
pub fn ensure() -> Result<PathBuf, String> {
    let path = exe();
    if path.is_file() {
        return Ok(path);
    }
    install(&path)?;
    Ok(path)
}

fn sha_hex(data: &[u8]) -> String {
    Sha256::digest(data).iter().map(|b| format!("{b:02x}")).collect()
}

fn published_hash() -> Result<String, String> {
    let sums = String::from_utf8_lossy(&get_bytes(&format!("{BASE}SHA2-256SUMS"))?).into_owned();
    sums.lines()
        .find_map(|l| {
            let (h, n) = l.split_once(char::is_whitespace)?;
            (n.trim().trim_start_matches('*') == "yt-dlp.exe").then(|| h.to_lowercase())
        })
        .ok_or_else(|| "no checksum for yt-dlp.exe".to_string())
}

/// Download the latest yt-dlp.exe, check it against the published SHA-256, and put it in place.
fn install(path: &std::path::Path) -> Result<(), String> {
    let want = published_hash()?;
    let data = get_bytes(&format!("{BASE}yt-dlp.exe"))?;
    if sha_hex(&data) != want {
        return Err("yt-dlp checksum mismatch".into());
    }
    let tmp = path.with_extension("part");
    std::fs::write(&tmp, &data).map_err(|e| e.to_string())?;
    std::fs::rename(&tmp, path).map_err(|e| e.to_string())
}

pub fn version() -> String {
    let Ok(exe) = ensure() else { return String::new() };
    Command::new(exe)
        .arg("--version")
        .creation_flags(NO_WINDOW)
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
        .unwrap_or_default()
}

/// Keep yt-dlp current: compares the file's SHA-256 with the published one, at most once a day
/// unless `force`. Returns a short message for the settings page.
pub fn update(force: bool) -> Result<String, String> {
    let path = ensure()?;
    let stamp = paths::dir("tools").join(".checked");
    let now = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0);
    let last: u64 = std::fs::read_to_string(&stamp).ok().and_then(|s| s.trim().parse().ok()).unwrap_or(0);
    if !force && now.saturating_sub(last) < 24 * 3600 {
        return Ok("Checked today".into());
    }
    let want = published_hash()?;
    let have = sha_hex(&std::fs::read(&path).map_err(|e| e.to_string())?);
    let _ = std::fs::write(&stamp, now.to_string());
    if have == want {
        return Ok("Up to date".into());
    }
    install(&path).map_err(|e| format!("Update failed: {e}"))?;
    Ok("Updated".into())
}

/// A YouTube / YouTube Music playlist, album or single-video link as `(name, tracks)`.
pub fn playlist(url: &str) -> Result<(String, Vec<Value>), String> {
    if !(url.starts_with("https://") || url.starts_with("http://")) {
        return Err("That is not a link".into());
    }
    let exe = ensure()?;
    let out = Command::new(exe)
        .args(["-J", "--flat-playlist", "--no-warnings", "--playlist-end", "1000", "--socket-timeout", "15", "--", url])
        .creation_flags(NO_WINDOW)
        .output()
        .map_err(|e| e.to_string())?;
    if !out.status.success() {
        let err = String::from_utf8_lossy(&out.stderr);
        return Err(nice(err.lines().last().unwrap_or("")));
    }
    let v: Value = serde_json::from_slice(&out.stdout).map_err(|e| e.to_string())?;
    let name = v["title"].as_str().unwrap_or("Imported playlist").to_string();
    let entries: Vec<Value> = match v["entries"].as_array() {
        Some(a) => a.clone(),
        None => vec![v.clone()],
    };
    let tracks: Vec<Value> = entries
        .iter()
        .filter_map(|e| {
            let id = e["id"].as_str().filter(|i| i.len() == 11)?;
            let title = e["title"].as_str().unwrap_or("");
            if title.starts_with("[Private") || title.starts_with("[Deleted") || title.is_empty() {
                return None;
            }
            let artist = e["artist"].as_str().or(e["channel"].as_str()).or(e["uploader"].as_str()).unwrap_or("");
            let artist = artist.trim_end_matches(" - Topic");
            Some(serde_json::json!({
                "id": id, "title": title, "artist": artist, "album": e["album"].as_str().unwrap_or(""),
                "dur": e["duration"].as_f64().unwrap_or(0.0) as u64,
                "thumb": format!("https://i.ytimg.com/vi/{id}/hqdefault.jpg"),
            }))
        })
        .collect();
    if tracks.is_empty() {
        return Err("No playable songs in that link".into());
    }
    Ok((name, tracks))
}

/// Ask yt-dlp for the best direct audio stream of a video.
pub fn resolve(vid: &str) -> Result<Resolved, String> {
    let exe = ensure()?;
    let out = Command::new(exe)
        .args([
            "-j",
            "--no-playlist",
            "--no-warnings",
            "--no-progress",
            "--socket-timeout",
            "15",
            "-f",
            if crate::settings::quality_low() {
                "bestaudio[ext=m4a][abr<=72][protocol^=http]/bestaudio[ext=m4a][protocol^=http]/bestaudio[protocol^=http]/best[protocol^=http]"
            } else {
                "bestaudio[ext=m4a][protocol^=http]/bestaudio[protocol^=http]/best[protocol^=http]"
            },
            &format!("https://music.youtube.com/watch?v={vid}"),
        ])
        .creation_flags(NO_WINDOW)
        .output()
        .map_err(|e| e.to_string())?;
    if !out.status.success() {
        let err = String::from_utf8_lossy(&out.stderr);
        return Err(nice(err.lines().last().unwrap_or("")));
    }
    let v: Value = serde_json::from_slice(&out.stdout).map_err(|e| e.to_string())?;
    let headers = v["http_headers"]
        .as_object()
        .map(|m| m.iter().filter_map(|(k, x)| Some((k.clone(), x.as_str()?.to_string()))).collect())
        .unwrap_or_default();
    Ok(Resolved {
        url: v["url"].as_str().ok_or("no stream url")?.to_string(),
        headers,
        size: v["filesize"].as_u64().or(v["filesize_approx"].as_u64()).unwrap_or(0),
        ext: v["ext"].as_str().unwrap_or("m4a").to_string(),
    })
}

fn nice(m: &str) -> String {
    let l = m.to_lowercase();
    if l.contains("age") && l.contains("restricted") {
        "This track is age-restricted".into()
    } else if l.contains("unviewable") {
        "That playlist can't be opened (YouTube mixes can't be imported)".into()
    } else if l.contains("private") {
        "This track is private".into()
    } else if l.contains("not available in your country") {
        "This track is not available in your country".into()
    } else if l.contains("unavailable") {
        "This track is unavailable".into()
    } else if l.contains("sign in to confirm") {
        "YouTube is asking for a sign-in check. Try again in a minute".into()
    } else if l.contains("getaddrinfo") || l.contains("connection") {
        "No internet connection".into()
    } else {
        "Could not load this track".into()
    }
}
