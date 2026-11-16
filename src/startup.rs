//! "Open Cloudify when I sign in": one value under the per-user Run key (no administrator needed).
use windows_sys::Win32::System::Registry::{RegCloseKey, RegDeleteValueW, RegOpenKeyExW, RegQueryValueExW, RegSetValueExW, HKEY, HKEY_CURRENT_USER, KEY_READ, KEY_SET_VALUE, REG_SZ};

const KEY: &str = "Software\\Microsoft\\Windows\\CurrentVersion\\Run";
const NAME: &str = "Cloudify";

fn wide(s: &str) -> Vec<u16> {
    s.encode_utf16().chain(std::iter::once(0)).collect()
}

pub fn enabled() -> bool {
    unsafe {
        let mut k: HKEY = std::ptr::null_mut();
        if RegOpenKeyExW(HKEY_CURRENT_USER, wide(KEY).as_ptr(), 0, KEY_READ, &mut k) != 0 {
            return false;
        }
        let r = RegQueryValueExW(k, wide(NAME).as_ptr(), std::ptr::null(), std::ptr::null_mut(), std::ptr::null_mut(), std::ptr::null_mut());
        RegCloseKey(k);
        r == 0
    }
}

/// Start with Windows (minimised to the tray) or stop doing so.
pub fn set(on: bool) -> bool {
    unsafe {
        let mut k: HKEY = std::ptr::null_mut();
        if RegOpenKeyExW(HKEY_CURRENT_USER, wide(KEY).as_ptr(), 0, KEY_SET_VALUE, &mut k) != 0 {
            return false;
        }
        let ok = if on {
            let exe = std::env::current_exe().map(|p| p.to_string_lossy().into_owned()).unwrap_or_default();
            let v = wide(&format!("\"{exe}\" --tray"));
            RegSetValueExW(k, wide(NAME).as_ptr(), 0, REG_SZ, v.as_ptr() as *const u8, (v.len() * 2) as u32) == 0
        } else {
            let r = RegDeleteValueW(k, wide(NAME).as_ptr());
            r == 0 || r == 2 // 2 = it was not there
        };
        RegCloseKey(k);
        ok
    }
}
