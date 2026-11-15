//! Exportify inside the app: a small WebView2 window on exportify.app. Whatever it downloads is
//! picked up as soon as it finishes: a CSV is imported at once, the "Export All" zip is unpacked,
//! imported and the window closes.
use crate::paths;
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use tao::dpi::LogicalSize;
use tao::event::{Event, WindowEvent};
use tao::event_loop::{ControlFlow, EventLoopBuilder};
use tao::platform::run_return::EventLoopExtRunReturn;
use tao::platform::windows::EventLoopBuilderExtWindows;
use tao::window::WindowBuilder;
use wry::{WebContext, WebViewBuilder};

static OPEN: AtomicBool = AtomicBool::new(false);

enum Ev {
    Close,
}

/// Open the window (one at a time). `on_files` is called from the window's thread with the CSV files.
pub fn open(on_files: impl Fn(Vec<PathBuf>) + Send + Sync + 'static) {
    if OPEN.swap(true, Ordering::SeqCst) {
        return;
    }
    std::thread::spawn(move || {
        if let Err(e) = run(Arc::new(on_files)) {
            paths::log(&format!("exportify window: {e}"));
        }
        OPEN.store(false, Ordering::SeqCst);
    });
}

fn unzip(zip_path: &PathBuf, out: &PathBuf) -> Vec<PathBuf> {
    let mut files = Vec::new();
    let Ok(f) = std::fs::File::open(zip_path) else { return files };
    let Ok(mut z) = zip::ZipArchive::new(f) else { return files };
    for i in 0..z.len() {
        let Ok(mut e) = z.by_index(i) else { continue };
        let Some(name) = e.enclosed_name().and_then(|p| p.file_name().map(|n| n.to_owned())) else { continue };
        if !name.to_string_lossy().to_lowercase().ends_with(".csv") || e.size() > 20 * 1024 * 1024 {
            continue;
        }
        let dest = out.join(name);
        if let Ok(mut w) = std::fs::File::create(&dest) {
            if std::io::copy(&mut e, &mut w).is_ok() {
                files.push(dest);
            }
        }
    }
    files
}

fn run(on_files: Arc<dyn Fn(Vec<PathBuf>) + Send + Sync>) -> Result<(), String> {
    let root = paths::dir("exportify");
    let dl = root.join("downloads");
    let _ = std::fs::remove_dir_all(&dl);
    std::fs::create_dir_all(&dl).map_err(|e| e.to_string())?;
    let mut ev = EventLoopBuilder::<Ev>::with_user_event().with_any_thread(true).build();
    let proxy = ev.create_proxy();
    let window = WindowBuilder::new()
        .with_title("Import from Spotify - Cloudify")
        .with_inner_size(LogicalSize::new(1040.0, 780.0))
        .build(&ev)
        .map_err(|e| e.to_string())?;
    let mut ctx = WebContext::new(Some(root.join("webview")));
    let dl2 = dl.clone();
    let dl3 = dl.clone();
    let webview = WebViewBuilder::new_with_web_context(&mut ctx)
        .with_url("https://exportify.app/")
        .with_download_started_handler(move |_url, path: &mut PathBuf| {
            if let Some(n) = path.file_name() {
                *path = dl2.join(n);
            }
            true
        })
        .with_download_completed_handler(move |_url, path: Option<PathBuf>, ok| {
            let Some(p) = path.filter(|_| ok) else { return };
            match p.extension().and_then(|e| e.to_str()).map(|e| e.to_lowercase()).as_deref() {
                Some("csv") => on_files(vec![p]),
                Some("zip") => {
                    let files = unzip(&p, &dl3);
                    if !files.is_empty() {
                        on_files(files);
                        let _ = proxy.send_event(Ev::Close);
                    }
                }
                _ => {}
            }
        })
        .build(&window)
        .map_err(|e| e.to_string())?;
    paths::log("exportify: webview ready");
    ev.run_return(move |event, _, flow| {
        let _keep = (&webview, &window);
        *flow = ControlFlow::Wait;
        match event {
            Event::WindowEvent { event: WindowEvent::CloseRequested, .. } | Event::UserEvent(Ev::Close) => *flow = ControlFlow::Exit,
            _ => {}
        }
    });
    Ok(())
}
