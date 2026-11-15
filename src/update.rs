//! Self-update from GitHub Releases.
//!
//! The app asks GitHub for the latest release of `REPO`. A release carries the installer
//! (`Cloudify-Setup-<version>.exe`) and its SHA-256, either as GitHub's own asset digest or as a
//! `<installer>.sha256` file. The download is only run when its hash matches, and only when it comes
//! from this repository's own release downloads.
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::io::{Read, Write};
use std::path::PathBuf;
use std::sync::Mutex;

/// GitHub `owner/repo` that publishes the releases. Change this to the repository you publish to.
pub const REPO: &str = "weepingcloud633/cloudify";

static FOUND: Mutex<Option<Found>> = Mutex::new(None);

#[derive(Clone)]
struct Found {
    url: String,
    sha256: String,
}

pub fn current() -> &'static str {
    env!("CARGO_PKG_VERSION")
}

/// `1.2.3` or `v1.2.3` -> [1, 2, 3]
fn parse(v: &str) -> Vec<u64> {
    v.trim().trim_start_matches(['v', 'V']).split('.').map(|p| p.chars().take_while(|c| c.is_ascii_digit()).collect::<String>().parse().unwrap_or(0)).collect()
}

fn newer(latest: &str, current: &str) -> bool {
    let (a, b) = (parse(latest), parse(current));
    for i in 0..a.len().max(b.len()) {
        let (x, y) = (a.get(i).copied().unwrap_or(0), b.get(i).copied().unwrap_or(0));
        if x != y {
            return x > y;
        }
    }
    false
}

fn get(url: &str) -> Result<ureq::Response, String> {
    ureq::get(url).set("User-Agent", "Cloudify-updater").set("Accept", "application/vnd.github+json").timeout(std::time::Duration::from_secs(20)).call().map_err(|e| e.to_string())
}

fn allowed(url: &str) -> bool {
    url.starts_with(&format!("https://github.com/{REPO}/releases/download/"))
}

/// Ask GitHub for the latest release. `{ok, current, available, latest, notes, page, installable}`
pub fn check() -> Value {
    let url = format!("https://api.github.com/repos/{REPO}/releases/latest");
    let rel: Value = match get(&url).and_then(|r| r.into_json().map_err(|e| e.to_string())) {
        Ok(v) => v,
        Err(e) if e.contains("404") => return json!({"ok": true, "current": current(), "available": false, "none": true}),
        Err(e) => return json!({"ok": false, "current": current(), "error": format!("Could not reach GitHub: {e}")}),
    };
    let tag = rel["tag_name"].as_str().unwrap_or("").to_string();
    let page = rel["html_url"].as_str().unwrap_or("").to_string();
    if tag.is_empty() {
        return json!({"ok": true, "current": current(), "available": false});
    }
    if !newer(&tag, current()) {
        return json!({"ok": true, "current": current(), "available": false, "latest": tag.trim_start_matches('v')});
    }
    let assets = rel["assets"].as_array().cloned().unwrap_or_default();
    let installer = assets.iter().find(|a| {
        let n = a["name"].as_str().unwrap_or("");
        n.starts_with("Cloudify-Setup") && n.ends_with(".exe")
    });
    let mut found = None;
    if let Some(a) = installer {
        let name = a["name"].as_str().unwrap_or("");
        let dl = a["browser_download_url"].as_str().unwrap_or("");
        let mut sha = a["digest"].as_str().and_then(|d| d.strip_prefix("sha256:")).unwrap_or("").to_string();
        if sha.is_empty() {
            if let Some(s) = assets.iter().find(|x| x["name"].as_str() == Some(&format!("{name}.sha256"))) {
                if let Some(u) = s["browser_download_url"].as_str().filter(|u| allowed(u)) {
                    sha = get(u).ok().and_then(|r| r.into_string().ok()).and_then(|t| t.split_whitespace().next().map(String::from)).unwrap_or_default();
                }
            }
        }
        if allowed(dl) && sha.len() == 64 && sha.bytes().all(|b| b.is_ascii_hexdigit()) {
            found = Some(Found { url: dl.to_string(), sha256: sha.to_lowercase() });
        }
    }
    let installable = found.is_some();
    *FOUND.lock().unwrap() = found;
    json!({"ok": true, "current": current(), "available": true, "latest": tag.trim_start_matches('v'), "notes": rel["body"].as_str().unwrap_or("").chars().take(600).collect::<String>(), "page": page, "installable": installable})
}

fn dir() -> PathBuf {
    let d = std::env::temp_dir().join("cloudify-update");
    let _ = std::fs::create_dir_all(&d);
    d
}

/// Download the found installer, checking its hash. Returns the path.
pub fn download(progress: impl Fn(u64, u64)) -> Result<PathBuf, String> {
    let f = FOUND.lock().unwrap().clone().ok_or("No update to install")?;
    if !allowed(&f.url) {
        return Err("The update is not from the expected repository".into());
    }
    let resp = get(&f.url)?;
    let total: u64 = resp.header("Content-Length").and_then(|s| s.parse().ok()).unwrap_or(0);
    let path = dir().join("Cloudify-Setup.exe");
    let mut out = std::fs::File::create(&path).map_err(|e| e.to_string())?;
    let mut reader = resp.into_reader().take(400 * 1024 * 1024);
    let (mut hasher, mut buf, mut done) = (Sha256::new(), vec![0u8; 64 * 1024], 0u64);
    loop {
        let n = reader.read(&mut buf).map_err(|e| e.to_string())?;
        if n == 0 {
            break;
        }
        hasher.update(&buf[..n]);
        out.write_all(&buf[..n]).map_err(|e| e.to_string())?;
        done += n as u64;
        progress(done, total);
    }
    drop(out);
    let got: String = hasher.finalize().iter().map(|b| format!("{b:02x}")).collect();
    if got != f.sha256 {
        let _ = std::fs::remove_file(&path);
        return Err("The download did not match its checksum, so it was not installed".into());
    }
    Ok(path)
}

/// Start the installer (it closes this app, installs and starts it again).
pub fn launch(path: &std::path::Path) -> bool {
    use std::os::windows::process::CommandExt;
    // DETACHED_PROCESS: the installer outlives this app, which it closes
    std::process::Command::new(path).args(["/SILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/CLOSEAPPLICATIONS", "/RESTARTAPPLICATIONS"]).creation_flags(0x0000_0008).spawn().is_ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn versions_compare_numerically() {
        assert!(newer("v0.16.0", "0.15.3"));
        assert!(newer("0.15.10", "0.15.9"));
        assert!(!newer("0.15.3", "0.15.3"));
        assert!(!newer("0.9.0", "0.15.0"));
    }

    #[test]
    fn only_this_repos_downloads_are_allowed() {
        assert!(allowed(&format!("https://github.com/{REPO}/releases/download/v1/x.exe")));
        assert!(!allowed("https://evil.example/releases/download/v1/x.exe"));
        assert!(!allowed("https://github.com/someone/else/releases/download/v1/x.exe"));
    }
}
