mut dn = require("../nn/dense.cy")
mut gm = require("../nn/gemm.cy")

pub fn centroid_bias(c: f32[], bias: f32[], k: u32, d: u32)
    mut j = u32(0)
    while j < k do
        mut acc = simd[f32, 8](f32(0.0))
        mut t = u32(0)
        while t + u32(8) <= d do
            mut v = simd[f32, 8](c, j * d + t)
            acc = fma(v, v, acc)
            t = t + u32(8)
        end
        mut s = hsum(acc)
        while t < d do
            s = s + c[j * d + t] * c[j * d + t]
            t = t + u32(1)
        end
        bias[j] = s * f32(-0.5)
        j = j + u32(1)
    end
end

pub fn assign_packed(pa: f32[], xn: f32[], c: f32[], pc: f32[], bias: f32[],
                     score: f32[], bs: f32[], lab: u32[],
                     n: u32, d: u32, k: u32) -> f64
    centroid_bias(c, bias, k, d)
    gm.pack_b(c, pc, d, k)
    gm.gemm(pa, pc, bias, score, n, d, k)
    mut i = u32(0)
    while i < n do
        mut best = score[i * k]
        mut bj = u32(0)
        mut j = u32(1)
        while j < k do
            if score[i * k + j] > best then
                best = score[i * k + j]
                bj = j
            end
            j = j + u32(1)
        end
        lab[i] = bj
        bs[i] = best
        i = i + u32(1)
    end
    mut total = 0.0
    mut q = u32(0)
    while q < n do
        total = total + f64(xn[q]) - 2.0 * f64(bs[q])
        q = q + u32(1)
    end
    return total
end

pub fn assign(x: f32[], xn: f32[], c: f32[], bias: f32[], score: f32[],
              lab: u32[], n: u32, d: u32, k: u32) -> f64
    centroid_bias(c, bias, k, d)
    dn.forward(x, c, bias, score, n, d, k)
    mut total = 0.0
    mut i = u32(0)
    while i < n do
        mut best = score[i * k]
        mut bj = u32(0)
        mut j = u32(1)
        while j < k do
            if score[i * k + j] > best then
                best = score[i * k + j]
                bj = j
            end
            j = j + u32(1)
        end
        lab[i] = bj
        total = total + f64(xn[i]) - 2.0 * f64(best)
        i = i + u32(1)
    end
    return total
end

pub fn update(x: f32[], lab: u32[], c: f32[], sums: f32[], cnt: u32[],
              n: u32, d: u32, k: u32)
    mut z = u32(0)
    while z < k * d do
        sums[z] = f32(0.0)
        z = z + u32(1)
    end
    mut q = u32(0)
    while q < k do
        cnt[q] = u32(0)
        q = q + u32(1)
    end
    mut i = u32(0)
    while i < n do
        mut j = lab[i]
        cnt[j] = cnt[j] + u32(1)
        mut t = u32(0)
        while t + u32(8) <= d do
            store(sums, j * d + t,
                  simd[f32, 8](sums, j * d + t) + simd[f32, 8](x, i * d + t))
            t = t + u32(8)
        end
        while t < d do
            sums[j * d + t] = sums[j * d + t] + x[i * d + t]
            t = t + u32(1)
        end
        i = i + u32(1)
    end
    mut m = u32(0)
    while m < k do
        if cnt[m] > u32(0) then
            mut inv = f32(1.0) / f32(cnt[m])
            mut t2 = u32(0)
            while t2 < d do
                c[m * d + t2] = sums[m * d + t2] * inv
                t2 = t2 + u32(1)
            end
        end
        m = m + u32(1)
    end
end

pub fn norms(x: f32[], xn: f32[], n: u32, d: u32)
    mut i = u32(0)
    while i < n do
        mut acc = simd[f32, 8](f32(0.0))
        mut t = u32(0)
        while t + u32(8) <= d do
            mut v = simd[f32, 8](x, i * d + t)
            acc = fma(v, v, acc)
            t = t + u32(8)
        end
        mut s = hsum(acc)
        while t < d do
            s = s + x[i * d + t] * x[i * d + t]
            t = t + u32(1)
        end
        xn[i] = s
        i = i + u32(1)
    end
end
