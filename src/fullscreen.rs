//! Real fullscreen for the frameless window: it covers the whole monitor, taskbar included, with no
//! border, shadow or rounded corners, and goes back exactly as it was.
use std::sync::Mutex;
use windows_sys::Win32::Foundation::{HWND, RECT};
use windows_sys::Win32::Graphics::Dwm::{DwmExtendFrameIntoClientArea, DwmSetWindowAttribute};
use windows_sys::Win32::Graphics::Gdi::{GetMonitorInfoW, MonitorFromWindow, MONITORINFO, MONITOR_DEFAULTTONEAREST};
use windows_sys::Win32::UI::Controls::MARGINS;
use windows_sys::Win32::UI::WindowsAndMessaging::*;

struct Saved {
    style: isize,
    rect: RECT,
    maximized: bool,
}

static SAVED: Mutex<Option<Saved>> = Mutex::new(None);

/// Enter or leave fullscreen. False when there is no window or nothing to do.
pub fn set(hwnd: isize, on: bool) -> bool {
    if hwnd == 0 {
        return false;
    }
    let h = hwnd as HWND;
    let mut saved = SAVED.lock().unwrap();
    unsafe {
        if on {
            if saved.is_some() {
                return true;
            }
            let mut rect: RECT = std::mem::zeroed();
            GetWindowRect(h, &mut rect);
            let maximized = IsZoomed(h) != 0;
            if maximized {
                ShowWindow(h, SW_RESTORE);
                GetWindowRect(h, &mut rect);
            }
            let style = GetWindowLongPtrW(h, GWL_STYLE);
            *saved = Some(Saved { style, rect, maximized });
            SetWindowLongPtrW(h, GWL_STYLE, (WS_POPUP | WS_VISIBLE) as isize);
            let corners: i32 = 1; // DWMWCP_DONOTROUND
            DwmSetWindowAttribute(h, 33, &corners as *const i32 as *const _, 4);
            DwmExtendFrameIntoClientArea(h, &MARGINS { cxLeftWidth: 0, cxRightWidth: 0, cyTopHeight: 0, cyBottomHeight: 0 });
            let mut mi: MONITORINFO = std::mem::zeroed();
            mi.cbSize = std::mem::size_of::<MONITORINFO>() as u32;
            GetMonitorInfoW(MonitorFromWindow(h, MONITOR_DEFAULTTONEAREST), &mut mi);
            let r = mi.rcMonitor;
            SetWindowPos(h, HWND_TOPMOST, r.left, r.top, r.right - r.left, r.bottom - r.top, SWP_FRAMECHANGED | SWP_SHOWWINDOW);
            true
        } else {
            let Some(s) = saved.take() else { return false };
            SetWindowLongPtrW(h, GWL_STYLE, s.style);
            let corners: i32 = 2; // DWMWCP_ROUND
            DwmSetWindowAttribute(h, 33, &corners as *const i32 as *const _, 4);
            DwmExtendFrameIntoClientArea(h, &MARGINS { cxLeftWidth: 0, cxRightWidth: 0, cyTopHeight: 0, cyBottomHeight: 1 });
            let r = s.rect;
            SetWindowPos(h, HWND_NOTOPMOST, r.left, r.top, r.right - r.left, r.bottom - r.top, SWP_FRAMECHANGED | SWP_SHOWWINDOW);
            if s.maximized {
                ShowWindow(h, SW_MAXIMIZE);
            }
            true
        }
    }
}
