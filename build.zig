const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zigimg_dependency = b.dependency("zigimg", .{
        .target = target,
        .optimize = optimize,
    });

    const mod = b.addModule("img_blur_detector", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    mod.addImport("zigimg", zigimg_dependency.module("zigimg"));

    const lib = b.addLibrary(.{
        .name = "img_blur_detector",
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .strip = true,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zigimg", .module = zigimg_dependency.module("zigimg") },
            },
        }),
    });
    b.installArtifact(lib);
}
