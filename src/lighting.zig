pub const LightingResult = extern struct {
    mean_brightness: f64,
    left_brightness: f64,
    right_brightness: f64,
    asymmetry_delta: f64,
    is_acceptable: bool,
};

pub fn evaluateLightingAsymmetry(
    pixels: []const f64,
    width: usize,
    height: usize,
    bbox_x: usize,
    bbox_y: usize,
    bbox_w: usize,
    bbox_h: usize,
    max_allowed_delta: f64,
) LightingResult {
    // 1. Clamp dynamic face bounding box to image bounds
    const start_x = @min(bbox_x, width);
    const start_y = @min(bbox_y, height);
    const end_x = @min(bbox_x + bbox_w, width);
    const end_y = @min(bbox_y + bbox_h, height);

    const roi_w = end_x -| start_x;
    const roi_h = end_y -| start_y;

    if (roi_w < 16 or roi_h < 16) return .{
        .mean_brightness = 0.0,
        .left_brightness = 0.0,
        .right_brightness = 0.0,
        .asymmetry_delta = 999.0,
        .is_acceptable = false,
    };

    // 2. Compute vertical midline across the dynamic face region
    const mid_x = start_x + (roi_w / 2);

    var left_sum: f64 = 0.0;
    var left_count: f64 = 0.0;
    var right_sum: f64 = 0.0;
    var right_count: f64 = 0.0;

    const stride: usize = if (width >= 320) 4 else 2;

    var y = start_y;
    while (y < end_y) : (y += stride) {
        const row = y * width;

        // Left Half of Face ROI
        var x_left = start_x;
        while (x_left < mid_x) : (x_left += stride) {
            left_sum += pixels[row + x_left];
            left_count += 1.0;
        }

        // Right Half of Face ROI
        var x_right = mid_x;
        while (x_right < end_x) : (x_right += stride) {
            right_sum += pixels[row + x_right];
            right_count += 1.0;
        }
    }

    const left_mean = if (left_count > 0.0) left_sum / left_count else 0.0;
    const right_mean = if (right_count > 0.0) right_sum / right_count else 0.0;
    const total_pixels = left_count + right_count;
    const total_mean = if (total_pixels > 0.0) (left_sum + right_sum) / total_pixels else 0.0;
    const delta = @abs(left_mean - right_mean);

    // Gate Condition: Overall brightness between 40-215 AND asymmetry below max allowed delta
    const is_acceptable = (total_mean >= 40.0) and
        (total_mean <= 215.0) and
        (delta <= max_allowed_delta);

    return .{
        .mean_brightness = total_mean,
        .left_brightness = left_mean,
        .right_brightness = right_mean,
        .asymmetry_delta = delta,
        .is_acceptable = is_acceptable,
    };
}
