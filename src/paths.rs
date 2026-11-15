use std::path::PathBuf;

fn base() -> PathBuf {
    // CLOUDIFY_DATA points a test run at its own folder, away from the real library
    if let Some(d) = std::env::var_os("CLOUDIFY_DATA") {
        return PathBuf::from(d);
    }
    let root = std::env::var_os("LOCALAPPDATA")
        .map(PathBuf::from)
        .unwrap_or_else(std::env::temp_dir);
    root.join("Cloud Music")
}

pub fn dir(sub: &str) -> PathBuf {
    let p = base().join(sub);
    let _ = std::fs::create_dir_all(&p);
    p
}

/// Write a diagnostic line to stderr; never panics when the app has no console.
pub fn log(msg: &str) {
    use std::io::Write;
    let _ = writeln!(std::io::stderr(), "{msg}");
}

/// Seconds east of UTC for the local zone (Windows).
pub fn utc_offset_secs() -> i64 {
    use windows_sys::Win32::System::Time::{GetTimeZoneInformation, TIME_ZONE_INFORMATION};
    let mut tz: TIME_ZONE_INFORMATION = unsafe { std::mem::zeroed() };
    let id = unsafe { GetTimeZoneInformation(&mut tz) };
    let bias = tz.Bias + if id == 2 { tz.DaylightBias } else { 0 };
    -(bias as i64) * 60
}
