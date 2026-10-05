# Image Blur & Lighting Checker (Zig FFI)

A lightweight, zero-dependency C-ABI native library written in **Zig** designed for fast image quality assessment (blur detection & lighting thresholding) in Flutter/Android applications via FFI.

## Features
- **Zero Heavy Dependencies:** Replaces bulky OpenCV/C++ binaries with a minimal, optimized native shared library (`.so`).
- **Low Footprint:** Built with `-Doptimize=ReleaseSmall` for minimal app bundle size impact.

## Building `.so` Libraries for Android :hammer:

Run the following commands to compile for all supported Android ABIs:

```bash
# ARM64
zig build -Dtarget=aarch64-linux-android -Doptimize=ReleaseSmall

# ARMv7
zig build -Dtarget=arm-linux-androideabi -Doptimize=ReleaseSmall

# x86_64
zig build -Dtarget=x86_64-linux-android -Doptimize=ReleaseSmall

# x86
zig build -Dtarget=x86-linux-android -Doptimize=ReleaseSmall