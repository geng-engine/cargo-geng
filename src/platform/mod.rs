pub mod web;

#[derive(Debug, PartialEq, Eq, Clone, Copy, strum::EnumString, strum::Display)]
#[strum(serialize_all = "snake_case")]
pub enum Platform {
    Linux,
    Windows,
    Mac,
    Web,
    Android,
}

impl Platform {
    pub fn current() -> Self {
        if cfg!(target_os = "windows") {
            Self::Windows
        } else if cfg!(target_os = "linux") {
            Self::Linux
        } else if cfg!(target_os = "macos") {
            Self::Mac
        } else {
            panic!("Unable to determine current platform")
        }
    }
}
