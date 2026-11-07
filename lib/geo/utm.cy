pub PI = 3.141592653589793
LN2 = 0.6931471805599453

fn pow2(k: i64) -> f64
    return frombits(u64(i64(1023) + k) << u64(52))
end

pub fn exp64(x: f64) -> f64
    k = round(x / LN2)
    r = x - k * LN2
    mut term = 1.0
    mut sum = 1.0
    mut i = 1
    while i < 18 do
        term = term * r / f64(i)
        sum = sum + term
        i = i + 1
    end
    return sum * pow2(i64(k))
end

pub fn log64(x: f64) -> f64
    b = tobits(x)
    mut e = i64((b >> u64(52)) & u64(2047)) - i64(1023)
    mut m = frombits((b & u64(4503599627370495)) | u64(4607182418800017408))
    if m > 1.4142135623730951 then
        m = m / 2.0
        e = e + i64(1)
    end
    s = (m - 1.0) / (m + 1.0)
    s2 = s * s
    mut term = s
    mut sum = 0.0
    mut k = 1
    while k < 40 do
        sum = sum + term / f64(k)
        term = term * s2
        k = k + 2
    end
    return 2.0 * sum + f64(e) * LN2
end

fn sincos(x: f64, out: f64[])
    q = round(x / (PI / 2.0))
    r = x - q * (PI / 2.0)
    r2 = r * r
    mut s = r
    mut c = 1.0
    mut ts = r
    mut tc = 1.0
    mut i = 1
    while i < 12 do
        ts = -ts * r2 / f64((2 * i) * (2 * i + 1))
        tc = -tc * r2 / f64((2 * i - 1) * (2 * i))
        s = s + ts
        c = c + tc
        i = i + 1
    end
    qi = i64(q) & i64(3)
    out[0] = s
    out[1] = c
    if qi == i64(1) then
        out[0] = c
        out[1] = -s
    end
    if qi == i64(2) then
        out[0] = -s
        out[1] = -c
    end
    if qi == i64(3) then
        out[0] = -c
        out[1] = s
    end
end

pub fn sin64(x: f64) -> f64
    mut o = array[f64](2)
    sincos(x, o)
    return o[0]
end

pub fn cos64(x: f64) -> f64
    mut o = array[f64](2)
    sincos(x, o)
    return o[1]
end

pub fn atan64(x: f64) -> f64
    mut a = abs(x)
    mut off = 0.0
    mut flip = false
    if a > 1.0 then
        a = 1.0 / a
        flip = true
    end
    a = a / (1.0 + sqrt(1.0 + a * a))
    a = a / (1.0 + sqrt(1.0 + a * a))
    a2 = a * a
    mut term = a
    mut sum = 0.0
    mut k = 1
    while k < 40 do
        sum = sum + term / f64(k)
        term = -term * a2
        k = k + 2
    end
    mut r = 4.0 * sum
    if flip then
        r = PI / 2.0 - r
    end
    if x < 0.0 then
        r = -r
    end
    return r
end

pub fn asin64(x: f64) -> f64
    return atan64(x / sqrt(1.0 - x * x))
end

pub fn atanh64(x: f64) -> f64
    return 0.5 * log64((1.0 + x) / (1.0 - x))
end

pub fn sinh64(x: f64) -> f64
    e = exp64(x)
    return (e - 1.0 / e) / 2.0
end

pub fn cosh64(x: f64) -> f64
    e = exp64(x)
    return (e + 1.0 / e) / 2.0
end

A_WGS = 6378137.0
F_WGS = 0.0033528106647474805
K0 = 0.9996

fn nn() -> f64
    return F_WGS / (2.0 - F_WGS)
end

fn rect() -> f64
    n = nn()
    return A_WGS / (1.0 + n) * (1.0 + n * n / 4.0 + n * n * n * n / 64.0)
end

pub fn zone_of(epsg: u32) -> u32
    if epsg > u32(32600) and epsg < u32(32661) then
        return epsg - u32(32600)
    end
    if epsg > u32(32700) and epsg < u32(32761) then
        return epsg - u32(32700)
    end
    return u32(0)
end

pub fn is_south(epsg: u32) -> bool
    return epsg > u32(32700) and epsg < u32(32761)
end

pub fn to_latlon(e: f64, n0: f64, zone: u32, south: bool) -> (f64, f64)
    n = nn()
    a = rect()
    b1 = n / 2.0 - 2.0 * n * n / 3.0 + 37.0 * n * n * n / 96.0
    b2 = n * n / 48.0 + n * n * n / 15.0
    b3 = 17.0 * n * n * n / 480.0
    d1 = 2.0 * n - 2.0 * n * n / 3.0 - 2.0 * n * n * n
    d2 = 7.0 * n * n / 3.0 - 8.0 * n * n * n / 5.0
    d3 = 56.0 * n * n * n / 15.0
    mut nn0 = n0
    if south then
        nn0 = n0 - 10000000.0
    end
    xi = nn0 / (K0 * a)
    eta = (e - 500000.0) / (K0 * a)
    xp = xi - b1 * sin64(2.0 * xi) * cosh64(2.0 * eta) - b2 * sin64(4.0 * xi) * cosh64(4.0 * eta) - b3 * sin64(6.0 * xi) * cosh64(6.0 * eta)
    ep = eta - b1 * cos64(2.0 * xi) * sinh64(2.0 * eta) - b2 * cos64(4.0 * xi) * sinh64(4.0 * eta) - b3 * cos64(6.0 * xi) * sinh64(6.0 * eta)
    chi = asin64(sin64(xp) / cosh64(ep))
    lat = chi + d1 * sin64(2.0 * chi) + d2 * sin64(4.0 * chi) + d3 * sin64(6.0 * chi)
    lon0 = f64(zone) * 6.0 - 183.0
    lon = lon0 + atan64(sinh64(ep) / cos64(xp)) * 180.0 / PI
    return (lat * 180.0 / PI, lon)
end

pub fn from_latlon(latd: f64, lond: f64, zone: u32) -> (f64, f64)
    n = nn()
    a = rect()
    a1 = n / 2.0 - 2.0 * n * n / 3.0 + 5.0 * n * n * n / 16.0
    a2 = 13.0 * n * n / 48.0 - 3.0 * n * n * n / 5.0
    a3 = 61.0 * n * n * n / 240.0
    lat = latd * PI / 180.0
    dl = (lond - (f64(zone) * 6.0 - 183.0)) * PI / 180.0
    c = 2.0 * sqrt(n) / (1.0 + n)
    t = sinh64(atanh64(sin64(lat)) - c * atanh64(c * sin64(lat)))
    xp = atan64(t / cos64(dl))
    ep = atanh64(sin64(dl) / sqrt(1.0 + t * t))
    e = 500000.0 + K0 * a * (ep + a1 * cos64(2.0 * xp) * sinh64(2.0 * ep) + a2 * cos64(4.0 * xp) * sinh64(4.0 * ep) + a3 * cos64(6.0 * xp) * sinh64(6.0 * ep))
    mut no = K0 * a * (xp + a1 * sin64(2.0 * xp) * cosh64(2.0 * ep) + a2 * sin64(4.0 * xp) * cosh64(4.0 * ep) + a3 * sin64(6.0 * xp) * cosh64(6.0 * ep))
    if latd < 0.0 then
        no = no + 10000000.0
    end
    return (e, no)
end
