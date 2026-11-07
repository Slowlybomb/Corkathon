mut mm = require("../math/scalar.cy")

fn last_key(i: u32, seq: u32, causal: bool) -> u32
    if causal then
        return i + u32(1)
    end
    return seq
end

fn dot(a: f32[], ao: u32, b: f32[], bo: u32, dim: u32) -> f32
    mut s = f32(0.0)
    mut c = u32(0)
    while c < dim do
        s = s + a[ao + c] * b[bo + c]
        c = c + u32(1)
    end
    return s
end

pub fn sdpa_row(q: f32[], k: f32[], v: f32[], out: f32[], buf: f32[],
                i: u32, seq: u32, dim: u32, causal: bool)
    mut scale = mm.rsqrt(f32(dim))
    mut n = last_key(i, seq, causal)
    mut qo = i * dim
    mut top = f32(0.0) - mm.inf()
    mut j = u32(0)
    while j < n do
        mut s = dot(q, qo, k, j * dim, dim) * scale
        buf[j] = s
        if s > top then
            top = s
        end
        j = j + u32(1)
    end
    mut tot = f32(0.0)
    mut e = u32(0)
    while e < n do
        mut x = mm.exp(buf[e] - top)
        buf[e] = x
        tot = tot + x
        e = e + u32(1)
    end
    mut inv = 1.0 / tot
    mut oo = i * dim
    mut z = u32(0)
    while z < dim do
        out[oo + z] = f32(0.0)
        z = z + u32(1)
    end
    mut m = u32(0)
    while m < n do
        mut w = buf[m] * inv
        mut vo = m * dim
        mut c = u32(0)
        while c < dim do
            out[oo + c] = out[oo + c] + w * v[vo + c]
            c = c + u32(1)
        end
        m = m + u32(1)
    end
end

pub fn sdpa_rows(q: f32[], k: f32[], v: f32[], out: f32[], seq: u32, dim: u32,
                 causal: bool)
    mut buf = array[f32](seq)
    mut i = u32(0)
    while i < seq do
        sdpa_row(q, k, v, out, buf, i, seq, dim, causal)
        i = i + u32(1)
    end
end

ROWS = u32(8)

pub fn sdpa_tiled(q: f32[], k: f32[], v: f32[], out: f32[], seq: u32, dim: u32,
                  causal: bool)
    mut buf = array[f32](ROWS * seq)
    mut top = array[f32](ROWS)
    mut tot = array[f32](ROWS)
    mut i0 = u32(0)
    while i0 < seq do
        mut rows = ROWS
        if i0 + rows > seq then
            rows = seq - i0
        end
        mut r = u32(0)
        while r < rows do
            top[r] = f32(0.0) - mm.inf()
            r = r + u32(1)
        end
        mut scale = mm.rsqrt(f32(dim))
        mut j = u32(0)
        while j < seq do
            mut ko = j * dim
            mut rr = u32(0)
            while rr < rows do
                if j < last_key(i0 + rr, seq, causal) then
                    mut s = dot(q, (i0 + rr) * dim, k, ko, dim) * scale
                    buf[rr * seq + j] = s
                    if s > top[rr] then
                        top[rr] = s
                    end
                end
                rr = rr + u32(1)
            end
            j = j + u32(1)
        end
        mut r2 = u32(0)
        while r2 < rows do
            mut n = last_key(i0 + r2, seq, causal)
            mut sum = f32(0.0)
            mut e = u32(0)
            while e < n do
                mut x = mm.exp(buf[r2 * seq + e] - top[r2])
                buf[r2 * seq + e] = x
                sum = sum + x
                e = e + u32(1)
            end
            tot[r2] = 1.0 / sum
            r2 = r2 + u32(1)
        end
        mut r3 = u32(0)
        while r3 < rows do
            mut oo = (i0 + r3) * dim
            mut z = u32(0)
            while z < dim do
                out[oo + z] = f32(0.0)
                z = z + u32(1)
            end
            r3 = r3 + u32(1)
        end
        mut m = u32(0)
        while m < seq do
            mut vo = m * dim
            mut r4 = u32(0)
            while r4 < rows do
                if m < last_key(i0 + r4, seq, causal) then
                    mut w = buf[r4 * seq + m] * tot[r4]
                    mut oo = (i0 + r4) * dim
                    mut c = u32(0)
                    while c < dim do
                        out[oo + c] = out[oo + c] + w * v[vo + c]
                        c = c + u32(1)
                    end
                end
                r4 = r4 + u32(1)
            end
            m = m + u32(1)
        end
        i0 = i0 + ROWS
    end
end

pub fn sdpa(q: f32[], k: f32[], v: f32[], out: f32[], seq: u32, dim: u32,
            causal: bool)
    sdpa_rows(q, k, v, out, seq, dim, causal)
end
