# Task for whisper-rs Developer

## Goal
Make the prebuilt whisper-rs directory usable as a Cargo path dependency.

## Current State
Location: `$HANDSFREEAI_DEV_HOME/whisper-rs`

Current structure:
```
whisper-rs/
├── include/
│   ├── README.md
│   └── bindings.rs          # FFI bindings (194KB)
├── linux-x86_64/
│   └── libwhisper_rs.rlib   # Precompiled library (504KB)
├── android/
│   └── arm64-v8a/
│       └── libwhisper_rs.rlib
├── README.md
└── VERSION
```

## Problem
Cannot be used as a Cargo path dependency because:
- Missing Cargo.toml
- Missing src/ directory structure
- No way for Cargo to discover and use the prebuilt .rlib files

## Required Solution
Add minimal Cargo package structure to make this directory usable as:
```toml
[dependencies]
whisper-rs = { path = "$HANDSFREEAI_DEV_HOME/whisper-rs" }
```

## Needed Files

1. **Cargo.toml** - Define the crate metadata
2. **src/lib.rs** - Minimal source that re-exports the API
3. **build.rs** (if needed) - Select correct .rlib for target platform

## Requirements
- Must work with prebuilt .rlib (no recompilation)
- Must provide backtrack branch API (token candidates, skip encode, forced tokens)
- Must link to whisper.cpp libraries at `$HANDSFREEAI_DEV_HOME/whisper.cpp`
- Must support Linux x86_64 and Android targets

## Environment
`HANDSFREEAI_DEV_HOME=/mnt/HC_Volume_103849597/home/olpa/audio/hfai_dev`
