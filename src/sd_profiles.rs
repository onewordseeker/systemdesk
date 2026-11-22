// SystemDesk: permission profiles for unattended access. The owner of a computer makes any number of profiles; each has its own password and its own
// set of permissions. Whoever connects with a profile's password gets exactly that profile's permissions. The computer's own password and the one-time
// password keep working as before (they get what Settings > Security > Permissions says).
//
// The profiles live in the option `sd-profiles` (JSON). A password is kept the way the old permanent password was: encrypted for this computer, because
// the login handshake needs the password itself to compute the hash the other side sends (it depends on a salt and a challenge made per connection).
use hbb_common::{
    config::Config,
    password_security as ps,
    sha2::{Digest, Sha256},
};
use serde::{Deserialize, Serialize};

pub const PROFILES_OPTION: &str = "sd-profiles";
/// read with `main_get_local_option`: the profiles without their passwords
pub const LIST_KEY: &str = "sd-profiles";
/// written with `main_set_option`: one command (see [`Command`])
pub const COMMAND_KEY: &str = "sd-profile-command";

const MAX_PROFILES: usize = 16;
const MAX_NAME: usize = 32;
const MIN_PASSWORD: usize = 6;
const MAX_PASSWORD: usize = 64;

#[derive(Clone, Debug, Default, Serialize, Deserialize, PartialEq, Eq)]
#[serde(default)]
pub struct Perms {
    pub keyboard: bool,
    pub clipboard: bool,
    pub file: bool,
    pub audio: bool,
    pub restart: bool,
    pub recording: bool,
    pub block_input: bool,
    pub privacy_mode: bool,
    pub system_info: bool,
    pub lock_on_end: bool,
}

impl Perms {
    /// every permission except "lock when the session ends", which is a rule for the computer and not something a person is allowed
    fn set_access(&mut self, on: bool) {
        self.keyboard = on;
        self.clipboard = on;
        self.file = on;
        self.audio = on;
        self.restart = on;
        self.recording = on;
        self.block_input = on;
        self.privacy_mode = on;
        self.system_info = on;
    }
}

#[derive(Clone, Debug, Default, Serialize, Deserialize, PartialEq, Eq)]
#[serde(default)]
pub struct Profile {
    pub name: String,
    pub enabled: bool,
    /// the password, sealed for this computer (never leaves it)
    pub secret: String,
    /// "custom" (the switches below as set), "full" (all on) or "view" (screen share: all off), like the general Permissions
    pub mode: String,
    pub perms: Perms,
    /// one of the standard profiles every computer has: it cannot be deleted
    pub builtin: bool,
}

const DEFAULT_NAME: &str = "Default";
/// the option that names the profile whose permissions are the computer's own (empty = "Default")
const ACTIVE_OPTION: &str = "sd-active-profile";
const ACCESS_MODE: &str = "access-mode";
/// off until it is set to "Y" (the app's `option2bool` reads an unset option as on for every key that is not an "enable-" or "allow-" one)
pub const LOCK_OPTION: &str = "lock-on-session-end";

// The "Default" profile IS the computer's general permissions (what a one-time password, an accepted request or the computer's own password get): its
// switches are the options the rest of the app reads, so there is one set of permissions and not two. These are the options, field by field.
const GENERAL_OPTIONS: [&str; 10] = [
    "enable-keyboard",
    "enable-clipboard",
    "enable-file-transfer",
    "enable-audio",
    "enable-remote-restart",
    "enable-record-session",
    "enable-block-input",
    "enable-privacy-mode",
    "enable-system-info",
    "lock-on-session-end",
];

fn perms_to_array(p: &Perms) -> [bool; 10] {
    [p.keyboard, p.clipboard, p.file, p.audio, p.restart, p.recording, p.block_input, p.privacy_mode, p.system_info, p.lock_on_end]
}

fn perms_from_array(a: [bool; 10]) -> Perms {
    Perms {
        keyboard: a[0],
        clipboard: a[1],
        file: a[2],
        audio: a[3],
        restart: a[4],
        recording: a[5],
        block_input: a[6],
        privacy_mode: a[7],
        system_info: a[8],
        lock_on_end: a[9],
    }
}

/// The mode and permissions the general options stand for: "full" and "view" decide everything (but the lock); otherwise each option says (an
/// "enable-" option that was never set is on, as everywhere in the app; the lock is off until it is set).
pub fn perms_from_options(get: &dyn Fn(&str) -> String) -> (String, Perms) {
    let mut a = [false; 10];
    for (i, key) in GENERAL_OPTIONS.iter().enumerate() {
        a[i] = if *key == LOCK_OPTION { get(key) == "Y" } else { hbb_common::config::option2bool(key, &get(key)) };
    }
    normalized(&get(ACCESS_MODE), perms_from_array(a))
}

/// The options that make the general permissions what a profile says.
pub fn options_for(mode: &str, perms: &Perms) -> Vec<(&'static str, String)> {
    let (mode, perms) = normalized(mode, perms.clone());
    let mut out = vec![(ACCESS_MODE, if mode == "custom" { String::new() } else { mode })];
    for (key, on) in GENERAL_OPTIONS.iter().zip(perms_to_array(&perms)) {
        out.push((*key, if on { "Y" } else { "N" }.to_owned()));
    }
    out
}

fn standard_profile(name: &str, mode: &str, perms: Perms) -> Profile {
    let (mode, perms) = normalized(mode, perms);
    Profile { name: name.to_owned(), enabled: false, secret: String::new(), mode, perms, builtin: true }
}

/// The profiles every computer starts with (as in AnyDesk). None has a password yet, so none lets anyone in until its owner sets one.
pub fn standard() -> Vec<Profile> {
    vec![
        // for a session someone is let into: sound, control, clipboard, files and system information; nothing that changes the computer's state, and no
        // recording of the session (that is for its owner to switch on)
        standard_profile(
            "Default",
            "custom",
            Perms { keyboard: true, clipboard: true, file: true, audio: true, system_info: true, ..Default::default() },
        ),
        standard_profile("Screen Sharing", "view", Perms::default()),
        standard_profile("Full Access", "full", Perms::default()),
        // for a computer nobody sits at: everything but recording the session, and the computer locks itself when the session ends
        standard_profile(
            "Unattended Access",
            "custom",
            Perms {
                keyboard: true,
                clipboard: true,
                file: true,
                audio: true,
                restart: true,
                block_input: true,
                privacy_mode: true,
                system_info: true,
                lock_on_end: true,
                ..Default::default()
            },
        ),
    ]
}

/// What a standard profile was before its permissions were changed in a release, for a computer that still has that one saved: it becomes the new one.
/// (A profile its owner changed is not equal to the old one, so it is left alone.)
fn superseded(name: &str) -> Option<(&'static str, Perms)> {
    match name {
        // recording used to be on
        "Default" => Some((
            "custom",
            Perms { keyboard: true, clipboard: true, file: true, audio: true, recording: true, system_info: true, ..Default::default() },
        )),
        // used to be "full" with the lock
        "Unattended Access" => {
            let mut p = Perms { lock_on_end: true, ..Default::default() };
            p.set_access(true);
            Some(("full", p))
        }
        _ => None,
    }
}

/// `profiles` with the standard ones in front (those that are missing are added; one made by hand under a standard name becomes that standard one).
pub fn with_standard(profiles: Vec<Profile>) -> Vec<Profile> {
    let mut out = Vec::with_capacity(profiles.len() + 4);
    let mut rest = profiles;
    for std in standard() {
        match rest.iter().position(|p| same(&p.name, &std.name)) {
            Some(i) => {
                let mut p = rest.remove(i);
                if let Some((old_mode, old_perms)) = superseded(&std.name) {
                    if p.builtin && p.mode == old_mode && p.perms == old_perms {
                        p.mode = std.mode.clone();
                        p.perms = std.perms.clone();
                    }
                }
                p.name = std.name;
                p.builtin = true;
                out.push(p);
            }
            None => out.push(std),
        }
    }
    out.extend(rest);
    out
}

/// The mode and the permissions it really gives: "full" and "view" decide every permission themselves, anything else is custom.
fn normalized(mode: &str, mut perms: Perms) -> (String, Perms) {
    match mode {
        "full" => {
            perms.set_access(true);
            ("full".to_owned(), perms)
        }
        "view" => {
            perms.set_access(false);
            ("view".to_owned(), perms)
        }
        _ => ("custom".to_owned(), perms),
    }
}

#[derive(Debug, Deserialize)]
#[serde(tag = "op", rename_all = "lowercase")]
pub enum Command {
    /// create the profile, or change it; without a password the old one stays
    Set {
        name: String,
        #[serde(default)]
        password: String,
        #[serde(default = "yes")]
        enabled: bool,
        #[serde(default)]
        mode: String,
        #[serde(default)]
        perms: Perms,
    },
    Delete { name: String },
    /// make this profile's permissions the computer's own (what a one-time password, an accepted request and the computer's password get)
    Use { name: String },
    /// switch unattended access of a profile on or off: on means its password lets someone in without anyone accepting. A password may come with it
    /// (made or changed); turning on without one needs the profile to have one already.
    Unattended {
        name: String,
        enabled: bool,
        #[serde(default)]
        password: String,
    },
}

fn yes() -> bool {
    true
}

fn same(a: &str, b: &str) -> bool {
    a.trim().to_lowercase() == b.trim().to_lowercase()
}

pub fn parse(json: &str) -> Vec<Profile> {
    serde_json::from_str(json).unwrap_or_default()
}

/// What Settings may see: everything but the passwords (and whether there is one).
#[cfg(test)]
pub fn list_json(profiles: &[Profile]) -> String {
    list_json_active(profiles, "", false)
}

/// The same, saying which profile gives the computer its own permissions (`active`) and whether those were changed by hand since (`modified`).
pub fn list_json_active(profiles: &[Profile], active: &str, modified: bool) -> String {
    let rows: Vec<_> = profiles
        .iter()
        .map(|p| {
            let is_active = !active.is_empty() && same(&p.name, active);
            serde_json::json!({
                "name": p.name,
                "enabled": p.enabled,
                "has_password": !p.secret.is_empty(),
                "builtin": p.builtin,
                "active": is_active,
                "modified": is_active && modified,
                "mode": if p.mode.is_empty() { "custom" } else { p.mode.as_str() },
                "perms": p.perms,
            })
        })
        .collect();
    serde_json::to_string(&rows).unwrap_or_else(|_| "[]".to_owned())
}

/// Apply one command to the list. `seal` makes the stored form of a password.
pub fn apply(profiles: &mut Vec<Profile>, cmd: Command, seal: impl Fn(&str) -> String) -> Result<(), String> {
    match cmd {
        Command::Use { name } => {
            if profiles.iter().any(|p| same(&p.name, &name)) {
                Ok(())
            } else {
                Err("no such profile".to_owned())
            }
        }
        Command::Unattended { name, enabled, password } => {
            let Some(i) = profiles.iter().position(|p| same(&p.name, &name)) else {
                return Err("no such profile".to_owned());
            };
            if !password.is_empty() && !(MIN_PASSWORD..=MAX_PASSWORD).contains(&password.chars().count()) {
                return Err(format!("the password must have {MIN_PASSWORD} to {MAX_PASSWORD} characters"));
            }
            if enabled && password.is_empty() && profiles[i].secret.is_empty() {
                return Err("create a password for this profile first".to_owned());
            }
            if !password.is_empty() {
                profiles[i].secret = seal(&password);
            }
            profiles[i].enabled = enabled;
            Ok(())
        }
        Command::Delete { name } => {
            if profiles.iter().any(|p| p.builtin && same(&p.name, &name)) {
                return Err("a standard profile cannot be deleted".to_owned());
            }
            let before = profiles.len();
            profiles.retain(|p| !same(&p.name, &name));
            if profiles.len() == before {
                return Err("no such profile".to_owned());
            }
            Ok(())
        }
        Command::Set { name, password, enabled, mode, perms } => {
            let (mode, perms) = normalized(&mode, perms);
            let name = name.trim().to_owned();
            if name.is_empty() || name.chars().count() > MAX_NAME {
                return Err(format!("the name must have 1 to {MAX_NAME} characters"));
            }
            let existing = profiles.iter().position(|p| same(&p.name, &name));
            if !password.is_empty() && !(MIN_PASSWORD..=MAX_PASSWORD).contains(&password.chars().count()) {
                return Err(format!("the password must have {MIN_PASSWORD} to {MAX_PASSWORD} characters"));
            }
            match existing {
                Some(i) => {
                    let p = &mut profiles[i];
                    p.name = name;
                    p.enabled = enabled;
                    p.mode = mode;
                    p.perms = perms;
                    if !password.is_empty() {
                        p.secret = seal(&password);
                    }
                }
                None => {
                    if password.is_empty() {
                        return Err("a new profile needs a password".to_owned());
                    }
                    if profiles.len() >= MAX_PROFILES {
                        return Err(format!("at most {MAX_PROFILES} profiles"));
                    }
                    profiles.push(Profile { name, enabled, secret: seal(&password), mode, perms, builtin: false });
                }
            }
            Ok(())
        }
    }
}

/// The profile whose password the connecting side used. `verify` gets the first hash of a candidate password (`sha256(password + salt)`, the way the
/// other side makes it) and says whether it is the one that was sent.
pub fn find<'a>(
    profiles: &'a [Profile],
    salt: &str,
    open: impl Fn(&str) -> String,
    verify: impl Fn(&[u8]) -> bool,
) -> Option<&'a Profile> {
    let mut found = None;
    // every enabled profile is tried (no early exit), so the time taken does not say which one is first
    for p in profiles.iter().filter(|p| p.enabled && !p.secret.is_empty()) {
        let password = open(&p.secret);
        if password.is_empty() {
            continue;
        }
        let mut hasher = Sha256::new();
        hasher.update(password.as_bytes());
        hasher.update(salt.as_bytes());
        let h1 = hasher.finalize();
        if verify(&h1[..]) && found.is_none() {
            found = Some(p);
        }
    }
    found
}

fn seal(password: &str) -> String {
    ps::encrypt_str_or_original(password, "00", MAX_PASSWORD)
}

fn open(sealed: &str) -> String {
    ps::decrypt_str_or_original(sealed, "00").0
}

/// In the computer's own process (the one that lets people in): its own configuration.
fn load_host() -> Vec<Profile> {
    parse(&Config::get_option(PROFILES_OPTION))
}

/// In the window of the app: the options as the computer's process has them (an installed Windows computer keeps them in the service's configuration,
/// so they are read and written through it, like every other option of Settings).
fn load_ui() -> Vec<Profile> {
    parse(&crate::ui_interface::get_option(PROFILES_OPTION.to_owned()))
}

fn ui_option(key: &str) -> String {
    crate::ui_interface::get_option(key.to_owned())
}

/// The profile that gives the computer its own permissions: the one named in the option, and "Default" when none is (or the one named is gone).
fn active_of(profiles: &[Profile], named: &str) -> String {
    profiles.iter().find(|p| same(&p.name, named)).map_or_else(|| DEFAULT_NAME.to_owned(), |p| p.name.clone())
}

/// Make `name` the profile that gives the computer its own permissions: its permissions are written where the rest of the app reads them.
fn activate(profiles: &[Profile], name: &str) {
    let Some(p) = profiles.iter().find(|p| same(&p.name, name)) else {
        return;
    };
    for (key, value) in options_for(&p.mode, &p.perms) {
        crate::ui_interface::set_option(key.to_owned(), value);
    }
    crate::ui_interface::set_option(ACTIVE_OPTION.to_owned(), p.name.clone());
}

pub fn list_json_now() -> String {
    let profiles = with_standard(load_ui());
    let named = ui_option(ACTIVE_OPTION);
    let active = active_of(&profiles, &named);
    if !same(&named, &active) {
        // the first time, or the profile that was active is gone: "Default" is the active one, and its permissions become the computer's
        activate(&profiles, &active);
    }
    let modified = profiles
        .iter()
        .find(|p| same(&p.name, &active))
        .map_or(false, |p| perms_from_options(&ui_option) != normalized(&p.mode, p.perms.clone()));
    list_json_active(&profiles, &active, modified)
}

/// A command from Settings (JSON). The answer is empty when it worked, else the reason to show.
pub fn run_command(json: &str) -> String {
    let cmd: Command = match serde_json::from_str(json) {
        Ok(c) => c,
        Err(_) => return "unreadable command".to_owned(),
    };
    // the profile this command is about, and what to do with the computer's own permissions afterwards
    let (touched, switch_to) = match &cmd {
        Command::Set { name, .. } | Command::Delete { name } => (Some(name.clone()), None),
        Command::Use { name } => (None, Some(name.clone())),
        // only the password and whether it lets anyone in: the permissions do not change
        Command::Unattended { .. } => (None, None),
    };
    let mut profiles = with_standard(load_ui());
    if let Err(why) = apply(&mut profiles, cmd, seal) {
        return why;
    }
    let s = match serde_json::to_string(&profiles) {
        Ok(s) => s,
        Err(_) => return "could not save".to_owned(),
    };
    crate::ui_interface::set_option(PROFILES_OPTION.to_owned(), s);
    let active = active_of(&profiles, &ui_option(ACTIVE_OPTION));
    match (switch_to, touched) {
        // another profile now gives the computer its permissions
        (Some(name), _) => activate(&profiles, &name),
        // the active profile was changed (its new permissions apply at once), or it was deleted ("Default" takes over)
        (None, Some(name)) if same(&name, &active) || !same(&ui_option(ACTIVE_OPTION), &active) => activate(&profiles, &active),
        _ => {}
    }
    String::new()
}

/// The name of the profile that gives the computer its own permissions, for the process that lets people in ("Default" when none was chosen).
pub fn active_name_host() -> String {
    active_of(&with_standard(load_host()), &Config::get_option(ACTIVE_OPTION))
}

/// Is there a profile whose password lets someone in (unattended access on and a password set)?
pub fn any_password_login(profiles: &[Profile]) -> bool {
    profiles.iter().any(|p| p.enabled && !p.secret.is_empty())
}

/// For the login: may the other side be asked for a profile's password?
pub fn password_access() -> bool {
    any_password_login(&load_host())
}

/// For the login: the profile that this connection's password belongs to, if any.
pub fn matching(salt: &str, verify: impl Fn(&[u8]) -> bool) -> Option<Profile> {
    find(&load_host(), salt, open, verify).cloned()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn seal(p: &str) -> String {
        format!("sealed:{p}")
    }
    fn open(s: &str) -> String {
        s.strip_prefix("sealed:").unwrap_or_default().to_owned()
    }
    fn set(name: &str, password: &str, perms: Perms) -> Command {
        Command::Set { name: name.to_owned(), password: password.to_owned(), enabled: true, mode: "custom".to_owned(), perms }
    }
    fn set_mode(name: &str, mode: &str, perms: Perms) -> Command {
        Command::Set { name: name.to_owned(), password: "secret-1".to_owned(), enabled: true, mode: mode.to_owned(), perms }
    }
    fn view_only() -> Perms {
        Perms::default()
    }
    fn support() -> Perms {
        Perms { keyboard: true, clipboard: true, audio: true, ..Default::default() }
    }

    #[test]
    fn a_profile_is_made_changed_and_removed() {
        let mut v = vec![];
        apply(&mut v, set("Support", "secret-1", support()), seal).unwrap();
        assert_eq!(v.len(), 1);
        assert_eq!(v[0].secret, "sealed:secret-1");
        // changed without a password: the old one stays; a name differing in case or spaces is the same profile
        apply(&mut v, set("  support ", "", view_only()), seal).unwrap();
        assert_eq!(v.len(), 1);
        assert_eq!(v[0].secret, "sealed:secret-1");
        assert!(!v[0].perms.keyboard);
        // a new password replaces the old
        apply(&mut v, set("Support", "secret-2", support()), seal).unwrap();
        assert_eq!(v[0].secret, "sealed:secret-2");
        apply(&mut v, Command::Delete { name: "SUPPORT".into() }, seal).unwrap();
        assert!(v.is_empty());
        assert!(apply(&mut v, Command::Delete { name: "x".into() }, seal).is_err());
    }

    #[test]
    fn bad_input_is_refused() {
        let mut v = vec![];
        assert!(apply(&mut v, set("", "secret-1", support()), seal).is_err());
        assert!(apply(&mut v, set(&"n".repeat(33), "secret-1", support()), seal).is_err());
        assert!(apply(&mut v, set("A", "short", support()), seal).is_err(), "too short");
        assert!(apply(&mut v, set("A", &"p".repeat(65), support()), seal).is_err(), "too long");
        assert!(apply(&mut v, set("A", "", support()), seal).is_err(), "a new profile needs a password");
        assert!(v.is_empty());
        for i in 0..16 {
            apply(&mut v, set(&format!("P{i}"), "secret-1", support()), seal).unwrap();
        }
        assert!(apply(&mut v, set("one more", "secret-1", support()), seal).is_err());
    }

    #[test]
    fn the_list_has_no_passwords() {
        let mut v = vec![];
        apply(&mut v, set("Support", "secret-1", support()), seal).unwrap();
        let json = list_json(&v);
        assert!(!json.contains("secret-1") && !json.contains("sealed"));
        assert!(json.contains("\"has_password\":true") && json.contains("\"name\":\"Support\""));
    }

    fn h1(password: &str, salt: &str) -> Vec<u8> {
        let mut h = Sha256::new();
        h.update(password.as_bytes());
        h.update(salt.as_bytes());
        h.finalize().to_vec()
    }

    #[test]
    fn the_login_finds_the_profile_of_the_password_that_was_sent() {
        let mut v = vec![];
        apply(&mut v, set("Support", "support-pw", support()), seal).unwrap();
        apply(&mut v, set("Viewer", "viewer-pw", view_only()), seal).unwrap();
        let sent = h1("viewer-pw", "salt-1");
        let got = find(&v, "salt-1", open, |c| c == &sent[..]).unwrap();
        assert_eq!(got.name, "Viewer");
        assert!(!got.perms.keyboard);
        // another salt, a wrong password: nothing
        assert!(find(&v, "salt-2", open, |c| c == &sent[..]).is_none());
        let wrong = h1("nope-nope", "salt-1");
        assert!(find(&v, "salt-1", open, |c| c == &wrong[..]).is_none());
    }

    #[test]
    fn a_switched_off_profile_and_one_without_a_password_never_match() {
        let mut v = vec![];
        apply(&mut v, set("Support", "support-pw", support()), seal).unwrap();
        v[0].enabled = false;
        let sent = h1("support-pw", "s");
        assert!(find(&v, "s", open, |c| c == &sent[..]).is_none());
        v[0].enabled = true;
        v[0].secret.clear();
        assert!(find(&v, "s", open, |_| true).is_none());
    }

    #[test]
    fn full_access_and_screen_share_decide_every_permission_but_the_lock() {
        let mut v = vec![];
        // the switches sent with "full" are ignored: everything is on, and the lock stays what was chosen
        apply(&mut v, set_mode("Boss", "full", Perms { lock_on_end: true, ..Default::default() }), seal).unwrap();
        let p = &v[0];
        assert_eq!(p.mode, "full");
        assert!(p.perms.keyboard && p.perms.clipboard && p.perms.file && p.perms.audio && p.perms.restart);
        assert!(p.perms.recording && p.perms.block_input && p.perms.privacy_mode && p.perms.system_info);
        assert!(p.perms.lock_on_end);
        // screen share: everything off, whatever was sent
        apply(&mut v, set_mode("Boss", "view", Perms { keyboard: true, audio: true, ..Default::default() }), seal).unwrap();
        let p = &v[0];
        assert_eq!(p.mode, "view");
        assert_eq!(p.perms, Perms::default());
        // custom keeps the switches as they are; an unknown mode is custom
        apply(&mut v, set_mode("Boss", "weird", Perms { audio: true, ..Default::default() }), seal).unwrap();
        assert_eq!(v[0].mode, "custom");
        assert!(v[0].perms.audio && !v[0].perms.keyboard);
    }

    #[test]
    fn the_list_names_the_mode_and_an_older_profile_is_custom() {
        let mut v = vec![];
        apply(&mut v, set_mode("Boss", "full", Perms::default()), seal).unwrap();
        assert!(list_json(&v).contains("\"mode\":\"full\""));
        let old = parse(r#"[{"name":"A","enabled":true,"secret":"x","perms":{"audio":true}}]"#);
        assert!(list_json(&old).contains("\"mode\":\"custom\""));
    }

    #[test]
    fn every_computer_starts_with_the_four_standard_profiles() {
        let v = with_standard(vec![]);
        assert_eq!(v.iter().map(|p| p.name.as_str()).collect::<Vec<_>>(), ["Default", "Screen Sharing", "Full Access", "Unattended Access"]);
        assert!(v.iter().all(|p| p.builtin && !p.enabled && p.secret.is_empty()), "none lets anyone in until a password is set");
        let by = |n: &str| v.iter().find(|p| p.name == n).unwrap();
        // Screen Sharing: nothing
        assert_eq!((by("Screen Sharing").mode.as_str(), &by("Screen Sharing").perms), ("view", &Perms::default()));
        // Full Access: everything, and no forced lock
        let full = &by("Full Access").perms;
        assert!(full.keyboard && full.clipboard && full.file && full.audio && full.restart && full.recording);
        assert!(full.block_input && full.privacy_mode && full.system_info && !full.lock_on_end);
        // Default: sound, control, clipboard, files, system information; not recording, restart, privacy mode or blocking the input
        let d = &by("Default").perms;
        assert!(d.audio && d.keyboard && d.clipboard && d.file && d.system_info);
        assert!(!d.recording && !d.restart && !d.privacy_mode && !d.block_input && !d.lock_on_end);
        // Unattended Access: everything but recording, and the computer locks itself afterwards
        let u = &by("Unattended Access").perms;
        assert!(u.keyboard && u.clipboard && u.file && u.audio && u.restart && u.privacy_mode && u.block_input && u.system_info && u.lock_on_end);
        assert!(!u.recording);
        // Full Access is the only standard profile that records
        assert!(by("Full Access").perms.recording);
    }

    #[test]
    fn a_computer_that_saved_the_old_standard_profiles_gets_the_new_ones_unless_they_were_changed() {
        let old = |name: &str| {
            let (mode, perms) = superseded(name).unwrap();
            let mut p = standard().into_iter().find(|p| p.name == name).unwrap();
            p.mode = mode.to_owned();
            p.perms = perms;
            p
        };
        let v = with_standard(vec![old("Default"), old("Unattended Access")]);
        let by = |n: &str| v.iter().find(|p| p.name == n).unwrap();
        assert!(!by("Default").perms.recording, "recording is off by default now");
        assert_eq!(by("Unattended Access").mode, "custom");
        assert!(!by("Unattended Access").perms.recording);
        // one its owner changed is left as it is
        let mut mine = old("Default");
        mine.perms.restart = true;
        mine.secret = "sealed:secret-1".to_owned();
        let v = with_standard(vec![mine.clone()]);
        let d = v.iter().find(|p| p.name == "Default").unwrap();
        assert!(d.perms.recording && d.perms.restart, "left alone");
        assert_eq!(d.secret, "sealed:secret-1");
    }

    #[test]
    fn the_standard_ones_are_kept_in_front_and_what_was_made_by_hand_follows() {
        let mut v = vec![];
        apply(&mut v, set("Support", "secret-1", support()), seal).unwrap();
        let v = with_standard(v);
        assert_eq!(v.len(), 5);
        assert_eq!(v[4].name, "Support");
        assert!(!v[4].builtin);
        // asking again changes nothing
        assert_eq!(with_standard(v.clone()), v);
    }

    #[test]
    fn a_profile_made_by_hand_under_a_standard_name_becomes_that_standard_one_and_keeps_its_password() {
        let mut v = vec![];
        apply(&mut v, set("full access", "secret-1", support()), seal).unwrap();
        let v = with_standard(v);
        let p = v.iter().find(|p| p.name == "Full Access").unwrap();
        assert!(p.builtin);
        assert_eq!(p.secret, "sealed:secret-1");
        assert_eq!(v.len(), 4);
    }

    #[test]
    fn a_standard_profile_cannot_be_deleted_but_can_be_given_a_password_and_then_lets_people_in() {
        let mut v = with_standard(vec![]);
        assert!(apply(&mut v, Command::Delete { name: "default".into() }, seal).is_err());
        assert_eq!(v.len(), 4);
        apply(
            &mut v,
            Command::Set { name: "Full Access".into(), password: "boss-pass".into(), enabled: true, mode: "full".into(), perms: Perms::default() },
            seal,
        )
        .unwrap();
        let sent = h1("boss-pass", "salt-1");
        let got = find(&v, "salt-1", open, |c| c == &sent[..]).unwrap();
        assert_eq!(got.name, "Full Access");
        assert!(got.perms.keyboard && got.perms.restart);
        assert!(got.builtin);
    }

    fn from(pairs: &[(&str, &str)]) -> (String, Perms) {
        let map: std::collections::HashMap<String, String> = pairs.iter().map(|(k, v)| (k.to_string(), v.to_string())).collect();
        perms_from_options(&|k| map.get(k).cloned().unwrap_or_default())
    }

    #[test]
    fn the_general_permissions_read_like_the_rest_of_the_app_reads_them() {
        // nothing set: every "enable-" option is on, the lock is off, the mode is custom
        let (mode, p) = from(&[]);
        assert_eq!(mode, "custom");
        assert!(p.keyboard && p.clipboard && p.file && p.audio && p.restart && p.recording && p.block_input && p.privacy_mode && p.system_info);
        assert!(!p.lock_on_end);
        // an option switched off, and the lock switched on
        let (_, p) = from(&[("enable-audio", "N"), ("enable-record-session", "N"), ("lock-on-session-end", "Y")]);
        assert!(!p.audio && !p.recording && p.lock_on_end && p.keyboard);
        // Screen Share and Full Access decide everything (the lock stays what it was)
        let (mode, p) = from(&[("access-mode", "view"), ("enable-keyboard", "Y"), ("lock-on-session-end", "Y")]);
        assert_eq!(mode, "view");
        assert_eq!(p, Perms { lock_on_end: true, ..Default::default() });
        let (mode, p) = from(&[("access-mode", "full"), ("enable-audio", "N")]);
        assert_eq!(mode, "full");
        assert!(p.audio && p.keyboard && p.restart && !p.lock_on_end);
    }

    #[test]
    fn a_profile_written_as_options_reads_back_the_same() {
        for (mode, perms) in [
            ("custom", Perms { keyboard: true, audio: true, lock_on_end: true, ..Default::default() }),
            ("custom", Perms::default()),
            ("full", Perms { lock_on_end: true, ..Default::default() }),
            ("view", Perms::default()),
        ] {
            let opts = options_for(mode, &perms);
            assert_eq!(opts.len(), 11);
            let map: std::collections::HashMap<String, String> = opts.iter().map(|(k, v)| (k.to_string(), v.clone())).collect();
            let (got_mode, got) = perms_from_options(&|k| map.get(k).cloned().unwrap_or_default());
            let (want_mode, want) = normalized(mode, perms.clone());
            assert_eq!((got_mode, got), (want_mode, want), "{mode}");
        }
        // custom is the empty access mode, as the rest of the app has it
        assert_eq!(options_for("custom", &Perms::default())[0], ("access-mode", String::new()));
        assert_eq!(options_for("full", &Perms::default())[0], ("access-mode", "full".to_owned()));
    }

    #[test]
    fn a_profile_is_chosen_to_give_the_computer_its_permissions_and_the_list_says_which() {
        let mut v = with_standard(vec![]);
        assert!(apply(&mut v, Command::Use { name: "nope".into() }, seal).is_err());
        apply(&mut v, Command::Use { name: "full access".into() }, seal).unwrap();
        assert_eq!(active_of(&v, "full access"), "Full Access");
        assert_eq!(active_of(&v, ""), "Default", "none named: Default");
        assert_eq!(active_of(&v, "a profile that was deleted"), "Default");
        let rows: Vec<serde_json::Value> = serde_json::from_str(&list_json_active(&v, "Full Access", true)).unwrap();
        let active: Vec<_> = rows.iter().filter(|r| r["active"] == true).collect();
        assert_eq!(active.len(), 1);
        assert_eq!(active[0]["name"], "Full Access");
        assert_eq!(active[0]["modified"], true);
        assert!(rows.iter().filter(|r| r["name"] != "Full Access").all(|r| r["active"] == false && r["modified"] == false));
        // the plain list names none
        let plain: Vec<serde_json::Value> = serde_json::from_str(&list_json(&v)).unwrap();
        assert!(plain.iter().all(|r| r["active"] == false));
    }

    #[test]
    fn what_a_chosen_profile_writes_into_the_options_is_what_it_allows() {
        let v = with_standard(vec![]);
        let by = |n: &str| v.iter().find(|p| p.name == n).unwrap();
        let get = |p: &Profile| options_for(&p.mode, &p.perms);
        // Screen Sharing: the view mode, every switch off; Full Access: the full mode
        let screen = get(by("Screen Sharing"));
        assert_eq!(screen[0], ("access-mode", "view".to_owned()));
        assert!(screen.iter().skip(1).filter(|(k, _)| *k != "lock-on-session-end").all(|(_, v)| v == "N"));
        assert_eq!(get(by("Full Access"))[0], ("access-mode", "full".to_owned()));
        // Default: custom, recording / restart / privacy mode / blocking the input off, the rest on
        let d: std::collections::HashMap<_, _> = get(by("Default")).into_iter().collect();
        assert_eq!(d["access-mode"], "");
        assert_eq!((d["enable-keyboard"].as_str(), d["enable-audio"].as_str(), d["enable-record-session"].as_str()), ("Y", "Y", "N"));
        assert_eq!((d["enable-remote-restart"].as_str(), d["enable-privacy-mode"].as_str(), d["enable-block-input"].as_str()), ("N", "N", "N"));
        assert_eq!(d["lock-on-session-end"], "N");
    }

    fn unattended(name: &str, enabled: bool, password: &str) -> Command {
        Command::Unattended { name: name.to_owned(), enabled, password: password.to_owned() }
    }

    #[test]
    fn unattended_access_of_a_profile_asks_for_a_password_first_and_then_lets_it_in() {
        let mut v = with_standard(vec![]);
        // on without a password: refused, nothing changed
        assert!(apply(&mut v, unattended("default", true, ""), seal).is_err());
        assert!(!v[0].enabled && v[0].secret.is_empty());
        // a password too short: refused
        assert!(apply(&mut v, unattended("Default", true, "short"), seal).is_err());
        assert!(!v[0].enabled && v[0].secret.is_empty());
        // on with a password: the password is kept and the profile lets people in
        apply(&mut v, unattended("Default", true, "office-pass-1"), seal).unwrap();
        assert!(v[0].enabled);
        assert_eq!(v[0].secret, "sealed:office-pass-1");
        let sent = h1("office-pass-1", "salt-1");
        assert_eq!(find(&v, "salt-1", open, |c| c == &sent[..]).map(|p| p.name.as_str()), Some("Default"));
        // off: the password stays but lets nobody in; on again needs no new password
        apply(&mut v, unattended("Default", false, ""), seal).unwrap();
        assert!(!v[0].enabled && !v[0].secret.is_empty());
        assert!(find(&v, "salt-1", open, |c| c == &sent[..]).is_none());
        apply(&mut v, unattended("Default", true, ""), seal).unwrap();
        assert!(v[0].enabled);
        // a new password replaces the old one; the permissions never change
        let before = v[0].perms.clone();
        apply(&mut v, unattended("Default", true, "another-pass-2"), seal).unwrap();
        assert_eq!(v[0].secret, "sealed:another-pass-2");
        assert_eq!(v[0].perms, before);
        assert!(apply(&mut v, unattended("nobody", true, "office-pass-1"), seal).is_err());
    }

    #[test]
    fn a_password_may_be_asked_for_only_when_a_profile_has_one_that_lets_people_in() {
        let mut v = with_standard(vec![]);
        assert!(!any_password_login(&v), "the standard profiles have no password");
        apply(&mut v, unattended("Full Access", true, "boss-pass-1"), seal).unwrap();
        assert!(any_password_login(&v));
        apply(&mut v, unattended("Full Access", false, ""), seal).unwrap();
        assert!(!any_password_login(&v), "switched off: the password stays but is not asked for");
        assert!(!any_password_login(&[]));
    }

    #[test]
    fn broken_json_gives_no_profiles() {
        assert!(parse("not json").is_empty());
        assert!(parse("").is_empty());
        // a field missing from an older file gets its default
        let v = parse(r#"[{"name":"A","enabled":true,"secret":"x"}]"#);
        assert_eq!(v[0].perms, Perms::default());
    }
}
