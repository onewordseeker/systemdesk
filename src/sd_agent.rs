// SystemDesk, macOS: keep the background service running.
//
// The service is a launch agent (/Library/LaunchAgents/<org>.<app>_server.plist) that runs `<app> --server` and shows the menu bar icon. launchd
// loads it at login. The in-app update replaces the app and reloads the agent in its last step; when that step failed quietly the agent stayed down
// until the next restart, and the window then ran a server of its own that ended with the window ("Ready", but closing the app closed everything).
//
// So when the app is opened and the service is installed (and not stopped on purpose) but not running, it is started here, before the app would start a
// server of its own (which the agent would take over, closing the window).
#![cfg_attr(not(target_os = "macos"), allow(dead_code))]

/// What the agent is called to launchd: the plist label.
pub fn agent_label(full_name: &str) -> String {
    format!("{full_name}_server")
}

pub fn agent_plist_path(label: &str) -> String {
    format!("/Library/LaunchAgents/{label}.plist")
}

/// The `launchctl` calls that bring the agent up for the user `uid`, in the order they are tried: start it if it is loaded, load it and start it,
/// the old `load` as the last resort.
pub fn start_attempts(uid: u32, label: &str, plist: &str) -> Vec<Vec<String>> {
    let service = format!("gui/{uid}/{label}");
    let domain = format!("gui/{uid}");
    let v = |a: &[&str]| a.iter().map(|s| s.to_string()).collect::<Vec<_>>();
    vec![
        v(&["kickstart", &service]),
        v(&["bootstrap", &domain, plist]),
        v(&["kickstart", &service]),
        v(&["load", "-w", plist]),
    ]
}

#[cfg(target_os = "macos")]
mod run {
    use super::{agent_label, agent_plist_path, start_attempts};
    use hbb_common::log;
    use std::time::{Duration, Instant};

    const WAIT_FOR_SERVER: Duration = Duration::from_secs(3);
    // the agent needs a moment after it is running to listen: the app asks it right away and would start a server of its own if it did not answer
    const SETTLE: Duration = Duration::from_secs(2);

    fn server_running() -> bool {
        crate::check_process("--server", true)
    }

    fn wait_for_server() -> bool {
        let until = Instant::now() + WAIT_FOR_SERVER;
        while Instant::now() < until {
            if server_running() {
                return true;
            }
            std::thread::sleep(Duration::from_millis(250));
        }
        server_running()
    }

    /// Starts the background service when it is installed, meant to run and not running. Blocks for a few seconds only in that case.
    pub fn ensure_running() {
        if crate::platform::is_root() || !crate::platform::macos::is_installed_daemon(false) {
            return;
        }
        if hbb_common::config::option2bool(
            "stop-service",
            &hbb_common::config::Config::get_option("stop-service"),
        ) {
            return;
        }
        if server_running() {
            return;
        }
        start_agent();
    }

    // Starts the agent for this user, one `launchctl` call after the other until the server answers.
    fn start_agent() -> bool {
        let uid = unsafe { hbb_common::libc::getuid() };
        let label = agent_label(&crate::get_full_name());
        let plist = agent_plist_path(&label);
        log::info!("The background service is installed but not running: starting {label}");
        for args in start_attempts(uid, &label, &plist) {
            match std::process::Command::new("/bin/launchctl")
                .args(&args)
                .output()
            {
                Ok(out) => log::info!(
                    "launchctl {}: {} {}",
                    args.join(" "),
                    out.status,
                    String::from_utf8_lossy(&out.stderr).trim()
                ),
                Err(e) => log::warn!("launchctl {} could not run: {}", args.join(" "), e),
            }
            if wait_for_server() {
                log::info!("The background service is running");
                std::thread::sleep(SETTLE);
                return true;
            }
        }
        log::warn!("The background service could not be started; the app runs without it");
        false
    }

    pub fn service_state() -> &'static str {
        if !crate::platform::macos::is_installed_daemon(false) {
            "not-installed"
        } else if server_running() {
            "running"
        } else {
            "not-running"
        }
    }

    /// The person asked for the service: install it when it is not there (macOS asks for the password), start it when it is.
    pub fn start_now() {
        if !crate::platform::macos::is_installed_daemon(false) {
            crate::platform::macos::is_installed_daemon(true);
        } else if !server_running() {
            start_agent();
        }
    }
}

/// What the home page of the app shows about the background service of this computer: `running`, `not-running` (installed, not running),
/// `not-installed` (macOS: no service; Windows: the app runs without being installed, or its service is not there), or `n/a` where there is no
/// such service (also the copy from the Microsoft Store).
pub fn service_state() -> &'static str {
    #[cfg(target_os = "macos")]
    {
        return run::service_state();
    }
    #[cfg(target_os = "windows")]
    {
        if !crate::platform::windows::is_installed() {
            return "not-installed";
        }
        // the Store copy has no Windows service, and a service that is not there is not a service that stopped
        if crate::platform::windows::is_msix_package() {
            return "n/a";
        }
        if !crate::platform::windows::is_service_registered(&crate::get_app_name()) {
            return "not-installed";
        }
        return if crate::platform::windows::is_self_service_running() {
            "running"
        } else {
            "not-running"
        };
    }
    #[allow(unreachable_code)]
    "n/a"
}

/// Starts the service of this computer for the person who asked: macOS installs or starts the agent; Windows starts the installed service
/// (Windows asks for permission, a service is not started by a normal user).
pub fn start_now() {
    #[cfg(target_os = "macos")]
    run::start_now();
    #[cfg(target_os = "windows")]
    {
        let started = crate::platform::windows::run_uac(
            "sc.exe",
            &format!("start {}", crate::get_app_name()),
        );
        hbb_common::log::info!("start of the service asked: {started:?}");
    }
}

/// Called when the main window is opened, before the app starts a server of its own.
#[cfg(target_os = "macos")]
pub fn ensure_running() {
    run::ensure_running();
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_agent_is_called_by_the_app_and_org_name() {
        assert_eq!(
            agent_label("com.carriez.SystemDesk"),
            "com.carriez.SystemDesk_server"
        );
        assert_eq!(
            agent_plist_path("com.carriez.SystemDesk_server"),
            "/Library/LaunchAgents/com.carriez.SystemDesk_server.plist"
        );
    }

    #[test]
    fn the_agent_is_started_for_the_users_own_session() {
        let a = start_attempts(
            501,
            "com.carriez.SystemDesk_server",
            "/Library/LaunchAgents/com.carriez.SystemDesk_server.plist",
        );
        assert_eq!(
            a[0],
            vec!["kickstart", "gui/501/com.carriez.SystemDesk_server"]
        );
        assert_eq!(
            a[1],
            vec![
                "bootstrap",
                "gui/501",
                "/Library/LaunchAgents/com.carriez.SystemDesk_server.plist"
            ]
        );
        assert_eq!(a[2], a[0], "after loading it, start it");
        assert_eq!(a[3][0], "load");
        assert!(a.iter().all(|c| !c.is_empty()));
    }
}
