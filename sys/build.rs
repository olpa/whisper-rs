#![allow(clippy::uninlined_format_args)]

extern crate bindgen;

use std::env;
use std::path::PathBuf;

fn main() {
    println!("cargo:rerun-if-changed=wrapper.h");
    println!("cargo:rerun-if-env-changed=HANDSFREEAI_DEV_HOME");

    let target = env::var("TARGET").unwrap();

    // Get prebuilt whisper.cpp location
    let whisper_dev_home = env::var("HANDSFREEAI_DEV_HOME")
        .unwrap_or_else(|_| panic!("HANDSFREEAI_DEV_HOME environment variable must be set"));

    let whisper_root = PathBuf::from(&whisper_dev_home).join("whisper.cpp");
    if !whisper_root.exists() {
        panic!("whisper.cpp not found at {}", whisper_root.display());
    }

    // Determine library directory based on target platform
    let lib_dir = if target.contains("linux") && target.contains("x86_64") {
        whisper_root.join("linux-x86_64")
    } else if target.contains("android") {
        if target.contains("aarch64") {
            whisper_root.join("android/arm64-v8a")
        } else if target.contains("arm") {
            whisper_root.join("android/armeabi-v7a")
        } else if target.contains("x86_64") {
            whisper_root.join("android/x86_64")
        } else {
            whisper_root.join("android/x86")
        }
    } else {
        panic!("Unsupported target platform: {}", target);
    };

    if !lib_dir.exists() {
        panic!("Library directory not found: {}", lib_dir.display());
    }

    let include_dir = whisper_root.join("include");
    if !include_dir.exists() {
        panic!("Include directory not found: {}", include_dir.display());
    }

    // Link C++ standard library
    if let Some(cpp_stdlib) = get_cpp_link_stdlib(&target) {
        println!("cargo:rustc-link-lib=dylib={}", cpp_stdlib);
    }

    // Link macOS Accelerate framework for matrix calculations
    if target.contains("apple") {
        println!("cargo:rustc-link-lib=framework=Accelerate");
    }

    // Generate or copy bindings
    let out = PathBuf::from(env::var("OUT_DIR").unwrap());

    if env::var("WHISPER_DONT_GENERATE_BINDINGS").is_ok() {
        let _: u64 = std::fs::copy("src/bindings.rs", out.join("bindings.rs"))
            .expect("Failed to copy bindings.rs");
    } else {
        let bindings = bindgen::Builder::default()
            .header("wrapper.h")
            .clang_arg(format!("-I{}", include_dir.display()))
            .parse_callbacks(Box::new(bindgen::CargoCallbacks::new()))
            .generate();

        match bindings {
            Ok(b) => {
                b.write_to_file(out.join("bindings.rs"))
                    .expect("Couldn't write bindings!");
            }
            Err(e) => {
                println!("cargo:warning=Unable to generate bindings: {}", e);
                println!("cargo:warning=Using bundled bindings.rs, which may be out of date");
                std::fs::copy("src/bindings.rs", out.join("bindings.rs"))
                    .expect("Unable to copy bindings.rs");
            }
        }
    }

    // Add library search path
    println!("cargo:rustc-link-search=native={}", lib_dir.display());

    // Link the prebuilt libraries (shared libraries)
    println!("cargo:rustc-link-lib=dylib=whisper");
    println!("cargo:rustc-link-lib=dylib=ggml");
    println!("cargo:rustc-link-lib=dylib=ggml-base");
    println!("cargo:rustc-link-lib=dylib=ggml-cpu");

    // Set version (hardcoded for now, or could be read from a version file)
    println!("cargo:WHISPER_CPP_VERSION=1.8.2");
}

// From https://github.com/alexcrichton/cc-rs/blob/fba7feded71ee4f63cfe885673ead6d7b4f2f454/src/lib.rs#L2462
fn get_cpp_link_stdlib(target: &str) -> Option<&'static str> {
    if target.contains("msvc") {
        None
    } else if target.contains("apple") || target.contains("freebsd") || target.contains("openbsd") {
        Some("c++")
    } else if target.contains("android") {
        Some("c++_shared")
    } else {
        Some("stdc++")
    }
}
