const std = @import("std");
const zigimg = @import("zigimg");
const dv = @import("directional_variance.zig");
const lighting = @import("lighting.zig");

pub const AnalysisResult = extern struct {
    status: bool,
    directional_variance: dv.PatchBlurResult,
    lighting: lighting.LightingResult,
};

pub export fn getauxval(type_num: usize) usize {
    _ = type_num;
    return 0;
}

export fn analyze_image_memory(
    image_data: [*]const u8,
    data_length: usize,
    bbox_x: usize,
    bbox_y: usize,
    bbox_w: usize,
    bbox_h: usize,
) AnalysisResult {
    var arena = std.heap.ArenaAllocator.init(std.heap.smp_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const bytes = image_data[0..data_length];

    var img = zigimg.Image.fromMemory(allocator, bytes) catch {
        return AnalysisResult{
            .status = false,
            .directional_variance = .{
                .is_blurred = true,
                .h_blur_patch_count = 0,
                .v_blur_patch_count = 0,
                .oof_patch_count = 0,
                .active_patches = 0,
            },
            .lighting = .{
                .is_acceptable = false,
                .asymmetry_delta = 999.0,
                .left_brightness = 0,
                .mean_brightness = 0,
                .right_brightness = 0,
            },
        };
    };
    defer img.deinit(allocator);

    const grayscaled_img = imgToGrayscale(img, allocator) catch {
        return AnalysisResult{
            .status = false,
            .directional_variance = .{
                .is_blurred = true,
                .h_blur_patch_count = 0,
                .v_blur_patch_count = 0,
                .oof_patch_count = 0,
                .active_patches = 0,
            },
            .lighting = .{
                .is_acceptable = false,
                .asymmetry_delta = 999.0,
                .left_brightness = 0,
                .mean_brightness = 0,
                .right_brightness = 0,
            },
        };
    };

    const dir_var = dv.evaluatePatchWiseBlur(
        grayscaled_img.pixels,
        img.width,
        img.height,
        bbox_x,
        bbox_y,
        bbox_w,
        bbox_h,
    );

    const light = lighting.evaluateLightingAsymmetry(
        grayscaled_img.pixels,
        img.width,
        img.height,
        bbox_x,
        bbox_y,
        bbox_w,
        bbox_h,
        35.0,
    );

    return AnalysisResult{
        .status = true,
        .directional_variance = dir_var,
        .lighting = light,
    };
}

pub fn imgToGrayscale(img: zigimg.Image, allocator: std.mem.Allocator) !struct {
    pixels: []f64,
    mean_brightness: f64,
} {
    const pixel_count = img.height * img.width;
    const gray_pixels = try allocator.alloc(f64, pixel_count);

    var iter = img.iterator();
    var idx: usize = 0;
    var total_brightness: f64 = 0.0;

    while (iter.next()) |color| {
        const gray = (0.299 * color.r + 0.587 * color.g + 0.114 * color.b) * 255.0;

        gray_pixels[idx] = gray;
        total_brightness += gray;
        idx += 1;
    }

    const mean_brightness = total_brightness / @as(f64, @floatFromInt(pixel_count));

    return .{
        .pixels = gray_pixels,
        .mean_brightness = mean_brightness,
    };
}
