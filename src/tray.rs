//! A notification-area icon: click to show or hide the window, right-click for a small menu.
//! It runs on its own thread with a hidden window, like the global hotkeys.
use std::sync::atomic::{AtomicIsize, Ordering};
use std::sync::{Mutex, OnceLock};
use windows_sys::Win32::Foundation::{HWND, LPARAM, LRESULT, WPARAM};
use windows_sys::Win32::System::LibraryLoader::GetModuleHandleW;
use windows_sys::Win32::UI::Shell::{Shell_NotifyIconW, NIF_ICON, NIF_MESSAGE, NIF_TIP, NIM_ADD, NIM_DELETE, NIM_MODIFY, NOTIFYICONDATAW};
use windows_sys::Win32::UI::WindowsAndMessaging::*;

const WM_TRAY: u32 = WM_APP + 1;
const WM_TIP: u32 = WM_APP + 2;
const ITEMS: [(&str, &str); 5] = [("show", "Show Cloudify"), ("playpause", "Play / Pause"), ("next", "Next"), ("prev", "Previous"), ("quit", "Quit")];

static ON_ACTION: OnceLock<Box<dyn Fn(&'static str) + Send + Sync>> = OnceLock::new();
static HWND_TRAY: AtomicIsize = AtomicIsize::new(0);
static TIP: Mutex<String> = Mutex::new(String::new());

fn wide(s: &str) -> Vec<u16> {
    s.encode_utf16().chain(std::iter::once(0)).collect()
}

fn nid(hwnd: HWND) -> NOTIFYICONDATAW {
    let mut n: NOTIFYICONDATAW = unsafe { std::mem::zeroed() };
    n.cbSize = std::mem::size_of::<NOTIFYICONDATAW>() as u32;
    n.hWnd = hwnd;
    n.uID = 1;
    n
}

fn set_tip_field(n: &mut NOTIFYICONDATAW, text: &str) {
    let w: Vec<u16> = text.encode_utf16().take(127).collect();
    n.szTip = [0; 128];
    n.szTip[..w.len()].copy_from_slice(&w);
}

unsafe extern "system" fn proc(hwnd: HWND, msg: u32, wp: WPARAM, lp: LPARAM) -> LRESULT {
    match msg {
        WM_TRAY => {
            let ev = (lp & 0xFFFF) as u32;
            if ev == WM_LBUTTONUP {
                if let Some(f) = ON_ACTION.get() {
                    f("toggle");
                }
            } else if ev == WM_RBUTTONUP {
                let menu = CreatePopupMenu();
                for (i, (_, label)) in ITEMS.iter().enumerate() {
                    if i == 4 {
                        AppendMenuW(menu, MF_SEPARATOR, 0, std::ptr::null());
                    }
                    AppendMenuW(menu, MF_STRING, i + 1, wide(label).as_ptr());
                }
                let mut p = std::mem::zeroed();
                GetCursorPos(&mut p);
                SetForegroundWindow(hwnd);
                let cmd = TrackPopupMenu(menu, TPM_RETURNCMD | TPM_NONOTIFY | TPM_RIGHTBUTTON, p.x, p.y, 0, hwnd, std::ptr::null());
                PostMessageW(hwnd, WM_NULL, 0, 0);
                DestroyMenu(menu);
                if cmd > 0 {
                    if let (Some(f), Some((name, _))) = (ON_ACTION.get(), ITEMS.get(cmd as usize - 1)) {
                        f(name);
                    }
                }
            }
            0
        }
        WM_TIP => {
            let mut n = nid(hwnd);
            n.uFlags = NIF_TIP;
            set_tip_field(&mut n, &TIP.lock().unwrap());
            Shell_NotifyIconW(NIM_MODIFY, &n);
            0
        }
        WM_DESTROY => {
            Shell_NotifyIconW(NIM_DELETE, &nid(hwnd));
            0
        }
        _ => DefWindowProcW(hwnd, msg, wp, lp),
    }
}

/// Add the icon. `on_action` gets "toggle", "show", "playpause", "next", "prev" or "quit".
pub fn start(on_action: impl Fn(&'static str) + Send + Sync + 'static) {
    if ON_ACTION.set(Box::new(on_action)).is_err() {
        return;
    }
    std::thread::spawn(|| unsafe {
        let inst = GetModuleHandleW(std::ptr::null());
        let class = wide("CloudifyTray");
        let wc = WNDCLASSW { lpfnWndProc: Some(proc), hInstance: inst, lpszClassName: class.as_ptr(), ..std::mem::zeroed() };
        RegisterClassW(&wc);
        let hwnd = CreateWindowExW(0, class.as_ptr(), class.as_ptr(), 0, 0, 0, 0, 0, std::ptr::null_mut(), std::ptr::null_mut(), inst, std::ptr::null());
        if hwnd.is_null() {
            return;
        }
        HWND_TRAY.store(hwnd as isize, Ordering::Relaxed);
        let mut n = nid(hwnd);
        n.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
        n.uCallbackMessage = WM_TRAY;
        n.hIcon = LoadImageW(inst, 1 as *const u16, IMAGE_ICON, GetSystemMetrics(SM_CXSMICON), GetSystemMetrics(SM_CYSMICON), 0) as _;
        set_tip_field(&mut n, "Cloudify");
        Shell_NotifyIconW(NIM_ADD, &n);
        let mut msg: MSG = std::mem::zeroed();
        while GetMessageW(&mut msg, std::ptr::null_mut(), 0, 0) > 0 {
            TranslateMessage(&msg);
            DispatchMessageW(&msg);
        }
    });
}

/// Show what is playing in the icon's tooltip.
pub fn set_tip(text: &str) {
    *TIP.lock().unwrap() = if text.is_empty() { "Cloudify".into() } else { text.into() };
    let h = HWND_TRAY.load(Ordering::Relaxed);
    if h != 0 {
        unsafe {
            PostMessageW(h as HWND, WM_TIP, 0, 0);
        }
    }
}
