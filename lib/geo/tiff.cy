mut BY = require("../io/bytes.cy")
mut IN = require("../io/inflate.cy")
mut SD = require("../io/strtod.cy")

pub type Tiff
    mut err: u32
    mut w: u32
    mut h: u32
    mut nb: u32
    mut px: f32[]
    mut x0: f64
    mut y0: f64
    mut dx: f64
    mut dy: f64
    mut epsg: u32
    mut nodata: f64
    mut hasnodata: bool
end

fn tsize(typ: u32) -> u32
    if typ == u32(3) or typ == u32(8) then
        return u32(2)
    end
    if typ == u32(4) or typ == u32(9) or typ == u32(11) then
        return u32(4)
    end
    if typ == u32(5) or typ == u32(10) or typ == u32(12) or typ == u32(16) or typ == u32(17) then
        return u32(8)
    end
    return u32(1)
end

fn vpos(d: u8[], e: u32) -> u32
    typ = BY.u16le(d, e + u32(2))
    cnt = BY.u32le(d, e + u32(4))
    if tsize(typ) * cnt <= u32(4) then
        return e + u32(8)
    end
    return BY.u32le(d, e + u32(8))
end

fn val(d: u8[], e: u32, k: u32) -> f64
    typ = BY.u16le(d, e + u32(2))
    p = vpos(d, e)
    mut r = 0.0
    if typ == u32(3) then
        r = f64(BY.u16le(d, p + k * u32(2)))
    end
    if typ == u32(4) then
        r = f64(BY.u32le(d, p + k * u32(4)))
    end
    if typ == u32(8) then
        r = f64(i16(BY.u16le(d, p + k * u32(2))))
    end
    if typ == u32(9) then
        r = f64(BY.i32le(d, p + k * u32(4)))
    end
    if typ == u32(11) then
        r = f64(BY.f32le(d, p + k * u32(4)))
    end
    if typ == u32(12) then
        r = BY.f64le(d, p + k * u32(8))
    end
    if typ == u32(16) then
        r = f64(BY.u64le(d, p + k * u32(8)))
    end
    if typ == u32(1) or typ == u32(2) or typ == u32(7) then
        r = f64(d[p + k])
    end
    return r
end

fn find(d: u8[], ifd: u32, tag: u32) -> u32
    n = BY.u16le(d, ifd)
    mut i = u32(0)
    mut at = u32(0)
    while i < n and at == u32(0) do
        e = ifd + u32(2) + i * u32(12)
        if BY.u16le(d, e) == tag then
            at = e
        end
        i = i + u32(1)
    end
    return at
end

fn count(d: u8[], e: u32) -> u32
    return BY.u32le(d, e + u32(4))
end

fn num(d: u8[], ifd: u32, tag: u32, dflt: f64) -> f64
    e = find(d, ifd, tag)
    if e == u32(0) then
        return dflt
    end
    return val(d, e, u32(0))
end

fn sample(buf: u8[], at: u32, bps: u32, fmt: u32) -> f32
    mut v = f32(0.0)
    if bps == u32(8) then
        if fmt == u32(2) then
            v = f32(i8(buf[at]))
        else
            v = f32(buf[at])
        end
    end
    if bps == u32(16) then
        if fmt == u32(2) then
            v = f32(i16(BY.u16le(buf, at)))
        else
            v = f32(BY.u16le(buf, at))
        end
    end
    if bps == u32(32) then
        if fmt == u32(3) then
            v = BY.f32le(buf, at)
        else
            if fmt == u32(2) then
                v = f32(BY.i32le(buf, at))
            else
                v = f32(BY.u32le(buf, at))
            end
        end
    end
    if bps == u32(64) then
        v = f32(BY.f64le(buf, at))
    end
    return v
end

fn unpredict(buf: u8[], rows: u32, cw: u32, spc: u32, bpsamp: u32)
    mut r = u32(0)
    while r < rows do
        mut i = spc
        while i < cw * spc do
            a = (r * cw * spc + i) * bpsamp
            b = (r * cw * spc + i - spc) * bpsamp
            if bpsamp == u32(1) then
                buf[a] = buf[a] + buf[b]
            end
            if bpsamp == u32(2) then
                s = (BY.u16le(buf, a) + BY.u16le(buf, b)) & u32(65535)
                buf[a] = u8(s & u32(255))
                buf[a + u32(1)] = u8(s >> u32(8))
            end
            if bpsamp == u32(4) then
                BY.putu32le(buf, a, BY.u32le(buf, a) + BY.u32le(buf, b))
            end
            i = i + u32(1)
        end
        r = r + u32(1)
    end
end

pub fn empty() -> Tiff
    return Tiff(err: u32(1), w: u32(0), h: u32(0), nb: u32(0), px: array[f32](0), x0: 0.0, y0: 0.0, dx: 1.0, dy: 1.0,
                epsg: u32(0), nodata: 0.0, hasnodata: false)
end

pub fn decode(d: u8[]) -> Tiff
    return decode_window(d, u32(0), u32(0), u32(0), u32(0))
end

pub fn decode_window(d: u8[], wx: u32, wy: u32, ww0: u32, wh0: u32) -> Tiff
    mut t = empty()
    if len(d) < u32(16) then
        return t
    end
    if d[0] != u8(73) or d[1] != u8(73) or BY.u16le(d, u32(2)) != u32(42) then
        return t
    end
    ifd = BY.u32le(d, u32(4))
    w = u32(num(d, ifd, u32(256), 0.0))
    h = u32(num(d, ifd, u32(257), 0.0))
    nb = u32(num(d, ifd, u32(277), 1.0))
    bps = u32(num(d, ifd, u32(258), 8.0))
    comp = u32(num(d, ifd, u32(259), 1.0))
    planar = u32(num(d, ifd, u32(284), 1.0))
    pred = u32(num(d, ifd, u32(317), 1.0))
    fmt = u32(num(d, ifd, u32(339), 1.0))
    t.err = u32(2)
    if comp != u32(1) and comp != u32(8) and comp != u32(32946) then
        return t
    end
    if bps != u32(8) and bps != u32(16) and bps != u32(32) and bps != u32(64) then
        return t
    end
    tiled = find(d, ifd, u32(322)) != u32(0)
    mut cw = w
    mut ch = h
    mut eo = u32(0)
    mut ec = u32(0)
    if tiled then
        cw = u32(num(d, ifd, u32(322), 0.0))
        ch = u32(num(d, ifd, u32(323), 0.0))
        eo = find(d, ifd, u32(324))
        ec = find(d, ifd, u32(325))
    else
        rps = num(d, ifd, u32(278), f64(h))
        if rps < f64(h) then
            ch = u32(rps)
        end
        eo = find(d, ifd, u32(273))
        ec = find(d, ifd, u32(279))
    end
    if eo == u32(0) or ec == u32(0) or cw == u32(0) or ch == u32(0) then
        return t
    end
    across = (w + cw - u32(1)) / cw
    down = (h + ch - u32(1)) / ch
    mut spc = nb
    if planar == u32(2) then
        spc = u32(1)
    end
    bpsamp = bps / u32(8)
    chunkbytes = cw * ch * spc * bpsamp
    mut buf = array[u8](chunkbytes)
    mut ww = ww0
    mut wh = wh0
    if ww == u32(0) or wh == u32(0) then
        ww = w
        wh = h
    end
    mut px = array[f32](ww * wh * nb)
    nchunks = count(d, eo)
    mut k = u32(0)
    while k < nchunks do
        mut kplane = u32(0)
        mut kidx = k
        if planar == u32(2) then
            kplane = k / (across * down)
            kidx = k % (across * down)
        end
        kx0 = (kidx % across) * cw
        ky0 = (kidx / across) * ch
        hit = kx0 < wx + ww and kx0 + cw > wx and ky0 < wy + wh and ky0 + ch > wy
        if hit then
        off = u32(val(d, eo, k))
        cnt = u32(val(d, ec, k))
        if comp == u32(1) then
            m = min(cnt, chunkbytes)
            mut q = u32(0)
            while q < m do
                buf[q] = d[off + q]
                q = q + u32(1)
            end
        else
            mut got = IN.inflate(d, off + u32(2), cnt - u32(2), buf, chunkbytes)
        end
        if pred == u32(2) then
            unpredict(buf, ch, cw, spc, bpsamp)
        end
        mut plane = u32(0)
        mut idx = k
        if planar == u32(2) then
            plane = k / (across * down)
            idx = k % (across * down)
        end
        tx = idx % across
        ty = idx / across
        mut r = u32(0)
        while r < ch do
            y = ty * ch + r
            if y < h then
                mut c = u32(0)
                while c < cw do
                    x = tx * cw + c
                    if x < w and x >= wx and x < wx + ww and y >= wy and y < wy + wh then
                        mut s = u32(0)
                        while s < spc do
                            px[((y - wy) * ww + x - wx) * nb + plane + s] = sample(buf, ((r * cw + c) * spc + s) * bpsamp, bps, fmt)
                            s = s + u32(1)
                        end
                    end
                    c = c + u32(1)
                end
            end
            r = r + u32(1)
        end
        end
        k = k + u32(1)
    end
    t.w = ww
    t.h = wh
    t.nb = nb
    t.px = px
    es = find(d, ifd, u32(33550))
    et = find(d, ifd, u32(33922))
    if es != u32(0) and et != u32(0) then
        t.dx = val(d, es, u32(0))
        t.dy = val(d, es, u32(1))
        t.x0 = val(d, et, u32(3)) - val(d, et, u32(0)) * t.dx + f64(wx) * t.dx
        t.y0 = val(d, et, u32(4)) + val(d, et, u32(1)) * t.dy - f64(wy) * t.dy
    end
    eg = find(d, ifd, u32(34735))
    if eg != u32(0) then
        nk = u32(val(d, eg, u32(3)))
        mut i = u32(0)
        mut proj = u32(0)
        mut geog = u32(0)
        while i < nk do
            key = u32(val(d, eg, u32(4) + i * u32(4)))
            loc = u32(val(d, eg, u32(5) + i * u32(4)))
            v = u32(val(d, eg, u32(7) + i * u32(4)))
            if loc == u32(0) then
                if key == u32(3072) then
                    proj = v
                end
                if key == u32(2048) then
                    geog = v
                end
                if key == u32(1025) and v == u32(2) then
                    t.x0 = t.x0 - t.dx / 2.0
                    t.y0 = t.y0 + t.dy / 2.0
                end
            end
            i = i + u32(1)
        end
        t.epsg = geog
        if proj != u32(0) and proj != u32(32767) then
            t.epsg = proj
        end
    end
    en = find(d, ifd, u32(42113))
    if en != u32(0) then
        p = vpos(d, en)
        mut e = p
        while e < p + count(d, en) and d[e] != u8(0) do
            e = e + u32(1)
        end
        mut out = array[u64](1)
        if SD.parse_f64(d, p, e, out) == u32(1) then
            t.nodata = frombits(out[0])
            t.hasnodata = true
        end
    end
    t.err = u32(0)
    return t
end

pub fn get(t: Tiff, x: u32, y: u32, b: u32) -> f32
    return t.px[(y * t.w + x) * t.nb + b]
end

pub fn bilinear(t: Tiff, mx: f64, my: f64, b: u32) -> f32
    fx = (mx - t.x0) / t.dx - 0.5
    fy = (t.y0 - my) / t.dy - 0.5
    mut cx = max(0.0, min(fx, f64(t.w) - 1.0))
    mut cy = max(0.0, min(fy, f64(t.h) - 1.0))
    x0 = u32(floor(cx))
    y0 = u32(floor(cy))
    x1 = min(x0 + u32(1), t.w - u32(1))
    y1 = min(y0 + u32(1), t.h - u32(1))
    ax = f32(cx - floor(cx))
    ay = f32(cy - floor(cy))
    top = get(t, x0, y0, b) * (f32(1.0) - ax) + get(t, x1, y0, b) * ax
    bot = get(t, x0, y1, b) * (f32(1.0) - ax) + get(t, x1, y1, b) * ax
    return top * (f32(1.0) - ay) + bot * ay
end

pub fn read(path: u8[]) -> Tiff
    return decode(readfile(path))
end

fn p16(b: u8[], v: u32)
    push(b, u8(v & u32(255)))
    push(b, u8((v >> u32(8)) & u32(255)))
end

fn p32(b: u8[], v: u32)
    p16(b, v & u32(65535))
    p16(b, v >> u32(16))
end

fn p64(b: u8[], v: f64)
    bits = tobits(v)
    p32(b, u32(bits & u64(4294967295)))
    p32(b, u32(bits >> u64(32)))
end

fn entry(b: u8[], tag: u32, typ: u32, cnt: u32, val: u32)
    p16(b, tag)
    p16(b, typ)
    p32(b, cnt)
    p32(b, val)
end

pub fn encode_f32(px: f32[], w: u32, h: u32, nb: u32, x0: f64, y0: f64, dx: f64, dy: f64, epsg: u32, nodata: f32) -> u8[]
    ne = u32(15)
    ifd = u32(8)
    extra = ifd + u32(2) + ne * u32(12) + u32(4)
    bps_at = extra
    fmt_at = bps_at + nb * u32(2)
    scale_at = fmt_at + nb * u32(2)
    tie_at = scale_at + u32(24)
    geo_at = tie_at + u32(48)
    nd_at = geo_at + u32(32)
    data_at = nd_at + u32(16)
    nbytes = w * h * nb * u32(4)
    mut b = array[u8](0)
    push(b, u8(73))
    push(b, u8(73))
    p16(b, u32(42))
    p32(b, ifd)
    p16(b, ne)
    entry(b, u32(256), u32(4), u32(1), w)
    entry(b, u32(257), u32(4), u32(1), h)
    if nb == u32(1) then
        entry(b, u32(258), u32(3), u32(1), u32(32))
    else
        if nb == u32(2) then
            entry(b, u32(258), u32(3), u32(2), u32(32) | (u32(32) << u32(16)))
        else
            entry(b, u32(258), u32(3), nb, bps_at)
        end
    end
    entry(b, u32(259), u32(3), u32(1), u32(1))
    entry(b, u32(262), u32(3), u32(1), u32(1))
    entry(b, u32(273), u32(4), u32(1), data_at)
    entry(b, u32(277), u32(3), u32(1), nb)
    entry(b, u32(278), u32(4), u32(1), h)
    entry(b, u32(279), u32(4), u32(1), nbytes)
    entry(b, u32(284), u32(3), u32(1), u32(1))
    if nb == u32(1) then
        entry(b, u32(339), u32(3), u32(1), u32(3))
    else
        if nb == u32(2) then
            entry(b, u32(339), u32(3), u32(2), u32(3) | (u32(3) << u32(16)))
        else
            entry(b, u32(339), u32(3), nb, fmt_at)
        end
    end
    entry(b, u32(33550), u32(12), u32(3), scale_at)
    entry(b, u32(33922), u32(12), u32(6), tie_at)
    entry(b, u32(34735), u32(3), u32(16), geo_at)
    entry(b, u32(42113), u32(2), u32(16), nd_at)
    p32(b, u32(0))
    mut i = u32(0)
    while i < nb do
        p16(b, u32(32))
        i = i + u32(1)
    end
    i = u32(0)
    while i < nb do
        p16(b, u32(3))
        i = i + u32(1)
    end
    p64(b, dx)
    p64(b, dy)
    p64(b, 0.0)
    p64(b, 0.0)
    p64(b, 0.0)
    p64(b, 0.0)
    p64(b, x0)
    p64(b, y0)
    p64(b, 0.0)
    p16(b, u32(1))
    p16(b, u32(1))
    p16(b, u32(0))
    p16(b, u32(3))
    p16(b, u32(1024))
    p16(b, u32(0))
    p16(b, u32(1))
    p16(b, u32(1))
    p16(b, u32(1025))
    p16(b, u32(0))
    p16(b, u32(1))
    p16(b, u32(1))
    p16(b, u32(3072))
    p16(b, u32(0))
    p16(b, u32(1))
    p16(b, epsg)
    mut nds = array[u8](0)
    for c in bytes("-9999") do
        push(nds, c)
    end
    i = u32(0)
    while i < u32(16) do
        if i < len(nds) then
            push(b, nds[i])
        else
            push(b, u8(0))
        end
        i = i + u32(1)
    end
    i = u32(0)
    while i < w * h * nb do
        p32(b, tobits(px[i]))
        i = i + u32(1)
    end
    return b
end
