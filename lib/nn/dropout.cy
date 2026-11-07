mut fast = require("../rng/fast.cy")

pub fn mask(seed: u32, step: u32, m: f32[], n: u32, keep: f32)
    mut inv = f32(1.0) / keep
    mut thrs = u32(i32(keep * f32(16777216.0)))
    mut base = step * n
    mut it8 = fast.iota8()
    mut i = u32(0)
    while i + u32(8) <= n do
        mut w = fast.hash8(it8 + simd[u32, 8](base + i), seed) >> simd[u32, 8](u32(8))
        store(m, i, select(w < simd[u32, 8](thrs), simd[f32, 8](inv),
                           simd[f32, 8](f32(0.0))))
        i = i + u32(8)
    end
    while i < n do
        if fast.word(seed, base + i) >> u32(8) < u32(i32(keep * f32(16777216.0))) then
            m[i] = inv
        else
            m[i] = f32(0.0)
        end
        i = i + u32(1)
    end
end

pub fn apply(y: f32[], m: f32[], n: u32)
    mut i = u32(0)
    while i + u32(8) <= n do
        store(y, i, simd[f32, 8](y, i) * simd[f32, 8](m, i))
        i = i + u32(8)
    end
    while i < n do
        y[i] = y[i] * m[i]
        i = i + u32(1)
    end
end

pub fn backward(dy: f32[], m: f32[], n: u32)
    apply(dy, m, n)
end
