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

// A Remote Desktop session hands every pointer move made on the computer back to it as if a person had made it, some milliseconds later and a pixel
// or two off (the remote desktop window may be scaled). What SystemDesk injects comes back that way: it must not be taken for the person at the
// computer. So in such a session a move that lands near one made by a program a moment ago is its echo. A person who starts moving the mouse from
// where the pointer is counts as soon as they are a little way off.
const ECHO_WINDOW_MS: u64 = 1000;
const ECHO_NEAR: i32 = 24;
const RECENT_MOVES: usize = 128;

struct RecentMoves {
    items: [(i32, i32, u64); RECENT_MOVES],
    next: usize,
}

impl RecentMoves {
    const fn new() -> Self {
        Self { items: [(0, 0, 0); RECENT_MOVES], next: 0 }
    }

    fn push(&mut self, x: i32, y: i32, at: u64) {
        self.items[self.next] = (x, y, at);
        self.next = (self.next + 1) % RECENT_MOVES;
    }

    fn echoes(&self, x: i32, y: i32, now: u64) -> bool {
        self.items.iter().any(|&(px, py, at)| {
            at != 0 && now.saturating_sub(at) <= ECHO_WINDOW_MS && (px - x).abs() <= ECHO_NEAR && (py - y).abs() <= ECHO_NEAR
        })
    }
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

    // only the thread of the hook reads and writes it
    thread_local! {
        static RECENT: std::cell::RefCell<super::RecentMoves> = std::cell::RefCell::new(super::RecentMoves::new());
    }

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
            if injected {
                if w_param as u32 == WM_MOUSEMOVE && GetSystemMetrics(SM_REMOTESESSION) != 0 {
                    RECENT.with(|r| r.borrow_mut().push(info.pt.x, info.pt.y, super::now_ms()));
                }
            } else if info.dwExtraInfo != enigo::ENIGO_INPUT_EXTRA_VALUE {
                let echo = w_param as u32 == WM_MOUSEMOVE
                    && GetSystemMetrics(SM_REMOTESESSION) != 0
                    && RECENT.with(|r| r.borrow().echoes(info.pt.x, info.pt.y, super::now_ms()));
                if !echo {
                    super::note_local_input();
                }
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
    fn a_move_near_one_a_program_just_made_is_its_echo() {
        let mut r = RecentMoves::new();
        r.push(1000, 500, 5_000);
        assert!(r.echoes(1000, 500, 5_020), "the same place, a moment later");
        assert!(r.echoes(1003, 497, 5_020), "a pixel or two off (a scaled window)");
        assert!(r.echoes(1000 + ECHO_NEAR, 500, 5_100), "right at the edge of near");
        assert!(r.echoes(1000, 500, 5_000 + ECHO_WINDOW_MS), "late echo, still inside the window");
    }

    #[test]
    fn a_move_far_from_them_or_long_after_is_a_person() {
        let mut r = RecentMoves::new();
        r.push(1000, 500, 5_000);
        assert!(!r.echoes(1000 + ECHO_NEAR + 1, 500, 5_020), "a person who has moved a little way off");
        assert!(!r.echoes(1000, 500 - ECHO_NEAR - 1, 5_020));
        assert!(!r.echoes(1000, 500, 5_000 + ECHO_WINDOW_MS + 1), "long after: nobody asked for this one");
        assert!(!RecentMoves::new().echoes(0, 0, 5_000), "nothing was moved by a program: every move is a person");
    }

    #[test]
    fn a_long_fast_path_is_still_remembered_when_its_echoes_come_late() {
        let mut r = RecentMoves::new();
        // 120 moves 40 px apart, 8 ms apart: the echo of the first one arrives after the whole path
        for n in 0..120 {
            r.push(100 + 40 * n, 300, 10_000 + 8 * n as u64);
        }
        assert!(r.echoes(100, 300, 10_000 + 8 * 120));
        assert!(r.echoes(100 + 40 * 119, 300, 10_000 + 8 * 120));
        // and the memory is a ring: the oldest are forgotten, never a crash
        for n in 0..1000 {
            r.push(n, n, 20_000);
        }
        assert!(r.echoes(999, 999, 20_001));
        assert!(!r.echoes(100, 300, 20_001), "the old path is gone");
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

    // A Remote Desktop session hands every pointer move made on the computer back to it as if a person had made it, a few milliseconds later and
    // a pixel or two off. What SystemDesk injects comes back that way too, and must not be taken for the person at the computer either, or the
    // remote person is paused after their first move. (It only shows in a Remote Desktop session; anywhere else this passes on its own.)
    #[cfg(windows)]
    #[test]
    fn what_systemdesk_injects_comes_back_through_remote_desktop_and_is_still_not_the_person_at_the_computer() {
        use enigo::{Enigo, MouseControllable};
        start();
        let began = Instant::now();
        let before = SEEN.load(Ordering::Relaxed);
        let mut en = Enigo::new();
        while SEEN.load(Ordering::Relaxed) == before && began.elapsed() < Duration::from_secs(5) {
            en.mouse_move_relative(1, 0);
            en.mouse_move_relative(-1, 0);
            std::thread::sleep(Duration::from_millis(50));
        }
        std::thread::sleep(Duration::from_millis(600));
        LAST_LOCAL.store(0, Ordering::Relaxed);
        let Some((x0, y0)) = crate::get_cursor_pos() else { return };
        for n in 0..60 {
            let a = n as f64 * std::f64::consts::TAU / 60.0;
            en.mouse_move_to(x0 + (60.0 * a.sin()) as i32, y0 + (60.0 * (1.0 - a.cos())) as i32);
            std::thread::sleep(Duration::from_millis(30));
        }
        std::thread::sleep(Duration::from_millis(600));
        en.mouse_move_to(x0, y0);
        std::thread::sleep(Duration::from_millis(600));
        assert_eq!(
            LAST_LOCAL.load(Ordering::Relaxed),
            0,
            "the pointer moves SystemDesk made came back as the person at the computer using the mouse"
        );
    }
}
