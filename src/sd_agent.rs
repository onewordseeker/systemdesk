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

/// The program a service starts: the first word of its `ImagePath`, in quotes or not.
pub fn image_path_exe(image_path: &str) -> String {
    let s = image_path.trim();
    if let Some(quoted) = s.strip_prefix('"') {
        return quoted.split('"').next().unwrap_or("").to_owned();
    }
    match s.to_ascii_lowercase().find(".exe") {
        Some(at) => s[..at + 4].to_owned(),
        None => s.split_whitespace().next().unwrap_or("").to_owned(),
    }
}

/// Both paths name the same program (on Windows capitals and the kind of slash do not matter).
pub fn same_program(a: &str, b: &str) -> bool {
    let norm = |p: &str| p.trim().trim_matches('"').replace('/', "\\").to_lowercase();
    !a.trim().is_empty() && norm(a) == norm(b)
}

/// What it takes to have the Windows service of this computer running.
#[derive(Debug, PartialEq)]
pub enum ServiceAction {
    /// no such service: install it
    Install,
    /// it is there but starts another program (a Store update moved this one): point it here and start it
    Repair,
    /// it is there and right but stopped
    Start,
    /// running
    Nothing,
}

/// `registered`: the program the registered service starts (None: no such service); `installed`: the program of the installed copy.
pub fn service_action(registered: Option<&str>, installed: &str, running: bool) -> ServiceAction {
    match registered {
        None => ServiceAction::Install,
        Some(exe) if !same_program(exe, installed) => ServiceAction::Repair,
        Some(_) if !running => ServiceAction::Start,
        Some(_) => ServiceAction::Nothing,
    }
}

#[cfg(target_os = "windows")]
fn windows_action() -> ServiceAction {
    use crate::platform::windows as w;
    service_action(
        w::service_exe(&crate::get_app_name()).as_deref(),
        &w::get_install_info().3,
        w::is_self_service_running(),
    )
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

/// What the home page of the app shows about the background service of this computer: `running`, `not-running` (installed, not running; on
/// Windows also a service that starts another program, as one left behind by an older version), `not-installed` (macOS: no service; Windows:
/// the app runs without being installed, or has no service), or `n/a` where there is no such service. The Microsoft Store copy has none on
/// purpose: a service starts the approval window with the user's token, and Windows does not let that run a program from the Store folder.
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
        if crate::sd_update::store_copy() {
            return "n/a";
        }
        return match windows_action() {
            ServiceAction::Install => "not-installed",
            ServiceAction::Repair | ServiceAction::Start => "not-running",
            ServiceAction::Nothing => "running",
        };
    }
    #[allow(unreachable_code)]
    "n/a"
}

/// Gets the background service of this computer going for the person who asked: macOS installs or starts the agent; Windows installs the
/// service when it is not there, points it at this copy when it starts another one, and starts it otherwise (Windows asks for permission, a
/// service is not started by a normal user). The relay (the `stop-service` option) is a separate matter and is not touched here.
pub fn start_now() {
    #[cfg(target_os = "macos")]
    run::start_now();
    #[cfg(target_os = "windows")]
    {
        use hbb_common::{config::Config, log};
        if crate::sd_update::store_copy() {
            log::info!("the Store copy has no background service");
            return;
        }
        match windows_action() {
            ServiceAction::Install => {
                // The install "Start service" always was: the service, the settings it takes over, a new window. It ends this process when it
                // works. When it fails it marks the relay as stopped, which the person did not ask for: put the option back.
                let relay = Config::get_option("stop-service");
                crate::platform::install_service();
                Config::set_option("stop-service".into(), relay);
                log::warn!("the background service could not be installed");
            }
            ServiceAction::Repair => {
                let repaired = crate::platform::windows::repair_and_start_service();
                log::info!("repair of the service asked: {repaired:?}");
            }
            ServiceAction::Start => {
                let started = crate::platform::windows::run_uac(
                    "sc.exe",
                    &format!("start {}", crate::get_app_name()),
                );
                log::info!("start of the service asked: {started:?}");
            }
            ServiceAction::Nothing => {}
        }
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

    #[test]
    fn the_program_of_a_service_is_found_in_its_image_path() {
        let exe = r"C:\Program Files\SystemDesk\SystemDesk.exe";
        assert_eq!(image_path_exe(&format!("\"{exe}\" --service")), exe);
        assert_eq!(image_path_exe(&format!("{exe} --service")), exe);
        assert_eq!(
            image_path_exe(r"C:\Program Files\SystemDesk\SystemDesk.EXE"),
            r"C:\Program Files\SystemDesk\SystemDesk.EXE"
        );
        assert_eq!(image_path_exe("svchost -k netsvcs"), "svchost");
        assert_eq!(image_path_exe(""), "");
    }

    #[test]
    fn two_paths_are_the_same_program_whatever_their_capitals() {
        assert!(same_program(
            r"C:\Program Files\SystemDesk\SystemDesk.exe",
            r"c:\program files\systemdesk\SYSTEMDESK.EXE"
        ));
        assert!(same_program(
            r#""C:\Program Files\SystemDesk\SystemDesk.exe""#,
            "C:/Program Files/SystemDesk/SystemDesk.exe"
        ));
        assert!(!same_program(r"C:\A\SystemDesk.exe", r"C:\B\SystemDesk.exe"));
        assert!(!same_program("", ""), "no program is no match");
    }

    #[test]
    fn the_windows_service_is_installed_repaired_started_or_left_alone() {
        let here = r"C:\Program Files\SystemDesk\SystemDesk.exe";
        assert_eq!(service_action(None, here, false), ServiceAction::Install);
        assert_eq!(service_action(None, here, true), ServiceAction::Install);
        assert_eq!(
            service_action(Some(here), here, false),
            ServiceAction::Start
        );
        assert_eq!(
            service_action(Some(here), here, true),
            ServiceAction::Nothing
        );
        assert_eq!(
            service_action(Some(&here.to_uppercase()), here, true),
            ServiceAction::Nothing
        );
        assert_eq!(service_action(Some(""), here, true), ServiceAction::Repair);
    }

    #[test]
    fn a_service_left_by_the_previous_store_version_is_repaired_even_when_it_runs() {
        let image = r#""C:\Program Files\WindowsApps\LesoftPvtLtd.systemdesk_1.5.15.0_x64__bkqns9tv45j1g\VFS\ProgramFilesX64\SystemDesk\SystemDesk.exe" --service"#;
        let now = r"C:\Program Files\WindowsApps\LesoftPvtLtd.systemdesk_1.5.16.0_x64__bkqns9tv45j1g\VFS\ProgramFilesX64\SystemDesk\SystemDesk.exe";
        for running in [true, false] {
            assert_eq!(
                service_action(Some(&image_path_exe(image)), now, running),
                ServiceAction::Repair
            );
        }
        let same = image.replace("1.5.15.0", "1.5.16.0");
        assert_eq!(
            service_action(Some(&image_path_exe(&same)), now, true),
            ServiceAction::Nothing
        );
    }
}
