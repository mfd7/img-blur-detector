pub const PatchBlurResult = extern struct {
    is_blurred: bool,
    h_blur_patch_count: usize,
    v_blur_patch_count: usize,
    oof_patch_count: usize,
    active_patches: usize,
};

pub fn evaluatePatchWiseBlur(
    pixels: []const f64,
    width: usize,
    height: usize,
    bbox_x: usize,
    bbox_y: usize,
    bbox_w: usize,
    bbox_h: usize,
) PatchBlurResult {
    // 1. Clamp dynamic face bounding box to image bounds
    const start_x = @min(bbox_x, width);
    const start_y = @min(bbox_y, height);
    const end_x = @min(bbox_x + bbox_w, width);
    const end_y = @min(bbox_y + bbox_h, height);

    const roi_w = end_x -| start_x;
    const roi_h = end_y -| start_y;

    if (roi_w < 16 or roi_h < 16) return .{
        .is_blurred = true,
        .h_blur_patch_count = 0,
        .v_blur_patch_count = 0,
        .oof_patch_count = 0,
        .active_patches = 0,
    };

    const grid_cols: usize = 4;
    const grid_rows: usize = 4;
    const patch_w = roi_w / grid_cols;
    const patch_h = roi_h / grid_rows;

    var h_blur_count: usize = 0;
    var v_blur_count: usize = 0;
    var oof_count: usize = 0;
    var active_patches: usize = 0;

    const stride: usize = if (width >= 320) 2 else 1;
    const max_h_energy_for_blur: f64 = 110.0;
    const max_v_energy_for_blur: f64 = 110.0;

    // Minimum 3x3 micro-detail residual floor (calibrated to tolerate smooth skin)
    const min_micro_detail_threshold: f64 = 2.8;

    var row_idx: usize = 0;
    while (row_idx < grid_rows) : (row_idx += 1) {
        var col_idx: usize = 0;
        while (col_idx < grid_cols) : (col_idx += 1) {
            const px_start = start_x + (col_idx * patch_w);
            const px_end = px_start + patch_w;
            const py_start = start_y + (row_idx * patch_h);
            const py_end = py_start + patch_h;

            var sum_gx: f64 = 0.0;
            var sum_sq_gx: f64 = 0.0;
            var sum_gy: f64 = 0.0;
            var sum_sq_gy: f64 = 0.0;
            var sum_micro_residual: f64 = 0.0;
            var count: f64 = 0.0;

            var y = py_start + stride;
            while (y < py_end - stride) : (y += stride) {
                const row = y * width;
                const prev = (y - stride) * width;
                const next = (y + stride) * width;

                var x = px_start + stride;
                while (x < px_end - stride) : (x += stride) {
                    // 1. Sobel Gradients
                    const gx = (pixels[prev + x + stride] - pixels[prev + x - stride]) +
                        2.0 * (pixels[row + x + stride] - pixels[row + x - stride]) +
                        (pixels[next + x + stride] - pixels[next + x - stride]);

                    const gy = (pixels[next + x - stride] - pixels[prev + x - stride]) +
                        2.0 * (pixels[next + x] - pixels[prev + x]) +
                        (pixels[next + x + stride] - pixels[prev + x + stride]);

                    // 2. 3x3 Micro-Detail Residual (Difference from local 3x3 mean)
                    const mean_3x3 = (pixels[prev + x - stride] + pixels[prev + x] + pixels[prev + x + stride] +
                        pixels[row + x - stride] + pixels[row + x] + pixels[row + x + stride] +
                        pixels[next + x - stride] + pixels[next + x] + pixels[next + x + stride]) / 9.0;

                    const diff = @abs(pixels[row + x] - mean_3x3);

                    sum_gx += gx;
                    sum_sq_gx += gx * gx;
                    sum_gy += gy;
                    sum_sq_gy += gy * gy;
                    sum_micro_residual += diff;
                    count += 1.0;
                }
            }

            if (count < 4.0) continue;

            const mean_gx = sum_gx / count;
            const mean_gy = sum_gy / count;
            const var_x = (sum_sq_gx / count) - (mean_gx * mean_gx);
            const var_y = (sum_sq_gy / count) - (mean_gy * mean_gy);
            const max_var = @max(var_x, var_y);
            const avg_micro_detail = sum_micro_residual / count;

            if (max_var >= 80.0) {
                active_patches += 1;
                const ratio = if (var_y > 1e-6) var_x / var_y else 1.0;

                // Directional Motion Blur Checks
                if (ratio < 0.32 and var_x < max_h_energy_for_blur) {
                    h_blur_count += 1;
                } else if (ratio > 3.30 and var_y < max_v_energy_for_blur) {
                    v_blur_count += 1;
                }

                // Out-of-Focus Check: Micro-detail residual is below sharpness floor
                if (avg_micro_detail < min_micro_detail_threshold) {
                    oof_count += 1;
                }
            }
        }
    }

    // Rejection Rules (Reference Registration Profile):
    // - Motion blur: >= 3 patches fail energy/ratio gate
    // - Out of focus: >= 65% of active patches lack micro-detail
    // - Flat / Occluded: active_patches == 0
    const is_oof = (active_patches > 0) and (oof_count >= ((active_patches * 65) / 100));
    const is_blurred = (h_blur_count >= 3) or (v_blur_count >= 3) or is_oof or (active_patches == 0);

    return .{
        .is_blurred = is_blurred,
        .h_blur_patch_count = h_blur_count,
        .v_blur_patch_count = v_blur_count,
        .oof_patch_count = oof_count,
        .active_patches = active_patches,
    };
}
