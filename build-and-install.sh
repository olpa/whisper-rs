#!/bin/bash
set -e

# Build and install whisper-rs to HANDSFREEAI_DEV_HOME
# Similar layout to whisper.cpp installation

if [ -z "$HANDSFREEAI_DEV_HOME" ]; then
    echo "Error: HANDSFREEAI_DEV_HOME environment variable is not set"
    exit 1
fi

INSTALL_ROOT="${HANDSFREEAI_DEV_HOME}/whisper-rs"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Building whisper-rs for multiple platforms..."
echo "    Repository: $REPO_ROOT"
echo "    Install to: $INSTALL_ROOT"

# Create directory structure
mkdir -p "${INSTALL_ROOT}/include"
mkdir -p "${INSTALL_ROOT}/linux-x86_64"
mkdir -p "${INSTALL_ROOT}/android/arm64-v8a"
mkdir -p "${INSTALL_ROOT}/android/armeabi-v7a"
mkdir -p "${INSTALL_ROOT}/android/x86_64"
mkdir -p "${INSTALL_ROOT}/android/x86"

cd "$REPO_ROOT"

# Build for Linux x86_64 (native)
echo ""
echo "==> Building for Linux x86_64..."
cargo build --release
echo "    Installing to ${INSTALL_ROOT}/linux-x86_64/"
cp -v target/release/libwhisper_rs.rlib "${INSTALL_ROOT}/linux-x86_64/"

# Build for Android targets if requested
if [ "$1" == "--with-android" ] || [ "$1" == "--all" ]; then
    # Check if Android targets are installed
    ANDROID_TARGETS=(
        "aarch64-linux-android:arm64-v8a"
        "armv7-linux-androideabi:armeabi-v7a"
        "x86_64-linux-android:x86_64"
        "i686-linux-android:x86"
    )

    for target_pair in "${ANDROID_TARGETS[@]}"; do
        IFS=':' read -r rust_target android_abi <<< "$target_pair"

        # Check if target is installed
        if rustup target list | grep -q "^${rust_target} (installed)"; then
            echo ""
            echo "==> Building for Android ${android_abi} (${rust_target})..."
            cargo build --release --target "${rust_target}"
            echo "    Installing to ${INSTALL_ROOT}/android/${android_abi}/"
            cp -v "target/${rust_target}/release/libwhisper_rs.rlib" "${INSTALL_ROOT}/android/${android_abi}/"
        else
            echo ""
            echo "==> Skipping ${rust_target} (not installed)"
            echo "    To install: rustup target add ${rust_target}"
        fi
    done
fi

# Copy header files (public API from src/lib.rs - for FFI consumers)
echo ""
echo "==> Copying header files..."
# Note: whisper-rs is a Rust library, so there's no traditional C header
# But we'll document the public API
cat > "${INSTALL_ROOT}/include/README.md" << 'EOF'
# whisper-rs Headers

whisper-rs is a Rust library that provides safe bindings to whisper.cpp.

## Usage in Rust Projects

Add to your `Cargo.toml`:

```toml
[dependencies]
whisper-rs = { path = "${HANDSFREEAI_DEV_HOME}/whisper-rs" }
```

Or reference the installed artifacts directly in your build system.

## Public API

The main types and functions are exported from `whisper_rs` crate:

- `WhisperContext` - Main context for loading models
- `WhisperState` - State for running inference
- `FullParams` - Parameters for transcription
- `SamplingStrategy` - Beam search or greedy sampling

For FFI bindings, use:
```toml
[dependencies]
whisper-rs-sys = { path = "${HANDSFREEAI_DEV_HOME}/whisper-rs/sys" }
```

The `whisper-rs-sys` crate provides direct FFI bindings to whisper.cpp C API.

## Backtrack Branch Features

This build includes backtrack branch features:
- Token candidates API
- Skip encode for interactive transcription
- Forced tokens for re-decoding

See examples in the repository for usage.
EOF

# Copy sys bindings header for reference
if [ -f "$REPO_ROOT/sys/src/bindings.rs" ]; then
    cp -v "$REPO_ROOT/sys/src/bindings.rs" "${INSTALL_ROOT}/include/"
fi

# Create version file
echo ""
echo "==> Creating version file..."
WHISPER_RS_VERSION=$(grep '^version = ' "$REPO_ROOT/Cargo.toml" | head -1 | cut -d'"' -f2)
WHISPER_RS_SYS_VERSION=$(grep '^version = ' "$REPO_ROOT/sys/Cargo.toml" | head -1 | cut -d'"' -f2)
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_DATE=$(date -u +"%Y-%m-%d %H:%M:%S UTC")

cat > "${INSTALL_ROOT}/VERSION" << EOF
whisper-rs version: ${WHISPER_RS_VERSION}
whisper-rs-sys version: ${WHISPER_RS_SYS_VERSION}
Git commit: ${GIT_COMMIT}
Branch: $(git branch --show-current 2>/dev/null || echo "unknown")
Build date: ${BUILD_DATE}
Backtrack features: enabled
EOF

cat "${INSTALL_ROOT}/VERSION"

# Create README
echo ""
echo "==> Creating README..."
cat > "${INSTALL_ROOT}/README.md" << 'EOF'
# whisper-rs Pre-built Libraries

Rust bindings to whisper.cpp (backtrack branch) for Linux and Android platforms.

## Directory Structure

```
whisper-rs/
├── include/              # Documentation and bindings
│   ├── README.md        # Usage instructions
│   └── bindings.rs      # FFI bindings reference
├── linux-x86_64/        # Native Linux libraries
│   └── libwhisper_rs.rlib
└── android/             # Android libraries by ABI
    ├── arm64-v8a/       # 64-bit ARM (most modern phones)
    ├── armeabi-v7a/     # 32-bit ARM (older devices)
    ├── x86_64/          # 64-bit x86 (emulators)
    └── x86/             # 32-bit x86 (older emulators)
        └── libwhisper_rs.rlib
```

## Dependencies

whisper-rs requires prebuilt whisper.cpp libraries. Ensure they are available at:
```
$HANDSFREEAI_DEV_HOME/whisper.cpp/
```

Set the environment variable:
```bash
export HANDSFREEAI_DEV_HOME=/path/to/dev/home
```

## Usage in Rust Projects

### Option 1: Use as Cargo Dependency

In your `Cargo.toml`:
```toml
[dependencies]
whisper-rs = { path = "${HANDSFREEAI_DEV_HOME}/whisper-rs" }
```

### Option 2: Link Prebuilt Libraries

For cross-compilation or to avoid rebuilding:

```toml
[dependencies]
whisper-rs = { version = "0.15" }
```

Then in your `build.rs`:
```rust
fn main() {
    let target = std::env::var("TARGET").unwrap();

    let base_path = std::env::var("HANDSFREEAI_DEV_HOME")
        .expect("HANDSFREEAI_DEV_HOME not set");

    let lib_dir = if target.contains("android") {
        let abi = match target.as_str() {
            "aarch64-linux-android" => "arm64-v8a",
            "armv7-linux-androideabi" => "armeabi-v7a",
            "x86_64-linux-android" => "x86_64",
            "i686-linux-android" => "x86",
            _ => panic!("Unsupported Android target"),
        };
        format!("{}/whisper-rs/android/{}", base_path, abi)
    } else {
        format!("{}/whisper-rs/linux-x86_64", base_path)
    };

    println!("cargo:rustc-link-search=native={}", lib_dir);
}
```

## Backtrack Branch Features

This build includes backtrack branch features for interactive transcription:

- **Token Candidates**: Access top candidate tokens with probabilities
  - `set_capture_top_candidates()`, `set_n_top_candidates()`
  - `WhisperToken::n_top_candidates()`, `get_top_candidate()`

- **Skip Encode**: Reuse encoded audio for multiple decode passes
  - `set_skip_encode(true)` for subsequent transcriptions

- **Forced Tokens**: Force specific tokens and re-decode
  - `set_forced_tokens()` for exploring alternatives

See the `whsh` example in the repository for interactive usage.

## Rebuilding

To rebuild from source:
```bash
cd /path/to/whisper-rs
./build-and-install.sh --all
```

Options:
- `--with-android` or `--all`: Build for Android targets (requires installed targets)
- No args: Build only for native Linux x86_64

## Version Information

See `VERSION` file for build details.
EOF

echo ""
echo "==> Installation complete!"
echo ""
echo "    Installed to: ${INSTALL_ROOT}"
echo ""
echo "    To use in your project, add to Cargo.toml:"
echo "    [dependencies]"
echo "    whisper-rs = { path = \"${INSTALL_ROOT}\" }"
echo ""
echo "    Or set HANDSFREEAI_DEV_HOME environment variable:"
echo "    export HANDSFREEAI_DEV_HOME=${HANDSFREEAI_DEV_HOME}"
echo ""
