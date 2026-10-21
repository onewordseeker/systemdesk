#[cfg(windows)]
fn build_windows() {
    let file = "src/platform/windows.cc";
    let file2 = "src/platform/windows_delete_test_cert.cc";
    cc::Build::new().file(file).file(file2).compile("windows");
    println!("cargo:rustc-link-lib=WtsApi32");
    println!("cargo:rerun-if-changed={}", file);
    println!("cargo:rerun-if-changed={}", file2);
}

#[cfg(target_os = "macos")]
fn build_mac() {
    let file = "src/platform/macos.mm";
    let mut b = cc::Build::new();
    if let Ok(os_version::OsVersion::MacOS(v)) = os_version::detect() {
        let v = v.version;
        if v.contains("10.14") {
            b.flag("-DNO_InputMonitoringAuthStatus=1");
        }
    }
    b.flag("-std=c++17").file(file).compile("macos");
    println!("cargo:rerun-if-changed={}", file);
}

#[cfg(all(windows, feature = "inline"))]
fn build_manifest() {
    use std::io::Write;
    if std::env::var("PROFILE").unwrap() == "release" {
        let mut res = winres::WindowsResource::new();
        res.set_icon("res/icon.ico")
            .set_language(winapi::um::winnt::MAKELANGID(
                winapi::um::winnt::LANG_ENGLISH,
                winapi::um::winnt::SUBLANG_ENGLISH_US,
            ))
            .set_manifest_file("res/manifest.xml");
        match res.compile() {
            Err(e) => {
                write!(std::io::stderr(), "{}", e).unwrap();
                std::process::exit(1);
            }
            Ok(_) => {}
        }
    }
}

// bionic only exports getifaddrs()/freeifaddrs() from API 24, while the jniLibs
// are built against the API 21 sysroot (flutter/ndk_*.sh). webrtc-util calls
// them, so without this the android link fails on undefined symbols.
fn build_android_ifaddrs() {
    let file = "src/platform/android_ifaddrs.c";
    cc::Build::new().file(file).compile("android_ifaddrs");
    println!("cargo:rerun-if-changed={}", file);
}

fn install_android_deps() {
    let target_os = std::env::var("CARGO_CFG_TARGET_OS").unwrap();
    if target_os != "android" {
        return;
    }
    let mut target_arch = std::env::var("CARGO_CFG_TARGET_ARCH").unwrap();
    if target_arch == "x86_64" {
        target_arch = "x64".to_owned();
    } else if target_arch == "x86" {
        target_arch = "x86".to_owned();
    } else if target_arch == "aarch64" {
        target_arch = "arm64".to_owned();
    } else {
        target_arch = "arm".to_owned();
    }
    let target = format!("{}-android", target_arch);
    let vcpkg_root = std::env::var("VCPKG_ROOT").unwrap();
    let mut path: std::path::PathBuf = vcpkg_root.into();
    if let Ok(vcpkg_root) = std::env::var("VCPKG_INSTALLED_ROOT") {
        path = vcpkg_root.into();
    } else {
        path.push("installed");
    }
    path.push(target);
    println!(
        "cargo:rustc-link-search={}",
        path.join("lib").to_str().unwrap()
    );
    println!("cargo:rustc-link-lib=ndk_compat");
    println!("cargo:rustc-link-lib=c++");
    println!("cargo:rustc-link-lib=OpenSLES");
}

// The servers of a build (ID server, relay, API server and key) are not written in the source. The build is given them in SD_PROFILE (a JSON
// text kept as a secret of the build, one per channel); they are checked and scrambled here and only the scrambled bytes go into the program
// (src/sd_servers.rs reads them). Without SD_PROFILE the blob is empty and the program keeps the servers it is told by hand (a developer's
// build); a build that must carry them (the CI) sets SD_REQUIRE_PROFILE and stops here when they are missing.
#[path = "src/sd_mask.rs"]
mod sd_mask;

fn sd_profile() {
    use std::{env, fs, path::PathBuf};
    println!("cargo:rerun-if-env-changed=SD_PROFILE");
    println!("cargo:rerun-if-env-changed=SD_REQUIRE_PROFILE");
    println!("cargo:rerun-if-env-changed=SD_UPDATE_CHANNEL");
    let out = PathBuf::from(env::var("OUT_DIR").unwrap()).join("sd_profile.bin");
    let raw = env::var("SD_PROFILE").unwrap_or_default();
    // a secret saved from Windows PowerShell starts with a byte-order mark, which is not whitespace to trim() nor valid JSON
    let raw = raw.trim_start_matches('\u{feff}');
    if raw.trim().is_empty() {
        if env::var("SD_REQUIRE_PROFILE").is_ok() {
            panic!("SD_PROFILE is empty: this build would carry no servers");
        }
        fs::write(out, []).unwrap();
        return;
    }
    let profile: serde_json::Value = serde_json::from_str(raw.trim())
        .unwrap_or_else(|e| panic!("SD_PROFILE is not valid JSON: {e}"));
    let text = |k: &str| profile.get(k).and_then(|v| v.as_str()).unwrap_or_default().trim().to_owned();
    // a test build never carries the production servers, and the other way round
    let channel = env::var("SD_UPDATE_CHANNEL").unwrap_or_else(|_| "stable".to_owned());
    if text("channel") != channel {
        panic!("SD_PROFILE is for the \"{}\" channel but this build is \"{}\"", text("channel"), channel);
    }
    for k in ["id", "api", "key"] {
        if text(k).is_empty() {
            panic!("SD_PROFILE has no \"{}\"", k);
        }
    }
    let seed = {
        use std::hash::{BuildHasher, Hasher};
        let mut h = std::collections::hash_map::RandomState::new().build_hasher();
        h.write_u128(
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .map(|d| d.as_nanos())
                .unwrap_or(0),
        );
        h.write_u32(std::process::id());
        h.finish()
    };
    fs::write(out, sd_mask::seal(profile.to_string().as_bytes(), seed)).unwrap();
}

fn main() {
    hbb_common::gen_version();
    sd_profile();
    install_android_deps();
    #[cfg(all(windows, feature = "inline"))]
    build_manifest();
    #[cfg(windows)]
    build_windows();
    let target_os = std::env::var("CARGO_CFG_TARGET_OS").unwrap();
    if target_os == "macos" {
        #[cfg(target_os = "macos")]
        build_mac();
        println!("cargo:rustc-link-lib=framework=ApplicationServices");
    }
    if target_os == "android" {
        build_android_ifaddrs();
    }
    println!("cargo:rerun-if-changed=build.rs");
}
