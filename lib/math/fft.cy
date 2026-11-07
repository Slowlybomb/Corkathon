mut m = require("scalar.cy")

pub fn twiddles_into(t: f32[], n: u32)
    mut k = u32(0)
    while k < n / u32(2) do
        mut a = f32(-6.28318530717958648) * f32(i32(k)) / f32(i32(n))
        t[k * u32(2)] = m.cos(a)
        t[k * u32(2) + u32(1)] = m.sin(a)
        k = k + u32(1)
    end
end

pub fn twiddles(n: u32) -> f32[]
    mut t = array[f32](n)
    twiddles_into(t, n)
    return t
end

pub fn log2u(n: u32) -> u32
    mut l = u32(0)
    mut v = n
    while v > u32(1) do
        v = v >> u32(1)
        l = l + u32(1)
    end
    return l
end

fn bitrev(re: f32[], ro: u32, n: u32, bits: u32)
    mut i = u32(0)
    while i < n do
        mut r = u32(0)
        mut x = i
        mut b = u32(0)
        while b < bits do
            r = (r << u32(1)) | (x & u32(1))
            x = x >> u32(1)
            b = b + u32(1)
        end
        if r > i then
            mut a0 = re[ro + i * u32(2)]
            mut a1 = re[ro + i * u32(2) + u32(1)]
            re[ro + i * u32(2)] = re[ro + r * u32(2)]
            re[ro + i * u32(2) + u32(1)] = re[ro + r * u32(2) + u32(1)]
            re[ro + r * u32(2)] = a0
            re[ro + r * u32(2) + u32(1)] = a1
        end
        i = i + u32(1)
    end
end

pub fn fft(z: f32[], zo: u32, n: u32, tw: f32[])
    mut bits = log2u(n)
    bitrev(z, zo, n, bits)
    mut len = u32(2)
    while len <= n do
        mut half = len / u32(2)
        mut step = n / len
        mut i = u32(0)
        while i < n do
            mut j = u32(0)
            while j < half do
                mut wr = tw[j * step * u32(2)]
                mut wi = tw[j * step * u32(2) + u32(1)]
                mut a = zo + (i + j) * u32(2)
                mut b = zo + (i + j + half) * u32(2)
                mut xr = z[b] * wr - z[b + u32(1)] * wi
                mut xi = z[b] * wi + z[b + u32(1)] * wr
                z[b] = z[a] - xr
                z[b + u32(1)] = z[a + u32(1)] - xi
                z[a] = z[a] + xr
                z[a + u32(1)] = z[a + u32(1)] + xi
                j = j + u32(1)
            end
            i = i + len
        end
        len = len * u32(2)
    end
end

pub fn rfft_power(x: f32[], xo: u32, n: u32, win: f32[], tw: f32[],
                  z: f32[], zo: u32, p: f32[], po: u32)
    mut h = n / u32(2)
    mut i = u32(0)
    while i < h do
        z[zo + i * u32(2)] = x[xo + i * u32(2)] * win[i * u32(2)]
        z[zo + i * u32(2) + u32(1)] = x[xo + i * u32(2) + u32(1)]
                                    * win[i * u32(2) + u32(1)]
        i = i + u32(1)
    end
    fft(z, zo, h, tw)
    mut k = u32(0)
    while k <= h / u32(2) do
        mut k2 = (h - k) % h
        mut ar = z[zo + k * u32(2)]
        mut ai = z[zo + k * u32(2) + u32(1)]
        mut br = z[zo + k2 * u32(2)]
        mut bi = f32(0.0) - z[zo + k2 * u32(2) + u32(1)]
        mut er = (ar + br) * f32(0.5)
        mut ei = (ai + bi) * f32(0.5)
        mut or1 = (ai - bi) * f32(0.5)
        mut oi = (br - ar) * f32(0.5)
        mut ang = f32(-6.28318530717958648) * f32(i32(k)) / f32(i32(n))
        mut cr = m.cos(ang)
        mut ci = m.sin(ang)
        mut tr = or1 * cr - oi * ci
        mut ti = or1 * ci + oi * cr
        mut rr = er + tr
        mut ri = ei + ti
        p[po + k] = rr * rr + ri * ri
        if k > u32(0) then
            mut sr = er - tr
            mut si = f32(0.0) - (ei - ti)
            p[po + h - k] = sr * sr + si * si
        end
        k = k + u32(1)
    end
    mut ny = z[zo] - z[zo + u32(1)]
    p[po + h] = ny * ny
end

pub fn hann_into(w: f32[], n: u32)
    mut i = u32(0)
    while i < n do
        w[i] = f32(0.5) - f32(0.5) * m.cos(f32(6.28318530717958648) * f32(i32(i))
                                          / f32(i32(n - u32(1))))
        i = i + u32(1)
    end
end

pub fn hann(n: u32) -> f32[]
    mut w = array[f32](n)
    hann_into(w, n)
    return w
end
