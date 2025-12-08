# Before Task 3.1.1: Add Version Checking to Build Script

**Date:** 2025-12-07
**Task:** Phase 3.1.1 - Add version checking to build.rs

## Current State

### File: `sys/build.rs`

The build script currently:
1. Locates prebuilt whisper.cpp libraries via `HANDSFREEAI_DEV_HOME` environment variable
2. Determines platform-specific library directory (linux-x86_64, android variants)
3. Links against prebuilt shared libraries: libwhisper, libggml, libggml-base, libggml-cpu
4. Generates or copies Rust bindings from C headers
5. **Has a hardcoded version on line 96:** `println!("cargo:WHISPER_CPP_VERSION=1.8.2");`

### Current Version Handling (Line 95-96)

```rust
// Set version (hardcoded for now, or could be read from a version file)
println!("cargo:WHISPER_CPP_VERSION=1.8.2");
```

**Comment indicates this was already planned!**

## Investigation: whisper.cpp VERSION File

Checked `/mnt/HC_Volume_103849597/home/olpa/audio/hfai_dev/whisper.cpp/`:

```
drwxrwxr-x 5 olpa olpa 4096 Dec  1 14:14 .
drwxrwxr-x 3 olpa olpa 4096 Dec  2 14:14 ..
drwxrwxr-x 6 olpa olpa 4096 Dec  1 13:34 android
drwxrwxr-x 2 olpa olpa 4096 Dec  1 14:06 include
drwxrwxr-x 2 olpa olpa 4096 Dec  1 14:14 linux-x86_64
-rw-rw-r-- 1 olpa olpa 9208 Dec  1 14:14 README.md
```

**No VERSION file exists!**

This is a **prebuilt whisper.cpp distribution**, not the full source repository.

## Plan Adjustment

The original plan assumes whisper.cpp has a VERSION file, but this prebuilt distribution doesn't have one.

### Options:

1. **Create a VERSION file manually** in the prebuilt distribution
2. **Keep hardcoded version** but add warnings if libraries are missing/incompatible
3. **Add a check for library compatibility** by attempting to detect version from library metadata
4. **Document the expected version** prominently in README

### Recommended Approach

Since this is a prebuilt distribution for a specific project setup:

1. Keep the hardcoded version in build.rs as the "expected" version
2. Add a check for a VERSION file (for future compatibility)
3. If VERSION file exists and doesn't match, emit a warning
4. If VERSION file doesn't exist, emit an informational warning
5. Document that users should ensure their prebuilt whisper.cpp matches version 1.8.2

This way:
- The build doesn't break if VERSION file is missing (current state)
- We get warnings if there's a version mismatch (future-proofing)
- Users are informed about version expectations

## Implementation Plan

```rust
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

    // NEW: Version checking
    let expected_version = "1.8.2";  // Update this when upgrading
    let version_file = whisper_root.join("VERSION");

    if version_file.exists() {
        // Read and check version
        match std::fs::read_to_string(&version_file) {
            Ok(actual_version) => {
                let actual_version = actual_version.trim();
                if actual_version != expected_version {
                    println!("cargo:warning=whisper.cpp version mismatch!");
                    println!("cargo:warning=Expected: {}", expected_version);
                    println!("cargo:warning=Found: {}", actual_version);
                    println!("cargo:warning=Bindings may be incompatible!");
                }
            }
            Err(e) => {
                println!("cargo:warning=Failed to read VERSION file: {}", e);
            }
        }
    } else {
        // VERSION file doesn't exist (current state)
        println!("cargo:warning=No VERSION file found in whisper.cpp distribution");
        println!("cargo:warning=Assuming version: {}", expected_version);
        println!("cargo:warning=Ensure your prebuilt whisper.cpp matches this version");
    }

    // Set version for cargo (keep existing line)
    println!("cargo:WHISPER_CPP_VERSION={}", expected_version);

    // ... rest of build script ...
}
```

## Benefits

1. **Non-breaking:** Works with current setup (no VERSION file)
2. **Forward-compatible:** Will check VERSION file if added later
3. **Informative:** Users get warnings about version expectations
4. **Maintainable:** Single source of truth for expected version (`expected_version` variable)
5. **Documented:** Clear warnings guide users to fix version mismatches

## Testing Strategy

Since we don't have a VERSION file:
1. Build should succeed with warnings about missing VERSION file
2. Can manually create VERSION file with matching version → no warnings
3. Can manually create VERSION file with different version → mismatch warnings
4. Existing functionality should not be affected

## Notes

- The prebuilt whisper.cpp distribution appears to be project-specific
- Full whisper.cpp source would have CMakeLists.txt with version info
- For this use case, hardcoded version + warnings is appropriate
- If switching to building from source, could extract version from CMakeLists.txt
