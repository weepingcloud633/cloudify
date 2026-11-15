//! App-wide settings, kept in `data/settings.json`.
use crate::paths;
use serde_json::{json, Value};
use std::sync::Mutex;

static S: Mutex<Option<Value>> = Mutex::new(None);

fn file() -> std::path::PathBuf {
    paths::dir("data").join("settings.json")
}

fn defaults() -> Value {
    json!({"quality": "high", "dynamicColor": true, "reduceMotion": false, "autoRadio": true, "cacheLimitMB": 2048, "volume": 0.8, "graphics": "auto", "themeMode": "dark", "accent": "", "spotifyId": "", "spotifySecret": "", "themeId": "", "recent": [], "eq": [0, 0, 0, 0, 0, 0], "eqPreset": "Flat", "localFolders": [], "autoUpdate": true})
}

fn load() -> Value {
    let mut v = defaults();
    if let Some(Value::Object(saved)) = std::fs::read(file()).ok().and_then(|b| serde_json::from_slice::<Value>(&b).ok()) {
        for (k, x) in saved {
            if v.get(&k).is_some_and(|d| std::mem::discriminant(d) == std::mem::discriminant(&x)) {
                v[k] = x;
            }
        }
    }
    v
}

pub fn get() -> Value {
    S.lock().unwrap().get_or_insert_with(load).clone()
}

/// Merge known keys of `patch` (same JSON type as the default) and save.
pub fn patch(p: &Value) -> Value {
    let mut g = S.lock().unwrap();
    let cur = g.get_or_insert_with(load);
    if let Value::Object(m) = p {
        for (k, x) in m {
            if cur.get(k).is_some_and(|d| std::mem::discriminant(d) == std::mem::discriminant(x)) {
                cur[k.as_str()] = x.clone();
            }
        }
    }
    if !["dark", "light", "amoled"].contains(&cur["themeMode"].as_str().unwrap_or("")) {
        cur["themeMode"] = json!("dark");
    }
    let tid = cur["themeId"].as_str().unwrap_or("").to_string();
    if !tid.is_empty() && !tid.bytes().all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'-') {
        cur["themeId"] = json!("");
    }
    let acc = cur["accent"].as_str().unwrap_or("").to_string();
    if !acc.is_empty() && !(acc.len() == 7 && acc.starts_with('#')) {
        cur["accent"] = json!("");
    }
    if !["auto", "d3d12", "opengl"].contains(&cur["graphics"].as_str().unwrap_or("")) {
        cur["graphics"] = json!("auto");
    }
    if cur["quality"] != "low" && cur["quality"] != "high" {
        cur["quality"] = json!("high");
    }
    if let Some(a) = cur["eq"].as_array_mut() {
        a.resize(6, json!(0));
        for g in a.iter_mut() {
            *g = json!(g.as_f64().unwrap_or(0.0).clamp(-12.0, 12.0));
        }
    }
    if cur["eqPreset"].as_str().is_some_and(|n| n.len() > 40) {
        cur["eqPreset"] = json!("Flat");
    }
    if let Some(a) = cur["localFolders"].as_array_mut() {
        a.retain(|f| f.as_str().is_some_and(|s| !s.is_empty() && s.len() < 400));
        a.truncate(12);
    }
    if let Some(a) = cur["recent"].as_array_mut() {
        a.truncate(24);
    }
    let mb = cur["cacheLimitMB"].as_i64().unwrap_or(2048).clamp(256, 51200);
    cur["cacheLimitMB"] = json!(mb);
    let tmp = file().with_extension("tmp");
    if std::fs::write(&tmp, serde_json::to_vec(&*cur).unwrap_or_default()).is_ok() {
        let _ = std::fs::rename(&tmp, file());
    }
    cur.clone()
}

pub fn quality_low() -> bool {
    get()["quality"] == "low"
}

pub fn cache_limit_bytes() -> u64 {
    get()["cacheLimitMB"].as_u64().unwrap_or(2048) * 1024 * 1024
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn patch_checks_types_and_ranges() {
        let _ = patch(&json!({"quality": "low", "cacheLimitMB": 99999999, "bogus": 1, "autoRadio": "yes"}));
        let s = get();
        assert_eq!(s["quality"], "low");
        assert_eq!(s["cacheLimitMB"], 51200);
        assert!(s.get("bogus").is_none());
        assert_eq!(s["autoRadio"], true);
        let _ = patch(&json!({"quality": "high", "cacheLimitMB": 2048}));
    }
}
