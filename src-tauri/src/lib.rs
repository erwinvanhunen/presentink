// Learn more about Tauri commands at https://tauri.app/develop/calling-rust/

use arboard::{Clipboard, ImageData};

use auto_launch::AutoLaunch;
use enigo::{
    Direction::{Press, Release},
    Enigo, Keyboard, Settings,
};
use std::error::Error;
use std::path::PathBuf;
use tauri::{
    Emitter, Manager, WebviewUrl, WebviewWindowBuilder,
    image::Image,
    menu::{CheckMenuItem, Menu, MenuItem, PredefinedMenuItem, Submenu},
    tray::TrayIconBuilder,
};

use tauri_plugin_opener::OpenerExt;
use xcap::{
    Monitor,
    image::{self, ImageBuffer, Rgba},
};
mod settings;
use settings::AppSettings;
use std::collections::HashMap;
use uuid::Uuid;
use std::sync::Mutex;

mod screen_capture_permissions;
use screen_capture_permissions::{preflight_access, request_access};
pub struct DrawMenuState(pub Mutex<Option<CheckMenuItem<tauri::Wry>>>);
pub struct FileNameMenuState(pub Mutex<Option<MenuItem<tauri::Wry>>>);

lazy_static::lazy_static! {
    static ref ICON_CACHE: Mutex<HashMap<String, tauri::image::Image<'static>>> = Mutex::new(HashMap::new());
}

fn get_icon(path: &str) -> Option<tauri::image::Image> {
    let mut cache = ICON_CACHE.lock().unwrap();
    if let Some(icon) = cache.get(path) {
        return Some(icon.clone());
    }
    let icon_path = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join(path);
    if let Ok(icon) = tauri::image::Image::from_path(&icon_path) {
        cache.insert(path.to_string(), icon.clone());
        Some(icon)
    } else {
        None
    }
}

pub fn run() {
    tauri::Builder::default()
        .manage(DrawMenuState(Mutex::new(None)))
        .manage(FileNameMenuState(Mutex::new(None)))
        .plugin(tauri_plugin_notification::init())
        .enable_macos_default_menu(false)
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_store::Builder::new().build())
        .plugin(tauri_plugin_store::Builder::default().build())
        .setup(|app| {
            app.set_activation_policy(tauri::ActivationPolicy::Accessory);
            setup_shortcuts(app)?;
            setup_menus(&app.handle())?;

            create_splash_window(&app.handle());
            create_overlay_windows(&app.handle());

            // app.manage(Mutex::new(ScriptData::default()));

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            broadcast_to_all_windows,
            print_output,
            start_draw,
            stop_draw,
            change_color,
            open_settings,
            update_settings,
            close_breaktimer,
            show_break_time,
            type_text,
            open_url,
            get_version,
            change_tray_icon,
            set_file_name,
            take_region_screenshot,
            close_screenshot_windows,
            enable_autolaunch,
            disable_autolaunch,
            auto_launch_enabled
        ])
        .plugin(tauri_plugin_opener::init())
        .run(tauri::generate_context!())
        .expect("error while running tauri application");

    // This is where the Tauri application starts running
}

fn setup_menus(app: &tauri::AppHandle) -> Result<(), Box<dyn Error + 'static>> {
    let settings: AppSettings = settings::get_settings(&app);

    let icon = Image::from_bytes(include_bytes!("../icons/iconTemplate.png"))
        .expect("failed to load embedded tray icon");

    let draw_i = CheckMenuItem::with_id(app, "draw", "Draw", true, false, Some("Alt+Shift+D"))?;
    {
        let draw_state = app.state::<DrawMenuState>();
        *draw_state.0.lock().unwrap() = Some(draw_i.clone());
    }
    let breaktimer_i =
        MenuItem::with_id(app, "breaktimer", "Break Timer", true, Some("Alt+Shift+B"))?;
    let screenshot_i =
        MenuItem::with_id(app, "screenshot", "Screenshot", true, Some("Alt+Shift+S"))?;
    let quit_i = MenuItem::with_id(app, "quit", "Quit", true, Some("Cmd+Q"))?;
    let separator = PredefinedMenuItem::separator(app)?;
    let settings_i = MenuItem::with_id(app, "settings", "Settings...", true, Some(""))?;
    let about_i = MenuItem::with_id(app, "about", "About", true, Some(""))?;
    let help_i = MenuItem::with_id(app, "help", "Help", true, Some(""))?;

    let mut items: Vec<&dyn tauri::menu::IsMenuItem<tauri::Wry>> = vec![
        &draw_i,
        &breaktimer_i,
        &screenshot_i,
        &separator,
        &settings_i,
        &help_i,
        &separator,
        &about_i,
        &separator,
    ];
    let select_text_i = MenuItem::with_id(app, "select-text", "Select Text", true, Some(""))?;
    let type_text_i = MenuItem::with_id(app, "edit-text", "Type Text", true, Some("Alt+Shift+T"))?;
    let filename_i = MenuItem::with_id(app, "file-name", "No file selected", false, Some(""))?;
    {
        let file_name_state = app.state::<FileNameMenuState>();
        *file_name_state.0.lock().unwrap() = Some(filename_i.clone());
    }
    let text_submenu = Submenu::with_id_and_items(
        app,
        "text-submenu",
        "Type Text",
        true,
        &[&select_text_i, &separator, &type_text_i, &filename_i],
    )?;

    if settings.show_experimental_features {
        items.push(&text_submenu);

        items.push(&separator);
    }
    items.push(&quit_i);

    let menu = Menu::with_items(app, &items)?;

    let _tray = TrayIconBuilder::with_id("main-tray")
        .menu(&menu)
        .show_menu_on_left_click(true)
        .icon(icon)
        .icon_as_template(true)
        .on_menu_event(|app, event| match event.id.as_ref() {
            "draw" => {
                toggle_draw(&app);
            }
            "breaktimer" => {
                create_breaktimer_window(&app.app_handle());
            }
            "screenshot" => {
                start_screenshot(app.app_handle());
            }
            "quit" => {
                app.exit(0);
            }
            "settings" => {
                if let Err(e) = open_settings(app.app_handle().clone()) {
                    println!("Failed to open settings: {}", e);
                }
            }
            "about" => {
                if let Err(e) = open_about(app.app_handle().clone()) {
                    println!("Failed to open settings: {}", e);
                }
            }
            "help" => {
                if let Err(e) = open_help(app.app_handle().clone()) {
                    println!("Failed to open help: {}", e);
                }
            }
            "select-text" => {
                app.webview_windows().get("main").map(|window| {
                    let _ = window.emit("select-text", ());
                });
            }
            _ => {
                println!("menu item {:?} not handled", event.id);
            }
        })
        .build(app)?;
    Ok(())
}

fn setup_shortcuts(app: &mut tauri::App) -> Result<(), Box<dyn Error + 'static>> {
    use tauri_plugin_global_shortcut::{
        Code, GlobalShortcutExt, Modifiers, Shortcut, ShortcutState,
    };

    let d_shortcut = Shortcut::new(Some(Modifiers::ALT | Modifiers::SHIFT), Code::KeyD);
    let t_shortcut = Shortcut::new(Some(Modifiers::ALT | Modifiers::SHIFT), Code::KeyT);
    let b_shortcut = Shortcut::new(Some(Modifiers::ALT | Modifiers::SHIFT), Code::KeyB);
    let s_shortcut = Shortcut::new(Some(Modifiers::ALT | Modifiers::SHIFT), Code::KeyS);
    let preferences_shortcut = Shortcut::new(Some(Modifiers::ALT | Modifiers::SHIFT), Code::Comma);

    let app_handle = app.handle().clone();
    app.handle().plugin(
        tauri_plugin_global_shortcut::Builder::new()
            .with_handler(move |_app, shortcut, event| {
                if shortcut == &d_shortcut {
                    match event.state() {
                        ShortcutState::Pressed => {
                            toggle_draw(&app_handle);
                        }
                        ShortcutState::Released => {}
                    }
                }

                if shortcut == &s_shortcut {
                    match event.state() {
                        ShortcutState::Pressed => {
                            start_screenshot(&app_handle);
                        }
                        ShortcutState::Released => {}
                    }
                }
                if shortcut == &t_shortcut {
                    match event.state() {
                        ShortcutState::Pressed => {
                            send_script(app_handle.clone());
                        }
                        ShortcutState::Released => {}
                    }
                }
                if shortcut == &b_shortcut {
                    match event.state() {
                        ShortcutState::Pressed => {
                            show_break_time(app_handle.clone());
                        }
                        ShortcutState::Released => {}
                    }
                }
                if cfg!(dev) && shortcut == &preferences_shortcut {
                    match event.state() {
                        ShortcutState::Pressed => {
                            let _ = open_settings(app_handle.clone());
                        }
                        ShortcutState::Released => {}
                    }
                }
            })
            .build(),
    )?;
    app.global_shortcut().register(d_shortcut)?;
    app.global_shortcut().register(t_shortcut)?;
    app.global_shortcut().register(b_shortcut)?;
    app.global_shortcut().register(s_shortcut)?;
    if cfg!(dev) {
        // In development mode, use Ctrl+Shift+D for drawing
        app.global_shortcut().register(preferences_shortcut)?;
    }
    Ok(())
}

fn toggle_draw(app_handle: &tauri::AppHandle) {
    let mut visible = false;
    for (label, window) in app_handle.webview_windows().iter() {
        // Emit an event to the window to toggle the draw action
        if label.starts_with("draw-window-") {
            if window.is_visible().unwrap_or(false) {
                visible = true;
                break;
            }
        }
    }

    if visible {
        // If the draw window is visible, stop drawing
        stop_draw(app_handle.clone());
        set_draw_menu_checked(app_handle, false);
    } else {
        // If the draw window is not visible, start drawing
        start_draw(app_handle.clone());
        set_draw_menu_checked(app_handle, true);
        // Change the tray icon to indicate drawing mode
    }
}

fn start_screenshot(app_handle: &tauri::AppHandle) {
    if cfg!(dev) {
        create_screenshot_windows(&app_handle);
    } else {
        if !preflight_access() {
            request_access();
        } else {
            create_screenshot_windows(&app_handle);
        }
    }
}

fn send_script(app_handle: tauri::AppHandle) {
    // let binding = app_handle.state::<Mutex<ScriptData>>();
    // let state = binding.lock().unwrap();
    // let script = state.original.clone();
    // Emit to a specific window (e.g., "main")
    if let Some(window) = app_handle.get_webview_window("main") {
        // let _ = window.emit("run-script", &script);
        let _ = window.emit("run-script", ());
    }
}

fn set_draw_menu_checked(app: &tauri::AppHandle, checked: bool) {
    let state = app.state::<DrawMenuState>();
    if let Some(draw_item) = &*state.0.lock().unwrap() {
        let _ = draw_item.set_checked(checked);
    }
}

fn create_breaktimer_window(app: &tauri::AppHandle) {
    if let Ok(monitors) = app.available_monitors() {
        for (index, monitor) in monitors.iter().enumerate() {
            let window_label = format!("break-window-{}", index);
            let position = monitor.position();
            let size = monitor.size();

            let break_window = WebviewWindowBuilder::new(
                app,
                &window_label,
                WebviewUrl::App("breaktimer.html".into()),
            )
            .title(&format!("PresentInk Break {}", index + 1))
            .position(position.x as f64, position.y as f64)
            .inner_size(size.width as f64, size.height as f64)
            .center()
            .resizable(false)
            .visible_on_all_workspaces(true)
            .decorations(false)
            .title_bar_style(tauri::TitleBarStyle::Transparent)
            .always_on_top(true)
            .build();

            match break_window {
                Ok(window) => {
                    let _ =
                        window.set_position(tauri::Position::Physical(tauri::PhysicalPosition {
                            x: position.x,
                            y: position.y,
                        }));
                    let _ = window.set_size(tauri::Size::Physical(tauri::PhysicalSize {
                        width: size.width,
                        height: size.height,
                    }));
                    let _ = window.show();
                    let _ = window.set_focus();
                }
                Err(e) => {
                    println!("Failed to create break timer window: {:?}", e);
                }
            }
        }
    }
}

fn create_splash_window(app: &tauri::AppHandle) {
    if let Ok(monitors) = app.available_monitors() {
        for (index, monitor) in monitors.iter().enumerate() {
            let window_label = format!("splash-window-{}", index);
            let position = monitor.position();
            let size = monitor.size();

            let splash_window = WebviewWindowBuilder::new(
                app,
                &window_label,
                WebviewUrl::App("splash.html".into()),
            )
            .title(&format!("PresentInk Splash {}", index + 1))
            .position(position.x as f64, position.y as f64)
            .inner_size(size.width as f64, size.height as f64)
            .center()
            .resizable(false)
            .transparent(true)
            .visible_on_all_workspaces(true)
            .decorations(false)
            .always_on_top(true)
            .build();

            match splash_window {
                Ok(window) => {
                    let _ =
                        window.set_position(tauri::Position::Physical(tauri::PhysicalPosition {
                            x: position.x,
                            y: position.y,
                        }));
                    let _ = window.set_size(tauri::Size::Physical(tauri::PhysicalSize {
                        width: size.width,
                        height: size.height,
                    }));
                    let _ = window.show();
                    let window_clone = window.clone();
                    std::thread::spawn(move || {
                        std::thread::sleep(std::time::Duration::from_millis(3200));
                        let _ = window_clone.close();
                        // Or if you want to close it completely:
                        // let _ = window_clone.close();
                    });
                }
                Err(e) => {
                    println!("Failed to create splash window: {:?}", e);
                }
            }
        }
    }
}

fn create_overlay_windows(app: &tauri::AppHandle) {
    if let Ok(monitors) = app.available_monitors() {
        for (index, monitor) in monitors.iter().enumerate() {
            let window_label = format!("draw-window-{}", index);

            // Close existing window if it exists
            if let Some(existing_window) = app.webview_windows().get(&window_label) {
                let _ = existing_window.close();
            }
            let position = monitor.position();
            let size = monitor.size();
            match WebviewWindowBuilder::new(
                app,
                &window_label,
                WebviewUrl::App("overlay.html".into()),
            )
            .title(&format!("PresentInk Draw Monitor {}", index + 1))
            .position(position.x as f64, position.y as f64)
            .inner_size(size.width as f64, size.height as f64)
            .position(position.x as f64, position.y as f64)
            .inner_size(size.width as f64, size.height as f64)
            .center()
            .shadow(false)
            .resizable(false)
            .transparent(true)
            .theme(None)
            .visible_on_all_workspaces(true)
            .decorations(false)
            .always_on_top(true)
            .build()
            {
                Ok(window) => {
                    let _ =
                        window.set_position(tauri::Position::Physical(tauri::PhysicalPosition {
                            x: position.x,
                            y: position.y,
                        }));
                    let _ = window.hide();
                    let _ = window.set_focus();
                    let _ = window.set_always_on_top(true);

                    let window_clone = window.clone();
                    std::thread::spawn(move || {
                        std::thread::sleep(std::time::Duration::from_millis(100));
                        let _ = window_clone.set_focus();
                    });
                }
                Err(e) => {
                    println!("Failed to create window {}: {:?}", index, e);
                }
            }
        }
    }
}

// #[tauri::command]
// fn type_text(app: tauri::AppHandle, text: &str) {
//     let mut enigo = Enigo::new(&Settings::default()).unwrap();
//     enigo.text(text).unwrap();
// }

#[tauri::command]
fn type_text(text: &str) {
    let mut enigo = Enigo::new(&Settings::default()).unwrap();

    // Replace [left], [up], [right], [down] with corresponding key events
    let mut remaining = text;
    while !remaining.is_empty() {
        if let Some(start) = remaining.find('[') {
            // Type any text before the [
            if start > 0 {
                let before = &remaining[..start];
                if !before.is_empty() {
                    enigo.text(before).unwrap();
                }
            }
            // Check for a recognized key command
            if let Some(end) = remaining[start..].find(']') {
                let command = &remaining[start + 1..start + end].to_lowercase();
                if command == "left" {
                    let _ = enigo.key(enigo::Key::LeftArrow, Press);
                    let _ = enigo.key(enigo::Key::LeftArrow, Release);
                } else if command == "right" {
                    let _ = enigo.key(enigo::Key::RightArrow, Press);
                    let _ = enigo.key(enigo::Key::RightArrow, Release);
                } else if command == "up" {
                    let _ = enigo.key(enigo::Key::UpArrow, Press);
                    let _ = enigo.key(enigo::Key::UpArrow, Release);
                } else if command == "down" {
                    let _ = enigo.key(enigo::Key::DownArrow, Press);
                    let _ = enigo.key(enigo::Key::DownArrow, Release);
                } else if command == "enter" {
                    let _ = enigo.key(enigo::Key::Return, Press);
                    let _ = enigo.key(enigo::Key::Return, Release);
                } else if command.starts_with("pause:") {
                    // Parse the pause duration in seconds
                    if let Some(secs) = command.strip_prefix("pause:") {
                        if let Ok(secs) = secs.parse::<u64>() {
                            std::thread::sleep(std::time::Duration::from_secs(secs));
                        }
                    }
                } else {
                    // If not recognized, type as normal text
                    enigo.text(&remaining[start..start + end + 1]).unwrap();
                }
                remaining = &remaining[start + end + 1..];
            } else {
                // No closing ], type the rest as normal text
                enigo.text(&remaining[start..]).unwrap();
                break;
            }
        } else {
            // No more [, type the rest as normal text
            enigo.text(remaining).unwrap();
            break;
        }
    }
}

#[tauri::command]
fn set_file_name(app: tauri::AppHandle, name: String) {
    if let Some(file_name_item) = app.state::<FileNameMenuState>().0.lock().unwrap().as_mut() {
        let _ = file_name_item.set_text(&name);
    }
}

#[tauri::command]
fn start_draw(app: tauri::AppHandle) {
    for (label, window) in app.webview_windows().iter() {
        if label.starts_with("draw-window-") {
            let _ = window.emit("start-drawing", ());
        }
    }
}

#[tauri::command]
fn stop_draw(app: tauri::AppHandle) {
    for (label, window) in app.webview_windows().iter() {
        if label.starts_with("draw-window-") {
            let _ = window.emit("stop-drawing", ());
        }
    }
    let _ = change_tray_icon(app.clone(), "#ffffff".to_string(), false);
}

#[tauri::command]
fn update_settings(app: tauri::AppHandle) {
    for (label, window) in app.webview_windows().iter() {
        if label.starts_with("draw-window-") {
            let _ = window.emit("settings-updated", ());
        }
    }
}

#[tauri::command]
fn close_breaktimer(app: tauri::AppHandle) {
    for (label, window) in app.webview_windows().iter() {
        if label.starts_with("break-window-") {
            let _ = window.close();
        }
    }
}

#[tauri::command]
fn show_break_time(app: tauri::AppHandle) {
    create_breaktimer_window(&app);
}

#[tauri::command]
fn change_color(app: tauri::AppHandle, color: String) {
    for (label, window) in app.webview_windows().iter() {
        if label.starts_with("draw-window-") {
            let _ = window.emit("change-color", &color);
        }
    }
    let _ = change_tray_icon(app, color, true);
}

#[tauri::command]
fn broadcast_to_all_windows(app: tauri::AppHandle, name: String, payload: serde_json::Value) {
    for (_label, window) in app.webview_windows().iter() {
        let _ = window.emit(&name, &payload);
    }
}

#[tauri::command]
fn print_output(text: &str) {
    println!("[DEBUG]: {}", text);
}

#[tauri::command]
fn open_settings(app: tauri::AppHandle) -> Result<(), String> {
    if let Some(existing_window) = app.get_webview_window("settings") {
        let _ = existing_window.close();
    }

    let _window =
        WebviewWindowBuilder::new(&app, "settings", WebviewUrl::App("preferences.html".into()))
            .title("PresentInk Settings")
            .inner_size(640.0, 470.0)
            .center()
            .resizable(false)
            .decorations(false)
            .accept_first_mouse(true)
            .transparent(true)
            .always_on_top(true)
            .build()
            .map_err(|e| format!("Failed to create settings window: {}", e))?;
    Ok(())
}

#[tauri::command]
fn open_about(app: tauri::AppHandle) -> Result<(), String> {
    if let Some(existing_window) = app.get_webview_window("about") {
        let _ = existing_window.close();
    }

    let _window = WebviewWindowBuilder::new(&app, "about", WebviewUrl::App("about.html".into()))
        .title("About PresentInk")
        .inner_size(340.0, 450.0)
        .center()
        .resizable(false)
        .decorations(false)
        .transparent(true)
        .always_on_top(true)
        .build()
        .map_err(|e| format!("Failed to create about window: {}", e))?;
    Ok(())
}

#[tauri::command]
fn get_version(app: tauri::AppHandle) -> String {
    app.package_info().version.to_string()
}

#[tauri::command]
fn open_help(app: tauri::AppHandle) -> Result<(), String> {
    if let Some(existing_window) = app.get_webview_window("about") {
        let _ = existing_window.close();
    }

    let _window = WebviewWindowBuilder::new(&app, "help", WebviewUrl::App("help.html".into()))
        .title("PresentInk Help")
        .inner_size(640.0, 670.0)
        .center()
        .resizable(true)
        .decorations(true)
        .always_on_top(false)
        .build()
        .map_err(|e| format!("Failed to create help window: {}", e))?;
    Ok(())
}

#[tauri::command]
async fn open_url(app: tauri::AppHandle, url: String) -> Result<(), String> {
    app.opener()
        .open_url(&url, None::<&str>)
        .map_err(|e| format!("Failed to open URL: {}", e))?;

    println!("Opened URL: {}", url);
    Ok(())
}

#[tauri::command]
fn change_tray_icon(app: tauri::AppHandle, color: String, is_drawing: bool) -> Result<(), String> {
    let icon_path = if is_drawing {
        match color.as_str() {
            "#ff0000" | "red" => "icons/icon-red.png",
            "#0000ff" | "blue" => "icons/icon-blue.png",
            "#00ff00" | "green" => "icons/icon-green.png",
            "#ffff00" | "yellow" => "icons/icon-yellow.png",
            "#ff00ff" | "black" => "icons/icon-pink.png",
            "#ffa500" | "orange" => "icons/icon-orange.png",
            _ => "icons/iconTemplate.png", // Default for unknown colors
        }
    } else {
        "icons/iconTemplate.png" // Default icon when not drawing
    };

    // let icon_path = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join(icon_path);

    if let Some(icon) = get_icon(icon_path) {
        if let Some(tray) = app.tray_by_id("main-tray") {
            tray.set_icon(Some(icon))
                .map_err(|e| format!("Failed to set tray icon: {}", e))?;
            let _ = tray.set_icon_as_template(!is_drawing);
        } else {
            return Err("Tray not found".to_string());
        }
    } else {
        return Err(format!("Failed to load icon: {}", icon_path));
    }

    Ok(())
}

fn imagebuffer_to_arboard(img: &ImageBuffer<Rgba<u8>, Vec<u8>>) -> ImageData<'static> {
    ImageData {
        width: img.width() as usize,
        height: img.height() as usize,
        bytes: std::borrow::Cow::Owned(img.clone().into_raw()),
    }
}

#[tauri::command]
async fn take_region_screenshot(
    app: tauri::AppHandle,
    index: u32,
    x: u32,
    y: u32,
    width: u32,
    height: u32,
    path: String,
    save: bool,
) -> Result<(), String> {
    let monitors = Monitor::all().map_err(|err| err.to_string())?;

    // Find the monitor by name
    if let Some(monitor) = monitors.get(index as usize) {
        close_screenshot_windows_async(&app).await;

        let mut image = monitor
            .capture_region(x, y, width, height)
            .map_err(|e| e.to_string())?;

        let scale = monitor.scale_factor().unwrap_or(1.0);
        if scale != 1.0 {
            let logical_width = (image.width() as f32 / scale) as u32;
            let logical_height = (image.height() as f32 / scale) as u32;
            image = image::imageops::resize(
                &image,
                logical_width,
                logical_height,
                image::imageops::FilterType::Lanczos3,
            );
        }
        if save {
            if !path.is_empty() {
                let _ = &image.save(&path);
            }
        } else {
            let img_data = imagebuffer_to_arboard(&image);

            let mut clipboard = Clipboard::new().map_err(|e| e.to_string())?;
            clipboard.set_image(img_data).map_err(|e| e.to_string())?;

            use tauri_plugin_notification::NotificationExt;
            let _ = app
                .notification()
                .builder()
                .title("PresentInk")
                .body("Screenshot taken and copied to clipboard")
                .show();
        }
    }
    Ok(())
}

async fn close_screenshot_windows_async(app: &tauri::AppHandle) {
    let windows_to_close: Vec<_> = app
        .webview_windows()
        .iter()
        .filter_map(|(label, window)| {
            if label.starts_with("screenshot-window-") {
                Some((label.clone(), window.clone()))
            } else {
                None
            }
        })
        .collect();

    for (label, window) in windows_to_close {
        println!("[DEBUG] Destroying screenshot window: {}", label);
        let _ = window.destroy();
    }

    // Wait for destruction to complete
    std::thread::sleep(std::time::Duration::from_millis(200));
}

#[tauri::command]
fn close_screenshot_windows(app: tauri::AppHandle) {
    for (label, window) in app.webview_windows().iter() {
        if label.starts_with("screenshot-window-") {
            println!("[DEBUG] Destroying {}", label);
            // Emit an event to the window to close it
            let _ = window.destroy();
            
        }
    }
}

#[tauri::command]
fn enable_autolaunch() {
    let app_name = "PresentInk";
    let app_path = "/Applications/PresentInk.app";
    let auto = AutoLaunch::new(
        app_name,
        app_path,
        true,
        &[] as &[&str],
        &["com.presentink"],
        "",
    );

    // enable the auto launch
    auto.enable()
        .map_err(|e| format!("Failed to enable auto launch: {}", e))
        .expect("Failed to enable auto launch");
}

#[tauri::command]
fn disable_autolaunch() {
    let app_name = "PresentInk";
    let app_path = "/Applications/PresentInk.app";
    let auto = AutoLaunch::new(
        app_name,
        app_path,
        true,
        &[] as &[&str],
        &["com.presentink"],
        "",
    );

    // enable the auto launch
    auto.disable()
        .map_err(|e| format!("Failed to enable auto launch: {}", e))
        .expect("Failed to enable auto launch");
}

#[tauri::command]
async fn auto_launch_enabled() -> bool {
    let app_name = "PresentInk";
    let app_path = "/Applications/PresentInk.app";
    let auto = AutoLaunch::new(
        app_name,
        app_path,
        true,
        &[] as &[&str],
        &["com.presentink"],
        "",
    );

    auto.is_enabled().unwrap()
}

fn create_screenshot_windows(app: &tauri::AppHandle) {
    // Close existing screenshot windows if they exist
    close_screenshot_windows(app.clone());
    if let Ok(monitors) = app.available_monitors() {
        for (index, monitor) in monitors.iter().enumerate() {
            let uuid = Uuid::new_v4();
            let window_label = format!("screenshot-window-{}-{}", index, uuid);
            println!("[DEBUG] {}", window_label);
            // Close existing window if it exists
            if let Some(existing_window) = app.webview_windows().get(&window_label) {
                let _ = existing_window.close();
            }
            let position = monitor.position();
            let size = monitor.size();

            let init_script = format!(
                r#"window.monitor = {{ index: {}, factor:{} }};"#,
                index,
                monitor.scale_factor()
            );

            match WebviewWindowBuilder::new(
                app,
                &window_label,
                WebviewUrl::App("screenshot.html".into()),
            )
            .title(&format!("Screenshot Handler {}-{}", index + 1, uuid))
            .background_throttling(tauri::utils::config::BackgroundThrottlingPolicy::Disabled)
            .position(position.x as f64, position.y as f64)
            .inner_size(size.width as f64, size.height as f64)
            .center()
            .resizable(false)
            .transparent(true)
            .visible_on_all_workspaces(true)
            .decorations(false)
            .always_on_top(true)
            .theme(None)
            .shadow(false)
            .initialization_script(init_script)
            .skip_taskbar(true)
            .accept_first_mouse(true)
            .build()
            {
                Ok(window) => {
                    let _ = window.hide_menu();
                    let _ =
                        window.set_position(tauri::Position::Physical(tauri::PhysicalPosition {
                            x: position.x,
                            y: position.y,
                        }));
                    let _ = window.set_size(tauri::Size::Physical(tauri::PhysicalSize {
                        width: size.width,
                        height: size.height,
                    }));
                    let _ = window.show();
                    let _ = window.set_focus();
                }

                Err(e) => {
                    println!("Failed to create window {}: {:?}", index, e);
                }
            }
        }
    }
}
