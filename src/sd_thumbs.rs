// SystemDesk: the small pictures of the computers on the cards of the Devices page. While someone controls a computer the app asks it for a screenshot now
// and then (the way the "Take screenshot" button does), shrinks it and keeps it on this computer, one picture per computer. Nothing leaves this computer.
use hbb_common::config::Config;
use std::{
    fs,
    path::{Path, PathBuf},
};

/// read with `main_get_option_sync`: the folder of the pictures (made when it is not there)
pub const DIR_KEY: &str = "sd-thumbs-dir";
/// read with `main_get_option_sync`: deletes every picture; the answer is empty
pub const CLEAR_KEY: &str = "sd-thumbs-clear";

const MAX_WIDTH: u32 = 480;
const MAX_HEIGHT: u32 = 300;
const QUALITY: u8 = 65;
const MAX_ID: usize = 64;
/// a picture whose pixels are darker than this on average (0 = black, 255 = white) is a black screen, not worth keeping
const DARKEST: u64 = 6;

pub fn dir() -> PathBuf {
    Config::path("thumbnails")
}

/// The folder as text, made if it is not there yet.
pub fn dir_string() -> String {
    let d = dir();
    let _ = fs::create_dir_all(&d);
    d.to_string_lossy().into_owned()
}

/// The name of the file of a computer: its ID with everything that is not a letter, a digit, "-" or "_" replaced, so no ID can reach another folder.
fn file_name(peer: &str) -> Option<String> {
    let id: String = peer.chars().map(|c| if c.is_ascii_alphanumeric() || c == '-' || c == '_' { c } else { '_' }).collect();
    if id.is_empty() || id.len() > MAX_ID {
        None
    } else {
        Some(format!("{id}.jpg"))
    }
}

fn is_dark(img: &image::DynamicImage) -> bool {
    let rgb = img.to_rgb8();
    let (w, h) = rgb.dimensions();
    if w == 0 || h == 0 {
        return true;
    }
    // a few thousand pixels are enough to tell
    let step = ((w as usize * h as usize) / 4000).max(1);
    let (mut sum, mut n) = (0u64, 0u64);
    for p in rgb.pixels().step_by(step) {
        sum += (p[0] as u64 * 299 + p[1] as u64 * 587 + p[2] as u64 * 114) / 1000;
        n += 1;
    }
    n == 0 || sum / n < DARKEST
}

/// Keeps `data` (the screenshot of the computer, as the host sent it) as the small picture of `peer` in `folder`.
fn save_in(folder: &Path, peer: &str, data: &[u8]) -> Result<(), String> {
    let name = file_name(peer).ok_or_else(|| "no picture for this computer".to_owned())?;
    let img = image::load_from_memory(data).map_err(|e| e.to_string())?;
    if is_dark(&img) {
        return Err("the screen is black".to_owned());
    }
    let small = if img.width() > MAX_WIDTH || img.height() > MAX_HEIGHT { img.thumbnail(MAX_WIDTH, MAX_HEIGHT) } else { img };
    let rgb = small.to_rgb8();
    let mut jpeg = Vec::new();
    image::codecs::jpeg::JpegEncoder::new_with_quality(&mut jpeg, QUALITY).encode_image(&rgb).map_err(|e| e.to_string())?;
    fs::create_dir_all(folder).map_err(|e| e.to_string())?;
    // written aside and moved over the old one: a card never reads half a picture
    let target = folder.join(&name);
    let aside = folder.join(format!("{name}.new"));
    fs::write(&aside, &jpeg).map_err(|e| e.to_string())?;
    fs::rename(&aside, &target).map_err(|e| {
        let _ = fs::remove_file(&aside);
        e.to_string()
    })
}

pub fn save(peer: &str, data: &[u8]) -> Result<(), String> {
    save_in(&dir(), peer, data)
}

fn remove_in(folder: &Path, peer: &str) {
    if let Some(name) = file_name(peer) {
        let _ = fs::remove_file(folder.join(name));
    }
}

/// The computer is gone from the list: so is its picture.
pub fn remove(peer: &str) {
    remove_in(&dir(), peer);
}

fn clear_in(folder: &Path) {
    if let Ok(entries) = fs::read_dir(folder) {
        for e in entries.flatten() {
            let p = e.path();
            if p.extension().map_or(false, |x| x == "jpg" || x == "new") {
                let _ = fs::remove_file(p);
            }
        }
    }
}

/// Every picture is deleted.
pub fn clear() {
    clear_in(&dir());
}

#[cfg(test)]
mod tests {
    use super::*;
    use image::{DynamicImage, ImageBuffer, ImageOutputFormat, Rgb};
    use std::io::Cursor;

    fn png(w: u32, h: u32, f: impl Fn(u32, u32) -> [u8; 3]) -> Vec<u8> {
        let img = ImageBuffer::from_fn(w, h, |x, y| Rgb(f(x, y)));
        let mut out = Cursor::new(Vec::new());
        DynamicImage::ImageRgb8(img).write_to(&mut out, ImageOutputFormat::Png).unwrap();
        out.into_inner()
    }

    fn scratch(name: &str) -> PathBuf {
        let d = std::env::temp_dir().join(format!("sd-thumbs-test-{name}-{}", std::process::id()));
        let _ = fs::remove_dir_all(&d);
        d
    }

    #[test]
    fn a_screenshot_becomes_a_small_jpeg_of_that_computer() {
        let d = scratch("small");
        let shot = png(1920, 1080, |x, y| [(x % 256) as u8, (y % 256) as u8, 120]);
        save_in(&d, "408118204", &shot).unwrap();
        let bytes = fs::read(d.join("408118204.jpg")).unwrap();
        assert!(bytes.len() < 60_000, "small: {}", bytes.len());
        assert!(bytes.starts_with(&[0xFF, 0xD8]), "a JPEG");
        let back = image::load_from_memory(&bytes).unwrap();
        assert!(back.width() <= MAX_WIDTH && back.height() <= MAX_HEIGHT);
        assert!((back.width() as f32 / back.height() as f32 - 16.0 / 9.0).abs() < 0.05, "kept its proportions");
        let _ = fs::remove_dir_all(&d);
    }

    #[test]
    fn a_small_screen_is_not_enlarged_and_a_new_picture_replaces_the_old() {
        let d = scratch("replace");
        save_in(&d, "abc-123", &png(200, 100, |_, _| [200, 50, 50])).unwrap();
        let first = image::load_from_memory(&fs::read(d.join("abc-123.jpg")).unwrap()).unwrap();
        assert_eq!((first.width(), first.height()), (200, 100));
        save_in(&d, "abc-123", &png(640, 480, |_, _| [30, 90, 200])).unwrap();
        let second = image::load_from_memory(&fs::read(d.join("abc-123.jpg")).unwrap()).unwrap();
        assert_eq!((second.width(), second.height()), (400, 300), "640x480 fits 480x300 as 400x300");
        assert!(!d.join("abc-123.jpg.new").exists(), "nothing is left aside");
        let _ = fs::remove_dir_all(&d);
    }

    #[test]
    fn a_black_screen_is_not_kept_and_a_dark_but_real_one_is() {
        let d = scratch("dark");
        assert!(save_in(&d, "1", &png(800, 600, |_, _| [0, 0, 0])).is_err());
        assert!(!d.join("1.jpg").exists());
        // a dark desktop with something on it is a real picture
        save_in(&d, "2", &png(800, 600, |x, y| if (x / 40 + y / 40) % 2 == 0 { [40, 40, 60] } else { [10, 10, 10] })).unwrap();
        assert!(d.join("2.jpg").exists());
        let _ = fs::remove_dir_all(&d);
    }

    #[test]
    fn bad_input_is_refused_and_no_id_reaches_another_folder() {
        let d = scratch("bad");
        assert!(save_in(&d, "1", b"not a picture").is_err());
        assert!(save_in(&d, "", &png(10, 10, |_, _| [90, 90, 90])).is_err());
        assert!(save_in(&d, &"x".repeat(65), &png(10, 10, |_, _| [90, 90, 90])).is_err());
        save_in(&d, "../../evil", &png(10, 10, |_, _| [90, 90, 90])).unwrap();
        assert!(d.join("______evil.jpg").exists());
        assert!(!d.parent().unwrap().join("evil.jpg").exists());
        assert_eq!(file_name("SaqibKhanBaloch").as_deref(), Some("SaqibKhanBaloch.jpg"));
        assert_eq!(file_name("a@b/c").as_deref(), Some("a_b_c.jpg"));
        let _ = fs::remove_dir_all(&d);
    }

    #[test]
    fn a_picture_is_removed_with_its_computer_and_all_of_them_can_be_cleared() {
        let d = scratch("clear");
        for id in ["1", "2", "3"] {
            save_in(&d, id, &png(100, 100, |_, _| [90, 90, 90])).unwrap();
        }
        remove_in(&d, "2");
        assert!(d.join("1.jpg").exists() && !d.join("2.jpg").exists() && d.join("3.jpg").exists());
        fs::write(d.join("keep.txt"), b"x").unwrap();
        clear_in(&d);
        assert!(!d.join("1.jpg").exists() && !d.join("3.jpg").exists());
        assert!(d.join("keep.txt").exists(), "only the pictures");
        remove_in(&d, "nothing");
        let _ = fs::remove_dir_all(&d);
    }
}
