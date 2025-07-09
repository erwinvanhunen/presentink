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
    #[serde(rename = "shortcuts")]
    pub shortcuts: Shortcuts,
    #[serde(rename = "lastVersionCheck")]
    pub last_version_check: String,
    #[serde(rename = "versionCheck")]
    pub version_check: bool, // Optional field for version check
    #[serde(rename = "defaultColor")]
    pub default_color: String,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Shortcuts {
    pub drawing: String,
    pub text: String,
    pub break_mode: String,
    pub screenshot: String,
    pub preferences: String,
}

impl Default for Shortcuts {
    fn default() -> Self {
        Self {
            drawing: "Option+Shift+D".into(),
            text: "Option+Shift+T".into(),
            break_mode: "Option+Shift+B".into(),
            screenshot: "Option+Shift+S".into(),
            preferences: "Option+Shift+P".into(),
        }
    }
}

impl Default for AppSettings {
    fn default() -> Self {
        Self {
            pen_width: 3,
            arrow_head_length: 20,
            launch_on_startup: false,
            show_experimental_features: false,
            break_time: 10,
            shortcuts: Shortcuts::default(),
            last_version_check: "0".into(), // Default date for last version check
            version_check: true,
            default_color: "#ff0000".into()
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

pub fn save_settings(app: &AppHandle, settings: &AppSettings) -> Result<(), String> {
    let store = StoreBuilder::new(app, ".settings.dat")
        .build()
        .map_err(|e| format!("Failed to create store: {}", e))?;

    let settings_value = serde_json::to_value(settings)
        .map_err(|e| format!("Failed to serialize settings: {}", e))?;

    store.set("settings", settings_value);

    store
        .save()
        .map_err(|e| format!("Failed to save settings: {}", e))?;

    Ok(())
}
