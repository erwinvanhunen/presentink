use serde::{Deserialize, Serialize};
use tauri::AppHandle;
use tauri_plugin_store::StoreBuilder;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppSettings {
    #[serde(rename = "penWidth")]
    pub pen_width: u32,
    #[serde(rename = "arrowHeadLength")]
    pub arrow_head_length: u32,
    #[serde(rename = "launchOnStartup")]
    pub launch_on_startup: bool,
    #[serde(rename = "showExperimentalFeatures")]
    pub show_experimental_features: bool,
    #[serde(rename = "breakTime")]
    pub break_time: u32,
    #[serde(rename = "drawingShortcut")]
    pub drawing_shortcut: String,
}

impl Default for AppSettings {
    fn default() -> Self {
        Self {
            pen_width: 3,
            arrow_head_length: 20,
            launch_on_startup: false,
            show_experimental_features: false,
            break_time: 10,
            drawing_shortcut: "Alt+Shift+D".into(),
        }
    }
}

/// Retrieve settings from the `.settings.dat` file using the Tauri Store plugin.
/// Returns `AppSettings` (with defaults if not found or invalid).
pub fn get_settings(app: &AppHandle) -> AppSettings {
    let store = match StoreBuilder::new(app, ".settings.dat").build() {
        Ok(store) => store,
        Err(_) => return AppSettings::default(),
    };
    match store.get("settings") {
        Some(val) => serde_json::from_value(val).unwrap_or_default(),
        None => AppSettings::default(),
    }
}
