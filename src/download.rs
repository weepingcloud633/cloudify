//! Save a cached track into the Music folder, with its tags.
use crate::stream;
use lofty::{config::WriteOptions, prelude::*, probe::Probe, tag::Tag};
use serde_json::Value;
use std::path::PathBuf;

fn music_dir() -> PathBuf {
    let home = std::env::var_os("USERPROFILE").map(PathBuf::from).unwrap_or_else(std::env::temp_dir);
    home.join("Music").join("Cloudify")
}

fn clean(s: &str) -> String {
    let c: String = s.chars().map(|c| if "<>:\"/\\|?*".contains(c) || c.is_control() { '_' } else { c }).collect();
    c.trim().trim_end_matches('.').chars().take(100).collect()
}

/// Download (or reuse the cache of) one track and copy it to `Music\Cloudify`.
pub fn save(track: &Value) -> Result<PathBuf, String> {
    let id = track["id"].as_str().ok_or("no id")?;
    let (title, artist, album) = (
        track["title"].as_str().unwrap_or("Unknown"),
        track["artist"].as_str().unwrap_or(""),
        track["album"].as_str().unwrap_or(""),
    );
    let t = stream::prepare(id)?;
    let (src, ext) = stream::wait_done(&t)?;
    let dir = music_dir();
    std::fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    let name = if artist.is_empty() { clean(title) } else { format!("{} - {}", clean(artist), clean(title)) };
    let mut dest = dir.join(format!("{name}.{ext}"));
    let mut n = 2;
    while dest.exists() {
        dest = dir.join(format!("{name} ({n}).{ext}"));
        n += 1;
    }
    std::fs::copy(&src, &dest).map_err(|e| e.to_string())?;
    // tags are best effort: the file plays without them
    let _ = (|| -> Result<(), lofty::error::LoftyError> {
        let mut f = Probe::open(&dest)?.read()?;
        if f.primary_tag().is_none() {
            let tt = f.primary_tag_type();
            f.insert_tag(Tag::new(tt));
        }
        if let Some(tag) = f.primary_tag_mut() {
            tag.set_title(title.to_string());
            tag.set_artist(artist.to_string());
            if !album.is_empty() {
                tag.set_album(album.to_string());
            }
            tag.save_to_path(&dest, WriteOptions::default())?;
        }
        Ok(())
    })();
    Ok(dest)
}
