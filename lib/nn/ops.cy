mut mm = require("../math/scalar.cy")

pub fn rmsnorm(x: f32[], w: f32[], out: f32[], n: u32, eps: f32)
    mut acc = 0.0
    mut i = u32(0)
    while i < n do
        acc = acc + f64(x[i]) * f64(x[i])
        i = i + u32(1)
    end
    mut scale = mm.rsqrt(f32(acc / f64(n)) + eps)
    mut k = u32(0)
    while k < n do
        out[k] = x[k] * w[k] * scale
        k = k + u32(1)
    end
end

pub fn layernorm(x: f32[], w: f32[], b: f32[], out: f32[], n: u32, eps: f32)
    mut sum = 0.0
    mut i = u32(0)
    while i < n do
        sum = sum + f64(x[i])
        i = i + u32(1)
    end
    mut mean = sum / f64(n)
    mut var = 0.0
    mut j = u32(0)
    while j < n do
        mut d = f64(x[j]) - mean
        var = var + d * d
        j = j + u32(1)
    end
    mut scale = mm.rsqrt(f32(var / f64(n)) + eps)
    mut m = f32(mean)
    mut k = u32(0)
    while k < n do
        out[k] = (x[k] - m) * scale * w[k] + b[k]
        k = k + u32(1)
    end
end

pub fn softmax(x: f32[], n: u32)
    mut top = x[u32(0)]
    mut i = u32(1)
    while i < n do
        if x[i] > top then
            top = x[i]
        end
        i = i + u32(1)
    end
    mut tot = 0.0
    mut j = u32(0)
    while j < n do
        mut e = mm.exp(x[j] - top)
        x[j] = e
        tot = tot + f64(e)
        j = j + u32(1)
    end
    mut inv = f32(1.0 / tot)
    mut k = u32(0)
    while k < n do
        x[k] = x[k] * inv
        k = k + u32(1)
    end
end

fn rope_angle(pos: u32, i: u32, dim: u32, theta: f32) -> f32
    return f32(pos) * mm.pow(theta, f32(0.0) - 2.0 * f32(i) / f32(dim))
end

pub fn rope_pairs(x: f32[], off: u32, pos: u32, dim: u32, theta: f32)
    mut h = dim / u32(2)
    mut i = u32(0)
    while i < h do
        mut a = rope_angle(pos, i, dim, theta)
        mut c = mm.cos(a)
        mut s = mm.sin(a)
        mut x0 = x[off + i * u32(2)]
        mut x1 = x[off + i * u32(2) + u32(1)]
        x[off + i * u32(2)] = x0 * c - x1 * s
        x[off + i * u32(2) + u32(1)] = x0 * s + x1 * c
        i = i + u32(1)
    end
end

pub fn rope_halves(x: f32[], off: u32, pos: u32, dim: u32, theta: f32)
    mut h = dim / u32(2)
    mut i = u32(0)
    while i < h do
        mut a = rope_angle(pos, i, dim, theta)
        mut c = mm.cos(a)
        mut s = mm.sin(a)
        mut x0 = x[off + i]
        mut x1 = x[off + i + h]
        x[off + i] = x0 * c - x1 * s
        x[off + i + h] = x0 * s + x1 * c
        i = i + u32(1)
    end
end

pub fn embed(table: f32[], id: u32, out: f32[], off: u32, dim: u32)
    mut base = id * dim
    mut i = u32(0)
    while i < dim do
        out[off + i] = table[base + i]
        i = i + u32(1)
    end
end

pub fn matvec(w: f32[], x: f32[], out: f32[], rows: u32, cols: u32)
    mut r = u32(0)
    while r < rows do
        mut acc = 0.0
        mut base = r * cols
        mut c = u32(0)
        while c < cols do
            acc = acc + f64(w[base + c]) * f64(x[c])
            c = c + u32(1)
        end
        out[r] = f32(acc)
        r = r + u32(1)
    end
end

pub fn silu_mul(gate: f32[], up: f32[], out: f32[], n: u32)
    mut i = u32(0)
    while i < n do
        out[i] = mm.silu(gate[i]) * up[i]
        i = i + u32(1)
    end
end

pub fn gelu_inplace(x: f32[], n: u32)
    mut i = u32(0)
    while i < n do
        x[i] = mm.gelu_tanh(x[i])
        i = i + u32(1)
    end
end

pub fn add_inplace(x: f32[], y: f32[], n: u32)
    mut i = u32(0)
    while i < n do
        x[i] = x[i] + y[i]
        i = i + u32(1)
    end
end

pub fn argmax(x: f32[], n: u32) -> u32
    mut best = u32(0)
    mut top = x[u32(0)]
    mut i = u32(1)
    while i < n do
        if x[i] > top then
            top = x[i]
            best = i
        end
        i = i + u32(1)
    end
    return best
end
