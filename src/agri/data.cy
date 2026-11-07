mut T = require("../../lib/geo/tiff.cy")
mut U = require("../../lib/geo/utm.cy")
mut SD = require("../../lib/io/strtod.cy")

pub N = u32(48)
pub NPIX = u32(2304)
pub NBAND = u32(10)
pub NBASE = u32(21)
pub NCROP = u32(18)
pub NSOIL = u32(24)
pub NWX = u32(4)
pub MAXFP = u32(16)
pub NOFP = u32(255)
pub ZONE = u32(32)
pub NDAY = u32(366)

pub type Patch
    mut ok: bool
    mut x0: f64
    mut y0: f64
    mut lat: f64
    mut lon: f64
    mut crop: u32[]
    mut bnd: u32[]
    mut fp: u32[]
    mut nfp: u32
    mut soil: f32[]
    mut wrb: u32[]
    mut fpok: u32[]
    mut plat: f64[]
    mut plon: f64[]
end

pub type Soil
    mut nl: u32
    mut w: u32[]
    mut h: u32[]
    mut off: u32[]
    mut x0: f64[]
    mut y0: f64[]
    mut dx: f64[]
    mut dy: f64[]
    mut v: f32[]
end

pub type Wx
    mut base: u32
    mut np: u32
    mut lat: f64[]
    mut lon: f64[]
    mut v: f32[]
end

pub fn cat(a: u8[], b: u8[])
    for c in b do
        push(a, c)
    end
end

pub fn putu(a: u8[], v: u32)
    if v >= u32(10) then
        putu(a, v / u32(10))
    end
    push(a, u8(u32(48) + v % u32(10)))
end

pub fn patch_dir(root: u8[], year: u32, id: u32) -> u8[]
    mut p = array[u8](0)
    cat(p, root)
    cat(p, bytes("data"))
    putu(p, year % u32(100))
    push(p, u8(47))
    putu(p, id)
    push(p, u8(47))
    return p
end

pub fn read_ids(path: u8[]) -> u32[]
    d = readfile(path)
    mut ids = array[u32](0)
    mut v = u32(0)
    mut have = false
    for c in d do
        if c >= u8(48) and c <= u8(57) then
            v = v * u32(10) + u32(c) - u32(48)
            have = true
        else
            if have then
                push(ids, v)
            end
            v = u32(0)
            have = false
        end
    end
    if have then
        push(ids, v)
    end
    return ids
end

fn mdays(m: u32, leap: bool) -> u32
    if m == u32(2) then
        if leap then
            return u32(29)
        end
        return u32(28)
    end
    if m == u32(4) or m == u32(6) or m == u32(9) or m == u32(11) then
        return u32(30)
    end
    return u32(31)
end

pub fn doy_of(y: u32, m: u32, d: u32) -> u32
    leap = y % u32(4) == u32(0)
    mut r = d
    mut k = u32(1)
    while k < m do
        r = r + mdays(k, leap)
        k = k + u32(1)
    end
    return r
end

pub fn doy(date: u32) -> u32
    return doy_of(date / u32(10000), (date / u32(100)) % u32(100), date % u32(100))
end

pub fn list_dates(dir: u8[]) -> u32[]
    d = readfile(dir)
    mut out = array[u32](0)
    n = len(d)
    mut i = u32(0)
    while i < n do
        mut e = i
        while e < n and d[e] != u8(10) do
            e = e + u32(1)
        end
        mut le = e
        if le > i and d[le - u32(1)] == u8(13) then
            le = le - u32(1)
        end
        if le - i == u32(16) then
            if d[i + u32(8)] == u8(95) and d[i + u32(9)] == u8(49) and d[i + u32(10)] == u8(48) and d[i + u32(11)] == u8(109) then
                mut v = u32(0)
                mut k = u32(0)
                while k < u32(8) do
                    v = v * u32(10) + u32(d[i + k]) - u32(48)
                    k = k + u32(1)
                end
                push(out, v)
            end
        end
        i = e + u32(1)
    end
    return out
end

pub fn crop_map(path: u8[]) -> u32[]
    d = readfile(path)
    mut m = array[u32](65536)
    mut idx = u32(0)
    mut v = u32(0)
    mut inid = true
    for c in d do
        if inid then
            if c >= u8(48) and c <= u8(57) then
                v = v * u32(10) + u32(c) - u32(48)
            end
            if c == u8(124) then
                m[v] = idx
                idx = idx + u32(1)
                inid = false
            end
        end
        if c == u8(10) then
            inid = true
            v = u32(0)
        end
    end
    return m
end

fn sample_path(dir: u8[], date: u32, res: u8[]) -> u8[]
    mut p = array[u8](0)
    cat(p, dir)
    putu(p, date)
    cat(p, res)
    return p
end

fn soil_name(i: u32) -> u8[]
    if i == u32(0) then
        return bytes("phh2o_")
    end
    if i == u32(1) then
        return bytes("soc_")
    end
    if i == u32(2) then
        return bytes("clay_")
    end
    return bytes("sand_")
end

fn depth_name(i: u32) -> u8[]
    if i == u32(0) then
        return bytes("0-5cm.tif")
    end
    if i == u32(1) then
        return bytes("5-15cm.tif")
    end
    if i == u32(2) then
        return bytes("15-30cm.tif")
    end
    if i == u32(3) then
        return bytes("30-60cm.tif")
    end
    if i == u32(4) then
        return bytes("60-100cm.tif")
    end
    return bytes("100-200cm.tif")
end

pub fn load_soil(dir: u8[]) -> Soil
    nl = NSOIL + u32(1)
    mut s = Soil(nl: nl, w: array[u32](nl), h: array[u32](nl), off: array[u32](nl), x0: array[f64](nl), y0: array[f64](nl),
                 dx: array[f64](nl), dy: array[f64](nl), v: array[f32](0))
    mut l = u32(0)
    while l < nl do
        mut p = array[u8](0)
        cat(p, dir)
        if l < NSOIL then
            cat(p, soil_name(l / u32(6)))
            cat(p, depth_name(l % u32(6)))
        else
            cat(p, bytes("wrb.tif"))
        end
        t = T.read(p)
        s.w[l] = t.w
        s.h[l] = t.h
        s.x0[l] = t.x0
        s.y0[l] = t.y0
        s.dx[l] = t.dx
        s.dy[l] = t.dy
        s.off[l] = len(s.v)
        mut q = u32(0)
        while q < t.w * t.h do
            push(s.v, t.px[q])
            q = q + u32(1)
        end
        l = l + u32(1)
    end
    return s
end

pub fn soil_at(s: Soil, l: u32, lat: f64, lon: f64) -> f32
    fx = (lon - s.x0[l]) / s.dx[l]
    fy = (s.y0[l] - lat) / s.dy[l]
    if fx < 0.0 or fy < 0.0 or fx >= f64(s.w[l]) or fy >= f64(s.h[l]) then
        return f32(-1.0)
    end
    return s.v[s.off[l] + u32(fy) * s.w[l] + u32(fx)]
end

pub fn load_patch(dir: u8[], cm: u32[], s: Soil) -> Patch
    mut pt = Patch(ok: false, x0: 0.0, y0: 0.0, lat: 0.0, lon: 0.0, crop: array[u32](NPIX), bnd: array[u32](NPIX), fp: array[u32](NPIX),
                   nfp: u32(0), soil: array[f32](MAXFP * NSOIL), wrb: array[u32](MAXFP), fpok: array[u32](MAXFP),
                   plat: array[f64](NPIX), plon: array[f64](NPIX))
    mut yp = array[u8](0)
    cat(yp, dir)
    cat(yp, bytes("y.tif"))
    y = T.read(yp)
    if y.err != u32(0) or y.w != N or y.h != N then
        return pt
    end
    pt.x0 = y.x0
    pt.y0 = y.y0
    mut p = u32(0)
    while p < NPIX do
        raw = u32(y.px[p])
        mut c = u32(0)
        if raw < u32(65536) then
            c = cm[raw]
        end
        pt.crop[p] = c
        p = p + u32(1)
    end
    p = u32(0)
    while p < NPIX do
        i = p / N
        j = p % N
        c = pt.crop[p]
        mut b = u32(0)
        if i > u32(0) and pt.crop[p - N] != c then
            b = u32(1)
        end
        if i + u32(1) < N and pt.crop[p + N] != c then
            b = u32(1)
        end
        if j > u32(0) and pt.crop[p - u32(1)] != c then
            b = u32(1)
        end
        if j + u32(1) < N and pt.crop[p + u32(1)] != c then
            b = u32(1)
        end
        pt.bnd[p] = b
        p = p + u32(1)
    end
    side = f64(N) * 10.0
    c00 = U.to_latlon(y.x0, y.y0, ZONE, false)
    c01 = U.to_latlon(y.x0 + side, y.y0, ZONE, false)
    c10 = U.to_latlon(y.x0, y.y0 - side, ZONE, false)
    c11 = U.to_latlon(y.x0 + side, y.y0 - side, ZONE, false)
    cc = U.to_latlon(y.x0 + side / 2.0, y.y0 - side / 2.0, ZONE, false)
    pt.lat = cc.0
    pt.lon = cc.1
    mut cells = array[u32](MAXFP)
    p = u32(0)
    while p < NPIX do
        u = (f64(p % N) + 0.5) / f64(N)
        v = (f64(p / N) + 0.5) / f64(N)
        la = (c00.0 * (1.0 - u) + c01.0 * u) * (1.0 - v) + (c10.0 * (1.0 - u) + c11.0 * u) * v
        lo = (c00.1 * (1.0 - u) + c01.1 * u) * (1.0 - v) + (c10.1 * (1.0 - u) + c11.1 * u) * v
        pt.plat[p] = la
        pt.plon[p] = lo
        fx = (lo - s.x0[0]) / s.dx[0]
        fy = (s.y0[0] - la) / s.dy[0]
        mut f = NOFP
        if fx >= 0.0 and fy >= 0.0 and fx < f64(s.w[0]) and fy < f64(s.h[0]) then
            cell = u32(fy) * s.w[0] + u32(fx)
            mut k = u32(0)
            while k < pt.nfp and f == NOFP do
                if cells[k] == cell then
                    f = k
                end
                k = k + u32(1)
            end
            if f == NOFP and pt.nfp < MAXFP then
                cells[pt.nfp] = cell
                f = pt.nfp
                pt.nfp = pt.nfp + u32(1)
            end
        end
        pt.fp[p] = f
        p = p + u32(1)
    end
    mut f = u32(0)
    while f < pt.nfp do
        row = cells[f] / s.w[0]
        col = cells[f] % s.w[0]
        la = s.y0[0] - (f64(row) + 0.5) * s.dy[0]
        lo = s.x0[0] + (f64(col) + 0.5) * s.dx[0]
        mut good = u32(1)
        mut l = u32(0)
        while l < NSOIL do
            raw = soil_at(s, l, la, lo)
            if raw <= f32(0.0) then
                good = u32(0)
            end
            pt.soil[f * NSOIL + l] = raw / f32(10.0)
            l = l + u32(1)
        end
        w = soil_at(s, NSOIL, la, lo)
        if w < f32(0.0) or w > f32(200.0) then
            good = u32(0)
            pt.wrb[f] = u32(0)
        else
            pt.wrb[f] = u32(w)
        end
        pt.fpok[f] = good
        f = f + u32(1)
    end
    pt.ok = true
    return pt
end

pub fn unmix_prep(em: f64[], pq: f32[])
    del2 = 100.0
    mut a = array[f64](16)
    mut i = u32(0)
    while i < u32(4) do
        mut j = u32(0)
        while j < u32(4) do
            mut s = del2
            mut b = u32(0)
            while b < NBAND do
                s = s + em[b * u32(4) + i] * em[b * u32(4) + j]
                b = b + u32(1)
            end
            a[i * u32(4) + j] = s
            j = j + u32(1)
        end
        i = i + u32(1)
    end
    mut inv = array[f64](16)
    i = u32(0)
    while i < u32(4) do
        inv[i * u32(5)] = 1.0
        i = i + u32(1)
    end
    mut c = u32(0)
    while c < u32(4) do
        piv = a[c * u32(5)]
        mut j = u32(0)
        while j < u32(4) do
            a[c * u32(4) + j] = a[c * u32(4) + j] / piv
            inv[c * u32(4) + j] = inv[c * u32(4) + j] / piv
            j = j + u32(1)
        end
        mut r = u32(0)
        while r < u32(4) do
            if r != c then
                fct = a[r * u32(4) + c]
                j = u32(0)
                while j < u32(4) do
                    a[r * u32(4) + j] = a[r * u32(4) + j] - fct * a[c * u32(4) + j]
                    inv[r * u32(4) + j] = inv[r * u32(4) + j] - fct * inv[c * u32(4) + j]
                    j = j + u32(1)
                end
            end
            r = r + u32(1)
        end
        c = c + u32(1)
    end
    i = u32(0)
    while i < u32(4) do
        mut b = u32(0)
        while b < NBAND do
            mut s = 0.0
            mut k = u32(0)
            while k < u32(4) do
                s = s + inv[i * u32(4) + k] * em[b * u32(4) + k]
                k = k + u32(1)
            end
            pq[i * NBAND + b] = f32(s)
            b = b + u32(1)
        end
        mut sq = 0.0
        mut k = u32(0)
        while k < u32(4) do
            sq = sq + inv[i * u32(4) + k] * del2
            k = k + u32(1)
        end
        pq[u32(40) + i] = f32(sq)
        i = i + u32(1)
    end
end

pub fn unmix(pq: f32[], r: f32[], ro: u32, stride: u32, a: f32[])
    mut s = f32(0.0)
    mut i = u32(0)
    while i < u32(4) do
        mut v = pq[u32(40) + i]
        mut b = u32(0)
        while b < NBAND do
            v = v + pq[i * NBAND + b] * r[ro + b * stride]
            b = b + u32(1)
        end
        v = max(v, f32(0.0))
        a[i] = v
        s = s + v
        i = i + u32(1)
    end
    if s <= f32(0.0) then
        s = f32(1.0)
        a[0] = f32(1.0)
    end
    i = u32(0)
    while i < u32(4) do
        a[i] = a[i] / s
        i = i + u32(1)
    end
end

pub fn unmix_r(pq: f32[], r: f32[], ro: u32, stride: u32) -> f32[]
    mut a = array[f32](4)
    unmix(pq, r, ro, stride, a)
    return a
end

pub fn ratio(a: f32, b: f32) -> f32
    return (a - b) / (a + b + f32(0.000001))
end

pub fn load_refl(dir: u8[], date: u32, refl: f32[], ro: u32) -> bool
    t10 = T.read(sample_path(dir, date, bytes("_10m.tif")))
    t20 = T.read(sample_path(dir, date, bytes("_20m.tif")))
    if t10.err != u32(0) or t20.err != u32(0) or t10.w != N or t10.nb != u32(4) or t20.w != N / u32(2) or t20.nb != u32(6) then
        return false
    end
    mut bright = u32(0)
    mut zero = u32(0)
    mut blue = f32(0.0)
    mut p = u32(0)
    while p < NPIX do
        i = p / N
        j = p % N
        q = (i / u32(2)) * (N / u32(2)) + j / u32(2)
        mut b = u32(0)
        while b < u32(4) do
            refl[ro + b * NPIX + p] = t10.px[p * u32(4) + b] / f32(10000.0)
            b = b + u32(1)
        end
        b = u32(0)
        while b < u32(6) do
            refl[ro + (u32(4) + b) * NPIX + p] = t20.px[q * u32(6) + b] / f32(10000.0)
            b = b + u32(1)
        end
        b2 = refl[ro + p]
        blue = blue + b2
        bright = bright + u32(b2 > f32(0.18))
        zero = zero + u32(t10.px[p * u32(4) + u32(3)] <= f32(0.0))
        p = p + u32(1)
    end
    if zero > u32(0) or bright * u32(50) > NPIX or blue > f32(0.12) * f32(NPIX) then
        return false
    end
    return true
end

pub fn base_channels(refl: f32[], ro: u32, d: u32, norm: f32[], pq: f32[], x: f32[], xo: u32)
    ang = 2.0 * U.PI * f64(d) / 365.25
    sd = f32(U.sin64(ang))
    cd = f32(U.cos64(ang))
    mut p = u32(0)
    while p < NPIX do
        mut b = u32(0)
        while b < NBAND do
            x[xo + b * NPIX + p] = (refl[ro + b * NPIX + p] - norm[b]) / norm[NBAND + b]
            b = b + u32(1)
        end
        b2 = refl[ro + p]
        b3 = refl[ro + NPIX + p]
        b4 = refl[ro + u32(2) * NPIX + p]
        b8 = refl[ro + u32(3) * NPIX + p]
        b5 = refl[ro + u32(4) * NPIX + p]
        b8a = refl[ro + u32(7) * NPIX + p]
        b11 = refl[ro + u32(8) * NPIX + p]
        x[xo + u32(10) * NPIX + p] = ratio(b8, b4)
        x[xo + u32(11) * NPIX + p] = ratio(b8a, b11)
        x[xo + u32(12) * NPIX + p] = ratio(b3, b8)
        x[xo + u32(13) * NPIX + p] = ratio(b8a, b5)
        x[xo + u32(14) * NPIX + p] = ratio(b11 + b4, b8 + b2)
        a = unmix_r(pq, refl, ro + p, NPIX)
        x[xo + u32(15) * NPIX + p] = a[0]
        x[xo + u32(16) * NPIX + p] = a[1]
        x[xo + u32(17) * NPIX + p] = a[2]
        x[xo + u32(18) * NPIX + p] = a[3]
        x[xo + u32(19) * NPIX + p] = sd
        x[xo + u32(20) * NPIX + p] = cd
        p = p + u32(1)
    end
end

fn field(d: u8[], s: u32, e: u32) -> f64
    mut out = array[u64](1)
    if SD.parse_f64(d, s, e, out) == u32(1) then
        return frombits(out[0])
    end
    return -999999.0
end

fn starts(d: u8[], at: u32, s: u8[]) -> bool
    if at + len(s) > len(d) then
        return false
    end
    mut i = u32(0)
    while i < len(s) do
        if d[at + i] != s[i] then
            return false
        end
        i = i + u32(1)
    end
    return true
end

pub fn load_weather(dir: u8[], base: u32) -> Wx
    mut w = Wx(base: base, np: u32(0), lat: array[f64](0), lon: array[f64](0), v: array[f32](0))
    listing = readfile(dir)
    n = len(listing)
    mut i = u32(0)
    while i < n do
        mut e = i
        while e < n and listing[e] != u8(10) do
            e = e + u32(1)
        end
        if starts(listing, i, bytes("om_20")) then
            mut path = array[u8](0)
            cat(path, dir)
            mut k = i
            while k < e and listing[k] != u8(13) do
                push(path, listing[k])
                k = k + u32(1)
            end
            w = parse_csv(w, readfile(path))
        end
        i = e + u32(1)
    end
    return w
end

fn parse_csv(w0: Wx, d: u8[]) -> Wx
    mut w = w0
    mut local = array[u32](1024)
    mut mode = u32(0)
    mut fs = array[u32](16)
    mut fe = array[u32](16)
    n = len(d)
    mut i = u32(0)
    while i < n do
        mut e = i
        while e < n and d[e] != u8(10) do
            e = e + u32(1)
        end
        mut le = e
        if le > i and d[le - u32(1)] == u8(13) then
            le = le - u32(1)
        end
        if le == i then
            mode = u32(0)
        else
            if starts(d, i, bytes("location_id,latitude")) then
                mode = u32(1)
            else
                if starts(d, i, bytes("location_id,time")) then
                    mode = u32(2)
                else
                    mut nf = u32(0)
                    fs[0] = i
                    mut k = i
                    while k < le do
                        if d[k] == u8(44) and nf < u32(15) then
                            fe[nf] = k
                            nf = nf + u32(1)
                            fs[nf] = k + u32(1)
                        end
                        k = k + u32(1)
                    end
                    fe[nf] = le
                    nf = nf + u32(1)
                    lid = u32(field(d, fs[0], fe[0]))
                    if mode == u32(1) and nf >= u32(3) then
                        la = field(d, fs[1], fe[1])
                        lo = field(d, fs[2], fe[2])
                        mut g = w.np
                        mut q = u32(0)
                        while q < w.np do
                            if abs(w.lat[q] - la) < 0.0001 and abs(w.lon[q] - lo) < 0.0001 then
                                g = q
                            end
                            q = q + u32(1)
                        end
                        if g == w.np then
                            push(w.lat, la)
                            push(w.lon, lo)
                            mut z = u32(0)
                            while z < u32(2) * NDAY * u32(5) do
                                push(w.v, f32(-999.0))
                                z = z + u32(1)
                            end
                            w.np = w.np + u32(1)
                        end
                        local[lid] = g
                    end
                    if mode == u32(2) and nf >= u32(7) then
                        ds = fs[1]
                        yr = u32(field(d, ds, ds + u32(4)))
                        mo = u32(field(d, ds + u32(5), ds + u32(7)))
                        dy = u32(field(d, ds + u32(8), ds + u32(10)))
                        if yr >= w.base and yr <= w.base + u32(1) then
                            dd = doy_of(yr, mo, dy)
                            base = ((local[lid] * u32(2) + yr - w.base) * NDAY + dd - u32(1)) * u32(5)
                            mut c = u32(0)
                            while c < u32(5) do
                                vv = field(d, fs[c + u32(2)], fe[c + u32(2)])
                                if vv > -99999.0 then
                                    w.v[base + c] = f32(vv)
                                end
                                c = c + u32(1)
                            end
                        end
                    end
                end
            end
        end
        i = e + u32(1)
    end
    return w
end

fn wxv(w: Wx, q: u32, yi: u32, d: u32, c: u32) -> f32
    return w.v[((q * u32(2) + yi) * NDAY + d - u32(1)) * u32(5) + c]
end

pub fn weather_at(w: Wx, lat: f64, lon: f64, year: u32, d: u32, out: f64[]) -> bool
    yi = year - w.base
    if year < w.base or yi > u32(1) or d < u32(31) or d > NDAY then
        return false
    end
    cl = U.cos64(lat * U.PI / 180.0)
    mut acc = array[f64](4)
    mut wsum = 0.0
    mut used = array[u32](w.np)
    mut t = u32(0)
    while t < u32(4) do
        mut best = 1000000000.0
        mut bq = w.np
        mut q = u32(0)
        while q < w.np do
            if used[q] == u32(0) then
                dla = w.lat[q] - lat
                dlo = (w.lon[q] - lon) * cl
                dist = dla * dla + dlo * dlo
                if dist < best then
                    best = dist
                    bq = q
                end
            end
            q = q + u32(1)
        end
        if bq < w.np then
            used[bq] = u32(1)
            mut good = wxv(w, bq, yi, d, u32(0)) > f32(-998.0) and wxv(w, bq, yi, d, u32(1)) > f32(-998.0) and wxv(w, bq, yi, d, u32(2)) > f32(-998.0)
            mut wb = 0.0
            mut k = d - u32(29)
            while k <= d do
                pr = wxv(w, bq, yi, k, u32(3))
                et = wxv(w, bq, yi, k, u32(4))
                if pr < f32(-998.0) or et < f32(-998.0) then
                    good = false
                end
                wb = wb + f64(pr) - f64(et)
                k = k + u32(1)
            end
            if good then
                wt = 1.0 / (best + 0.000001)
                acc[0] = acc[0] + wt * f64(wxv(w, bq, yi, d, u32(0)))
                acc[1] = acc[1] + wt * f64(wxv(w, bq, yi, d, u32(1)))
                acc[2] = acc[2] + wt * f64(wxv(w, bq, yi, d, u32(2)))
                acc[3] = acc[3] + wt * wb
                wsum = wsum + wt
            end
        end
        t = t + u32(1)
    end
    if wsum <= 0.0 then
        return false
    end
    mut c = u32(0)
    while c < u32(4) do
        out[c] = acc[c] / wsum
        c = c + u32(1)
    end
    return true
end
