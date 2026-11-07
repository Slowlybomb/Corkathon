mut st = require("../format/safetensors.cy")
mut io = require("../io/bytes.cy")
mut mm = require("../math/scalar.cy")
mut op = require("../nn/ops.cy")
mut vv = require("../math/vector.cy")

BLOCKS = u32(16)

N_LAYER = u32(12)
N_EMBD = u32(768)
N_HEAD = u32(12)
N_VOCAB = u32(50257)
HEAD_DIM = u32(64)
EPS = f32(0.00001)

T_LN1_W = u32(0)
T_LN1_B = u32(1)
T_ATTN_W = u32(2)
T_ATTN_B = u32(3)
T_APROJ_W = u32(4)
T_APROJ_B = u32(5)
T_LN2_W = u32(6)
T_LN2_B = u32(7)
T_FC_W = u32(8)
T_FC_B = u32(9)
T_PROJ_W = u32(10)
T_PROJ_B = u32(11)
PER_LAYER = u32(12)

T_WTE = u32(0)
T_WPE = u32(1)
T_LNF_W = u32(2)
T_LNF_B = u32(3)
T_LMQ_W = u32(4)
T_LMQ_S = u32(5)

T_LM16_S = u32(6)

T_Q4_TOT = u32(7)

Q_BASE = N_LAYER * PER_LAYER
G_BASE = N_LAYER * PER_LAYER * u32(2)
OFF_N = N_LAYER * PER_LAYER * u32(2) + u32(8)

pub type Model
    w: f32[]
    mut off: u32[]
    w8: i8[]
    qs: f32[]
    csum: i32[]
    hw: i8[]
end

fn suffix_slot(d: u8[], at: u32, from: u32) -> u32
    if io.matches(d, from, bytes("ln_1.weight")) then
        return T_LN1_W
    end
    if io.matches(d, from, bytes("ln_1.bias")) then
        return T_LN1_B
    end
    if io.matches(d, from, bytes("attn.c_attn.weight")) then
        return T_ATTN_W
    end
    if io.matches(d, from, bytes("attn.c_attn.bias")) then
        return T_ATTN_B
    end
    if io.matches(d, from, bytes("attn.c_proj.weight")) then
        return T_APROJ_W
    end
    if io.matches(d, from, bytes("attn.c_proj.bias")) then
        return T_APROJ_B
    end
    if io.matches(d, from, bytes("ln_2.weight")) then
        return T_LN2_W
    end
    if io.matches(d, from, bytes("ln_2.bias")) then
        return T_LN2_B
    end
    if io.matches(d, from, bytes("mlp.c_fc.weight")) then
        return T_FC_W
    end
    if io.matches(d, from, bytes("mlp.c_fc.bias")) then
        return T_FC_B
    end
    if io.matches(d, from, bytes("mlp.c_proj.weight")) then
        return T_PROJ_W
    end
    if io.matches(d, from, bytes("mlp.c_proj.bias")) then
        return T_PROJ_B
    end
    return PER_LAYER
end

fn layer_of(d: u8[], nameAt: u32, nameLen: u32) -> u32
    if nameLen < u32(3) then
        return N_LAYER
    end
    if d[nameAt] != u8(104) then
        return N_LAYER
    end
    if d[nameAt + u32(1)] != u8(46) then
        return N_LAYER
    end
    mut v = u32(0)
    mut i = nameAt + u32(2)
    mut seen = u32(0)
    while i < nameAt + nameLen do
        mut c = d[i]
        if c == u8(46) then
            if seen == u32(0) then
                return N_LAYER
            end
            if v >= N_LAYER then
                return N_LAYER
            end
            return v
        end
        if c < u8(48) then
            return N_LAYER
        end
        if c > u8(57) then
            return N_LAYER
        end
        v = v * u32(10) + u32(c) - u32(48)
        seen = seen + u32(1)
        i = i + u32(1)
    end
    return N_LAYER
end

fn digits_after_h(d: u8[], nameAt: u32, nameLen: u32) -> u32
    mut i = nameAt + u32(2)
    while i < nameAt + nameLen do
        if d[i] == u8(46) then
            return i + u32(1)
        end
        i = i + u32(1)
    end
    return nameAt + nameLen
end

pub fn load() -> Model
    mut d = readfile("data/models/gpt2.safetensors")
    mut off = array[u32](OFF_N)
    if len(d) == u32(0) then
        return Model(w: array[f32](u32(0)), off: off,
                     w8: array[i8](u32(0)), qs: array[f32](u32(0)),
                     csum: array[i32](u32(0)), hw: array[i8](u32(0)))
    end
    mut base = st.data_start(d)
    mut floats = (len(d) - base) / u32(4)
    mut w = array[f32](floats)
    mut i = u32(0)
    while i < floats do
        w[i] = io.f32le(d, base + i * u32(4))
        i = i + u32(1)
    end
    mut at = st.first(d)
    while st.done(d, at) == false do
        mut nameAt = st.name_at(d, at)
        mut nameLen = st.name_len(d, at)
        mut elem = u32(st.begin_at(d, at)) / u32(4)
        mut lay = layer_of(d, nameAt, nameLen)
        if lay < N_LAYER then
            mut rest = digits_after_h(d, nameAt, nameLen)
            mut slot = suffix_slot(d, at, rest)
            if slot < PER_LAYER then
                off[lay * PER_LAYER + slot] = elem
            end
        else
            if io.matches(d, nameAt, bytes("wte.weight")) then
                off[G_BASE + T_WTE] = elem
            end
            if io.matches(d, nameAt, bytes("wpe.weight")) then
                off[G_BASE + T_WPE] = elem
            end
            if io.matches(d, nameAt, bytes("ln_f.weight")) then
                off[G_BASE + T_LNF_W] = elem
            end
            if io.matches(d, nameAt, bytes("ln_f.bias")) then
                off[G_BASE + T_LNF_B] = elem
            end
        end
        at = st.next(d, at)
    end
    return Model(w: w, off: off,
                 w8: array[i8](u32(0)), qs: array[f32](u32(0)),
                 csum: array[i32](u32(0)), hw: array[i8](u32(0)))
end

fn linear_batch(w: f32[], wo: u32, bo: u32, x: f32[], y: f32[],
                n: u32, indim: u32, outdim: u32)
    mut t = u32(0)
    while t < n do
        mut j = u32(0)
        while j < outdim do
            y[t * outdim + j] = w[bo + j]
            j = j + u32(1)
        end
        t = t + u32(1)
    end
    mut i = u32(0)
    while i < indim do
        mut wbase = wo + i * outdim
        mut s = u32(0)
        while s < n do
            mut xi = x[s * indim + i]
            mut yo = s * outdim
            mut c = u32(0)
            while c < outdim do
                y[yo + c] = y[yo + c] + xi * w[wbase + c]
                c = c + u32(1)
            end
            s = s + u32(1)
        end
        i = i + u32(1)
    end
end

fn linear(w: f32[], wo: u32, bo: u32, x: f32[], xo: u32, y: f32[], yo: u32,
          indim: u32, outdim: u32)
    mut j = u32(0)
    while j < outdim do
        y[yo + j] = w[bo + j]
        j = j + u32(1)
    end
    mut i = u32(0)
    while i < indim do
        mut xi = x[xo + i]
        mut base = wo + i * outdim
        mut c = u32(0)
        while c < outdim do
            y[yo + c] = y[yo + c] + xi * w[base + c]
            c = c + u32(1)
        end
        i = i + u32(1)
    end
end

pub fn layernorm_at(w: f32[], go: u32, bo: u32, x: f32[], xo: u32, y: f32[], yo: u32,
                n: u32)
    mut sum = 0.0
    mut i = u32(0)
    while i < n do
        sum = sum + f64(x[xo + i])
        i = i + u32(1)
    end
    mut mean = sum / f64(n)
    mut var = 0.0
    mut j = u32(0)
    while j < n do
        mut dd = f64(x[xo + j]) - mean
        var = var + dd * dd
        j = j + u32(1)
    end
    mut inv = mm.rsqrt(f32(var / f64(n)) + EPS)
    mut m = f32(mean)
    mut k = u32(0)
    while k < n do
        y[yo + k] = (x[xo + k] - m) * inv * w[go + k] + w[bo + k]
        k = k + u32(1)
    end
end

pub fn head(qkv: f32[], out: f32[], buf: f32[], h: u32, n: u32)
    mut scale = mm.rsqrt(f32(HEAD_DIM))
    mut stride = u32(3) * N_EMBD
    mut qoff = h * HEAD_DIM
    mut koff = N_EMBD + h * HEAD_DIM
    mut voff = u32(2) * N_EMBD + h * HEAD_DIM
    mut t = u32(0)
    while t < n do
        mut top = f32(0.0) - mm.inf()
        mut s = u32(0)
        while s <= t do
            mut acc = 0.0
            mut c = u32(0)
            while c < HEAD_DIM do
                acc = acc + f64(qkv[t * stride + qoff + c]) * f64(qkv[s * stride + koff + c])
                c = c + u32(1)
            end
            mut sc = f32(acc) * scale
            buf[s] = sc
            if sc > top then
                top = sc
            end
            s = s + u32(1)
        end
        mut tot = 0.0
        mut e = u32(0)
        while e <= t do
            mut x = mm.exp(buf[e] - top)
            buf[e] = x
            tot = tot + f64(x)
            e = e + u32(1)
        end
        mut inv = f32(1.0 / tot)
        mut z = u32(0)
        while z < HEAD_DIM do
            out[t * N_EMBD + h * HEAD_DIM + z] = f32(0.0)
            z = z + u32(1)
        end
        mut m = u32(0)
        while m <= t do
            mut wgt = buf[m] * inv
            mut c2 = u32(0)
            while c2 < HEAD_DIM do
                out[t * N_EMBD + h * HEAD_DIM + c2] =
                    out[t * N_EMBD + h * HEAD_DIM + c2] + wgt * qkv[m * stride + voff + c2]
                c2 = c2 + u32(1)
            end
            m = m + u32(1)
        end
        t = t + u32(1)
    end
end

pub fn forward(md: Model, ids: u32[], n: u32, logits: f32[]) -> u32
    if len(md.w) == u32(0) then
        return u32(0)
    end
    mut x = array[f32](n * N_EMBD)
    mut h1 = array[f32](n * N_EMBD)
    mut qkv = array[f32](n * u32(3) * N_EMBD)
    mut att = array[f32](n * N_EMBD)
    mut ff = array[f32](n * u32(4) * N_EMBD)
    mut buf = array[f32](n)

    mut t = u32(0)
    while t < n do
        mut e = md.off[G_BASE + T_WTE] + ids[t] * N_EMBD
        mut pp = md.off[G_BASE + T_WPE] + t * N_EMBD
        mut c = u32(0)
        while c < N_EMBD do
            x[t * N_EMBD + c] = md.w[e + c] + md.w[pp + c]
            c = c + u32(1)
        end
        t = t + u32(1)
    end

    mut l = u32(0)
    while l < N_LAYER do
        mut b = l * PER_LAYER
        mut i = u32(0)
        while i < n do
            layernorm_at(md.w, md.off[b + T_LN1_W], md.off[b + T_LN1_B],
                         x, i * N_EMBD, h1, i * N_EMBD, N_EMBD)
            i = i + u32(1)
        end
        linear_batch(md.w, md.off[b + T_ATTN_W], md.off[b + T_ATTN_B],
                     h1, qkv, n, N_EMBD, u32(3) * N_EMBD)
        mut hh = u32(0)
        while hh < N_HEAD do
            head(qkv, att, buf, hh, n)
            hh = hh + u32(1)
        end
        linear_batch(md.w, md.off[b + T_APROJ_W], md.off[b + T_APROJ_B],
                     att, h1, n, N_EMBD, N_EMBD)
        mut j = u32(0)
        while j < n do
            mut c2 = u32(0)
            while c2 < N_EMBD do
                x[j * N_EMBD + c2] = x[j * N_EMBD + c2] + h1[j * N_EMBD + c2]
                c2 = c2 + u32(1)
            end
            j = j + u32(1)
        end
        mut k = u32(0)
        while k < n do
            layernorm_at(md.w, md.off[b + T_LN2_W], md.off[b + T_LN2_B],
                         x, k * N_EMBD, h1, k * N_EMBD, N_EMBD)
            k = k + u32(1)
        end
        linear_batch(md.w, md.off[b + T_FC_W], md.off[b + T_FC_B],
                     h1, ff, n, N_EMBD, u32(4) * N_EMBD)
        mut gn = n * u32(4) * N_EMBD
        mut g = u32(0)
        while g + u32(8) <= gn do
            store(ff, g, vv.geluv(simd[f32, 8](ff, g)))
            g = g + u32(8)
        end
        linear_batch(md.w, md.off[b + T_PROJ_W], md.off[b + T_PROJ_B],
                     ff, h1, n, u32(4) * N_EMBD, N_EMBD)
        mut k2 = u32(0)
        while k2 < n do
            mut c3 = u32(0)
            while c3 < N_EMBD do
                x[k2 * N_EMBD + c3] = x[k2 * N_EMBD + c3] + h1[k2 * N_EMBD + c3]
                c3 = c3 + u32(1)
            end
            k2 = k2 + u32(1)
        end
        l = l + u32(1)
    end

    mut last = (n - u32(1)) * N_EMBD
    layernorm_at(md.w, md.off[G_BASE + T_LNF_W], md.off[G_BASE + T_LNF_B],
                 x, last, h1, u32(0), N_EMBD)
    mut v = u32(0)
    while v < N_VOCAB do
        mut acc = 0.0
        mut wbase = md.off[G_BASE + T_WTE] + v * N_EMBD
        mut c4 = u32(0)
        while c4 < N_EMBD do
            acc = acc + f64(h1[c4]) * f64(md.w[wbase + c4])
            c4 = c4 + u32(1)
        end
        logits[v] = f32(acc)
        v = v + u32(1)
    end
    return op.argmax(logits, N_VOCAB)
end

pub fn forward_nolm(md: Model, ids: u32[], n: u32, out: f32[]) -> u32
    if len(md.w) == u32(0) then
        return u32(0)
    end
    mut x = array[f32](n * N_EMBD)
    mut h1 = array[f32](n * N_EMBD)
    mut qkv = array[f32](n * u32(3) * N_EMBD)
    mut att = array[f32](n * N_EMBD)
    mut ff = array[f32](n * u32(4) * N_EMBD)
    mut buf = array[f32](n)
    mut t = u32(0)
    while t < n do
        mut e = md.off[G_BASE + T_WTE] + ids[t] * N_EMBD
        mut pp = md.off[G_BASE + T_WPE] + t * N_EMBD
        mut c = u32(0)
        while c < N_EMBD do
            x[t * N_EMBD + c] = md.w[e + c] + md.w[pp + c]
            c = c + u32(1)
        end
        t = t + u32(1)
    end
    mut l = u32(0)
    while l < N_LAYER do
        mut b = l * PER_LAYER
        mut i = u32(0)
        while i < n do
            layernorm_at(md.w, md.off[b + T_LN1_W], md.off[b + T_LN1_B],
                         x, i * N_EMBD, h1, i * N_EMBD, N_EMBD)
            i = i + u32(1)
        end
        linear_batch(md.w, md.off[b + T_ATTN_W], md.off[b + T_ATTN_B],
                     h1, qkv, n, N_EMBD, u32(3) * N_EMBD)
        mut hh = u32(0)
        while hh < N_HEAD do
            head(qkv, att, buf, hh, n)
            hh = hh + u32(1)
        end
        linear_batch(md.w, md.off[b + T_APROJ_W], md.off[b + T_APROJ_B],
                     att, h1, n, N_EMBD, N_EMBD)
        mut j = u32(0)
        while j < n do
            mut c2 = u32(0)
            while c2 < N_EMBD do
                x[j * N_EMBD + c2] = x[j * N_EMBD + c2] + h1[j * N_EMBD + c2]
                c2 = c2 + u32(1)
            end
            j = j + u32(1)
        end
        mut k = u32(0)
        while k < n do
            layernorm_at(md.w, md.off[b + T_LN2_W], md.off[b + T_LN2_B],
                         x, k * N_EMBD, h1, k * N_EMBD, N_EMBD)
            k = k + u32(1)
        end
        linear_batch(md.w, md.off[b + T_FC_W], md.off[b + T_FC_B],
                     h1, ff, n, N_EMBD, u32(4) * N_EMBD)
        mut gn = n * u32(4) * N_EMBD
        mut g = u32(0)
        while g + u32(8) <= gn do
            store(ff, g, vv.geluv(simd[f32, 8](ff, g)))
            g = g + u32(8)
        end
        linear_batch(md.w, md.off[b + T_PROJ_W], md.off[b + T_PROJ_B],
                     ff, h1, n, u32(4) * N_EMBD, N_EMBD)
        mut k2 = u32(0)
        while k2 < n do
            mut c3 = u32(0)
            while c3 < N_EMBD do
                x[k2 * N_EMBD + c3] = x[k2 * N_EMBD + c3] + h1[k2 * N_EMBD + c3]
                c3 = c3 + u32(1)
            end
            k2 = k2 + u32(1)
        end
        l = l + u32(1)
    end
    mut last = (n - u32(1)) * N_EMBD
    layernorm_at(md.w, md.off[G_BASE + T_LNF_W], md.off[G_BASE + T_LNF_B],
                 x, last, out, u32(0), N_EMBD)
    return u32(tobits(out[u32(0)]))
end

pub fn forward_linears(md: Model, n: u32) -> u32
    if len(md.w) == u32(0) then
        return u32(0)
    end
    mut h1 = array[f32](n * N_EMBD)
    mut qkv = array[f32](n * u32(3) * N_EMBD)
    mut att = array[f32](n * N_EMBD)
    mut ff = array[f32](n * u32(4) * N_EMBD)
    mut l = u32(0)
    while l < N_LAYER do
        mut b = l * PER_LAYER
        linear_batch(md.w, md.off[b + T_ATTN_W], md.off[b + T_ATTN_B],
                     h1, qkv, n, N_EMBD, u32(3) * N_EMBD)
        linear_batch(md.w, md.off[b + T_APROJ_W], md.off[b + T_APROJ_B],
                     att, h1, n, N_EMBD, N_EMBD)
        linear_batch(md.w, md.off[b + T_FC_W], md.off[b + T_FC_B],
                     h1, ff, n, N_EMBD, u32(4) * N_EMBD)
        linear_batch(md.w, md.off[b + T_PROJ_W], md.off[b + T_PROJ_B],
                     ff, h1, n, u32(4) * N_EMBD, N_EMBD)
        l = l + u32(1)
    end
    return u32(tobits(h1[u32(0)]))
end

fn slot_indim(slot: u32) -> u32
    if slot == T_ATTN_W then
        return N_EMBD
    end
    if slot == T_APROJ_W then
        return N_EMBD
    end
    if slot == T_FC_W then
        return N_EMBD
    end
    if slot == T_PROJ_W then
        return u32(4) * N_EMBD
    end
    return u32(0)
end

fn slot_outdim(slot: u32) -> u32
    if slot == T_ATTN_W then
        return u32(3) * N_EMBD
    end
    if slot == T_APROJ_W then
        return N_EMBD
    end
    if slot == T_FC_W then
        return u32(4) * N_EMBD
    end
    if slot == T_PROJ_W then
        return N_EMBD
    end
    return u32(0)
end

fn quantise_one(w: f32[], w8: i8[], qs: f32[], amax: f32[],
                wo: u32, qb: u32, indim: u32, outdim: u32)
    mut j = u32(0)
    while j < outdim do
        amax[j] = f32(0.0)
        j = j + u32(1)
    end
    mut i = u32(0)
    while i < indim do
        mut base = wo + i * outdim
        mut c = u32(0)
        while c < outdim do
            mut a = abs(w[base + c])
            if a > amax[c] then
                amax[c] = a
            end
            c = c + u32(1)
        end
        i = i + u32(1)
    end
    mut k = u32(0)
    while k < outdim do
        mut sc = amax[k] / 127.0
        if sc == 0.0 then
            sc = f32(1.0)
        end
        qs[qb + k] = sc
        amax[k] = 1.0 / sc
        k = k + u32(1)
    end
    mut r = u32(0)
    while r < indim do
        mut base = wo + r * outdim
        mut c2 = u32(0)
        while c2 < outdim do
            w8[wo + c2 * indim + r] = i8(i32(round(w[base + c2] * amax[c2])))
            c2 = c2 + u32(1)
        end
        r = r + u32(1)
    end
end

fn quantise_rows(w: f32[], w8: i8[], qs: f32[], wo: u32, qb: u32,
                 rows: u32, cols: u32)
    mut j = u32(0)
    while j < rows do
        mut base = wo + j * cols
        mut amax = f32(0.0)
        mut i = u32(0)
        while i < cols do
            mut a = abs(w[base + i])
            if a > amax then
                amax = a
            end
            i = i + u32(1)
        end
        mut sc = amax / 127.0
        if sc == 0.0 then
            sc = f32(1.0)
        end
        qs[qb + j] = sc
        mut inv = 1.0 / sc
        mut k = u32(0)
        while k < cols do
            w8[base + k] = i8(i32(round(w[base + k] * inv)))
            k = k + u32(1)
        end
        j = j + u32(1)
    end
end

I32_LIMIT = f32(2147483647.0)
W8_MAX = f32(127.0)
X16_MAX = f32(32767.0)

LM16_EXTRA = u32(4)

fn pack_dot2_head(w: f32[], hw: i8[], qs: f32[], sb: u32, wo: u32,
                  rows: u32, cols: u32) -> f32
    mut nvb = (rows + u32(7)) / u32(8) * u32(8)
    mut rmax = f32(1.0)
    mut wamax = f32(0.0)
    mut wsabs = f32(0.0)
    mut v = u32(0)
    while v < rows do
        mut amax = f32(0.0)
        mut sabs = f32(0.0)
        mut i = u32(0)
        while i < cols do
            mut a = abs(w[wo + v * cols + i])
            sabs = sabs + a
            if a > amax then
                amax = a
            end
            i = i + u32(1)
        end
        qs[sb + v] = amax
        qs[sb + nvb + LM16_EXTRA + v] = sabs
        if amax > f32(0.0) then
            mut r = sabs / amax
            if r > rmax then
                rmax = r
            end
        end
        if amax > wamax then
            wamax = amax
        end
        if sabs > wsabs then
            wsabs = sabs
        end
        v = v + u32(1)
    end
    mut m = W8_MAX
    mut pad = rows
    while pad < nvb do
        qs[sb + pad] = f32(1.0)
        qs[sb + nvb + LM16_EXTRA + pad] = f32(0.0)
        pad = pad + u32(1)
    end
    qs[sb + nvb] = wamax
    qs[sb + nvb + u32(1)] = wsabs
    qs[sb + nvb + u32(2)] = X16_MAX
    qs[sb + nvb + u32(3)] = W8_MAX

    mut np = cols / u32(2)
    mut nb = nvb / u32(8)
    mut jb = u32(0)
    while jb < nb do
        mut j = u32(0)
        while j < u32(8) do
            mut vv = jb * u32(8) + j
            mut have = vv < rows
            mut sc = qs[sb + vv] / m
            if sc == f32(0.0) then
                sc = f32(1.0)
            end
            qs[sb + vv] = sc
            mut inv = f32(1.0) / sc
            mut kp = u32(0)
            while kp < np do
                mut o = (jb * np + kp) * u32(16) + j * u32(2)
                mut lo = f32(0.0)
                mut hi = f32(0.0)
                if have then
                    lo = w[wo + vv * cols + kp * u32(2)]
                    hi = w[wo + vv * cols + kp * u32(2) + u32(1)]
                end
                hw[o] = i8(i32(round(lo * inv)))
                hw[o + u32(1)] = i8(i32(round(hi * inv)))
                kp = kp + u32(1)
            end
            j = j + u32(1)
        end
        jb = jb + u32(1)
    end
    return m
end

fn pack_act16(x: f32[], xo: u32, xw: i32[], n: u32, m: f32, out: f32[])
    mut amax = f32(0.0)
    mut sabs = f32(0.0)
    mut i = u32(0)
    while i < n do
        mut a = abs(x[xo + i])
        sabs = sabs + a
        if a > amax then
            amax = a
        end
        i = i + u32(1)
    end
    mut sc = amax / m
    if sc == f32(0.0) then
        sc = f32(1.0)
    end
    mut inv = f32(1.0) / sc
    mut np = n / u32(2)
    mut kp = u32(0)
    while kp < np do
        mut lo = i32(round(x[xo + kp * u32(2)] * inv))
        mut hi = i32(round(x[xo + kp * u32(2) + u32(1)] * inv))
        xw[kp] = (lo & i32(65535)) | ((hi & i32(65535)) << i32(16))
        kp = kp + u32(1)
    end
    out[u32(0)] = sc
    out[u32(1)] = sabs
end

pub fn head_dot2_pub(hw: i8[], qs: f32[], sb: u32, xw: i32[], sx: f32,
                     logits: f32[], rows: u32, cols: u32)
    head_dot2(hw, qs, sb, xw, sx, logits, rows, cols)
end

fn head_dot2(hw: i8[], qs: f32[], sb: u32, xw: i32[], sx: f32,
             logits: f32[], rows: u32, cols: u32)
    mut np = cols / u32(2)
    mut nb = rows / u32(8)
    mut ng = nb / u32(4)
    mut g = u32(0)
    while g < ng do
        mut a0 = simd[i32, 8](i32(0))
        mut a1 = simd[i32, 8](i32(0))
        mut a2 = simd[i32, 8](i32(0))
        mut a3 = simd[i32, 8](i32(0))
        mut o0 = g * u32(4) * np * u32(16)
        mut o1 = o0 + np * u32(16)
        mut o2 = o1 + np * u32(16)
        mut o3 = o2 + np * u32(16)
        mut sxv = simd[f32, 8](sx)
        mut kp = u32(0)
        while kp < np do
            mut xb = simd[i32, 8](xw[kp])
            a0 = dot2(xb, i16(simd[i8, 16](hw, o0)), a0)
            a1 = dot2(xb, i16(simd[i8, 16](hw, o1)), a1)
            a2 = dot2(xb, i16(simd[i8, 16](hw, o2)), a2)
            a3 = dot2(xb, i16(simd[i8, 16](hw, o3)), a3)
            o0 = o0 + u32(16)
            o1 = o1 + u32(16)
            o2 = o2 + u32(16)
            o3 = o3 + u32(16)
            kp = kp + u32(1)
        end
        store(logits, g * u32(32),
              f32(a0) * sxv * simd[f32, 8](qs, sb + g * u32(32)))
        store(logits, g * u32(32) + u32(8),
              f32(a1) * sxv * simd[f32, 8](qs, sb + g * u32(32) + u32(8)))
        store(logits, g * u32(32) + u32(16),
              f32(a2) * sxv * simd[f32, 8](qs, sb + g * u32(32) + u32(16)))
        store(logits, g * u32(32) + u32(24),
              f32(a3) * sxv * simd[f32, 8](qs, sb + g * u32(32) + u32(24)))
        g = g + u32(1)
    end
    mut jb = ng * u32(4)
    while jb < nb do
        mut c0 = simd[i32, 8](i32(0))
        mut q0 = jb * np * u32(16)
        mut sxv = simd[f32, 8](sx)
        mut k2 = u32(0)
        while k2 < np do
            c0 = dot2(simd[i32, 8](xw[k2]), i16(simd[i8, 16](hw, q0)), c0)
            q0 = q0 + u32(16)
            k2 = k2 + u32(1)
        end
        mut at2 = jb * u32(8)
        store(logits, at2, f32(c0) * sxv * simd[f32, 8](qs, sb + at2))
        jb = jb + u32(1)
    end
    mut v = nb * u32(8)
    while v < rows do
        mut acc = i32(0)
        mut kq = u32(0)
        while kq < np do
            mut pk = xw[kq]
            mut xl = (pk << i32(16)) >> i32(16)
            mut xh = pk >> i32(16)
            acc = acc + xl * i32(hw[(v / u32(8)) * np * u32(16)
                                   + kq * u32(16) + (v % u32(8)) * u32(2)])
                      + xh * i32(hw[(v / u32(8)) * np * u32(16)
                                   + kq * u32(16) + (v % u32(8)) * u32(2) + u32(1)])
            kq = kq + u32(1)
        end
        logits[v] = f32(acc) * sx * qs[sb + v]
        v = v + u32(1)
    end
end

fn argmax_exact(logits: f32[], w: f32[], wte: u32, h1: f32[], rows: u32,
                cols: u32, bound: f32, qs: f32[], sb: u32, nvb: u32,
                sumx: f32, sx: f32, stat: u32[]) -> u32
    mut best = logits[u32(0)]
    mut bi = u32(0)
    mut v = u32(1)
    while v < rows do
        if logits[v] > best then
            best = logits[v]
            bi = v
        end
        v = v + u32(1)
    end
    mut sbase = sb + nvb + LM16_EXTRA
    mut cut = best - (sumx * qs[sb + bi] + qs[sbase + bi] * sx) * f32(0.5)
    mut nres = u32(0)
    mut top = u32(0)
    mut topv = f32(-1.0e30)
    mut c = u32(0)
    while c < rows do
        if logits[c] + (sumx * qs[sb + c] + qs[sbase + c] * sx) * f32(0.5) >= cut then
            mut a0 = simd[f32, 8](f32(0.0))
            mut a1 = simd[f32, 8](f32(0.0))
            mut a2 = simd[f32, 8](f32(0.0))
            mut a3 = simd[f32, 8](f32(0.0))
            mut wb = wte + c * cols
            mut k = u32(0)
            while k < cols do
                a0 = fma(simd[f32, 8](h1, k), simd[f32, 8](w, wb + k), a0)
                a1 = fma(simd[f32, 8](h1, k + u32(8)),
                         simd[f32, 8](w, wb + k + u32(8)), a1)
                a2 = fma(simd[f32, 8](h1, k + u32(16)),
                         simd[f32, 8](w, wb + k + u32(16)), a2)
                a3 = fma(simd[f32, 8](h1, k + u32(24)),
                         simd[f32, 8](w, wb + k + u32(24)), a3)
                k = k + u32(32)
            end
            mut e = hsum(a0 + a1) + hsum(a2 + a3)
            logits[c] = e
            nres = nres + u32(1)
            if e > topv then
                topv = e
                top = c
            end
        end
        c = c + u32(1)
    end
    stat[u32(0)] = nres
    stat[u32(1)] = u32(i32((best - cut) * f32(1000.0)))
    return top
end

pub fn head_packsum(which: u32) -> u32
    mut rows = u32(24)
    mut cols = u32(64)
    mut w = array[f32](rows * cols)
    mut x = array[f32](cols)
    mut i = u32(0)
    while i < rows * cols do
        w[i] = f32(i32(i % u32(97))) * f32(0.031) - f32(1.5)
        i = i + u32(1)
    end
    mut k = u32(0)
    while k < cols do
        x[k] = f32(i32(k % u32(13))) * f32(0.17) - f32(1.1)
        k = k + u32(1)
    end
    mut nvb = (rows + u32(7)) / u32(8) * u32(8)
    mut hw = array[i8](nvb * cols)
    mut qs = array[f32]((nvb + LM16_EXTRA) * u32(2))
    mut m = pack_dot2_head(w, hw, qs, u32(0), u32(0), rows, cols)
    mut xw = array[i32](cols / u32(2))
    mut ai = array[f32](u32(2))
    pack_act16(x, u32(0), xw, cols, m, ai)
    mut sx = ai[u32(0)]
    if which == u32(0) then
        mut h = i32(0)
        mut j = u32(0)
        while j < nvb * cols do
            h = h * i32(31) + i32(hw[j])
            j = j + u32(1)
        end
        return u32(h)
    end
    if which == u32(1) then
        mut h2 = i32(0)
        mut j2 = u32(0)
        while j2 < cols / u32(2) do
            h2 = h2 * i32(31) + xw[j2]
            j2 = j2 + u32(1)
        end
        return u32(h2)
    end
    if which == u32(2) then
        return u32(i32(round(sx * f32(100000000.0))))
    end
    mut got = array[f32](rows)
    head_dot2(hw, qs, u32(0), xw, sx, got, rows, cols)
    mut acc = f64(0.0)
    mut v = u32(0)
    while v < rows do
        if which == u32(3) then
            acc = acc + f64(got[v]) * f64(i32(v) + i32(1))
        else
            mut r = f32(0.0)
            mut c = u32(0)
            while c < cols do
                r = r + x[c] * w[v * cols + c]
                c = c + u32(1)
            end
            acc = acc + f64(r) * f64(i32(v) + i32(1))
        end
        v = v + u32(1)
    end
    return u32(i32(round(f32(acc) * f32(1000.0))) + i32(1000000))
end

pub fn head_selftest(rows: u32) -> u32
    mut cols = u32(64)
    mut w = array[f32](rows * cols)
    mut x = array[f32](cols)
    mut i = u32(0)
    while i < rows * cols do
        w[i] = f32(i32(i % u32(97))) * f32(0.031) - f32(1.5)
        i = i + u32(1)
    end
    mut k = u32(0)
    while k < cols do
        x[k] = f32(i32(k % u32(13))) * f32(0.17) - f32(1.1)
        k = k + u32(1)
    end
    mut nvb = (rows + u32(7)) / u32(8) * u32(8)
    mut hw = array[i8](nvb * cols)
    mut qs = array[f32]((nvb + LM16_EXTRA) * u32(2))
    mut m = pack_dot2_head(w, hw, qs, u32(0), u32(0), rows, cols)
    mut xw = array[i32](cols / u32(2))
    mut ai = array[f32](u32(2))
    pack_act16(x, u32(0), xw, cols, m, ai)
    mut sx = ai[u32(0)]
    mut got = array[f32](rows)
    head_dot2(hw, qs, u32(0), xw, sx, got, rows, cols)
    mut worst = f32(0.0)
    mut scale = f32(0.0)
    mut v = u32(0)
    while v < rows do
        mut r = f32(0.0)
        mut c = u32(0)
        while c < cols do
            r = r + x[c] * w[v * cols + c]
            c = c + u32(1)
        end
        mut e = abs(r - got[v])
        if e > worst then
            worst = e
        end
        if abs(r) > scale then
            scale = abs(r)
        end
        v = v + u32(1)
    end
    if scale == f32(0.0) then
        scale = f32(1.0)
    end
    return u32(i32(round(worst / scale * f32(1000000.0))))
end

pub fn quantise(md: Model) -> Model
    mut n8 = len(md.w)
    mut w8 = array[i8](n8)
    mut total = u32(0)
    mut l = u32(0)
    while l < N_LAYER do
        mut sl = u32(0)
        while sl < PER_LAYER do
            mut od = slot_outdim(sl)
            if od > u32(0) then
                md.off[Q_BASE + l * PER_LAYER + sl] = total
                total = total + od
            end
            sl = sl + u32(1)
        end
        l = l + u32(1)
    end
    mut lmBase = total
    total = total + N_VOCAB
    mut lm16Base = total
    total = total + ((N_VOCAB + u32(7)) / u32(8) * u32(8) + LM16_EXTRA) * u32(2)
    mut qs = array[f32](total)
    mut csum = array[i32](total)
    mut amax = array[f32](u32(4) * N_EMBD)
    mut lmPack = n8
    mut wp = array[i8](n8 + (N_VOCAB + u32(7)) / u32(8) * (N_EMBD / u32(4)) * u32(32) + u32(64))
    mut l2 = u32(0)
    while l2 < N_LAYER do
        mut s2 = u32(0)
        while s2 < PER_LAYER do
            mut id = slot_indim(s2)
            mut od = slot_outdim(s2)
            if od > u32(0) then
                mut wo = md.off[l2 * PER_LAYER + s2]
                mut qb = md.off[Q_BASE + l2 * PER_LAYER + s2]
                quantise_one(md.w, w8, qs, amax, wo, qb, id, od)
                pack_dot4(w8, wp, csum, wo, qb, id, od)
            end
            s2 = s2 + u32(1)
        end
        l2 = l2 + u32(1)
    end
    quantise_rows(md.w, w8, qs, md.off[G_BASE + T_WTE], lmBase, N_VOCAB, N_EMBD)
    pack_dot4_at(w8, wp, csum, md.off[G_BASE + T_WTE], lmPack, lmBase, N_EMBD, N_VOCAB)
    md.off[G_BASE + T_LMQ_W] = lmPack
    md.off[G_BASE + T_LMQ_S] = lmBase
    mut nvb = (N_VOCAB + u32(7)) / u32(8) * u32(8)
    mut hw = array[i8](nvb * N_EMBD)
    pack_dot2_head(md.w, hw, qs, lm16Base, md.off[G_BASE + T_WTE],
                   N_VOCAB, N_EMBD)
    md.off[G_BASE + T_LM16_S] = lm16Base
    return Model(w: md.w, off: md.off,
                 w8: wp, qs: qs, csum: csum, hw: hw)
end

fn pack_dot4(w8: i8[], wp: i8[], csum: i32[], wo: u32, qb: u32,
             indim: u32, outdim: u32)
    pack_dot4_at(w8, wp, csum, wo, wo, qb, indim, outdim)
end

fn pack_dot4_at(w8: i8[], wp: i8[], csum: i32[], wo: u32, po: u32, qb: u32,
                indim: u32, outdim: u32)
    mut nw = indim / u32(4)
    mut nb = (outdim + u32(7)) / u32(8)
    mut jb = u32(0)
    while jb < nb do
        mut kw = u32(0)
        while kw < nw do
            mut ln = u32(0)
            while ln < u32(8) do
                mut col = jb * u32(8) + ln
                mut src = wo + col * indim + kw * u32(4)
                mut dst = po + (jb * nw + kw) * u32(32) + ln * u32(4)
                mut kk = u32(0)
                while kk < u32(4) do
                    if col < outdim then
                        wp[dst + kk] = w8[src + kk]
                    else
                        wp[dst + kk] = i8(0)
                    end
                    kk = kk + u32(1)
                end
                ln = ln + u32(1)
            end
            kw = kw + u32(1)
        end
        jb = jb + u32(1)
    end
    mut j = u32(0)
    while j < outdim do
        mut t = i32(0)
        mut i = u32(0)
        while i < indim do
            t = t + i32(w8[wo + j * indim + i])
            i = i + u32(1)
        end
        csum[qb + j] = t
        j = j + u32(1)
    end
end

fn pack_act(x: f32[], xo: u32, xw: u32[], wo: u32, n: u32) -> f32
    mut amax = f32(0.0)
    mut i = u32(0)
    while i < n do
        mut a = abs(x[xo + i])
        if a > amax then
            amax = a
        end
        i = i + u32(1)
    end
    mut sc = amax / 127.0
    if sc == 0.0 then
        sc = f32(1.0)
    end
    mut inv = 1.0 / sc
    mut w = u32(0)
    while w < n / u32(4) do
        mut b0 = u32(i32(round(x[xo + w * u32(4)] * inv)) + i32(128))
        mut b1 = u32(i32(round(x[xo + w * u32(4) + u32(1)] * inv)) + i32(128))
        mut b2 = u32(i32(round(x[xo + w * u32(4) + u32(2)] * inv)) + i32(128))
        mut b3 = u32(i32(round(x[xo + w * u32(4) + u32(3)] * inv)) + i32(128))
        xw[wo + w] = (b0 & u32(255)) | ((b1 & u32(255)) << u32(8))
                   | ((b2 & u32(255)) << u32(16)) | ((b3 & u32(255)) << u32(24))
        w = w + u32(1)
    end
    return sc
end

fn pack_pad(xw: u32[], wo: u32, n: u32)
    mut w = u32(0)
    while w < n / u32(4) do
        xw[wo + w] = u32(2155905152)
        w = w + u32(1)
    end
end

TOK = u32(5)

pub fn linear_dot4_pub(wp: i8[], qs: f32[], csum: i32[], wo: u32, qb: u32,
                       bias: f32[], bo: u32, xw: u32[], sx: f32[], t32: i32[],
                       y: f32[], yo: u32, ystride: u32, ntok: u32,
                       indim: u32, outdim: u32)
    linear_dot4(wp, qs, csum, wo, qb, bias, bo, xw, sx, t32, y, yo, ystride,
                ntok, indim, outdim)
end

fn linear_dot4(wp: i8[], qs: f32[], csum: i32[], wo: u32, qb: u32,
               bias: f32[], bo: u32, xw: u32[], sx: f32[], t32: i32[],
               y: f32[], yo: u32, ystride: u32, ntok: u32,
               indim: u32, outdim: u32)
    mut nw = indim / u32(4)
    mut nb = (outdim + u32(7)) / u32(8)
    mut ng = nb / u32(2)
    mut g = u32(0)
    while g < ng do
        mut a0_0 = simd[i32, 8](i32(0))
        mut a0_1 = simd[i32, 8](i32(0))
        mut a1_0 = simd[i32, 8](i32(0))
        mut a1_1 = simd[i32, 8](i32(0))
        mut a2_0 = simd[i32, 8](i32(0))
        mut a2_1 = simd[i32, 8](i32(0))
        mut a3_0 = simd[i32, 8](i32(0))
        mut a3_1 = simd[i32, 8](i32(0))
        mut a4_0 = simd[i32, 8](i32(0))
        mut a4_1 = simd[i32, 8](i32(0))
        mut p0 = wo + (g * u32(2) + u32(0)) * nw * u32(32)
        mut p1 = wo + (g * u32(2) + u32(1)) * nw * u32(32)
        mut kw = u32(0)
        while kw < nw do
            mut v0 = simd[i8, 32](wp, p0)
            mut v1 = simd[i8, 32](wp, p1)
            mut x0 = simd[u32, 8](xw[kw])
            a0_0 = dot4(x0, v0, a0_0)
            a0_1 = dot4(x0, v1, a0_1)
            mut x1 = simd[u32, 8](xw[nw * u32(1) + kw])
            a1_0 = dot4(x1, v0, a1_0)
            a1_1 = dot4(x1, v1, a1_1)
            mut x2 = simd[u32, 8](xw[nw * u32(2) + kw])
            a2_0 = dot4(x2, v0, a2_0)
            a2_1 = dot4(x2, v1, a2_1)
            mut x3 = simd[u32, 8](xw[nw * u32(3) + kw])
            a3_0 = dot4(x3, v0, a3_0)
            a3_1 = dot4(x3, v1, a3_1)
            mut x4 = simd[u32, 8](xw[nw * u32(4) + kw])
            a4_0 = dot4(x4, v0, a4_0)
            a4_1 = dot4(x4, v1, a4_1)
            p0 = p0 + u32(32)
            p1 = p1 + u32(32)
            kw = kw + u32(1)
        end
        store(t32, g * u32(80) + u32(0), a0_0)
        store(t32, g * u32(80) + u32(8), a0_1)
        store(t32, g * u32(80) + u32(16), a1_0)
        store(t32, g * u32(80) + u32(24), a1_1)
        store(t32, g * u32(80) + u32(32), a2_0)
        store(t32, g * u32(80) + u32(40), a2_1)
        store(t32, g * u32(80) + u32(48), a3_0)
        store(t32, g * u32(80) + u32(56), a3_1)
        store(t32, g * u32(80) + u32(64), a4_0)
        store(t32, g * u32(80) + u32(72), a4_1)
        g = g + u32(1)
    end
    mut jb = ng * u32(2)
    while jb < nb do
        mut c0 = simd[i32, 8](i32(0))
        mut c1 = simd[i32, 8](i32(0))
        mut c2 = simd[i32, 8](i32(0))
        mut c3 = simd[i32, 8](i32(0))
        mut c4 = simd[i32, 8](i32(0))
        mut q0 = wo + jb * nw * u32(32)
        mut k2 = u32(0)
        while k2 < nw do
            mut vv = simd[i8, 32](wp, q0)
            c0 = dot4(simd[u32, 8](xw[k2]), vv, c0)
            c1 = dot4(simd[u32, 8](xw[nw * u32(1) + k2]), vv, c1)
            c2 = dot4(simd[u32, 8](xw[nw * u32(2) + k2]), vv, c2)
            c3 = dot4(simd[u32, 8](xw[nw * u32(3) + k2]), vv, c3)
            c4 = dot4(simd[u32, 8](xw[nw * u32(4) + k2]), vv, c4)
            q0 = q0 + u32(32)
            k2 = k2 + u32(1)
        end
        store(t32, ng * u32(80) + (jb - ng * u32(2)) * u32(40) + u32(0), c0)
        store(t32, ng * u32(80) + (jb - ng * u32(2)) * u32(40) + u32(8), c1)
        store(t32, ng * u32(80) + (jb - ng * u32(2)) * u32(40) + u32(16), c2)
        store(t32, ng * u32(80) + (jb - ng * u32(2)) * u32(40) + u32(24), c3)
        store(t32, ng * u32(80) + (jb - ng * u32(2)) * u32(40) + u32(32), c4)
        jb = jb + u32(1)
    end
    mut t = u32(0)
    while t < ntok do
        mut yb = yo + t * ystride
        mut sxv = simd[f32, 8](sx[t])
        mut c128 = simd[i32, 8](i32(128))
        mut gg = u32(0)
        while gg < ng do
            mut bb = u32(0)
            while bb < u32(2) do
                mut jj = (gg * u32(2) + bb) * u32(8)
                mut at = gg * u32(80) + t * u32(16) + bb * u32(8)
                if jj + u32(8) <= outdim then
                    store(y, yb + jj,
                          simd[f32, 8](bias, bo + jj)
                          + f32(simd[i32, 8](t32, at)
                                - c128 * simd[i32, 8](csum, qb + jj))
                            * sxv * simd[f32, 8](qs, qb + jj))
                end
                bb = bb + u32(1)
            end
            gg = gg + u32(1)
        end
        mut jb2 = ng * u32(2)
        while jb2 < nb do
            mut j2 = jb2 * u32(8)
            mut a2 = ng * u32(80) + (jb2 - ng * u32(2)) * u32(40) + t * u32(8)
            mut e = u32(0)
            while e < u32(8) do
                if j2 + e < outdim then
                    y[yb + j2 + e] = bias[bo + j2 + e]
                                   + f32(t32[a2 + e] - i32(128) * csum[qb + j2 + e])
                                     * sx[t] * qs[qb + j2 + e]
                end
                e = e + u32(1)
            end
            jb2 = jb2 + u32(1)
        end
        t = t + u32(1)
    end
end

Q4_GROUP = u32(64)
Q4_KW = u32(16)
Q4_PAIRS = u32(8)
LOMASK = u32(252645135)

fn pack_q4(w: f32[], w4: u32[], qs4: f32[], wo: u32, po: u32, so: u32,
           sk: u32, indim: u32, outdim: u32)
    mut ng = (indim + Q4_GROUP - u32(1)) / Q4_GROUP
    mut nb = (outdim + u32(7)) / u32(8)
    mut jb = u32(0)
    while jb < nb do
        mut g = u32(0)
        while g < ng do
            mut L = u32(0)
            while L < u32(8) do
                mut col = jb * u32(8) + L
                mut amax = f32(0.0)
                mut kk = u32(0)
                while kk < Q4_GROUP do
                    mut k = g * Q4_GROUP + kk
                    if k < indim then
                        if col < outdim then
                            mut a = abs(w[wo + k * outdim + col])
                            if a > amax then
                                amax = a
                            end
                        end
                    end
                    kk = kk + u32(1)
                end
                mut sc = amax / f32(7.0)
                if sc == f32(0.0) then
                    sc = f32(1.0)
                end
                mut inv = f32(1.0) / sc
                mut sw = i32(0)
                mut p = u32(0)
                while p < Q4_PAIRS do
                    mut word = u32(0)
                    mut t = u32(0)
                    while t < u32(4) do
                        mut klo = g * Q4_GROUP + p * u32(2) + t * (Q4_GROUP / u32(4))
                        mut khi = klo + u32(1)
                        mut nlo = u32(8)
                        mut nhi = u32(8)
                        if klo < indim then
                            if col < outdim then
                                mut q = i32(round(w[wo + klo * outdim + col] * inv)) + i32(8)
                                if q < i32(0) then
                                    q = i32(0)
                                end
                                if q > i32(15) then
                                    q = i32(15)
                                end
                                nlo = u32(q)
                            end
                        end
                        if khi < indim then
                            if col < outdim then
                                mut q2 = i32(round(w[wo + khi * outdim + col] * inv)) + i32(8)
                                if q2 < i32(0) then
                                    q2 = i32(0)
                                end
                                if q2 > i32(15) then
                                    q2 = i32(15)
                                end
                                nhi = u32(q2)
                            end
                        end
                        sw = sw + i32(nlo) + i32(nhi)
                        word = word | ((nlo | (nhi << u32(4))) << (t * u32(8)))
                        t = t + u32(1)
                    end
                    w4[po + ((jb * ng + g) * Q4_PAIRS + p) * u32(8) + L] = word
                    p = p + u32(1)
                end
                qs4[so + (jb * ng + g) * u32(8) + L] = sc
                qs4[sk + (jb * ng + g) * u32(8) + L] =
                    (f32(65536.0) - f32(128.0) * f32(sw)) * sc
                L = L + u32(1)
            end
            g = g + u32(1)
        end
        jb = jb + u32(1)
    end
end

pub fn linear_q4_pub(w4: u32[], qs4: f32[], po: u32, so: u32, sk: u32,
                     bias: f32[], bo: u32, xw: u32[], sx: f32[], sxs: f32[],
                     fa: f32[], y: f32[], yo: u32, ystride: u32, ntok: u32,
                     indim: u32, outdim: u32)
    linear_q4(w4, qs4, po, so, sk, bias, bo, xw, sx, sxs, fa, y, yo, ystride,
              ntok, indim, outdim)
end

fn linear_q4(w4: u32[], qs4: f32[], po: u32, so: u32, sk: u32,
             bias: f32[], bo: u32, xw: u32[], sx: f32[], sxs: f32[],
             fa: f32[], y: f32[], yo: u32, ystride: u32, ntok: u32,
             indim: u32, outdim: u32)
    mut ng = (indim + Q4_GROUP - u32(1)) / Q4_GROUP
    mut nw = indim / u32(4)
    mut nb = (outdim + u32(7)) / u32(8)
    mut npair = nb / u32(2)
    mut pr = u32(0)
    while pr < npair do
        mut msk = simd[u32, 8](LOMASK)
            store(fa, pr * u32(80) + u32(0), simd[f32, 8](f32(0.0)))
            store(fa, pr * u32(80) + u32(8), simd[f32, 8](f32(0.0)))
            store(fa, pr * u32(80) + u32(16), simd[f32, 8](f32(0.0)))
            store(fa, pr * u32(80) + u32(24), simd[f32, 8](f32(0.0)))
            store(fa, pr * u32(80) + u32(32), simd[f32, 8](f32(0.0)))
            store(fa, pr * u32(80) + u32(40), simd[f32, 8](f32(0.0)))
            store(fa, pr * u32(80) + u32(48), simd[f32, 8](f32(0.0)))
            store(fa, pr * u32(80) + u32(56), simd[f32, 8](f32(0.0)))
            store(fa, pr * u32(80) + u32(64), simd[f32, 8](f32(0.0)))
            store(fa, pr * u32(80) + u32(72), simd[f32, 8](f32(0.0)))
        mut g = u32(0)
        while g < ng do
            mut a0 = simd[i32, 8](i32(0))
            mut a1 = simd[i32, 8](i32(0))
            mut a2 = simd[i32, 8](i32(0))
            mut a3 = simd[i32, 8](i32(0))
            mut a4 = simd[i32, 8](i32(0))
            mut b0 = simd[i32, 8](i32(0))
            mut b1 = simd[i32, 8](i32(0))
            mut b2 = simd[i32, 8](i32(0))
            mut b3 = simd[i32, 8](i32(0))
            mut b4 = simd[i32, 8](i32(0))
            mut base0 = po + ((pr * u32(2) * ng + g) * Q4_PAIRS) * u32(8)
            mut base1 = po + (((pr * u32(2) + u32(1)) * ng + g) * Q4_PAIRS) * u32(8)
            mut p = u32(0)
            while p < Q4_PAIRS do
                mut kwl = g * Q4_KW + p * u32(2)
                mut lo0 = simd[u32, 8](w4, base0 + p * u32(8)) & msk
                mut lo1 = simd[u32, 8](w4, base1 + p * u32(8)) & msk
                mut x0 = simd[u32, 8](xw[u32(0) + kwl])
                a0 = dot4(x0, lo0, a0)
                b0 = dot4(x0, lo1, b0)
                mut x1 = simd[u32, 8](xw[nw * u32(1) + kwl])
                a1 = dot4(x1, lo0, a1)
                b1 = dot4(x1, lo1, b1)
                mut x2 = simd[u32, 8](xw[nw * u32(2) + kwl])
                a2 = dot4(x2, lo0, a2)
                b2 = dot4(x2, lo1, b2)
                mut x3 = simd[u32, 8](xw[nw * u32(3) + kwl])
                a3 = dot4(x3, lo0, a3)
                b3 = dot4(x3, lo1, b3)
                mut x4 = simd[u32, 8](xw[nw * u32(4) + kwl])
                a4 = dot4(x4, lo0, a4)
                b4 = dot4(x4, lo1, b4)
                mut hi0 = (simd[u32, 8](w4, base0 + p * u32(8))
                           >> simd[u32, 8](u32(4))) & msk
                mut hi1 = (simd[u32, 8](w4, base1 + p * u32(8))
                           >> simd[u32, 8](u32(4))) & msk
                mut z0 = simd[u32, 8](xw[u32(0) + kwl + u32(1)])
                a0 = dot4(z0, hi0, a0)
                b0 = dot4(z0, hi1, b0)
                mut z1 = simd[u32, 8](xw[nw * u32(1) + kwl + u32(1)])
                a1 = dot4(z1, hi0, a1)
                b1 = dot4(z1, hi1, b1)
                mut z2 = simd[u32, 8](xw[nw * u32(2) + kwl + u32(1)])
                a2 = dot4(z2, hi0, a2)
                b2 = dot4(z2, hi1, b2)
                mut z3 = simd[u32, 8](xw[nw * u32(3) + kwl + u32(1)])
                a3 = dot4(z3, hi0, a3)
                b3 = dot4(z3, hi1, b3)
                mut z4 = simd[u32, 8](xw[nw * u32(4) + kwl + u32(1)])
                a4 = dot4(z4, hi0, a4)
                b4 = dot4(z4, hi1, b4)
                p = p + u32(1)
            end
            mut gb = (pr * u32(2) * ng + g) * u32(8)
            mut gb2 = ((pr * u32(2) + u32(1)) * ng + g) * u32(8)
            store(fa, pr * u32(80) + u32(0),
                  simd[f32, 8](fa, pr * u32(80) + u32(0))
                  + (f32(a0) - simd[f32, 8](f32(8.0) * sxs[0 * ng + g]))
                    * simd[f32, 8](sx[0]) * simd[f32, 8](qs4, so + gb)
                  + simd[f32, 8](sx[0]) * simd[f32, 8](qs4, sk + gb))
            store(fa, pr * u32(80) + u32(8),
                  simd[f32, 8](fa, pr * u32(80) + u32(8))
                  + (f32(b0) - simd[f32, 8](f32(8.0) * sxs[0 * ng + g]))
                    * simd[f32, 8](sx[0]) * simd[f32, 8](qs4, so + gb2)
                  + simd[f32, 8](sx[0]) * simd[f32, 8](qs4, sk + gb2))
            store(fa, pr * u32(80) + u32(16),
                  simd[f32, 8](fa, pr * u32(80) + u32(16))
                  + (f32(a1) - simd[f32, 8](f32(8.0) * sxs[1 * ng + g]))
                    * simd[f32, 8](sx[1]) * simd[f32, 8](qs4, so + gb)
                  + simd[f32, 8](sx[1]) * simd[f32, 8](qs4, sk + gb))
            store(fa, pr * u32(80) + u32(24),
                  simd[f32, 8](fa, pr * u32(80) + u32(24))
                  + (f32(b1) - simd[f32, 8](f32(8.0) * sxs[1 * ng + g]))
                    * simd[f32, 8](sx[1]) * simd[f32, 8](qs4, so + gb2)
                  + simd[f32, 8](sx[1]) * simd[f32, 8](qs4, sk + gb2))
            store(fa, pr * u32(80) + u32(32),
                  simd[f32, 8](fa, pr * u32(80) + u32(32))
                  + (f32(a2) - simd[f32, 8](f32(8.0) * sxs[2 * ng + g]))
                    * simd[f32, 8](sx[2]) * simd[f32, 8](qs4, so + gb)
                  + simd[f32, 8](sx[2]) * simd[f32, 8](qs4, sk + gb))
            store(fa, pr * u32(80) + u32(40),
                  simd[f32, 8](fa, pr * u32(80) + u32(40))
                  + (f32(b2) - simd[f32, 8](f32(8.0) * sxs[2 * ng + g]))
                    * simd[f32, 8](sx[2]) * simd[f32, 8](qs4, so + gb2)
                  + simd[f32, 8](sx[2]) * simd[f32, 8](qs4, sk + gb2))
            store(fa, pr * u32(80) + u32(48),
                  simd[f32, 8](fa, pr * u32(80) + u32(48))
                  + (f32(a3) - simd[f32, 8](f32(8.0) * sxs[3 * ng + g]))
                    * simd[f32, 8](sx[3]) * simd[f32, 8](qs4, so + gb)
                  + simd[f32, 8](sx[3]) * simd[f32, 8](qs4, sk + gb))
            store(fa, pr * u32(80) + u32(56),
                  simd[f32, 8](fa, pr * u32(80) + u32(56))
                  + (f32(b3) - simd[f32, 8](f32(8.0) * sxs[3 * ng + g]))
                    * simd[f32, 8](sx[3]) * simd[f32, 8](qs4, so + gb2)
                  + simd[f32, 8](sx[3]) * simd[f32, 8](qs4, sk + gb2))
            store(fa, pr * u32(80) + u32(64),
                  simd[f32, 8](fa, pr * u32(80) + u32(64))
                  + (f32(a4) - simd[f32, 8](f32(8.0) * sxs[4 * ng + g]))
                    * simd[f32, 8](sx[4]) * simd[f32, 8](qs4, so + gb)
                  + simd[f32, 8](sx[4]) * simd[f32, 8](qs4, sk + gb))
            store(fa, pr * u32(80) + u32(72),
                  simd[f32, 8](fa, pr * u32(80) + u32(72))
                  + (f32(b4) - simd[f32, 8](f32(8.0) * sxs[4 * ng + g]))
                    * simd[f32, 8](sx[4]) * simd[f32, 8](qs4, so + gb2)
                  + simd[f32, 8](sx[4]) * simd[f32, 8](qs4, sk + gb2))
            g = g + u32(1)
        end
        pr = pr + u32(1)
    end
    mut t = u32(0)
    while t < ntok do
        mut q = u32(0)
        while q < npair do
            store(y, yo + t * ystride + q * u32(16),
                  simd[f32, 8](bias, bo + q * u32(16))
                  + simd[f32, 8](fa, q * u32(80) + t * u32(16)))
            store(y, yo + t * ystride + q * u32(16) + u32(8),
                  simd[f32, 8](bias, bo + q * u32(16) + u32(8))
                  + simd[f32, 8](fa, q * u32(80) + t * u32(16) + u32(8)))
            q = q + u32(1)
        end
        t = t + u32(1)
    end
end

pub fn pack_act_q4_pub(x: f32[], xo: u32, xw: u32[], wo: u32, sxs: f32[],
                       so: u32, n: u32) -> f32
    return pack_act_q4(x, xo, xw, wo, sxs, so, n)
end

fn pack_act_q4(x: f32[], xo: u32, xw: u32[], wo: u32, sxs: f32[], so: u32,
               n: u32) -> f32
    mut amax = f32(0.0)
    mut i = u32(0)
    while i < n do
        mut a = abs(x[xo + i])
        if a > amax then
            amax = a
        end
        i = i + u32(1)
    end
    mut sc = amax / 127.0
    if sc == 0.0 then
        sc = f32(1.0)
    end
    mut ng = (n + Q4_GROUP - u32(1)) / Q4_GROUP
    mut wpg = Q4_GROUP / u32(4)
    mut lanes = array[i32](u32(8))
    mut g = u32(0)
    while g < ng do
        mut invv = simd[f32, 8](f32(1.0) / sc)
        mut c128 = simd[i32, 8](i32(128))
        mut bytemask = simd[i32, 8](i32(255))
        mut tot = simd[i32, 8](i32(0))
        mut base = xo + g * Q4_GROUP
        mut m = u32(0)
        while m < wpg do
            mut v0 = i32(round(simd[f32, 8](x, base + m) * invv)) + c128
            mut v1 = i32(round(simd[f32, 8](x, base + m + wpg) * invv)) + c128
            mut v2 = i32(round(simd[f32, 8](x, base + m + wpg * u32(2)) * invv)) + c128
            mut v3 = i32(round(simd[f32, 8](x, base + m + wpg * u32(3)) * invv)) + c128
            v0 = min(max(v0, simd[i32, 8](i32(0))), bytemask)
            v1 = min(max(v1, simd[i32, 8](i32(0))), bytemask)
            v2 = min(max(v2, simd[i32, 8](i32(0))), bytemask)
            v3 = min(max(v3, simd[i32, 8](i32(0))), bytemask)
            tot = tot + v0 + v1 + v2 + v3
            store(xw, wo + g * wpg + m,
                  u32(v0) | (u32(v1) << simd[u32, 8](u32(8)))
                          | (u32(v2) << simd[u32, 8](u32(16)))
                          | (u32(v3) << simd[u32, 8](u32(24))))
            m = m + u32(8)
        end
        store(lanes, u32(0), tot)
        mut s2 = i32(0)
        mut q = u32(0)
        while q < u32(8) do
            s2 = s2 + lanes[q]
            q = q + u32(1)
        end
        sxs[so + g] = f32(s2)
        g = g + u32(1)
    end
    return sc
end

pub fn q4_selftest(n: u32) -> u32
    mut indim = u32(128)
    mut outdim = u32(16)
    mut ntok = u32(5)
    mut w = array[f32](indim * outdim)
    mut i = u32(0)
    while i < indim * outdim do
        w[i] = f32(i32((i * u32(37) + n) % u32(211))) * f32(0.003) - f32(0.31)
        i = i + u32(1)
    end
    mut x = array[f32](ntok * indim)
    mut k = u32(0)
    while k < ntok * indim do
        x[k] = f32(i32((k * u32(53) + n) % u32(101))) * f32(0.02) - f32(1.0)
        k = k + u32(1)
    end
    mut ng = (indim + Q4_GROUP - u32(1)) / Q4_GROUP
    mut nb = (outdim + u32(7)) / u32(8)
    mut w4 = array[u32](nb * ng * Q4_PAIRS * u32(8))
    mut qs4 = array[f32](nb * ng * u32(16))
    pack_q4(w, w4, qs4, u32(0), u32(0), u32(0), nb * ng * u32(8), indim, outdim)
    mut xw = array[u32](ntok * indim / u32(4))
    mut sx = array[f32](ntok)
    mut sxs = array[f32](ntok * ng)
    mut t = u32(0)
    while t < ntok do
        sx[t] = pack_act_q4(x, t * indim, xw, t * indim / u32(4), sxs, t * ng, indim)
        t = t + u32(1)
    end
    mut bias = array[f32](outdim)
    mut y = array[f32](ntok * outdim)
    mut fa = array[f32](nb / u32(2) * ntok * u32(16) + u32(64))
    linear_q4(w4, qs4, u32(0), u32(0), nb * ng * u32(8), bias, u32(0),
              xw, sx, sxs, fa, y, u32(0), outdim, ntok, indim, outdim)
    mut worst = f64(0.0)
    mut scale = f64(0.0)
    mut tt = u32(0)
    while tt < ntok do
        mut j = u32(0)
        while j < outdim do
            mut r = f64(0.0)
            mut c = u32(0)
            while c < indim do
                r = r + f64(x[tt * indim + c]) * f64(w[c * outdim + j])
                c = c + u32(1)
            end
            mut e = abs(r - f64(y[tt * outdim + j]))
            if e > worst then
                worst = e
            end
            if abs(r) > scale then
                scale = abs(r)
            end
            j = j + u32(1)
        end
        tt = tt + u32(1)
    end
    if scale == f64(0.0) then
        scale = f64(1.0)
    end
    return u32(i32(worst / scale * f64(1000000.0)))
end

pub type Q4Model
    w: f32[]
    mut off: u32[]
    w4: u32[]
    qs4: f32[]
    hw: i8[]
    qs: f32[]
end

fn q4_words(indim: u32, outdim: u32) -> u32
    mut ng = (indim + Q4_GROUP - u32(1)) / Q4_GROUP
    mut nb = (outdim + u32(7)) / u32(8)
    return nb * ng * Q4_PAIRS * u32(8)
end

pub fn quantise_q4(md: Model) -> Q4Model
    mut total = u32(0)
    mut l = u32(0)
    while l < N_LAYER do
        mut sl = u32(0)
        while sl < PER_LAYER do
            mut id = slot_indim(sl)
            mut od = slot_outdim(sl)
            if od > u32(0) then
                md.off[Q_BASE + l * PER_LAYER + sl] = total
                total = total + q4_words(id, od)
            end
            sl = sl + u32(1)
        end
        l = l + u32(1)
    end
    md.off[G_BASE + T_Q4_TOT] = total
    mut w4 = array[u32](total)
    mut qs4 = array[f32](total / Q4_PAIRS * u32(2))
    mut l2 = u32(0)
    while l2 < N_LAYER do
        mut s2 = u32(0)
        while s2 < PER_LAYER do
            mut id2 = slot_indim(s2)
            mut od2 = slot_outdim(s2)
            if od2 > u32(0) then
                mut po = md.off[Q_BASE + l2 * PER_LAYER + s2]
                pack_q4(md.w, w4, qs4, md.off[l2 * PER_LAYER + s2], po,
                        po / Q4_PAIRS, total / Q4_PAIRS + po / Q4_PAIRS, id2, od2)
            end
            s2 = s2 + u32(1)
        end
        l2 = l2 + u32(1)
    end
    return Q4Model(w: md.w, off: md.off, w4: w4, qs4: qs4, hw: md.hw, qs: md.qs)
end

fn linear_prefill(wp: i8[], qs: f32[], csum: i32[], wo: u32, qb: u32,
                  bias: f32[], bo: u32, xw: u32[], sx: f32[], t32: i32[],
                  y: f32[], yo: u32, ystride: u32, ntok: u32,
                  indim: u32, outdim: u32)
    mut nw = indim / u32(4)
    mut nb = (outdim + u32(7)) / u32(8)
    mut npair = nb / u32(2)
    mut ngroup = (ntok + TOK - u32(1)) / TOK
    mut pr = u32(0)
    while pr < npair do
        mut g = u32(0)
        while g < ngroup do
            mut gb = g * TOK
            mut a0 = simd[i32, 8](i32(0))
            mut a1 = simd[i32, 8](i32(0))
            mut a2 = simd[i32, 8](i32(0))
            mut a3 = simd[i32, 8](i32(0))
            mut a4 = simd[i32, 8](i32(0))
            mut b0 = simd[i32, 8](i32(0))
            mut b1 = simd[i32, 8](i32(0))
            mut b2 = simd[i32, 8](i32(0))
            mut b3 = simd[i32, 8](i32(0))
            mut b4 = simd[i32, 8](i32(0))
            mut p0 = wo + pr * u32(2) * nw * u32(32)
            mut p1 = p0 + nw * u32(32)
            mut kw = u32(0)
            while kw < nw do
                mut v0 = simd[i8, 32](wp, p0)
                mut v1 = simd[i8, 32](wp, p1)
                mut x0 = simd[u32, 8](xw[(gb + u32(0)) * nw + kw])
                a0 = dot4(x0, v0, a0)
                b0 = dot4(x0, v1, b0)
                mut x1 = simd[u32, 8](xw[(gb + u32(1)) * nw + kw])
                a1 = dot4(x1, v0, a1)
                b1 = dot4(x1, v1, b1)
                mut x2 = simd[u32, 8](xw[(gb + u32(2)) * nw + kw])
                a2 = dot4(x2, v0, a2)
                b2 = dot4(x2, v1, b2)
                mut x3 = simd[u32, 8](xw[(gb + u32(3)) * nw + kw])
                a3 = dot4(x3, v0, a3)
                b3 = dot4(x3, v1, b3)
                mut x4 = simd[u32, 8](xw[(gb + u32(4)) * nw + kw])
                a4 = dot4(x4, v0, a4)
                b4 = dot4(x4, v1, b4)
                p0 = p0 + u32(32)
                p1 = p1 + u32(32)
                kw = kw + u32(1)
            end
            store(t32, (pr * ngroup + g) * u32(80) + u32(0), a0)
            store(t32, (pr * ngroup + g) * u32(80) + u32(8), b0)
            store(t32, (pr * ngroup + g) * u32(80) + u32(16), a1)
            store(t32, (pr * ngroup + g) * u32(80) + u32(24), b1)
            store(t32, (pr * ngroup + g) * u32(80) + u32(32), a2)
            store(t32, (pr * ngroup + g) * u32(80) + u32(40), b2)
            store(t32, (pr * ngroup + g) * u32(80) + u32(48), a3)
            store(t32, (pr * ngroup + g) * u32(80) + u32(56), b3)
            store(t32, (pr * ngroup + g) * u32(80) + u32(64), a4)
            store(t32, (pr * ngroup + g) * u32(80) + u32(72), b4)
            g = g + u32(1)
        end
        pr = pr + u32(1)
    end
    mut q = u32(0)
    while q < npair do
        mut t = u32(0)
        while t < ntok do
            mut r = u32(0)
            while r < u32(16) do
                mut j = q * u32(16) + r
                if j < outdim then
                    y[yo + t * ystride + j] = bias[bo + j]
                        + f32(t32[(q * ngroup + t / TOK) * u32(80) + (t % TOK) * u32(16) + r]
                              - i32(128) * csum[qb + j]) * sx[t] * qs[qb + j]
                end
                r = r + u32(1)
            end
            t = t + u32(1)
        end
        q = q + u32(1)
    end
    mut jb = npair * u32(2)
    while jb < nb do
        mut tt = u32(0)
        while tt < ntok do
            mut e = u32(0)
            while e < u32(8) do
                mut jj = jb * u32(8) + e
                if jj < outdim then
                    mut s2 = i32(0)
                    mut k2 = u32(0)
                    while k2 < nw do
                        mut pk = xw[tt * nw + k2]
                        mut wb = wo + jb * nw * u32(32) + k2 * u32(32) + e * u32(4)
                        mut c = u32(0)
                        while c < u32(4) do
                            s2 = s2 + i32((pk >> (c * u32(8))) & u32(255))
                                    * i32(wp[wb + c])
                            c = c + u32(1)
                        end
                        k2 = k2 + u32(1)
                    end
                    y[yo + tt * ystride + jj] = bias[bo + jj]
                        + f32(s2 - i32(128) * csum[qb + jj]) * sx[tt] * qs[qb + jj]
                end
                e = e + u32(1)
            end
            tt = tt + u32(1)
        end
        jb = jb + u32(1)
    end
end

fn pack_all(src: f32[], stride: u32, xw: u32[], sx: f32[], n: u32, dim: u32)
    mut nw = dim / u32(4)
    mut t = u32(0)
    while t < n do
        sx[t] = pack_act(src, t * stride, xw, t * nw, dim)
        t = t + u32(1)
    end
    mut ng = (n + TOK - u32(1)) / TOK
    while t < ng * TOK do
        pack_pad(xw, t * nw, dim)
        sx[t] = f32(1.0)
        t = t + u32(1)
    end
end

fn fill_group(src: f32[], stride: u32, xw: u32[], sx: f32[],
              g: u32, n: u32, dim: u32) -> u32
    mut nw = dim / u32(4)
    mut nt = u32(0)
    mut t = u32(0)
    while t < TOK do
        if g + t < n then
            sx[t] = pack_act(src, (g + t) * stride, xw, t * nw, dim)
            nt = nt + u32(1)
        else
            pack_pad(xw, t * nw, dim)
            sx[t] = f32(1.0)
        end
        t = t + u32(1)
    end
    return nt
end

fn fill_group_q4(src: f32[], stride: u32, xw: u32[], sx: f32[], sxs: f32[],
                 g: u32, n: u32, dim: u32) -> u32
    mut nw = dim / u32(4)
    mut ng = (dim + Q4_GROUP - u32(1)) / Q4_GROUP
    mut nt = u32(0)
    mut t = u32(0)
    while t < TOK do
        if g + t < n then
            sx[t] = pack_act_q4(src, (g + t) * stride, xw, t * nw, sxs, t * ng, dim)
            nt = nt + u32(1)
        else
            pack_pad(xw, t * nw, dim)
            sx[t] = f32(1.0)
            mut q = u32(0)
            while q < ng do
                sxs[t * ng + q] = f32(128.0) * f32(i32(Q4_GROUP))
                q = q + u32(1)
            end
        end
        t = t + u32(1)
    end
    return nt
end

pub fn forward_dot4(md: Model, ids: u32[], n: u32, logits: f32[]) -> u32
    if len(md.w8) == u32(0) then
        return u32(0)
    end
    mut x = array[f32](n * N_EMBD)
    mut h1 = array[f32](n * N_EMBD)
    mut qkv = array[f32](n * u32(3) * N_EMBD)
    mut att = array[f32](n * N_EMBD)
    mut ff = array[f32](n * u32(4) * N_EMBD)
    mut buf = array[f32](n)
    mut xw = array[u32](TOK * N_EMBD * u32(2))
    mut sx = array[f32](TOK)
    mut t32 = array[i32](TOK * u32(4) * N_EMBD + TOK * u32(8))

    mut t = u32(0)
    while t < n do
        mut e = md.off[G_BASE + T_WTE] + ids[t] * N_EMBD
        mut pp = md.off[G_BASE + T_WPE] + t * N_EMBD
        mut c = u32(0)
        while c < N_EMBD do
            x[t * N_EMBD + c] = md.w[e + c] + md.w[pp + c]
            c = c + u32(1)
        end
        t = t + u32(1)
    end

    mut l = u32(0)
    while l < N_LAYER do
        mut b = l * PER_LAYER

        mut i = u32(0)
        while i < n do
            layernorm_at(md.w, md.off[b + T_LN1_W], md.off[b + T_LN1_B],
                         x, i * N_EMBD, h1, i * N_EMBD, N_EMBD)
            i = i + u32(1)
        end
        mut g = u32(0)
        while g < n do
            mut nt = fill_group(h1, N_EMBD, xw, sx, g, n, N_EMBD)
            linear_dot4(md.w8, md.qs, md.csum,
                        md.off[b + T_ATTN_W], md.off[Q_BASE + b + T_ATTN_W],
                        md.w, md.off[b + T_ATTN_B], xw, sx, t32,
                        qkv, g * u32(3) * N_EMBD, u32(3) * N_EMBD, nt,
                        N_EMBD, u32(3) * N_EMBD)
            g = g + TOK
        end

        mut hh = u32(0)
        while hh < N_HEAD do
            head(qkv, att, buf, hh, n)
            hh = hh + u32(1)
        end

        mut g2 = u32(0)
        while g2 < n do
            mut nt2 = fill_group(att, N_EMBD, xw, sx, g2, n, N_EMBD)
            linear_dot4(md.w8, md.qs, md.csum,
                        md.off[b + T_APROJ_W], md.off[Q_BASE + b + T_APROJ_W],
                        md.w, md.off[b + T_APROJ_B], xw, sx, t32,
                        h1, g2 * N_EMBD, N_EMBD, nt2, N_EMBD, N_EMBD)
            g2 = g2 + TOK
        end
        mut j = u32(0)
        while j < n * N_EMBD do
            x[j] = x[j] + h1[j]
            j = j + u32(1)
        end

        mut k = u32(0)
        while k < n do
            layernorm_at(md.w, md.off[b + T_LN2_W], md.off[b + T_LN2_B],
                         x, k * N_EMBD, h1, k * N_EMBD, N_EMBD)
            k = k + u32(1)
        end
        mut g3 = u32(0)
        while g3 < n do
            mut nt3 = fill_group(h1, N_EMBD, xw, sx, g3, n, N_EMBD)
            linear_dot4(md.w8, md.qs, md.csum,
                        md.off[b + T_FC_W], md.off[Q_BASE + b + T_FC_W],
                        md.w, md.off[b + T_FC_B], xw, sx, t32,
                        ff, g3 * u32(4) * N_EMBD, u32(4) * N_EMBD, nt3,
                        N_EMBD, u32(4) * N_EMBD)
            g3 = g3 + TOK
        end
        mut ggn = n * u32(4) * N_EMBD
        mut gg = u32(0)
        while gg + u32(8) <= ggn do
            store(ff, gg, vv.geluv(simd[f32, 8](ff, gg)))
            gg = gg + u32(8)
        end
        mut g4 = u32(0)
        while g4 < n do
            mut nt4 = fill_group(ff, u32(4) * N_EMBD, xw, sx, g4, n, u32(4) * N_EMBD)
            linear_dot4(md.w8, md.qs, md.csum,
                        md.off[b + T_PROJ_W], md.off[Q_BASE + b + T_PROJ_W],
                        md.w, md.off[b + T_PROJ_B], xw, sx, t32,
                        h1, g4 * N_EMBD, N_EMBD, nt4, u32(4) * N_EMBD, N_EMBD)
            g4 = g4 + TOK
        end
        mut j2 = u32(0)
        while j2 < n * N_EMBD do
            x[j2] = x[j2] + h1[j2]
            j2 = j2 + u32(1)
        end

        l = l + u32(1)
    end

    mut last = (n - u32(1)) * N_EMBD
    layernorm_at(md.w, md.off[G_BASE + T_LNF_W], md.off[G_BASE + T_LNF_B],
                 x, last, h1, u32(0), N_EMBD)
    mut v = u32(0)
    while v < N_VOCAB do
        mut a0 = simd[f32, 8](f32(0.0))
        mut a1 = simd[f32, 8](f32(0.0))
        mut a2 = simd[f32, 8](f32(0.0))
        mut a3 = simd[f32, 8](f32(0.0))
        mut wbase = md.off[G_BASE + T_WTE] + v * N_EMBD
        mut c4 = u32(0)
        while c4 < N_EMBD do
            a0 = fma(simd[f32, 8](h1, c4), simd[f32, 8](md.w, wbase + c4), a0)
            a1 = fma(simd[f32, 8](h1, c4 + u32(8)),
                     simd[f32, 8](md.w, wbase + c4 + u32(8)), a1)
            a2 = fma(simd[f32, 8](h1, c4 + u32(16)),
                     simd[f32, 8](md.w, wbase + c4 + u32(16)), a2)
            a3 = fma(simd[f32, 8](h1, c4 + u32(24)),
                     simd[f32, 8](md.w, wbase + c4 + u32(24)), a3)
            c4 = c4 + u32(32)
        end
        logits[v] = hsum(a0 + a1) + hsum(a2 + a3)
        v = v + u32(1)
    end
    return op.argmax(logits, N_VOCAB)
end

pub fn forward_dot4_i16(md: Model, ids: u32[], n: u32, logits: f32[]) -> u32
    if len(md.w8) == u32(0) then
        return u32(0)
    end
    mut x = array[f32](n * N_EMBD)
    mut h1 = array[f32](n * N_EMBD)
    mut qkv = array[f32](n * u32(3) * N_EMBD)
    mut att = array[f32](n * N_EMBD)
    mut ff = array[f32](n * u32(4) * N_EMBD)
    mut buf = array[f32](n)
    mut xw = array[u32](TOK * N_EMBD * u32(2))
    mut sx = array[f32](TOK)
    mut t32 = array[i32](TOK * u32(4) * N_EMBD + TOK * u32(8))

    mut t = u32(0)
    while t < n do
        mut e = md.off[G_BASE + T_WTE] + ids[t] * N_EMBD
        mut pp = md.off[G_BASE + T_WPE] + t * N_EMBD
        mut c = u32(0)
        while c < N_EMBD do
            x[t * N_EMBD + c] = md.w[e + c] + md.w[pp + c]
            c = c + u32(1)
        end
        t = t + u32(1)
    end

    mut l = u32(0)
    while l < N_LAYER do
        mut b = l * PER_LAYER

        mut i = u32(0)
        while i < n do
            layernorm_at(md.w, md.off[b + T_LN1_W], md.off[b + T_LN1_B],
                         x, i * N_EMBD, h1, i * N_EMBD, N_EMBD)
            i = i + u32(1)
        end
        mut g = u32(0)
        while g < n do
            mut nt = fill_group(h1, N_EMBD, xw, sx, g, n, N_EMBD)
            linear_dot4(md.w8, md.qs, md.csum,
                        md.off[b + T_ATTN_W], md.off[Q_BASE + b + T_ATTN_W],
                        md.w, md.off[b + T_ATTN_B], xw, sx, t32,
                        qkv, g * u32(3) * N_EMBD, u32(3) * N_EMBD, nt,
                        N_EMBD, u32(3) * N_EMBD)
            g = g + TOK
        end

        mut hh = u32(0)
        while hh < N_HEAD do
            head(qkv, att, buf, hh, n)
            hh = hh + u32(1)
        end

        mut g2 = u32(0)
        while g2 < n do
            mut nt2 = fill_group(att, N_EMBD, xw, sx, g2, n, N_EMBD)
            linear_dot4(md.w8, md.qs, md.csum,
                        md.off[b + T_APROJ_W], md.off[Q_BASE + b + T_APROJ_W],
                        md.w, md.off[b + T_APROJ_B], xw, sx, t32,
                        h1, g2 * N_EMBD, N_EMBD, nt2, N_EMBD, N_EMBD)
            g2 = g2 + TOK
        end
        mut j = u32(0)
        while j < n * N_EMBD do
            x[j] = x[j] + h1[j]
            j = j + u32(1)
        end

        mut k = u32(0)
        while k < n do
            layernorm_at(md.w, md.off[b + T_LN2_W], md.off[b + T_LN2_B],
                         x, k * N_EMBD, h1, k * N_EMBD, N_EMBD)
            k = k + u32(1)
        end
        mut g3 = u32(0)
        while g3 < n do
            mut nt3 = fill_group(h1, N_EMBD, xw, sx, g3, n, N_EMBD)
            linear_dot4(md.w8, md.qs, md.csum,
                        md.off[b + T_FC_W], md.off[Q_BASE + b + T_FC_W],
                        md.w, md.off[b + T_FC_B], xw, sx, t32,
                        ff, g3 * u32(4) * N_EMBD, u32(4) * N_EMBD, nt3,
                        N_EMBD, u32(4) * N_EMBD)
            g3 = g3 + TOK
        end
        mut ggn = n * u32(4) * N_EMBD
        mut gg = u32(0)
        while gg + u32(8) <= ggn do
            store(ff, gg, vv.geluv(simd[f32, 8](ff, gg)))
            gg = gg + u32(8)
        end
        mut g4 = u32(0)
        while g4 < n do
            mut nt4 = fill_group(ff, u32(4) * N_EMBD, xw, sx, g4, n, u32(4) * N_EMBD)
            linear_dot4(md.w8, md.qs, md.csum,
                        md.off[b + T_PROJ_W], md.off[Q_BASE + b + T_PROJ_W],
                        md.w, md.off[b + T_PROJ_B], xw, sx, t32,
                        h1, g4 * N_EMBD, N_EMBD, nt4, u32(4) * N_EMBD, N_EMBD)
            g4 = g4 + TOK
        end
        mut j2 = u32(0)
        while j2 < n * N_EMBD do
            x[j2] = x[j2] + h1[j2]
            j2 = j2 + u32(1)
        end

        l = l + u32(1)
    end

    mut last = (n - u32(1)) * N_EMBD
    layernorm_at(md.w, md.off[G_BASE + T_LNF_W], md.off[G_BASE + T_LNF_B],
                 x, last, h1, u32(0), N_EMBD)
    mut sb = md.off[G_BASE + T_LM16_S]
    mut nvb = (N_VOCAB + u32(7)) / u32(8) * u32(8)
    mut m16 = md.qs[sb + nvb + u32(2)]
    mut xw16 = array[i32](N_EMBD / u32(2))
    mut ai = array[f32](u32(2))
    pack_act16(h1, u32(0), xw16, N_EMBD, m16, ai)
    head_dot2(md.hw, md.qs, sb, xw16, ai[u32(0)], logits, N_VOCAB, N_EMBD)
    mut bound = (ai[u32(1)] * md.qs[sb + nvb] / md.qs[sb + nvb + u32(3)]
               + md.qs[sb + nvb + u32(1)] * ai[u32(0)]) * f32(0.5)
    return argmax_exact(logits, md.w, md.off[G_BASE + T_WTE], h1,
                        N_VOCAB, N_EMBD, bound, md.qs, sb, nvb,
                        ai[u32(1)], ai[u32(0)], array[u32](u32(2)))
end

pub fn forward_prefill(md: Model, ids: u32[], n: u32, logits: f32[]) -> u32
    if len(md.w8) == u32(0) then
        return u32(0)
    end
    mut x = array[f32](n * N_EMBD)
    mut h1 = array[f32](n * N_EMBD)
    mut qkv = array[f32](n * u32(3) * N_EMBD)
    mut att = array[f32](n * N_EMBD)
    mut ff = array[f32](n * u32(4) * N_EMBD)
    mut buf = array[f32](n)
    mut ngrp = (n + TOK - u32(1)) / TOK
    mut xw = array[u32](ngrp * TOK * u32(4) * N_EMBD / u32(4) + u32(64))
    mut sx = array[f32](ngrp * TOK + u32(8))
    mut t32 = array[i32](ngrp * TOK * u32(4) * N_EMBD + u32(1024))

    mut t = u32(0)
    while t < n do
        mut e = md.off[G_BASE + T_WTE] + ids[t] * N_EMBD
        mut pp = md.off[G_BASE + T_WPE] + t * N_EMBD
        mut c = u32(0)
        while c < N_EMBD do
            x[t * N_EMBD + c] = md.w[e + c] + md.w[pp + c]
            c = c + u32(1)
        end
        t = t + u32(1)
    end

    mut l = u32(0)
    while l < N_LAYER do
        mut b = l * PER_LAYER

        mut i = u32(0)
        while i < n do
            layernorm_at(md.w, md.off[b + T_LN1_W], md.off[b + T_LN1_B],
                         x, i * N_EMBD, h1, i * N_EMBD, N_EMBD)
            i = i + u32(1)
        end
        pack_all(h1, N_EMBD, xw, sx, n, N_EMBD)
            linear_prefill(md.w8, md.qs, md.csum,
                        md.off[b + T_ATTN_W], md.off[Q_BASE + b + T_ATTN_W],
                        md.w, md.off[b + T_ATTN_B], xw, sx, t32,
                        qkv, u32(0), u32(3) * N_EMBD, n,
                        N_EMBD, u32(3) * N_EMBD)

        mut hh = u32(0)
        while hh < N_HEAD do
            head(qkv, att, buf, hh, n)
            hh = hh + u32(1)
        end

        pack_all(att, N_EMBD, xw, sx, n, N_EMBD)
            linear_prefill(md.w8, md.qs, md.csum,
                        md.off[b + T_APROJ_W], md.off[Q_BASE + b + T_APROJ_W],
                        md.w, md.off[b + T_APROJ_B], xw, sx, t32,
                        h1, u32(0), N_EMBD, n, N_EMBD, N_EMBD)
        mut j = u32(0)
        while j < n * N_EMBD do
            x[j] = x[j] + h1[j]
            j = j + u32(1)
        end

        mut k = u32(0)
        while k < n do
            layernorm_at(md.w, md.off[b + T_LN2_W], md.off[b + T_LN2_B],
                         x, k * N_EMBD, h1, k * N_EMBD, N_EMBD)
            k = k + u32(1)
        end
        pack_all(h1, N_EMBD, xw, sx, n, N_EMBD)
            linear_prefill(md.w8, md.qs, md.csum,
                        md.off[b + T_FC_W], md.off[Q_BASE + b + T_FC_W],
                        md.w, md.off[b + T_FC_B], xw, sx, t32,
                        ff, u32(0), u32(4) * N_EMBD, n,
                        N_EMBD, u32(4) * N_EMBD)
        mut ggn = n * u32(4) * N_EMBD
        mut gg = u32(0)
        while gg + u32(8) <= ggn do
            store(ff, gg, vv.geluv(simd[f32, 8](ff, gg)))
            gg = gg + u32(8)
        end
        pack_all(ff, u32(4) * N_EMBD, xw, sx, n, u32(4) * N_EMBD)
        linear_prefill(md.w8, md.qs, md.csum,
                       md.off[b + T_PROJ_W], md.off[Q_BASE + b + T_PROJ_W],
                       md.w, md.off[b + T_PROJ_B], xw, sx, t32,
                       h1, u32(0), N_EMBD, n, u32(4) * N_EMBD, N_EMBD)
        mut j2 = u32(0)
        while j2 < n * N_EMBD do
            x[j2] = x[j2] + h1[j2]
            j2 = j2 + u32(1)
        end

        l = l + u32(1)
    end

    mut last = (n - u32(1)) * N_EMBD
    layernorm_at(md.w, md.off[G_BASE + T_LNF_W], md.off[G_BASE + T_LNF_B],
                 x, last, h1, u32(0), N_EMBD)
    mut sb = md.off[G_BASE + T_LM16_S]
    mut nvb = (N_VOCAB + u32(7)) / u32(8) * u32(8)
    mut m16 = md.qs[sb + nvb + u32(2)]
    mut xw16 = array[i32](N_EMBD / u32(2))
    mut ai = array[f32](u32(2))
    pack_act16(h1, u32(0), xw16, N_EMBD, m16, ai)
    head_dot2(md.hw, md.qs, sb, xw16, ai[u32(0)], logits, N_VOCAB, N_EMBD)
    mut bound = (ai[u32(1)] * md.qs[sb + nvb] / md.qs[sb + nvb + u32(3)]
               + md.qs[sb + nvb + u32(1)] * ai[u32(0)]) * f32(0.5)
    return argmax_exact(logits, md.w, md.off[G_BASE + T_WTE], h1,
                        N_VOCAB, N_EMBD, bound, md.qs, sb, nvb,
                        ai[u32(1)], ai[u32(0)], array[u32](u32(2)))
end

pub fn forward_q4(md: Q4Model, ids: u32[], n: u32, logits: f32[]) -> u32
    mut x = array[f32](n * N_EMBD)
    mut h1 = array[f32](n * N_EMBD)
    mut qkv = array[f32](n * u32(3) * N_EMBD)
    mut att = array[f32](n * N_EMBD)
    mut ff = array[f32](n * u32(4) * N_EMBD)
    mut buf = array[f32](n)
    mut xw = array[u32](TOK * N_EMBD * u32(2))
    mut sx = array[f32](TOK)
    mut sxs = array[f32](TOK * ((u32(4) * N_EMBD + Q4_GROUP - u32(1)) / Q4_GROUP))
    mut fa = array[f32](u32(4) * N_EMBD / u32(16) * TOK * u32(16))

    mut t = u32(0)
    while t < n do
        mut e = md.off[G_BASE + T_WTE] + ids[t] * N_EMBD
        mut pp = md.off[G_BASE + T_WPE] + t * N_EMBD
        mut c = u32(0)
        while c < N_EMBD do
            x[t * N_EMBD + c] = md.w[e + c] + md.w[pp + c]
            c = c + u32(1)
        end
        t = t + u32(1)
    end

    mut l = u32(0)
    while l < N_LAYER do
        mut b = l * PER_LAYER

        mut i = u32(0)
        while i < n do
            layernorm_at(md.w, md.off[b + T_LN1_W], md.off[b + T_LN1_B],
                         x, i * N_EMBD, h1, i * N_EMBD, N_EMBD)
            i = i + u32(1)
        end
        mut g = u32(0)
        while g < n do
            mut nt = fill_group_q4(h1, N_EMBD, xw, sx, sxs, g, n, N_EMBD)
            linear_q4(md.w4, md.qs4, md.off[Q_BASE + b + T_ATTN_W],
                      md.off[Q_BASE + b + T_ATTN_W] / Q4_PAIRS,
                      md.off[G_BASE + T_Q4_TOT] / Q4_PAIRS
                      + md.off[Q_BASE + b + T_ATTN_W] / Q4_PAIRS,
                      md.w, md.off[b + T_ATTN_B], xw, sx, sxs, fa,
                        qkv, g * u32(3) * N_EMBD, u32(3) * N_EMBD, nt,
                        N_EMBD, u32(3) * N_EMBD)
            g = g + TOK
        end

        mut hh = u32(0)
        while hh < N_HEAD do
            head(qkv, att, buf, hh, n)
            hh = hh + u32(1)
        end

        mut g2 = u32(0)
        while g2 < n do
            mut nt2 = fill_group_q4(att, N_EMBD, xw, sx, sxs, g2, n, N_EMBD)
            linear_q4(md.w4, md.qs4, md.off[Q_BASE + b + T_APROJ_W],
                      md.off[Q_BASE + b + T_APROJ_W] / Q4_PAIRS,
                      md.off[G_BASE + T_Q4_TOT] / Q4_PAIRS
                      + md.off[Q_BASE + b + T_APROJ_W] / Q4_PAIRS,
                      md.w, md.off[b + T_APROJ_B], xw, sx, sxs, fa,
                        h1, g2 * N_EMBD, N_EMBD, nt2, N_EMBD, N_EMBD)
            g2 = g2 + TOK
        end
        mut j = u32(0)
        while j < n * N_EMBD do
            x[j] = x[j] + h1[j]
            j = j + u32(1)
        end

        mut k = u32(0)
        while k < n do
            layernorm_at(md.w, md.off[b + T_LN2_W], md.off[b + T_LN2_B],
                         x, k * N_EMBD, h1, k * N_EMBD, N_EMBD)
            k = k + u32(1)
        end
        mut g3 = u32(0)
        while g3 < n do
            mut nt3 = fill_group_q4(h1, N_EMBD, xw, sx, sxs, g3, n, N_EMBD)
            linear_q4(md.w4, md.qs4, md.off[Q_BASE + b + T_FC_W],
                      md.off[Q_BASE + b + T_FC_W] / Q4_PAIRS,
                      md.off[G_BASE + T_Q4_TOT] / Q4_PAIRS
                      + md.off[Q_BASE + b + T_FC_W] / Q4_PAIRS,
                      md.w, md.off[b + T_FC_B], xw, sx, sxs, fa,
                        ff, g3 * u32(4) * N_EMBD, u32(4) * N_EMBD, nt3,
                        N_EMBD, u32(4) * N_EMBD)
            g3 = g3 + TOK
        end
        mut ggn = n * u32(4) * N_EMBD
        mut gg = u32(0)
        while gg + u32(8) <= ggn do
            store(ff, gg, vv.geluv(simd[f32, 8](ff, gg)))
            gg = gg + u32(8)
        end
        mut g4 = u32(0)
        while g4 < n do
            mut nt4 = fill_group_q4(ff, u32(4) * N_EMBD, xw, sx, sxs, g4, n, u32(4) * N_EMBD)
            linear_q4(md.w4, md.qs4, md.off[Q_BASE + b + T_PROJ_W],
                      md.off[Q_BASE + b + T_PROJ_W] / Q4_PAIRS,
                      md.off[G_BASE + T_Q4_TOT] / Q4_PAIRS
                      + md.off[Q_BASE + b + T_PROJ_W] / Q4_PAIRS,
                      md.w, md.off[b + T_PROJ_B], xw, sx, sxs, fa,
                        h1, g4 * N_EMBD, N_EMBD, nt4, u32(4) * N_EMBD, N_EMBD)
            g4 = g4 + TOK
        end
        mut j2 = u32(0)
        while j2 < n * N_EMBD do
            x[j2] = x[j2] + h1[j2]
            j2 = j2 + u32(1)
        end

        l = l + u32(1)
    end

    mut last = (n - u32(1)) * N_EMBD
    layernorm_at(md.w, md.off[G_BASE + T_LNF_W], md.off[G_BASE + T_LNF_B],
                 x, last, h1, u32(0), N_EMBD)
    mut sb = md.off[G_BASE + T_LM16_S]
    mut nvb = (N_VOCAB + u32(7)) / u32(8) * u32(8)
    mut m16 = md.qs[sb + nvb + u32(2)]
    mut xw16 = array[i32](N_EMBD / u32(2))
    mut ai = array[f32](u32(2))
    pack_act16(h1, u32(0), xw16, N_EMBD, m16, ai)
    head_dot2(md.hw, md.qs, sb, xw16, ai[u32(0)], logits, N_VOCAB, N_EMBD)
    mut bound = (ai[u32(1)] * md.qs[sb + nvb] / md.qs[sb + nvb + u32(3)]
               + md.qs[sb + nvb + u32(1)] * ai[u32(0)]) * f32(0.5)
    return argmax_exact(logits, md.w, md.off[G_BASE + T_WTE], h1,
                        N_VOCAB, N_EMBD, bound, md.qs, sb, nvb,
                        ai[u32(1)], ai[u32(0)], array[u32](u32(2)))
end

pub fn forward_i16_stat(md: Model, ids: u32[], n: u32, logits: f32[],
                        st: u32[], bmul: f32) -> u32
    if len(md.w8) == u32(0) then
        return u32(0)
    end
    mut x = array[f32](n * N_EMBD)
    mut h1 = array[f32](n * N_EMBD)
    mut qkv = array[f32](n * u32(3) * N_EMBD)
    mut att = array[f32](n * N_EMBD)
    mut ff = array[f32](n * u32(4) * N_EMBD)
    mut buf = array[f32](n)
    mut xw = array[u32](TOK * N_EMBD * u32(2))
    mut sx = array[f32](TOK)
    mut t32 = array[i32](TOK * u32(4) * N_EMBD + TOK * u32(8))

    mut t = u32(0)
    while t < n do
        mut e = md.off[G_BASE + T_WTE] + ids[t] * N_EMBD
        mut pp = md.off[G_BASE + T_WPE] + t * N_EMBD
        mut c = u32(0)
        while c < N_EMBD do
            x[t * N_EMBD + c] = md.w[e + c] + md.w[pp + c]
            c = c + u32(1)
        end
        t = t + u32(1)
    end

    mut l = u32(0)
    while l < N_LAYER do
        mut b = l * PER_LAYER

        mut i = u32(0)
        while i < n do
            layernorm_at(md.w, md.off[b + T_LN1_W], md.off[b + T_LN1_B],
                         x, i * N_EMBD, h1, i * N_EMBD, N_EMBD)
            i = i + u32(1)
        end
        mut g = u32(0)
        while g < n do
            mut nt = fill_group(h1, N_EMBD, xw, sx, g, n, N_EMBD)
            linear_dot4(md.w8, md.qs, md.csum,
                        md.off[b + T_ATTN_W], md.off[Q_BASE + b + T_ATTN_W],
                        md.w, md.off[b + T_ATTN_B], xw, sx, t32,
                        qkv, g * u32(3) * N_EMBD, u32(3) * N_EMBD, nt,
                        N_EMBD, u32(3) * N_EMBD)
            g = g + TOK
        end

        mut hh = u32(0)
        while hh < N_HEAD do
            head(qkv, att, buf, hh, n)
            hh = hh + u32(1)
        end

        mut g2 = u32(0)
        while g2 < n do
            mut nt2 = fill_group(att, N_EMBD, xw, sx, g2, n, N_EMBD)
            linear_dot4(md.w8, md.qs, md.csum,
                        md.off[b + T_APROJ_W], md.off[Q_BASE + b + T_APROJ_W],
                        md.w, md.off[b + T_APROJ_B], xw, sx, t32,
                        h1, g2 * N_EMBD, N_EMBD, nt2, N_EMBD, N_EMBD)
            g2 = g2 + TOK
        end
        mut j = u32(0)
        while j < n * N_EMBD do
            x[j] = x[j] + h1[j]
            j = j + u32(1)
        end

        mut k = u32(0)
        while k < n do
            layernorm_at(md.w, md.off[b + T_LN2_W], md.off[b + T_LN2_B],
                         x, k * N_EMBD, h1, k * N_EMBD, N_EMBD)
            k = k + u32(1)
        end
        mut g3 = u32(0)
        while g3 < n do
            mut nt3 = fill_group(h1, N_EMBD, xw, sx, g3, n, N_EMBD)
            linear_dot4(md.w8, md.qs, md.csum,
                        md.off[b + T_FC_W], md.off[Q_BASE + b + T_FC_W],
                        md.w, md.off[b + T_FC_B], xw, sx, t32,
                        ff, g3 * u32(4) * N_EMBD, u32(4) * N_EMBD, nt3,
                        N_EMBD, u32(4) * N_EMBD)
            g3 = g3 + TOK
        end
        mut ggn = n * u32(4) * N_EMBD
        mut gg = u32(0)
        while gg + u32(8) <= ggn do
            store(ff, gg, vv.geluv(simd[f32, 8](ff, gg)))
            gg = gg + u32(8)
        end
        mut g4 = u32(0)
        while g4 < n do
            mut nt4 = fill_group(ff, u32(4) * N_EMBD, xw, sx, g4, n, u32(4) * N_EMBD)
            linear_dot4(md.w8, md.qs, md.csum,
                        md.off[b + T_PROJ_W], md.off[Q_BASE + b + T_PROJ_W],
                        md.w, md.off[b + T_PROJ_B], xw, sx, t32,
                        h1, g4 * N_EMBD, N_EMBD, nt4, u32(4) * N_EMBD, N_EMBD)
            g4 = g4 + TOK
        end
        mut j2 = u32(0)
        while j2 < n * N_EMBD do
            x[j2] = x[j2] + h1[j2]
            j2 = j2 + u32(1)
        end

        l = l + u32(1)
    end

    mut last = (n - u32(1)) * N_EMBD
    layernorm_at(md.w, md.off[G_BASE + T_LNF_W], md.off[G_BASE + T_LNF_B],
                 x, last, h1, u32(0), N_EMBD)
    mut sb = md.off[G_BASE + T_LM16_S]
    mut nvb = (N_VOCAB + u32(7)) / u32(8) * u32(8)
    mut m16 = md.qs[sb + nvb + u32(2)]
    mut xw16 = array[i32](N_EMBD / u32(2))
    mut ai = array[f32](u32(2))
    pack_act16(h1, u32(0), xw16, N_EMBD, m16, ai)
    head_dot2(md.hw, md.qs, sb, xw16, ai[u32(0)], logits, N_VOCAB, N_EMBD)
    mut bound = (ai[u32(1)] * md.qs[sb + nvb] / md.qs[sb + nvb + u32(3)]
               + md.qs[sb + nvb + u32(1)] * ai[u32(0)]) * f32(0.5)
    return argmax_exact(logits, md.w, md.off[G_BASE + T_WTE], h1,
                        N_VOCAB, N_EMBD, bound * bmul, md.qs, sb, nvb,
                        ai[u32(1)] * bmul, ai[u32(0)] * bmul, st)
end

pub fn forward_dot4_nolm(md: Model, ids: u32[], n: u32, logits: f32[]) -> u32
    if len(md.w8) == u32(0) then
        return u32(0)
    end
    mut x = array[f32](n * N_EMBD)
    mut h1 = array[f32](n * N_EMBD)
    mut qkv = array[f32](n * u32(3) * N_EMBD)
    mut att = array[f32](n * N_EMBD)
    mut ff = array[f32](n * u32(4) * N_EMBD)
    mut buf = array[f32](n)
    mut xw = array[u32](TOK * N_EMBD * u32(2))
    mut sx = array[f32](TOK)
    mut t32 = array[i32](TOK * u32(4) * N_EMBD + TOK * u32(8))

    mut t = u32(0)
    while t < n do
        mut e = md.off[G_BASE + T_WTE] + ids[t] * N_EMBD
        mut pp = md.off[G_BASE + T_WPE] + t * N_EMBD
        mut c = u32(0)
        while c < N_EMBD do
            x[t * N_EMBD + c] = md.w[e + c] + md.w[pp + c]
            c = c + u32(1)
        end
        t = t + u32(1)
    end

    mut l = u32(0)
    while l < N_LAYER do
        mut b = l * PER_LAYER

        mut i = u32(0)
        while i < n do
            layernorm_at(md.w, md.off[b + T_LN1_W], md.off[b + T_LN1_B],
                         x, i * N_EMBD, h1, i * N_EMBD, N_EMBD)
            i = i + u32(1)
        end
        mut g = u32(0)
        while g < n do
            mut nt = fill_group(h1, N_EMBD, xw, sx, g, n, N_EMBD)
            linear_dot4(md.w8, md.qs, md.csum,
                        md.off[b + T_ATTN_W], md.off[Q_BASE + b + T_ATTN_W],
                        md.w, md.off[b + T_ATTN_B], xw, sx, t32,
                        qkv, g * u32(3) * N_EMBD, u32(3) * N_EMBD, nt,
                        N_EMBD, u32(3) * N_EMBD)
            g = g + TOK
        end

        mut hh = u32(0)
        while hh < N_HEAD do
            head(qkv, att, buf, hh, n)
            hh = hh + u32(1)
        end

        mut g2 = u32(0)
        while g2 < n do
            mut nt2 = fill_group(att, N_EMBD, xw, sx, g2, n, N_EMBD)
            linear_dot4(md.w8, md.qs, md.csum,
                        md.off[b + T_APROJ_W], md.off[Q_BASE + b + T_APROJ_W],
                        md.w, md.off[b + T_APROJ_B], xw, sx, t32,
                        h1, g2 * N_EMBD, N_EMBD, nt2, N_EMBD, N_EMBD)
            g2 = g2 + TOK
        end
        mut j = u32(0)
        while j < n * N_EMBD do
            x[j] = x[j] + h1[j]
            j = j + u32(1)
        end

        mut k = u32(0)
        while k < n do
            layernorm_at(md.w, md.off[b + T_LN2_W], md.off[b + T_LN2_B],
                         x, k * N_EMBD, h1, k * N_EMBD, N_EMBD)
            k = k + u32(1)
        end
        mut g3 = u32(0)
        while g3 < n do
            mut nt3 = fill_group(h1, N_EMBD, xw, sx, g3, n, N_EMBD)
            linear_dot4(md.w8, md.qs, md.csum,
                        md.off[b + T_FC_W], md.off[Q_BASE + b + T_FC_W],
                        md.w, md.off[b + T_FC_B], xw, sx, t32,
                        ff, g3 * u32(4) * N_EMBD, u32(4) * N_EMBD, nt3,
                        N_EMBD, u32(4) * N_EMBD)
            g3 = g3 + TOK
        end
        mut ggn = n * u32(4) * N_EMBD
        mut gg = u32(0)
        while gg + u32(8) <= ggn do
            store(ff, gg, vv.geluv(simd[f32, 8](ff, gg)))
            gg = gg + u32(8)
        end
        mut g4 = u32(0)
        while g4 < n do
            mut nt4 = fill_group(ff, u32(4) * N_EMBD, xw, sx, g4, n, u32(4) * N_EMBD)
            linear_dot4(md.w8, md.qs, md.csum,
                        md.off[b + T_PROJ_W], md.off[Q_BASE + b + T_PROJ_W],
                        md.w, md.off[b + T_PROJ_B], xw, sx, t32,
                        h1, g4 * N_EMBD, N_EMBD, nt4, u32(4) * N_EMBD, N_EMBD)
            g4 = g4 + TOK
        end
        mut j2 = u32(0)
        while j2 < n * N_EMBD do
            x[j2] = x[j2] + h1[j2]
            j2 = j2 + u32(1)
        end

        l = l + u32(1)
    end

    mut lastq = (n - u32(1)) * N_EMBD
    layernorm_at(md.w, md.off[G_BASE + T_LNF_W], md.off[G_BASE + T_LNF_B],
                 x, lastq, h1, u32(0), N_EMBD)
    return u32(tobits(h1[u32(0)]))
end

pub fn forward_dot4_noline(md: Model, ids: u32[], n: u32, logits: f32[]) -> u32
    if len(md.w8) == u32(0) then
        return u32(0)
    end
    mut x = array[f32](n * N_EMBD)
    mut h1 = array[f32](n * N_EMBD)
    mut qkv = array[f32](n * u32(3) * N_EMBD)
    mut att = array[f32](n * N_EMBD)
    mut ff = array[f32](n * u32(4) * N_EMBD)
    mut buf = array[f32](n)
    mut xw = array[u32](TOK * N_EMBD * u32(2))
    mut sx = array[f32](TOK)
    mut t32 = array[i32](TOK * u32(4) * N_EMBD + TOK * u32(8))

    mut t = u32(0)
    while t < n do
        mut e = md.off[G_BASE + T_WTE] + ids[t] * N_EMBD
        mut pp = md.off[G_BASE + T_WPE] + t * N_EMBD
        mut c = u32(0)
        while c < N_EMBD do
            x[t * N_EMBD + c] = md.w[e + c] + md.w[pp + c]
            c = c + u32(1)
        end
        t = t + u32(1)
    end

    mut l = u32(0)
    while l < N_LAYER do
        mut b = l * PER_LAYER

        mut i = u32(0)
        while i < n do
            layernorm_at(md.w, md.off[b + T_LN1_W], md.off[b + T_LN1_B],
                         x, i * N_EMBD, h1, i * N_EMBD, N_EMBD)
            i = i + u32(1)
        end
        mut g = u32(0)
        while g < n do
            mut nt = fill_group(h1, N_EMBD, xw, sx, g, n, N_EMBD)
            g = g + TOK
        end

        mut hh = u32(0)
        while hh < N_HEAD do
            head(qkv, att, buf, hh, n)
            hh = hh + u32(1)
        end

        mut g2 = u32(0)
        while g2 < n do
            mut nt2 = fill_group(att, N_EMBD, xw, sx, g2, n, N_EMBD)
            g2 = g2 + TOK
        end
        mut j = u32(0)
        while j < n * N_EMBD do
            x[j] = x[j] + h1[j]
            j = j + u32(1)
        end

        mut k = u32(0)
        while k < n do
            layernorm_at(md.w, md.off[b + T_LN2_W], md.off[b + T_LN2_B],
                         x, k * N_EMBD, h1, k * N_EMBD, N_EMBD)
            k = k + u32(1)
        end
        mut g3 = u32(0)
        while g3 < n do
            mut nt3 = fill_group(h1, N_EMBD, xw, sx, g3, n, N_EMBD)
            g3 = g3 + TOK
        end
        mut ggn = n * u32(4) * N_EMBD
        mut gg = u32(0)
        while gg + u32(8) <= ggn do
            store(ff, gg, vv.geluv(simd[f32, 8](ff, gg)))
            gg = gg + u32(8)
        end
        mut g4 = u32(0)
        while g4 < n do
            mut nt4 = fill_group(ff, u32(4) * N_EMBD, xw, sx, g4, n, u32(4) * N_EMBD)
            g4 = g4 + TOK
        end
        mut j2 = u32(0)
        while j2 < n * N_EMBD do
            x[j2] = x[j2] + h1[j2]
            j2 = j2 + u32(1)
        end

        l = l + u32(1)
    end

    mut lastq = (n - u32(1)) * N_EMBD
    layernorm_at(md.w, md.off[G_BASE + T_LNF_W], md.off[G_BASE + T_LNF_B],
                 x, lastq, h1, u32(0), N_EMBD)
    return u32(tobits(h1[u32(0)]))
end
