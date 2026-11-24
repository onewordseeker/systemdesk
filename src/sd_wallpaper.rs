// SystemDesk: the picture of a computer on the cards is its desktop background (wallpaper), never a screenshot. The controller asks for it the way it asks for a
// screenshot, with a display number no computer has ([`REQUEST_DISPLAY`]), so no new message is needed; a computer that can answer says so in the `sd_wallpaper`
// key of its `platform_additions` and the controller asks only those. The answer is a small JPEG, or the reason there is none.
use base::message_proto::{Message, ScreenshotResponse};
use hbb_common::{log, tokio::time::Instant};
use std::{path::PathBuf, sync::Arc};

/// A screenshot request for this "display" is a request for the wallpaper.
pub const REQUEST_DISPLAY: i32 = 9999;

/// The wallpaper is sent no bigger than this (a card shows it across the top, a few hundred pixels wide).
const MAX_WIDTH: u32 = 640;
const MAX_HEIGHT: u32 = 400;
const JPEG_QUALITY: u8 = 75;
/// A wallpaper file bigger than this is not read.
const MAX_FILE: u64 = 96 * 1024 * 1024;

/// The wallpaper as a JPEG that fits [`MAX_WIDTH`] x [`MAX_HEIGHT`], from the bytes of a picture file in any format the `image` crate reads.
pub fn shrink_to_jpeg(data: &[u8]) -> Result<Vec<u8>, String> {
    let img = image::load_from_memory(data).map_err(|e| e.to_string())?;
    let small = if img.width() > MAX_WIDTH || img.height() > MAX_HEIGHT {
        img.thumbnail(MAX_WIDTH, MAX_HEIGHT)
    } else {
        img
    };
    let rgb = small.to_rgb8();
    let mut jpeg = Vec::new();
    image::codecs::jpeg::JpegEncoder::new_with_quality(&mut jpeg, JPEG_QUALITY)
        .encode_image(&rgb)
        .map_err(|e| e.to_string())?;
    Ok(jpeg)
}

/// The file of the wallpaper of the person at this computer, when it has one.
#[cfg(target_os = "windows")]
fn find_path() -> Option<PathBuf> {
    let themes = |roaming: PathBuf| {
        roaming
            .join("Microsoft")
            .join("Windows")
            .join("Themes")
            .join("TranscodedWallpaper")
    };
    // A service that runs as SYSTEM has no wallpaper of its own: the signed-in person's copy of the current one is in their profile.
    if crate::platform::is_root() {
        let path = themes(
            crate::platform::get_active_user_home()?
                .join("AppData")
                .join("Roaming"),
        );
        return path.exists().then_some(path);
    }
    // This person's own: the file of the wallpaper (for a slideshow, the copy Windows keeps of the picture it shows now); empty = a plain colour.
    match wallpaper::get() {
        Ok(path) if path.is_empty() => None,
        Ok(path) => Some(PathBuf::from(path)),
        Err(_) => std::env::var_os("APPDATA")
            .map(|roaming| themes(PathBuf::from(roaming)))
            .filter(|path| path.exists()),
    }
}

/// The file of the wallpaper of the main screen, from the system (no permission is asked for it).
#[cfg(target_os = "macos")]
fn find_path() -> Option<PathBuf> {
    use cocoa::base::{id, nil};
    use objc::{class, msg_send, rc::autoreleasepool, sel, sel_impl};
    autoreleasepool(|| unsafe {
        let workspace: id = msg_send![class!(NSWorkspace), sharedWorkspace];
        let screen: id = msg_send![class!(NSScreen), mainScreen];
        if workspace == nil || screen == nil {
            return None;
        }
        let url: id = msg_send![workspace, desktopImageURLForScreen: screen];
        if url == nil {
            return None;
        }
        let path: id = msg_send![url, path];
        if path == nil {
            return None;
        }
        let c_str: *const std::os::raw::c_char = msg_send![path, UTF8String];
        if c_str.is_null() {
            return None;
        }
        std::ffi::CStr::from_ptr(c_str)
            .to_str()
            .ok()
            .map(PathBuf::from)
    })
}

#[cfg(not(any(target_os = "windows", target_os = "macos")))]
fn find_path() -> Option<PathBuf> {
    None
}

/// The bytes of the picture file as something `shrink_to_jpeg` reads. A Mac keeps wallpapers in formats the `image` crate does not know (HEIC, the dynamic
/// desktops), so the system's own `sips` turns them into a small JPEG.
#[cfg(target_os = "macos")]
fn read_picture(path: &std::path::Path) -> Result<Vec<u8>, String> {
    let out = std::env::temp_dir().join(format!("sd-wallpaper-{}.jpg", std::process::id()));
    let done = std::process::Command::new("/usr/bin/sips")
        .args(["-s", "format", "jpeg", "-s", "formatOptions", "75", "-Z"])
        .arg(MAX_WIDTH.to_string())
        .arg(path)
        .arg("--out")
        .arg(&out)
        .output()
        .map_err(|e| e.to_string())?;
    let data = std::fs::read(&out);
    let _ = std::fs::remove_file(&out);
    if !done.status.success() {
        return Err("the wallpaper could not be read".to_owned());
    }
    data.map_err(|e| e.to_string())
}

#[cfg(not(target_os = "macos"))]
fn read_picture(path: &std::path::Path) -> Result<Vec<u8>, String> {
    let size = std::fs::metadata(path).map_err(|e| e.to_string())?.len();
    if size > MAX_FILE {
        return Err("the wallpaper file is too big".to_owned());
    }
    std::fs::read(path).map_err(|e| e.to_string())
}

/// The wallpaper of this computer as a small JPEG, or why there is none.
pub fn load_small() -> Result<Vec<u8>, String> {
    let path = find_path().ok_or_else(|| "This computer has no wallpaper to show.".to_owned())?;
    shrink_to_jpeg(&read_picture(&path)?)
}

/// The answer to a request: the picture, or the reason there is none. `sid` is the request's own, so the controller knows it is the answer to its request.
pub fn response_for(sid: String, picture: Result<Vec<u8>, String>) -> Message {
    let mut response = ScreenshotResponse::new();
    response.sid = sid;
    match picture {
        Ok(jpeg) => response.data = jpeg.into(),
        Err(reason) => response.msg = reason,
    }
    let mut msg = Message::new();
    msg.set_screenshot_response(response);
    msg
}

/// Answers a request for the wallpaper on `tx` (the connection's way out). Reading and shrinking a big picture takes a moment, so it is done on a thread of its own.
pub fn answer(sid: String, tx: crate::server::Sender) {
    std::thread::spawn(move || {
        let msg = response_for(sid, load_small());
        if let Err(e) = tx.send((Instant::now(), Arc::new(msg))) {
            log::warn!("Failed to send the wallpaper: {e}");
        }
    });
}

/// Whether this kind of computer can answer a request for its wallpaper.
pub const SUPPORTED: bool = cfg!(any(target_os = "windows", target_os = "macos"));

#[cfg(test)]
mod tests {
    use super::*;
    use image::{DynamicImage, ImageBuffer, ImageOutputFormat, Rgb};
    use std::io::Cursor;

    fn png(w: u32, h: u32) -> Vec<u8> {
        let img = ImageBuffer::from_fn(w, h, |x, y| Rgb([(x % 251) as u8, (y % 241) as u8, ((x + y) % 239) as u8]));
        let mut out = Cursor::new(Vec::new());
        DynamicImage::ImageRgb8(img).write_to(&mut out, ImageOutputFormat::Png).unwrap();
        out.into_inner()
    }

    #[test]
    fn the_request_is_a_display_no_computer_has() {
        assert!(REQUEST_DISPLAY >= 1000, "a real display is a small number");
    }

    #[test]
    fn a_big_wallpaper_is_made_small_and_keeps_its_shape() {
        let jpeg = shrink_to_jpeg(&png(3840, 2160)).unwrap();
        assert_eq!(&jpeg[..2], &[0xFF, 0xD8], "a JPEG");
        let img = image::load_from_memory(&jpeg).unwrap();
        assert!(img.width() <= MAX_WIDTH && img.height() <= MAX_HEIGHT);
        // 16:9 stays 16:9 (within a pixel of rounding)
        let ratio = img.width() as f64 / img.height() as f64;
        assert!((ratio - 16.0 / 9.0).abs() < 0.03, "ratio {ratio}");
        assert!(jpeg.len() < 200 * 1024, "light enough to send in a moment: {} bytes", jpeg.len());
    }

    #[test]
    fn a_small_wallpaper_is_not_made_bigger() {
        let img = image::load_from_memory(&shrink_to_jpeg(&png(320, 200)).unwrap()).unwrap();
        assert_eq!((img.width(), img.height()), (320, 200));
    }

    #[test]
    fn something_that_is_not_a_picture_is_refused() {
        assert!(shrink_to_jpeg(b"not a picture").is_err());
        assert!(shrink_to_jpeg(&[]).is_err());
    }

    #[test]
    fn the_answer_carries_the_picture_or_the_reason_and_the_sid_of_the_request() {
        let ok = response_for("sid-1".to_owned(), Ok(vec![1, 2, 3]));
        match ok.union {
            Some(base::message_proto::message::Union::ScreenshotResponse(r)) => {
                assert_eq!(r.sid, "sid-1");
                assert_eq!(r.data.as_ref(), &[1, 2, 3]);
                assert!(r.msg.is_empty());
            }
            other => panic!("not a screenshot response: {other:?}"),
        }
        let failed = response_for("sid-2".to_owned(), Err("no wallpaper".to_owned()));
        match failed.union {
            Some(base::message_proto::message::Union::ScreenshotResponse(r)) => {
                assert_eq!(r.sid, "sid-2");
                assert!(r.data.is_empty());
                assert_eq!(r.msg, "no wallpaper");
            }
            other => panic!("not a screenshot response: {other:?}"),
        }
    }

    #[test]
    fn only_windows_and_macs_say_they_can() {
        assert_eq!(SUPPORTED, cfg!(any(target_os = "windows", target_os = "macos")));
    }

    // Reads the wallpaper of the computer it runs on: run by hand with
    //   SD_WALLPAPER_OUT=<file.jpg> cargo test --features hwcodec,flutter --lib this_computer_gives -- --ignored --nocapture
    #[test]
    #[ignore = "reads the wallpaper of the computer it runs on"]
    fn this_computer_gives_its_wallpaper() {
        println!("wallpaper file: {:?}", find_path());
        let jpeg = load_small().expect("this computer has a wallpaper");
        let img = image::load_from_memory(&jpeg).unwrap();
        println!("sent as {}x{}, {} bytes", img.width(), img.height(), jpeg.len());
        if let Ok(out) = std::env::var("SD_WALLPAPER_OUT") {
            std::fs::write(out, &jpeg).unwrap();
        }
        assert!(img.width() <= MAX_WIDTH && img.height() <= MAX_HEIGHT);
    }
}
