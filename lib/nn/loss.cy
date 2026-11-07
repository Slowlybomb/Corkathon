mut m = require("../math/scalar.cy")

pub fn softmax_cross_entropy(z: f32[], y: u32[], dz: f32[],
                             batch: u32, ncls: u32) -> f32
    mut total = f64(0.0)
    mut inv = f32(1.0) / f32(i32(batch))
    mut b = u32(0)
    while b < batch do
        mut base = b * ncls
        mut mx = z[base]
        mut i = u32(1)
        while i < ncls do
            if z[base + i] > mx then
                mx = z[base + i]
            end
            i = i + u32(1)
        end
        mut sum = f32(0.0)
        mut j = u32(0)
        while j < ncls do
            mut e = m.exp(z[base + j] - mx)
            dz[base + j] = e
            sum = sum + e
            j = j + u32(1)
        end
        mut rs = f32(1.0) / sum
        mut t = y[b]
        mut k = u32(0)
        while k < ncls do
            mut p = dz[base + k] * rs
            if k == t then
                total = total - f64(m.log(p + f32(1.0e-30)))
                dz[base + k] = (p - f32(1.0)) * inv
            else
                dz[base + k] = p * inv
            end
            k = k + u32(1)
        end
        b = b + u32(1)
    end
    return f32(total)
end

pub fn correct(z: f32[], y: u32[], batch: u32, ncls: u32) -> u32
    mut n = u32(0)
    mut b = u32(0)
    while b < batch do
        mut base = b * ncls
        mut best = u32(0)
        mut bv = z[base]
        mut i = u32(1)
        while i < ncls do
            if z[base + i] > bv then
                bv = z[base + i]
                best = i
            end
            i = i + u32(1)
        end
        if best == y[b] then
            n = n + u32(1)
        end
        b = b + u32(1)
    end
    return n
end
