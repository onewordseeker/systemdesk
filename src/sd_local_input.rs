// SystemDesk: the person at the controlled computer has priority over the person controlling it, as with AnyDesk. While they move or click the mouse
// (a physical mouse or touchpad, not the pointer SystemDesk itself moves for the remote person), the remote mouse is paused: its moves, clicks and
// wheel are dropped, and the controller is told (permission `LocalInput`) so it shows "input not allowed" instead of a pointer that does nothing.
// It resumes by itself a moment after the person at the computer stops. A release of a button always goes through, so a button the remote person
// pressed is never left down. Windows only (a low-level mouse hook tells a physical event from one SystemDesk sent); elsewhere nothing changes.
use std::{
    sync::atomic::{AtomicU64, Ordering},
    time::{Duration, Instant},
};

/// How long the remote mouse stays paused after the last movement of the person at the computer.
const HOLD: Duration = Duration::from_millis(1200);

lazy_static::lazy_static! {
    static ref START: Instant = Instant::now();
}

// when the person at the computer last used the mouse, in milliseconds since START plus one (0: never)
static LAST_LOCAL: AtomicU64 = AtomicU64::new(0);

fn now_ms() -> u64 {
    START.elapsed().as_millis() as u64 + 1
}

/// The person at this computer used the mouse just now.
pub fn note_local_input() {
    LAST_LOCAL.store(now_ms(), Ordering::Relaxed);
}

fn in_use(last: u64, now: u64, hold: Duration) -> bool {
    last != 0 && now.saturating_sub(last) < hold.as_millis() as u64
}

/// Is the person at this computer using the mouse right now (or did they a moment ago)?
pub fn host_in_use() -> bool {
    in_use(LAST_LOCAL.load(Ordering::Relaxed), now_ms(), HOLD)
}

fn drops(host_in_use: bool, mask: i32) -> bool {
    host_in_use && (mask & 0x7) != crate::input::MOUSE_TYPE_UP
}

/// Must this mouse event of a remote person be dropped? Only while the person at the computer uses the mouse, and never a button release.
pub fn drops_remote_mouse(mask: i32) -> bool {
    drops(host_in_use(), mask)
}

/// Starts watching the physical mouse of this computer (once per process).
pub fn start() {
    #[cfg(windows)]
    {
        static ONCE: std::sync::Once = std::sync::Once::new();
        ONCE.call_once(win::spawn);
    }
}

// every mouse event the hook was given, whoever made it (tests only)
#[cfg(test)]
static SEEN: AtomicU64 = AtomicU64::new(0);

#[cfg(windows)]
mod win {
    use hbb_common::log;
    use winapi::{
        shared::{
            minwindef::{FALSE, HMODULE, LPARAM, LRESULT, WPARAM},
            ntdef::NULL,
        },
        um::{libloaderapi::GetModuleHandleExA, winuser::*},
    };

    const GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT: u32 = 2;
    const GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS: u32 = 4;

    pub fn spawn() {
        let started = std::thread::Builder::new()
            .name("sd-local-input".to_owned())
            .spawn(run);
        if let Err(e) = started {
            log::warn!("Cannot watch the mouse of this computer: {e}");
        }
    }

    fn run() {
        unsafe {
            let mut module = 0 as HMODULE;
            if 0 == GetModuleHandleExA(
                GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                mouse_hook as _,
                &mut module as _,
            ) {
                log::warn!("Cannot watch the mouse of this computer: no module ({})", std::io::Error::last_os_error());
                return;
            }
            let hook = SetWindowsHookExA(WH_MOUSE_LL, Some(mouse_hook), module, 0);
            if hook.is_null() {
                log::warn!("Cannot watch the mouse of this computer: {}", std::io::Error::last_os_error());
                return;
            }
            log::info!("Watching the mouse of this computer, so its person has priority");
            let mut msg: MSG = std::mem::zeroed();
            while FALSE != GetMessageA(&mut msg, NULL as _, 0, 0) {
                TranslateMessage(&msg);
                DispatchMessageA(&msg);
            }
            UnhookWindowsHookEx(hook);
        }
    }

    // Called by Windows for every mouse event of the desktop: it must be quick. An event that SystemDesk (or any program) injected is not the
    // person at the computer: only events from the hardware count.
    unsafe extern "system" fn mouse_hook(code: i32, w_param: WPARAM, l_param: LPARAM) -> LRESULT {
        if code >= 0 {
            let info = &*(l_param as *const MSLLHOOKSTRUCT);
            #[cfg(test)]
            super::SEEN.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
            let injected = info.flags & LLMHF_INJECTED != 0;
            if !injected && info.dwExtraInfo != enigo::ENIGO_INPUT_EXTRA_VALUE {
                super::note_local_input();
            }
        }
        CallNextHookEx(NULL as _, code, w_param, l_param)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::input::{MOUSE_TYPE_DOWN, MOUSE_TYPE_MOVE, MOUSE_TYPE_UP, MOUSE_TYPE_WHEEL};

    #[test]
    fn nobody_at_the_computer_means_not_in_use() {
        assert!(!in_use(0, 5_000, HOLD), "never used");
    }

    #[test]
    fn in_use_while_the_hold_runs_and_free_after() {
        assert!(in_use(1_000, 1_001, HOLD));
        assert!(in_use(1_000, 2_199, HOLD));
        assert!(!in_use(1_000, 2_200, HOLD), "the hold is over");
        assert!(!in_use(1_000, 60_000, HOLD));
    }

    #[test]
    fn a_clock_that_looks_earlier_does_not_break_it() {
        assert!(in_use(5_000, 4_990, HOLD), "saturating: the difference is zero, still in use");
    }

    #[test]
    fn while_in_use_moves_clicks_and_wheel_are_dropped_but_a_release_goes_through() {
        for mask in [MOUSE_TYPE_MOVE, MOUSE_TYPE_DOWN | (1 << 3), MOUSE_TYPE_WHEEL] {
            assert!(drops(true, mask), "dropped: {mask}");
        }
        assert!(!drops(true, MOUSE_TYPE_UP | (1 << 3)), "a button the remote pressed must be able to go up");
    }

    #[test]
    fn when_nobody_is_at_the_computer_nothing_is_dropped() {
        for mask in [MOUSE_TYPE_MOVE, MOUSE_TYPE_DOWN | (1 << 3), MOUSE_TYPE_UP, MOUSE_TYPE_WHEEL] {
            assert!(!drops(false, mask));
        }
    }

    // What SystemDesk itself sends for the remote person is made with SendInput: Windows marks it as injected, and the hook must not take it for
    // the person at the computer, or the remote person would stop themselves after the first move.
    #[cfg(windows)]
    #[test]
    fn what_systemdesk_injects_for_the_remote_person_is_not_the_person_at_the_computer() {
        use enigo::{Enigo, MouseControllable};
        start();
        let began = Instant::now();
        let before = SEEN.load(Ordering::Relaxed);
        let mut en = Enigo::new();
        // the hook is installed on its own thread a moment after start(): move until it has seen something
        while SEEN.load(Ordering::Relaxed) == before && began.elapsed() < Duration::from_secs(5) {
            en.mouse_move_relative(1, 0);
            en.mouse_move_relative(-1, 0);
            std::thread::sleep(Duration::from_millis(50));
        }
        let seen = SEEN.load(Ordering::Relaxed) - before;
        assert!(seen > 0, "the hook was given no mouse event at all: it is not installed on this desktop");
        assert_eq!(LAST_LOCAL.load(Ordering::Relaxed), 0, "{seen} injected moves were taken for the person at the computer");
        assert!(!host_in_use());
    }
}
