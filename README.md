# Image Blur and Lighting Checker

## Build .so files for Android :hammer:
zig build -Dtarget=aarch64-linux-android -Doptimize=ReleaseSmall
zig build -Dtarget=arm-linux-androideabi -Doptimize=ReleaseSmall
zig build -Dtarget=x86_64-linux-android -Doptimize=ReleaseSmall
zig build -Dtarget=x86-linux-android -Doptimize=ReleaseSmall
