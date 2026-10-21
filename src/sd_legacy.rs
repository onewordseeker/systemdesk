// SystemDesk: files an older version put in the install folder under a RustDesk name. The program's files are named SystemDesk now
// (libsystemdesk.dll, RuntimeBroker_systemdesk.exe); an install or update copies the new ones next to the old ones, so the old ones are removed
// at the same time and nothing named RustDesk is left behind.
#![cfg(windows)]

const LEGACY_FILES: [&str; 2] = ["librustdesk.dll", "RuntimeBroker_rustdesk.exe"];

/// Lines for the install / update script: stop the old broker (it may be running for privacy mode), then delete the old files.
pub fn remove_legacy_files_cmd(path: &str) -> String {
    let files = LEGACY_FILES
        .iter()
        .map(|f| format!("\"{path}\\{f}\""))
        .collect::<Vec<_>>()
        .join(" ");
    format!(
        "
        taskkill /F /IM {broker}
        del /F /Q {files}
        ",
        broker = LEGACY_FILES[1],
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_old_names_are_stopped_and_deleted_inside_the_install_folder() {
        let cmd = remove_legacy_files_cmd(r"C:\Program Files\SystemDesk");
        assert!(cmd.contains("taskkill /F /IM RuntimeBroker_rustdesk.exe"));
        assert!(cmd.contains(r#"del /F /Q "C:\Program Files\SystemDesk\librustdesk.dll" "C:\Program Files\SystemDesk\RuntimeBroker_rustdesk.exe""#));
        // nothing that is still in use
        assert!(!cmd.contains("libsystemdesk"));
        assert!(!cmd.contains("RuntimeBroker_systemdesk"));
    }
}
