mut D = require("data.cy")
mut M = require("model.cy")
mut FA = require("fast.cy")
mut U = require("../../lib/geo/utm.cy")
mut BY = require("../../lib/io/bytes.cy")

pub OUTPUTS = u32(31)
LAW_SLOTS = u32(29)
PIXEL_HEADS = u32(19)
TAPS = u32(9)

fn add_scaled_row(target: f32[], target_at: u32, source: f32[], source_at: u32, weight: f32, count: u32)
    mut j = u32(0)
    while j < count do
        target[target_at + j] = target[target_at + j] + weight * source[source_at + j]
        j = j + u32(1)
    end
end

fn conv3x3(input: f32[], params: f32[], output: f32[], in_channels: u32, out_channels: u32, size: u32, dilation: u32, weights_at: u32, bias_at: u32, relu: u32)
    plane = size * size
    width = i32(size)
    step = i32(dilation)
    mut o = u32(0)
    while o < out_channels do
        out_at = o * plane
        bias = params[bias_at + o]
        mut q = u32(0)
        while q < plane do
            output[out_at + q] = bias
            q = q + u32(1)
        end
        mut c = u32(0)
        while c < in_channels do
            in_at = i32(c * plane)
            mut tap = u32(0)
            while tap < TAPS do
                dy = i32(tap / u32(3)) * step - step
                dx = i32(tap % u32(3)) * step - step
                weight = params[weights_at + (o * in_channels + c) * TAPS + tap]
                row_start = max(i32(0), i32(0) - dy)
                row_end = min(width, width - dy)
                col_start = max(i32(0), i32(0) - dx)
                col_end = min(width, width - dx)
                count = u32(col_end - col_start)
                mut row = row_start
                while row < row_end do
                    add_scaled_row(output, out_at + u32(row * width + col_start), input, u32(in_at + (row + dy) * width + col_start + dx), weight, count)
                    row = row + i32(1)
                end
                tap = tap + u32(1)
            end
            c = c + u32(1)
        end
        if relu == u32(1) then
            q = u32(0)
            while q < plane do
                output[out_at + q] = max(output[out_at + q], f32(0.0))
                q = q + u32(1)
            end
        end
        o = o + u32(1)
    end
end

fn linear_heads(features: f32[], weights: f32[], scores: f32[], feature_count: u32, columns: u32, pixels: u32)
    mut o = u32(0)
    while o < columns do
        out_at = o * pixels
        mut q = u32(0)
        while q < pixels do
            scores[out_at + q] = f32(0.0)
            q = q + u32(1)
        end
        mut c = u32(0)
        while c < feature_count do
            add_scaled_row(scores, out_at, features, c * pixels, weights[c * columns + o], pixels)
            c = c + u32(1)
        end
        o = o + u32(1)
    end
end

fn run_chunk(refl: f32[], size: u32, doy: u32, feature_count: u32, soil_groups: u32, stage2: u32,
             band_norm: f32[], unmix: f32[], conv: f32[], laws: u32[], law_coefs: f32[], heads: f32[], stage2_heads: f32[], stage2_conv: f32[],
             target_mean: f32[], target_sd: f32[],
             base: f32[], local_mean: f32[], context_mean: f32[], scratch: f32[], conv1: f32[], conv2: f32[], conv3: f32[], conv4: f32[],
             law_values: f32[], edges: f32[], edge_peaks: f32[], features: f32[], scores: f32[], out: f32[],
             maps: f32[], map_conv1: f32[], map_conv2: f32[], map_context: f32[], stage2_features: f32[])
    pixels = size * size
    columns = PIXEL_HEADS + D.NSOIL + soil_groups + D.NWX
    angle = 2.0 * U.PI * f64(doy) / 365.25
    FA.k_base(refl, base, band_norm, unmix, f32(U.sin64(angle)), f32(U.cos64(angle)), pixels)
    FA.k_boxh(base, scratch, u32(21), size, u32(3))
    FA.k_boxv(scratch, local_mean, u32(21), size, u32(3))
    FA.k_boxh(base, scratch, u32(21), size, FA.MARGIN)
    FA.k_boxv(scratch, context_mean, u32(21), size, FA.MARGIN)
    layer1_bias = M.NFEAT * D.NBASE * TAPS
    layer2_weights = layer1_bias + M.NFEAT
    layer2_bias = layer2_weights + M.NFEAT * M.NFEAT * TAPS
    layer3_weights = layer2_bias + M.NFEAT
    layer3_bias = layer3_weights + M.NFEAT * M.NFEAT * TAPS
    layer4_weights = layer3_bias + M.NFEAT
    layer4_bias = layer4_weights + M.NFEAT * M.NFEAT * TAPS
    conv3x3(base, conv, conv1, D.NBASE, M.NFEAT, size, u32(1), u32(0), layer1_bias, u32(1))
    conv3x3(conv1, conv, conv2, M.NFEAT, M.NFEAT, size, u32(2), layer2_weights, layer2_bias, u32(1))
    conv3x3(conv2, conv, conv3, M.NFEAT, M.NFEAT, size, u32(4), layer3_weights, layer3_bias, u32(1))
    conv3x3(conv3, conv, conv4, M.NFEAT, M.NFEAT, size, u32(8), layer4_weights, layer4_bias, u32(1))
    FA.k_neur(base, local_mean, laws, law_coefs, law_values, pixels)
    FA.k_fill(features, pixels, f32(1.0))
    FA.k_copy(base, features, pixels, u32(21) * pixels)
    FA.k_copy(conv1, features, u32(22) * pixels, u32(48) * pixels)
    FA.k_copy(conv2, features, u32(70) * pixels, u32(48) * pixels)
    FA.k_copy(conv3, features, u32(118) * pixels, u32(48) * pixels)
    FA.k_copy(conv4, features, u32(166) * pixels, u32(48) * pixels)
    FA.k_copy(context_mean, features, u32(214) * pixels, u32(21) * pixels)
    FA.k_copy(law_values, features, u32(235) * pixels, u32(58) * pixels)
    if feature_count >= u32(301) then
        FA.k_sobel(base, edges, size)
        FA.k_max3(edges, edge_peaks, size)
        FA.k_copy(edges, features, u32(293) * pixels, u32(4) * pixels)
        FA.k_copy(edge_peaks, features, u32(297) * pixels, u32(4) * pixels)
    end
    linear_heads(features, heads, scores, feature_count, columns, pixels)
    FA.k_final(scores, out, target_mean, target_sd, soil_groups, pixels)
    if stage2 == u32(1) then
        FA.k_maps(out, maps, target_mean, target_sd, pixels)
        map_layer1 = u32(24) * u32(9) * TAPS
        map_layer2 = u32(24) * u32(24) * TAPS
        conv3x3(maps, stage2_conv, map_conv1, u32(9), u32(24), size, u32(2), u32(0), map_layer1, u32(1))
        conv3x3(map_conv1, stage2_conv, map_conv2, u32(24), u32(24), size, u32(4), map_layer1 + u32(24), map_layer1 + u32(24) + map_layer2, u32(1))
        FA.k_boxh(maps, scratch, u32(9), size, FA.MARGIN)
        FA.k_boxv(scratch, map_context, u32(9), size, FA.MARGIN)
        FA.k_copy(features, stage2_features, u32(0), feature_count * pixels)
        FA.k_copy(maps, stage2_features, feature_count * pixels, u32(9) * pixels)
        FA.k_copy(map_conv1, stage2_features, (feature_count + u32(9)) * pixels, u32(24) * pixels)
        FA.k_copy(map_conv2, stage2_features, (feature_count + u32(33)) * pixels, u32(24) * pixels)
        FA.k_copy(map_context, stage2_features, (feature_count + u32(57)) * pixels, u32(9) * pixels)
        linear_heads(stage2_features, stage2_heads, scores, feature_count + u32(66), columns, pixels)
        FA.k_final(scores, out, target_mean, target_sd, soil_groups, pixels)
    end
end

fn read_f32s(data: u8[], cursor: u32[], count: u32) -> f32[]
    mut values = array[f32](count)
    mut i = u32(0)
    while i < count do
        values[i] = BY.f32le(data, cursor[0])
        cursor[0] = cursor[0] + u32(4)
        i = i + u32(1)
    end
    return values
end

fn read_f32s_as_f64(data: u8[], cursor: u32[], count: u32) -> f64[]
    mut values = array[f64](count)
    mut i = u32(0)
    while i < count do
        values[i] = f64(BY.f32le(data, cursor[0]))
        cursor[0] = cursor[0] + u32(4)
        i = i + u32(1)
    end
    return values
end

fn read_u32s(data: u8[], cursor: u32[], count: u32) -> u32[]
    mut values = array[u32](count)
    mut i = u32(0)
    while i < count do
        values[i] = BY.u32le(data, cursor[0])
        cursor[0] = cursor[0] + u32(4)
        i = i + u32(1)
    end
    return values
end

pub fn infer(model: u8[], regional_soil_heads: u8[], refl: f32[], size: u32, doy: u32, out: f32[]) -> f64
    mut cursor = array[u32](1)
    cursor[0] = u32(8)
    feature_count = BY.u32le(model, cursor[0])
    soil_groups = BY.u32le(model, cursor[0] + u32(4))
    conv_count = BY.u32le(model, cursor[0] + u32(8))
    cursor[0] = cursor[0] + u32(12)
    soil_columns = D.NSOIL + soil_groups
    mut band_norm = read_f32s(model, cursor, u32(20))
    endmembers = read_f32s_as_f64(model, cursor, u32(40))
    wrb_codes = read_u32s(model, cursor, soil_groups)
    mut conv = read_f32s(model, cursor, conv_count)
    mut laws = read_u32s(model, cursor, LAW_SLOTS * u32(8))
    mut law_coefs = read_f32s(model, cursor, LAW_SLOTS * u32(8))
    mut target_mean = read_f32s(model, cursor, LAW_SLOTS)
    mut target_sd = read_f32s(model, cursor, LAW_SLOTS)
    pixel_heads = read_f32s(model, cursor, feature_count * PIXEL_HEADS)
    mut soil_heads = read_f32s(model, cursor, feature_count * soil_columns)
    weather_heads = read_f32s(model, cursor, feature_count * D.NWX)
    cursor[0] = cursor[0] + (soil_columns + D.NWX) * u32(4) + u32(8) * feature_count * feature_count
    if cursor[0] + D.NCROP * u32(4) <= len(model) then
        cursor[0] = cursor[0] + D.NCROP * u32(4)
    end
    mut stage2 = u32(0)
    mut stage2_count = u32(0)
    mut stage2_conv = array[f32](1)
    mut stage2_pixel = array[f32](1)
    mut stage2_soil = array[f32](1)
    mut stage2_weather = array[f32](1)
    if cursor[0] + u32(12) <= len(model) then
        stage2 = BY.u32le(model, cursor[0])
        stage2_count = BY.u32le(model, cursor[0] + u32(4))
        stage2_conv_count = BY.u32le(model, cursor[0] + u32(8))
        cursor[0] = cursor[0] + u32(12)
        stage2_conv = read_f32s(model, cursor, stage2_conv_count)
        stage2_pixel = read_f32s(model, cursor, stage2_count * PIXEL_HEADS)
        stage2_soil = read_f32s(model, cursor, stage2_count * soil_columns)
        stage2_weather = read_f32s(model, cursor, stage2_count * D.NWX)
    end
    if len(regional_soil_heads) == feature_count * D.NSOIL * u32(4) then
        mut f = u32(0)
        while f < feature_count do
            mut t = u32(0)
            while t < D.NSOIL do
                soil_heads[f * soil_columns + t] = BY.f32le(regional_soil_heads, (f * D.NSOIL + t) * u32(4))
                t = t + u32(1)
            end
            f = f + u32(1)
        end
        stage2 = u32(0)
    end
    mut unmix = array[f32](44)
    D.unmix_prep(endmembers, unmix)
    pixels = size * size
    mut heads = FA.combine(pixel_heads, soil_heads, weather_heads, feature_count, soil_groups)
    mut stage2_heads = array[f32](1)
    mut stage2_pixels = u32(1)
    if stage2 == u32(1) then
        stage2_heads = FA.combine(stage2_pixel, stage2_soil, stage2_weather, stage2_count, soil_groups)
        stage2_pixels = pixels
    end
    mut base = array[f32](u32(21) * pixels)
    mut local_mean = array[f32](u32(21) * pixels)
    mut context_mean = array[f32](u32(21) * pixels)
    mut scratch = array[f32](u32(21) * pixels)
    mut conv1 = array[f32](u32(48) * pixels)
    mut conv2 = array[f32](u32(48) * pixels)
    mut conv3 = array[f32](u32(48) * pixels)
    mut conv4 = array[f32](u32(48) * pixels)
    mut law_values = array[f32](u32(58) * pixels)
    mut edges = array[f32](u32(4) * pixels)
    mut edge_peaks = array[f32](u32(4) * pixels)
    mut features = array[f32](feature_count * pixels)
    columns = PIXEL_HEADS + soil_columns + D.NWX
    mut scores = array[f32](columns * pixels)
    mut maps = array[f32](u32(9) * stage2_pixels)
    mut map_conv1 = array[f32](u32(24) * stage2_pixels)
    mut map_conv2 = array[f32](u32(24) * stage2_pixels)
    mut map_context = array[f32](u32(9) * stage2_pixels)
    mut stage2_features = array[f32]((feature_count + u32(66)) * stage2_pixels)
    started = clock()
    run_chunk(refl, size, doy, feature_count, soil_groups, stage2, band_norm, unmix, conv, laws, law_coefs, heads, stage2_heads, stage2_conv,
              target_mean, target_sd, base, local_mean, context_mean, scratch, conv1, conv2, conv3, conv4,
              law_values, edges, edge_peaks, features, scores, out, maps, map_conv1, map_conv2, map_context, stage2_features)
    return clock() - started
end
