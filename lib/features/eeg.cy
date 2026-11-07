mut m = require("../math/scalar.cy")
mut f = require("../math/fft.cy")

pub fn hjorth3(x: f32[], xo: u32, n: u32) -> (f32, f32, f32)
    mut mean = f64(0.0)
    mut i = u32(0)
    while i < n do
        mean = mean + f64(x[xo + i])
        i = i + u32(1)
    end
    mean = mean / f64(i32(n))
    mut s0 = f64(0.0)
    mut j = u32(0)
    while j < n do
        mut v = f64(x[xo + j]) - mean
        s0 = s0 + v * v
        j = j + u32(1)
    end
    mut s1 = f64(0.0)
    mut k = u32(1)
    while k < n do
        mut d = f64(x[xo + k]) - f64(x[xo + k - u32(1)])
        s1 = s1 + d * d
        k = k + u32(1)
    end
    mut s2 = f64(0.0)
    mut l = u32(2)
    while l < n do
        mut dd = f64(x[xo + l]) - f64(2.0) * f64(x[xo + l - u32(1)])
               + f64(x[xo + l - u32(2)])
        s2 = s2 + dd * dd
        l = l + u32(1)
    end
    mut a = s0 / f64(i32(n))
    mut d1 = s1 / f64(i32(n))
    mut d2 = s2 / f64(i32(n))
    mut mob = sqrt(d1 / (a + f64(1.0e-30)))
    mut mob2 = sqrt(d2 / (d1 + f64(1.0e-30)))
    return (f32(a), f32(mob), f32(mob2 / (mob + f64(1.0e-30))))
end

pub fn hjorth(x: f32[], xo: u32, n: u32, out: f32[], oo: u32)
    mut h = hjorth3(x, xo, n)
    out[oo] = h.0
    out[oo + u32(1)] = h.1
    out[oo + u32(2)] = h.2
end

pub fn higuchi(x: f32[], xo: u32, n: u32, kmax: u32) -> f32
    mut sx = f64(0.0)
    mut sy = f64(0.0)
    mut sxx = f64(0.0)
    mut sxy = f64(0.0)
    mut cnt = f64(0.0)
    mut k = u32(1)
    while k <= kmax do
        mut tot = f64(0.0)
        mut start = u32(0)
        while start < k do
            mut steps = (n - start - u32(1)) / k
            if steps > u32(0) then
                mut sum = f64(0.0)
                mut i = u32(1)
                while i <= steps do
                    sum = sum + abs(f64(x[xo + start + i * k])
                                  - f64(x[xo + start + (i - u32(1)) * k]))
                    i = i + u32(1)
                end
                mut norm = f64(i32(n - u32(1))) / (f64(i32(steps)) * f64(i32(k)))
                tot = tot + sum * norm / f64(i32(k))
            end
            start = start + u32(1)
        end
        mut lk = tot / f64(i32(k))
        if lk > f64(0.0) then
            mut lx = f64(m.log(f32(1.0) / f32(i32(k))))
            mut ly = f64(m.log(f32(lk)))
            sx = sx + lx
            sy = sy + ly
            sxx = sxx + lx * lx
            sxy = sxy + lx * ly
            cnt = cnt + f64(1.0)
        end
        k = k + u32(1)
    end
    mut den = cnt * sxx - sx * sx
    if abs(den) < f64(1.0e-30) then
        return f32(0.0)
    end
    return f32((cnt * sxy - sx * sy) / den)
end

pub fn sample_entropy(x: f32[], xo: u32, n: u32, r: f32) -> f32
    mut mean = f64(0.0)
    mut i = u32(0)
    while i < n do
        mean = mean + f64(x[xo + i])
        i = i + u32(1)
    end
    mean = mean / f64(i32(n))
    mut var = f64(0.0)
    mut j = u32(0)
    while j < n do
        mut d = f64(x[xo + j]) - mean
        var = var + d * d
        j = j + u32(1)
    end
    mut tol = f32(sqrt(var / f64(i32(n)))) * r
    mut nm = n - u32(2)
    mut tolv = simd[f32, 8](tol)
    mut one = simd[f32, 8](f32(1.0))
    mut zero = simd[f32, 8](f32(0.0))
    mut av = simd[f32, 8](f32(0.0))
    mut bv = simd[f32, 8](f32(0.0))
    mut a = u32(0)
    mut b = u32(0)
    mut p = u32(0)
    while p < nm do
        mut x0 = simd[f32, 8](x[xo + p])
        mut x1 = simd[f32, 8](x[xo + p + u32(1)])
        mut x2 = simd[f32, 8](x[xo + p + u32(2)])
        mut q = p + u32(1)
        while q + u32(8) <= nm do
            mut v0 = simd[f32, 8](x, xo + q)
            mut v1 = simd[f32, 8](x, xo + q + u32(1))
            mut v2 = simd[f32, 8](x, xo + q + u32(2))
            mut d0 = max(x0 - v0, v0 - x0)
            mut d1 = max(x1 - v1, v1 - x1)
            mut d2 = max(x2 - v2, v2 - x2)
            mut mx = max(d0, d1)
            mut hitb = select(mx <= tolv, one, zero)
            mut hita = select(max(mx, d2) <= tolv, one, zero)
            bv = bv + hitb
            av = av + hita
            q = q + u32(8)
        end
        while q < nm do
            mut e0 = abs(x[xo + p] - x[xo + q])
            mut e1 = abs(x[xo + p + u32(1)] - x[xo + q + u32(1)])
            mut mm = e0
            if e1 > mm then
                mm = e1
            end
            if mm <= tol then
                b = b + u32(1)
                mut e2 = abs(x[xo + p + u32(2)] - x[xo + q + u32(2)])
                if e2 <= tol then
                    a = a + u32(1)
                end
            end
            q = q + u32(1)
        end
        p = p + u32(1)
    end
    mut at = a + u32(i32(hsum(av)))
    mut bt = b + u32(i32(hsum(bv)))
    if at == u32(0) then
        return m.log(f32(i32(nm)) * f32(i32(nm - u32(1))))
    end
    if bt == u32(0) then
        return f32(0.0)
    end
    return f32(0.0) - m.log(f32(i32(at)) / f32(i32(bt)))
end

E0 = f32(0.5)
E1 = f32(4.0)
E2 = f32(8.0)
E3 = f32(13.0)
E4 = f32(30.0)
E5 = f32(45.0)

pub fn first_bin(e: f32, n: u32, fs: f32, half: u32) -> u32
    mut k = u32(1)
    while k <= half do
        if f32(i32(k)) * fs / f32(i32(n)) >= e then
            return k
        end
        k = k + u32(1)
    end
    return half + u32(1)
end

fn bin_sum(p: f32[], po: u32, lo: u32, hi: u32, s0: f32) -> f32
    mut s = s0
    mut k = lo
    while k < hi do
        s = s + p[po + k]
        k = k + u32(1)
    end
    return s
end

pub fn band_edges(n: u32, fs: f32, kb: u32[])
    mut half = n / u32(2)
    kb[u32(0)] = first_bin(E0, n, fs, half)
    kb[u32(1)] = first_bin(E1, n, fs, half)
    kb[u32(2)] = first_bin(E2, n, fs, half)
    kb[u32(3)] = first_bin(E3, n, fs, half)
    kb[u32(4)] = first_bin(E4, n, fs, half)
    kb[u32(5)] = first_bin(E5, n, fs, half)
end

pub fn band_power(x: f32[], xo: u32, n: u32, fs: f32, win: f32[], tw: f32[],
                  z: f32[], zo: u32, p: f32[], po: u32, out: f32[], oo: u32)
    f.rfft_power(x, xo, n, win, tw, z, zo, p, po)
    mut half = n / u32(2)
    mut k0 = first_bin(E0, n, fs, half)
    mut k1 = first_bin(E1, n, fs, half)
    mut k2 = first_bin(E2, n, fs, half)
    mut k3 = first_bin(E3, n, fs, half)
    mut k4 = first_bin(E4, n, fs, half)
    mut k5 = first_bin(E5, n, fs, half)
    out[oo] = bin_sum(p, po, k0, k1, f32(0.0))
    out[oo + u32(1)] = bin_sum(p, po, k1, k2, f32(0.0))
    out[oo + u32(2)] = bin_sum(p, po, k2, k3, f32(0.0))
    out[oo + u32(3)] = bin_sum(p, po, k3, k4, f32(0.0))
    out[oo + u32(4)] = bin_sum(p, po, k4, k5, f32(0.0))
    mut tot = bin_sum(p, po, u32(1), k5, f32(1.0e-20))
    mut d = u32(0)
    while d < u32(5) do
        out[oo + d] = m.log(out[oo + d] / tot + f32(1.0e-8))
        d = d + u32(1)
    end
end

pub PER_CHANNEL = u32(10)

pub fn window(x: f32[], xo: u32, n: u32, fs: f32, win: f32[], tw: f32[],
              z: f32[], zo: u32, p: f32[], po: u32, out: f32[], oo: u32)
    window_some(x, xo, n, fs, win, tw, z, zo, p, po, out, oo, u32(15))
end

pub fn window_some(x: f32[], xo: u32, n: u32, fs: f32, win: f32[], tw: f32[],
                   z: f32[], zo: u32, p: f32[], po: u32, out: f32[], oo: u32,
                   pick: u32)
    if pick & u32(1) != u32(0) then
        hjorth(x, xo, n, out, oo)
    end
    if pick & u32(2) != u32(0) then
        out[oo + u32(3)] = higuchi(x, xo, n, u32(8))
    end
    if pick & u32(4) != u32(0) then
        out[oo + u32(4)] = sample_entropy(x, xo, n, f32(0.2))
    end
    if pick & u32(8) != u32(0) then
        band_power(x, xo, n, fs, win, tw, z, zo, p, po, out, oo + u32(5))
    end
end
