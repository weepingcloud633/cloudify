//! The Windows media overlay (volume-key flyout, lock screen, Bluetooth buttons): title, artist,
//! cover and the play / pause / next / previous buttons, through SystemMediaTransportControls.
use std::sync::Mutex;
use windows::core::HSTRING;
use windows::Foundation::{TypedEventHandler, Uri};
use windows::Media::{MediaPlaybackStatus, MediaPlaybackType, SystemMediaTransportControls, SystemMediaTransportControlsButton, SystemMediaTransportControlsButtonPressedEventArgs};
use windows::Storage::Streams::RandomAccessStreamReference;
use windows::Win32::Foundation::HWND;
use windows::Win32::System::WinRT::ISystemMediaTransportControlsInterop;

struct Holder(SystemMediaTransportControls);
// the controls object is agile: it may be used from any thread
unsafe impl Send for Holder {}

static SMTC: Mutex<Option<Holder>> = Mutex::new(None);

/// Attach to the window and report button presses as "playpause", "next" or "prev".
pub fn start(hwnd: isize, on_action: impl Fn(&'static str) + Send + Sync + 'static) -> Result<(), String> {
    let run = || -> windows::core::Result<()> {
        let interop: ISystemMediaTransportControlsInterop = windows::core::factory::<SystemMediaTransportControls, ISystemMediaTransportControlsInterop>()?;
        let smtc: SystemMediaTransportControls = unsafe { interop.GetForWindow(HWND(hwnd as *mut _))? };
        smtc.SetIsEnabled(true)?;
        smtc.SetIsPlayEnabled(true)?;
        smtc.SetIsPauseEnabled(true)?;
        smtc.SetIsNextEnabled(true)?;
        smtc.SetIsPreviousEnabled(true)?;
        smtc.ButtonPressed(&TypedEventHandler::new(move |_, args: &Option<SystemMediaTransportControlsButtonPressedEventArgs>| {
            if let Some(a) = args {
                match a.Button()? {
                    SystemMediaTransportControlsButton::Play | SystemMediaTransportControlsButton::Pause => on_action("playpause"),
                    SystemMediaTransportControlsButton::Next => on_action("next"),
                    SystemMediaTransportControlsButton::Previous => on_action("prev"),
                    _ => {}
                }
            }
            Ok(())
        }))?;
        *SMTC.lock().unwrap() = Some(Holder(smtc));
        Ok(())
    };
    run().map_err(|e| e.to_string())
}

/// Show the song and whether it is playing.
pub fn update(title: &str, artist: &str, thumb: &str, playing: bool) {
    let g = SMTC.lock().unwrap();
    let Some(h) = g.as_ref() else { return };
    let s = &h.0;
    let _ = (|| -> windows::core::Result<()> {
        s.SetPlaybackStatus(if playing { MediaPlaybackStatus::Playing } else { MediaPlaybackStatus::Paused })?;
        let du = s.DisplayUpdater()?;
        du.SetType(MediaPlaybackType::Music)?;
        let mp = du.MusicProperties()?;
        mp.SetTitle(&HSTRING::from(title))?;
        mp.SetArtist(&HSTRING::from(artist))?;
        if thumb.starts_with("http") {
            if let Ok(uri) = Uri::CreateUri(&HSTRING::from(thumb)) {
                if let Ok(r) = RandomAccessStreamReference::CreateFromUri(&uri) {
                    let _ = du.SetThumbnail(&r);
                }
            }
        }
        du.Update()
    })();
}

