mut IN = require("../io/inflate.cy")

pub type Png
    err: u32
    w: u32
    h: u32
    ctype: u32
    depth: u32
    nch: u32
    s: u16[]
    palette: u8[]
    alpha: u8[]
end

fn fail(code: u32) -> Png
    return Png(err: code, w: u32(0), h: u32(0), ctype: u32(0), depth: u32(0), nch: u32(0), s: array[u16](0), palette: array[u8](0), alpha: array[u8](0))
end

fn be32(d: u8[], p: u32) -> u32
    return (u32(d[p]) << u32(24)) | (u32(d[p + u32(1)]) << u32(16)) | (u32(d[p + u32(2)]) << u32(8)) | u32(d[p + u32(3)])
end

fn paeth(a: i32, b: i32, c: i32) -> i32
    p = a + b - c
    pa = abs(p - a)
    pb = abs(p - b)
    pc = abs(p - c)
    if pa <= pb and pa <= pc then
        return a
    end
    if pb <= pc then
        return b
    end
    return c
end

fn unfilter_row(raw: u8[], at: u32, prev: u32, has_prev: bool, rb: u32, bpp: u32, ft: u32)
    mut i = u32(0)
    while i < rb do
        mut a = i32(0)
        mut b = i32(0)
        mut c = i32(0)
        if i >= bpp then
            a = i32(raw[at + i - bpp])
        end
        if has_prev then
            b = i32(raw[prev + i])
            if i >= bpp then
                c = i32(raw[prev + i - bpp])
            end
        end
        x = i32(raw[at + i])
        mut v = x
        if ft == u32(1) then
            v = x + a
        end
        if ft == u32(2) then
            v = x + b
        end
        if ft == u32(3) then
            v = x + ((a + b) >> u32(1))
        end
        if ft == u32(4) then
            v = x + paeth(a, b, c)
        end
        raw[at + i] = u8(v & i32(255))
        i = i + u32(1)
    end
end

fn sample(raw: u8[], at: u32, k: u32, depth: u32) -> u32
    if depth == u32(8) then
        return u32(raw[at + k])
    end
    if depth == u32(16) then
        return (u32(raw[at + k * u32(2)]) << u32(8)) | u32(raw[at + k * u32(2) + u32(1)])
    end
    bitpos = k * depth
    byte = u32(raw[at + (bitpos >> u32(3))])
    sh = u32(8) - depth - (bitpos & u32(7))
    return (byte >> sh) & ((u32(1) << depth) - u32(1))
end

pub fn decode(d: u8[], o: u32, n: u32) -> Png
    if n < u32(33) then
        return fail(u32(1))
    end
    sig = d[o] == u8(137) and d[o + u32(1)] == u8(80) and d[o + u32(2)] == u8(78) and d[o + u32(3)] == u8(71) and d[o + u32(4)] == u8(13) and d[o + u32(5)] == u8(10) and d[o + u32(6)] == u8(26) and d[o + u32(7)] == u8(10)
    if not sig then
        return fail(u32(1))
    end
    mut w = u32(0)
    mut h = u32(0)
    mut depth = u32(0)
    mut ctype = u32(0)
    mut interlace = u32(0)
    mut have_ihdr = false
    mut z = array[u8](0)
    mut palette = array[u8](0)
    mut trns = array[u8](0)
    mut p = o + u32(8)
    end_ = o + n
    mut done = false
    while not done and p + u32(12) <= end_ do
        ln = be32(d, p)
        ty = be32(d, p + u32(4))
        body = p + u32(8)
        if body + ln > end_ then
            done = true
        else
            if ty == u32(1229472850) and ln >= u32(13) then
                w = be32(d, body)
                h = be32(d, body + u32(4))
                depth = u32(d[body + u32(8)])
                ctype = u32(d[body + u32(9)])
                interlace = u32(d[body + u32(12)])
                have_ihdr = true
            end
            if ty == u32(1347179589) then
                mut i = u32(0)
                while i < ln do
                    push(palette, d[body + i])
                    i = i + u32(1)
                end
            end
            if ty == u32(1951551059) then
                mut i = u32(0)
                while i < ln do
                    push(trns, d[body + i])
                    i = i + u32(1)
                end
            end
            if ty == u32(1229209940) then
                mut i = u32(0)
                while i < ln do
                    push(z, d[body + i])
                    i = i + u32(1)
                end
            end
            if ty == u32(1229278788) then
                done = true
            end
            p = body + ln + u32(4)
        end
    end
    if not have_ihdr or w == u32(0) or h == u32(0) then
        return fail(u32(2))
    end
    mut nch = u32(1)
    if ctype == u32(2) then
        nch = u32(3)
    end
    if ctype == u32(4) then
        nch = u32(2)
    end
    if ctype == u32(6) then
        nch = u32(4)
    end
    ok_depth = depth == u32(8) or depth == u32(16) or (ctype == u32(0) and (depth == u32(1) or depth == u32(2) or depth == u32(4))) or (ctype == u32(3) and (depth == u32(1) or depth == u32(2) or depth == u32(4)))
    if not ok_depth or (ctype != u32(0) and ctype != u32(2) and ctype != u32(3) and ctype != u32(4) and ctype != u32(6)) or interlace > u32(1) then
        return fail(u32(2))
    end
    if u64(w) * u64(h) * u64(nch) > u64(400000000) then
        return fail(u32(4))
    end
    bpp = max(u32(1), (nch * depth) >> u32(3))
    mut total = u32(0)
    if interlace == u32(0) then
        total = h * (u32(1) + ((w * nch * depth + u32(7)) >> u32(3)))
    else
        mut ps = u32(0)
        while ps < u32(7) do
            pw = pass_dim(w, ps, true)
            ph = pass_dim(h, ps, false)
            if pw > u32(0) and ph > u32(0) then
                total = total + ph * (u32(1) + ((pw * nch * depth + u32(7)) >> u32(3)))
            end
            ps = ps + u32(1)
        end
    end
    if len(z) < u32(3) then
        return fail(u32(3))
    end
    mut raw = array[u8](total)
    got = IN.inflate(z, u32(2), len(z) - u32(2), raw, total)
    if got != total then
        return fail(u32(3))
    end
    mut s = array[u16](w * h * nch)
    mut at = u32(0)
    if interlace == u32(0) then
        mut y = u32(0)
        rb = (w * nch * depth + u32(7)) >> u32(3)
        while y < h do
            unfilter_row(raw, at + u32(1), at + u32(1) - (rb + u32(1)), y > u32(0), rb, bpp, u32(raw[at]))
            mut k = u32(0)
            while k < w * nch do
                s[y * w * nch + k] = u16(sample(raw, at + u32(1), k, depth))
                k = k + u32(1)
            end
            at = at + rb + u32(1)
            y = y + u32(1)
        end
    else
        mut ps = u32(0)
        while ps < u32(7) do
            pw = pass_dim(w, ps, true)
            ph = pass_dim(h, ps, false)
            if pw > u32(0) and ph > u32(0) then
                rb = (pw * nch * depth + u32(7)) >> u32(3)
                x0 = pass_start(ps, true)
                y0 = pass_start(ps, false)
                dx = pass_step(ps, true)
                dy = pass_step(ps, false)
                mut y = u32(0)
                while y < ph do
                    unfilter_row(raw, at + u32(1), at + u32(1) - (rb + u32(1)), y > u32(0), rb, bpp, u32(raw[at]))
                    mut x = u32(0)
                    while x < pw do
                        mut ch = u32(0)
                        while ch < nch do
                            s[((y0 + y * dy) * w + x0 + x * dx) * nch + ch] = u16(sample(raw, at + u32(1), x * nch + ch, depth))
                            ch = ch + u32(1)
                        end
                        x = x + u32(1)
                    end
                    at = at + rb + u32(1)
                    y = y + u32(1)
                end
            end
            ps = ps + u32(1)
        end
    end
    mut alpha = array[u8](0)
    if ctype == u32(3) then
        np = len(palette) / u32(3)
        alpha = array[u8](np)
        mut i = u32(0)
        while i < np do
            alpha[i] = u8(255)
            if i < len(trns) then
                alpha[i] = trns[i]
            end
            i = i + u32(1)
        end
    end
    return Png(err: u32(0), w: w, h: h, ctype: ctype, depth: depth, nch: nch, s: s, palette: palette, alpha: alpha)
end

fn pass_start(ps: u32, horiz: bool) -> u32
    if horiz then
        if ps == u32(1) then
            return u32(4)
        end
        if ps == u32(3) then
            return u32(2)
        end
        if ps == u32(5) then
            return u32(1)
        end
        if ps == u32(2) then
            return u32(0)
        end
        return u32(0)
    end
    if ps == u32(2) then
        return u32(4)
    end
    if ps == u32(4) then
        return u32(2)
    end
    if ps == u32(6) then
        return u32(1)
    end
    return u32(0)
end

fn pass_step(ps: u32, horiz: bool) -> u32
    if horiz then
        if ps == u32(0) or ps == u32(1) then
            return u32(8)
        end
        if ps == u32(2) or ps == u32(3) then
            return u32(4)
        end
        if ps == u32(4) or ps == u32(5) then
            return u32(2)
        end
        return u32(1)
    end
    if ps == u32(0) or ps == u32(1) or ps == u32(2) then
        return u32(8)
    end
    if ps == u32(3) or ps == u32(4) then
        return u32(4)
    end
    return u32(2)
end

fn pass_dim(n: u32, ps: u32, horiz: bool) -> u32
    st = pass_start(ps, horiz)
    sp = pass_step(ps, horiz)
    if n <= st then
        return u32(0)
    end
    return (n - st + sp - u32(1)) / sp
end
