//! Global hotkeys through RegisterHotKey, plus the keyboard media keys.
use windows_sys::Win32::UI::Input::KeyboardAndMouse::{
    RegisterHotKey, MOD_ALT, MOD_CONTROL, MOD_NOREPEAT, MOD_SHIFT, VK_DOWN, VK_LEFT, VK_MEDIA_NEXT_TRACK,
    VK_MEDIA_PLAY_PAUSE, VK_MEDIA_PREV_TRACK, VK_RIGHT, VK_UP,
};
use windows_sys::Win32::UI::WindowsAndMessaging::{GetMessageW, MSG, WM_HOTKEY};

const KEYS: &[(&str, u32, u32)] = &[
    ("playpause", 0, VK_MEDIA_PLAY_PAUSE as u32),
    ("next", 0, VK_MEDIA_NEXT_TRACK as u32),
    ("prev", 0, VK_MEDIA_PREV_TRACK as u32),
    ("playpause", MOD_CONTROL | MOD_ALT | MOD_SHIFT, b'P' as u32),
    ("next", MOD_CONTROL | MOD_ALT | MOD_SHIFT, VK_RIGHT as u32),
    ("prev", MOD_CONTROL | MOD_ALT | MOD_SHIFT, VK_LEFT as u32),
    ("volup", MOD_CONTROL | MOD_ALT | MOD_SHIFT, VK_UP as u32),
    ("voldown", MOD_CONTROL | MOD_ALT | MOD_SHIFT, VK_DOWN as u32),
    ("like", MOD_CONTROL | MOD_ALT | MOD_SHIFT, b'L' as u32),
];

/// Starts a message-loop thread. `on_key` gets the action name; returns nothing, failures are
/// logged to stderr (another program may already own a key).
pub fn start(on_key: impl Fn(&'static str) + Send + 'static) {
    std::thread::spawn(move || unsafe {
        for (i, (name, mods, vk)) in KEYS.iter().enumerate() {
            if RegisterHotKey(std::ptr::null_mut(), i as i32 + 1, mods | MOD_NOREPEAT, *vk) == 0 {
                crate::paths::log(&format!("hotkey in use by another program: {name} ({mods:#x}+{vk:#x})"));
            }
        }
        let mut msg: MSG = std::mem::zeroed();
        while GetMessageW(&mut msg, std::ptr::null_mut(), 0, 0) > 0 {
            if msg.message == WM_HOTKEY {
                if let Some((name, _, _)) = KEYS.get((msg.wParam as usize).wrapping_sub(1)) {
                    on_key(name);
                }
            }
        }
    });
}
