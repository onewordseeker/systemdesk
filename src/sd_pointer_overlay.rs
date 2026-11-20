// SystemDesk: the pointer of a computer that is looked at through Remote Desktop (or any viewer that draws its own pointer). The controller moves the
// computer's real pointer, but such a viewer shows its own local arrow and never the movement of the real one: the person watching sees a pointer
// frozen where they last left it while the controller clicks elsewhere. While somebody controls this computer, its real pointer is drawn on the
// screen itself (a small click-through window with the same arrow, at the same place), so what is on the screen is seen wherever it is viewed.
// Only on Windows, only while somebody controls the computer, and by default only when the screen is seen through Remote Desktop: on a computer
// that is sat at, the real pointer moves by itself and nothing is drawn (one pointer, not two). The option `sd-controller-pointer` forces it: `Y`
// always (while controlled), `N` never.
use std::sync::atomic::{AtomicBool, Ordering};

static WANTED: AtomicBool = AtomicBool::new(false);
// the pointer is on the screen right now (so it is in the picture the controller gets)
static SHOWN: AtomicBool = AtomicBool::new(false);
#[cfg(windows)]
static RUNNING: AtomicBool = AtomicBool::new(false);

/// Is the pointer drawn on the screen right now? Then the controller's picture has it too, and the controller hides its own pointer.
pub fn on_screen() -> bool {
    SHOWN.load(Ordering::Relaxed)
}

/// Somebody controls this computer now (true), or nobody does (false).
pub fn controlled(on: bool) {
    WANTED.store(on, Ordering::Relaxed);
    #[cfg(windows)]
    if on && !RUNNING.swap(true, Ordering::SeqCst) {
        let started = std::thread::Builder::new()
            .name("sd-pointer-overlay".to_owned())
            .spawn(|| {
                win::run();
                RUNNING.store(false, Ordering::SeqCst);
            });
        if started.is_err() {
            RUNNING.store(false, Ordering::SeqCst);
        }
    }
}

/// Is the pointer to be drawn right now? `option` is the saved `sd-controller-pointer`.
fn draw_now(remote_session: bool, option: &str) -> bool {
    match option {
        "Y" => true,
        "N" => false,
        _ => remote_session,
    }
}

// how much lighter a pixel of a pointer is drawn on white than on black: 0 when it is all there, 255 when it is not there, below 0 when the pointer
// inverts what is under it (the text cursor)
fn spread(on_black: u32, on_white: u32) -> i32 {
    let channel = |v: u32, shift: u32| ((v >> shift) & 0xFF) as i32;
    (0..3).map(|c| channel(on_white, c * 8) - channel(on_black, c * 8)).sum::<i32>() / 3
}

/// Premultiplied BGRA of one pixel of a pointer, from how it looks drawn on black (`on_black`) and on white (`on_white`): the two tell how much of the
/// pixel is there. What inverts the screen under it is drawn white (see [outline]).
fn pixel(on_black: u32, on_white: u32) -> u32 {
    let diff = spread(on_black, on_white);
    if diff < 0 {
        return 0xFFFF_FFFF;
    }
    let alpha = 255 - diff.min(255) as u32;
    if alpha == 0 {
        0
    } else {
        (alpha << 24) | (on_black & 0x00FF_FFFF)
    }
}

/// A black line round the parts that were white because they invert the screen, so the text cursor shows on a dark screen and on a light one.
fn outline(pixels: &mut [u32], inverting: &[bool], width: usize, height: usize) {
    for y in 0..height {
        for x in 0..width {
            if pixels[y * width + x] != 0 {
                continue;
            }
            let touches = (y.saturating_sub(1)..=(y + 1).min(height - 1)).any(|ny| (x.saturating_sub(1)..=(x + 1).min(width - 1)).any(|nx| inverting[ny * width + nx]));
            if touches {
                pixels[y * width + x] = 0xFF00_0000;
            }
        }
    }
}

#[cfg(windows)]
mod win {
    use super::{draw_now, outline, pixel, spread, Ordering, SHOWN, WANTED};
    use hbb_common::{config::Config, log};
    use std::{
        ptr::null_mut,
        time::{Duration, Instant},
    };
    use winapi::{
        shared::{
            minwindef::{DWORD, HINSTANCE, LPARAM, LRESULT, UINT, WPARAM},
            windef::{DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2, HBITMAP, HCURSOR, HDC, HGDIOBJ, HWND, POINT, SIZE},
        },
        um::{libloaderapi::GetModuleHandleW, wingdi::*, winuser::*},
    };

    pub(super) const CLASS: &str = "SystemDeskPointerOverlay";
    // DrawIconEx: the image and the mask as the pointer is normally drawn
    const DI_NORMAL: UINT = 0x0003;
    const TICK: Duration = Duration::from_millis(8);
    const IDLE: Duration = Duration::from_millis(500);

    pub(super) fn wide(s: &str) -> Vec<u16> {
        s.encode_utf16().chain(std::iter::once(0)).collect()
    }

    // the pointer as a bitmap with per-pixel opacity, ready for UpdateLayeredWindow
    struct Shape {
        cursor: HCURSOR,
        width: i32,
        height: i32,
        hot: POINT,
        dc: HDC,
        bitmap: HBITMAP,
        previous: HGDIOBJ,
    }

    impl Drop for Shape {
        fn drop(&mut self) {
            unsafe {
                SelectObject(self.dc, self.previous);
                DeleteObject(self.bitmap as _);
                DeleteDC(self.dc);
            }
        }
    }

    impl Shape {
        fn of(cursor: HCURSOR, screen: HDC) -> Option<Shape> {
            unsafe {
                let mut info: ICONINFO = std::mem::zeroed();
                if GetIconInfo(cursor, &mut info) == 0 {
                    return None;
                }
                let mut size = (0, 0);
                let probe = if info.hbmColor.is_null() { info.hbmMask } else { info.hbmColor };
                let mut bm: BITMAP = std::mem::zeroed();
                if GetObjectW(probe as _, std::mem::size_of::<BITMAP>() as _, &mut bm as *mut _ as _) != 0 {
                    // a pointer with a mask only has the two halves (AND, XOR) one above the other
                    size = (bm.bmWidth, if info.hbmColor.is_null() { bm.bmHeight / 2 } else { bm.bmHeight });
                }
                let hot = POINT { x: info.xHotspot as i32, y: info.yHotspot as i32 };
                if !info.hbmMask.is_null() {
                    DeleteObject(info.hbmMask as _);
                }
                if !info.hbmColor.is_null() {
                    DeleteObject(info.hbmColor as _);
                }
                let (width, height) = size;
                if width <= 0 || height <= 0 || width > 512 || height > 512 {
                    return None;
                }
                let mut header: BITMAPINFO = std::mem::zeroed();
                header.bmiHeader = BITMAPINFOHEADER {
                    biSize: std::mem::size_of::<BITMAPINFOHEADER>() as DWORD,
                    biWidth: width,
                    biHeight: -height,
                    biPlanes: 1,
                    biBitCount: 32,
                    biCompression: BI_RGB,
                    ..std::mem::zeroed()
                };
                let mut bits: *mut winapi::ctypes::c_void = null_mut();
                let dc = CreateCompatibleDC(screen);
                if dc.is_null() {
                    return None;
                }
                let bitmap = CreateDIBSection(dc, &header, DIB_RGB_COLORS, &mut bits, null_mut(), 0);
                if bitmap.is_null() || bits.is_null() {
                    DeleteDC(dc);
                    return None;
                }
                let previous = SelectObject(dc, bitmap as _);
                let count = (width * height) as usize;
                let pixels = std::slice::from_raw_parts_mut(bits as *mut u32, count);
                // drawn on black, then on white: the difference says how much of each pixel is there
                pixels.fill(0);
                DrawIconEx(dc, 0, 0, cursor, width, height, 0, null_mut(), DI_NORMAL);
                let on_black = pixels.to_vec();
                pixels.fill(0x00FF_FFFF);
                DrawIconEx(dc, 0, 0, cursor, width, height, 0, null_mut(), DI_NORMAL);
                let on_white = pixels.to_vec();
                let inverting: Vec<bool> = on_black.iter().zip(on_white.iter()).map(|(b, w)| spread(*b, *w) < 0).collect();
                for (out, (b, w)) in pixels.iter_mut().zip(on_black.iter().zip(on_white.iter())) {
                    *out = pixel(*b, *w);
                }
                outline(pixels, &inverting, width as usize, height as usize);
                Some(Shape { cursor, width, height, hot, dc, bitmap, previous })
            }
        }
    }

    unsafe extern "system" fn window_proc(hwnd: HWND, msg: UINT, w: WPARAM, l: LPARAM) -> LRESULT {
        DefWindowProcW(hwnd, msg, w, l)
    }

    unsafe fn create_window() -> Option<HWND> {
        let instance = GetModuleHandleW(null_mut()) as HINSTANCE;
        let class = wide(CLASS);
        let wc = WNDCLASSW {
            style: 0,
            lpfnWndProc: Some(window_proc),
            cbClsExtra: 0,
            cbWndExtra: 0,
            hInstance: instance,
            hIcon: null_mut(),
            hCursor: null_mut(),
            hbrBackground: null_mut(),
            lpszMenuName: null_mut(),
            lpszClassName: class.as_ptr(),
        };
        RegisterClassW(&wc);
        let title = wide("SystemDesk pointer");
        let hwnd = CreateWindowExW(
            WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE,
            class.as_ptr(),
            title.as_ptr(),
            WS_POPUP,
            0,
            0,
            1,
            1,
            null_mut(),
            null_mut(),
            instance,
            null_mut(),
        );
        (!hwnd.is_null()).then_some(hwnd)
    }

    pub(super) fn remote_session() -> bool {
        unsafe { GetSystemMetrics(SM_REMOTESESSION) != 0 }
    }

    // the thread lives while somebody controls this computer
    pub(super) fn run() {
        unsafe {
            SetThreadDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
            let Some(hwnd) = create_window() else {
                log::warn!("Cannot draw the pointer of this computer: no window");
                return;
            };
            log::info!("Drawing the pointer of this computer while it is controlled (seen through Remote Desktop)");
            let screen = GetDC(null_mut());
            let mut shape: Option<Shape> = None;
            let mut shown = false;
            let mut at = POINT { x: i32::MIN, y: i32::MIN };
            let mut option = Config::get_option("sd-controller-pointer");
            let mut checked = Instant::now();
            let mut raised = Instant::now();
            let mut msg: MSG = std::mem::zeroed();
            while WANTED.load(Ordering::Relaxed) {
                while PeekMessageW(&mut msg, null_mut(), 0, 0, PM_REMOVE) != 0 {
                    TranslateMessage(&msg);
                    DispatchMessageW(&msg);
                }
                if checked.elapsed() > Duration::from_secs(1) {
                    option = Config::get_option("sd-controller-pointer");
                    checked = Instant::now();
                }
                let mut ci: CURSORINFO = std::mem::zeroed();
                ci.cbSize = std::mem::size_of::<CURSORINFO>() as DWORD;
                let visible = draw_now(remote_session(), &option) && GetCursorInfo(&mut ci) != 0 && ci.flags & CURSOR_SHOWING != 0;
                if !visible {
                    if shown {
                        ShowWindow(hwnd, SW_HIDE);
                        shown = false;
                        SHOWN.store(false, Ordering::Relaxed);
                    }
                    std::thread::sleep(IDLE);
                    continue;
                }
                if shape.as_ref().map(|s| s.cursor) != Some(ci.hCursor) {
                    shape = Shape::of(ci.hCursor, screen);
                    at = POINT { x: i32::MIN, y: i32::MIN };
                }
                if let Some(s) = &shape {
                    let to = POINT { x: ci.ptScreenPos.x - s.hot.x, y: ci.ptScreenPos.y - s.hot.y };
                    if to.x != at.x || to.y != at.y || !shown {
                        let mut dst = to;
                        let mut size = SIZE { cx: s.width, cy: s.height };
                        let mut src = POINT { x: 0, y: 0 };
                        let mut blend = BLENDFUNCTION { BlendOp: AC_SRC_OVER, BlendFlags: 0, SourceConstantAlpha: 255, AlphaFormat: AC_SRC_ALPHA };
                        UpdateLayeredWindow(hwnd, screen, &mut dst, &mut size, s.dc, &mut src, 0, &mut blend, ULW_ALPHA);
                        at = to;
                        if !shown {
                            ShowWindow(hwnd, SW_SHOWNOACTIVATE);
                            shown = true;
                            SHOWN.store(true, Ordering::Relaxed);
                        }
                    }
                    // other always-on-top windows may have come up since: stay above them
                    if raised.elapsed() > Duration::from_secs(1) {
                        SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
                        raised = Instant::now();
                    }
                }
                std::thread::sleep(TICK);
            }
            SHOWN.store(false, Ordering::Relaxed);
            drop(shape);
            DestroyWindow(hwnd);
            ReleaseDC(null_mut(), screen);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn by_default_only_a_screen_seen_through_remote_desktop_gets_a_drawn_pointer() {
        assert!(draw_now(true, ""));
        assert!(!draw_now(false, ""));
        assert!(!draw_now(false, "whatever"));
    }

    #[test]
    fn the_option_forces_it_on_or_off() {
        assert!(draw_now(false, "Y"));
        assert!(!draw_now(true, "N"));
    }

    #[test]
    fn a_pixel_that_is_all_there_keeps_its_colour() {
        // the same on black and on white: opaque
        assert_eq!(pixel(0x0012_3456, 0x0012_3456), 0xFF12_3456);
    }

    #[test]
    fn a_pixel_that_is_not_there_is_clear() {
        // black stays black, white stays white: nothing was drawn
        assert_eq!(pixel(0x0000_0000, 0x00FF_FFFF), 0);
    }

    #[test]
    fn a_half_see_through_pixel_is_half_opaque_and_premultiplied() {
        // white at half opacity: 128 over black, 128 + 127 = 255 over white
        let p = pixel(0x0080_8080, 0x00FF_FFFF);
        assert_eq!(p >> 24, 128);
        assert_eq!(p & 0x00FF_FFFF, 0x0080_8080);
    }

    #[test]
    fn a_pointer_that_inverts_what_is_under_it_is_drawn_white() {
        // the text cursor: white over black, black over white
        assert_eq!(pixel(0x00FF_FFFF, 0x0000_0000), 0xFFFF_FFFF);
    }

    #[test]
    fn what_was_white_because_it_inverts_gets_a_black_line_round_it() {
        // 3 x 3, the middle one inverts: its eight neighbours are the line, nothing else changes
        let mut pixels = [0u32; 9];
        pixels[4] = 0xFFFF_FFFF;
        let mut inverting = [false; 9];
        inverting[4] = true;
        outline(&mut pixels, &inverting, 3, 3);
        assert_eq!(pixels[4], 0xFFFF_FFFF);
        assert!(pixels.iter().enumerate().all(|(i, p)| i == 4 || *p == 0xFF00_0000), "{pixels:x?}");
    }

    #[test]
    fn a_pointer_that_does_not_invert_gets_no_line() {
        // an arrow keeps its own outline: a clear pixel next to it stays clear
        let mut pixels = [0u32; 9];
        pixels[4] = 0xFFFF_FFFF;
        outline(&mut pixels, &[false; 9], 3, 3);
        assert!(pixels.iter().enumerate().all(|(i, p)| (i == 4) == (*p != 0)));
    }

    // by hand: `cargo test --lib sd_pointer_overlay -- --ignored --nocapture`, then look at the screen (or take a picture of it) for 25 seconds
    #[cfg(windows)]
    #[test]
    #[ignore]
    fn show_the_pointer_for_a_while() {
        controlled(true);
        std::thread::sleep(std::time::Duration::from_secs(25));
        controlled(false);
        std::thread::sleep(std::time::Duration::from_secs(1));
    }

    #[cfg(windows)]
    #[test]
    fn while_controlled_and_seen_through_remote_desktop_the_pointer_is_on_the_screen_at_the_real_pointer() {
        use winapi::um::winuser::*;
        if !win::remote_session() {
            return; // on a computer that is sat at nothing is drawn: nothing to look for
        }
        let find = || unsafe { FindWindowW(win::wide(win::CLASS).as_ptr(), std::ptr::null()) };
        controlled(true);
        let began = std::time::Instant::now();
        while (find().is_null() || unsafe { IsWindowVisible(find()) } == 0) && began.elapsed() < std::time::Duration::from_secs(5) {
            std::thread::sleep(std::time::Duration::from_millis(50));
        }
        let hwnd = find();
        assert!(!hwnd.is_null() && unsafe { IsWindowVisible(hwnd) } != 0, "no pointer window on the screen");
        let mut at = winapi::shared::windef::POINT { x: 0, y: 0 };
        let mut rect: winapi::shared::windef::RECT = unsafe { std::mem::zeroed() };
        unsafe {
            GetCursorPos(&mut at);
            GetWindowRect(hwnd, &mut rect);
        }
        assert!(
            rect.left <= at.x && at.x <= rect.right && rect.top <= at.y && at.y <= rect.bottom,
            "the pointer window ({},{})-({},{}) is not at the real pointer ({},{})",
            rect.left,
            rect.top,
            rect.right,
            rect.bottom,
            at.x,
            at.y
        );
        controlled(false);
        let began = std::time::Instant::now();
        while !find().is_null() && began.elapsed() < std::time::Duration::from_secs(5) {
            std::thread::sleep(std::time::Duration::from_millis(50));
        }
        assert!(find().is_null(), "the pointer window stays after nobody controls the computer");
    }
}
