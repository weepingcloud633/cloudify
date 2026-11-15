//! Local profiles. Each has its own library; a PIN (optional) is a privacy lock, not encryption.
use crate::paths;
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::path::PathBuf;
use std::sync::Mutex;

static ACTIVE: Mutex<String> = Mutex::new(String::new());

fn index_file() -> PathBuf {
    paths::dir("data").join("profiles.json")
}

fn load() -> Vec<Value> {
    if let Some(v) = std::fs::read(index_file()).ok().and_then(|b| serde_json::from_slice::<Vec<Value>>(&b).ok()) {
        if !v.is_empty() {
            return v;
        }
    }
    // first run, or an install from before profiles: one default profile owns the old library
    let id = "default".to_string();
    let old = paths::dir("data").join("library.json");
    if old.is_file() {
        let _ = std::fs::create_dir_all(profile_dir(&id));
        let _ = std::fs::rename(&old, profile_dir(&id).join("library.json"));
    }
    let v = vec![json!({"id": id, "name": "Me", "color": "#8fb8ff", "pin": ""})];
    save(&v);
    v
}

fn save(v: &[Value]) {
    let tmp = index_file().with_extension("tmp");
    if std::fs::write(&tmp, serde_json::to_vec(v).unwrap_or_default()).is_ok() {
        let _ = std::fs::rename(&tmp, index_file());
    }
}

fn valid_id(id: &str) -> bool {
    !id.is_empty() && id.len() <= 32 && id.bytes().all(|b| b.is_ascii_alphanumeric())
}

fn profile_dir(id: &str) -> PathBuf {
    paths::dir("data").join("profiles").join(id)
}

/// The folder of the profile in use (a default one before any is chosen).
pub fn dir() -> PathBuf {
    let mut a = ACTIVE.lock().unwrap();
    if a.is_empty() {
        *a = load()[0]["id"].as_str().unwrap_or("default").to_string();
    }
    let p = profile_dir(&a);
    let _ = std::fs::create_dir_all(&p);
    p
}

fn hash(salt: &str, pin: &str) -> String {
    let d = Sha256::digest(format!("{salt}:{pin}").as_bytes());
    d.iter().map(|b| format!("{b:02x}")).collect()
}

/// `[{id, name, color, locked}]`, never the PIN hash.
pub fn list() -> Value {
    Value::Array(
        load()
            .iter()
            .map(|p| json!({"id": p["id"], "name": p["name"], "color": p["color"], "locked": p["pin"].as_str().is_some_and(|s| !s.is_empty())}))
            .collect(),
    )
}

pub fn create(name: &str, color: &str, pin: &str) -> Result<Value, String> {
    let name = name.trim();
    if name.is_empty() {
        return Err("Give the profile a name".into());
    }
    if !pin.is_empty() && !(pin.len() >= 4 && pin.bytes().all(|b| b.is_ascii_digit())) {
        return Err("A PIN is 4 or more digits".into());
    }
    let mut v = load();
    let id = format!("{:x}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_nanos()).unwrap_or(0));
    let pin_entry = if pin.is_empty() { String::new() } else { format!("{id}:{}", hash(&id, pin)) };
    v.push(json!({"id": id, "name": name.chars().take(24).collect::<String>(), "color": color, "pin": pin_entry}));
    save(&v);
    Ok(list())
}

pub fn delete(id: &str, pin: &str) -> Result<Value, String> {
    let mut v = load();
    if v.len() <= 1 {
        return Err("Keep at least one profile".into());
    }
    if !verify_in(&v, id, pin) {
        return Err("Wrong PIN".into());
    }
    v.retain(|p| p["id"] != id);
    save(&v);
    if valid_id(id) {
        let _ = std::fs::remove_dir_all(profile_dir(id));
    }
    let mut a = ACTIVE.lock().unwrap();
    if *a == id {
        a.clear();
    }
    Ok(list())
}

fn verify_in(v: &[Value], id: &str, pin: &str) -> bool {
    match v.iter().find(|p| p["id"] == id) {
        None => false,
        Some(p) => match p["pin"].as_str().unwrap_or("") {
            "" => true,
            s => s.split_once(':').is_some_and(|(salt, h)| hash(salt, pin) == h),
        },
    }
}

/// Switch to a profile (checking its PIN); the library cache is dropped.
pub fn select(id: &str, pin: &str) -> bool {
    let v = load();
    if !valid_id(id) || !verify_in(&v, id, pin) {
        return false;
    }
    *ACTIVE.lock().unwrap() = id.to_string();
    crate::library::reset();
    true
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn pin_check() {
        let id = "abc";
        let v = vec![json!({"id": id, "name": "x", "color": "#fff", "pin": format!("{id}:{}", hash(id, "1234"))}), json!({"id": "open", "pin": ""})];
        assert!(verify_in(&v, id, "1234"));
        assert!(!verify_in(&v, id, "0000"));
        assert!(verify_in(&v, "open", ""));
        assert!(!verify_in(&v, "missing", ""));
    }
}

// ---- the one profile: name, colour and picture ----

fn first_mut(v: &mut Vec<Value>) -> &mut Value {
    &mut v[0]
}

/// `{id, name, color, avatar}`; `avatar` is a file:// URL or "".
pub fn current() -> Value {
    let v = load();
    let p = &v[0];
    let avatar = p["avatar"].as_str().filter(|a| !a.is_empty()).map(|a| profile_dir(p["id"].as_str().unwrap_or("default")).join(a)).filter(|f| f.is_file());
    json!({
        "id": p["id"], "name": p["name"], "color": p["color"],
        "avatar": avatar.map(|f| format!("file:///{}?v={}", f.display().to_string().replace(std::path::MAIN_SEPARATOR, "/"), std::fs::metadata(&f).and_then(|m| m.modified()).ok().and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok()).map(|d| d.as_secs()).unwrap_or(0))).unwrap_or_default(),
    })
}

pub fn save_profile(name: &str, color: &str) -> Value {
    let mut v = load();
    {
        let p = first_mut(&mut v);
        let name = name.trim();
        if !name.is_empty() {
            p["name"] = json!(name.chars().take(24).collect::<String>());
        }
        if color.starts_with('#') && color.len() == 7 {
            p["color"] = json!(color);
        }
    }
    save(&v);
    current()
}

/// Copy a picture into the profile folder.
pub fn set_avatar(src: &str) -> Result<Value, String> {
    let src = src.strip_prefix("file:///").unwrap_or(src);
    let ext = std::path::Path::new(src).extension().and_then(|e| e.to_str()).unwrap_or("png").to_lowercase();
    if !["png", "jpg", "jpeg", "webp", "bmp", "gif"].contains(&ext.as_str()) {
        return Err("Choose a PNG, JPG or WebP picture".into());
    }
    if std::fs::metadata(src).map(|m| m.len()).unwrap_or(u64::MAX) > 20 * 1024 * 1024 {
        return Err("That picture is too large".into());
    }
    let mut v = load();
    let id = v[0]["id"].as_str().unwrap_or("default").to_string();
    let name = format!("avatar-{}.{ext}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0));
    let dir = profile_dir(&id);
    let _ = std::fs::create_dir_all(&dir);
    std::fs::copy(src, dir.join(&name)).map_err(|e| e.to_string())?;
    if let Some(old) = v[0]["avatar"].as_str().filter(|a| !a.is_empty()) {
        let _ = std::fs::remove_file(dir.join(old));
    }
    first_mut(&mut v)["avatar"] = json!(name);
    save(&v);
    Ok(current())
}

pub fn clear_avatar() -> Value {
    let mut v = load();
    let id = v[0]["id"].as_str().unwrap_or("default").to_string();
    if let Some(old) = v[0]["avatar"].as_str().filter(|a| !a.is_empty()) {
        let _ = std::fs::remove_file(profile_dir(&id).join(old));
    }
    first_mut(&mut v)["avatar"] = json!("");
    save(&v);
    current()
}
