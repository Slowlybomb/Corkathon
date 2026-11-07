fn coeffs(insize: u32, outsize: u32, bounds: i32[], kk: i32[], ksize: u32)
    scale = f64(insize) / f64(outsize)
    mut fscale = scale
    if fscale < 1.0 then
        fscale = 1.0
    end
    support = fscale
    ss = 1.0 / fscale
    mut tmp = array[f64](ksize)
    mut xx = u32(0)
    while xx < outsize do
        center = (f64(xx) + 0.5) * scale
        mut xmin = i32(center - support + 0.5)
        if xmin < i32(0) then
            xmin = i32(0)
        end
        mut xmax = i32(center + support + 0.5)
        if xmax > i32(insize) then
            xmax = i32(insize)
        end
        xmax = xmax - xmin
        mut ww = 0.0
        mut x = i32(0)
        while x < xmax do
            mut t = (f64(x + xmin) - center + 0.5) * ss
            if t < 0.0 then
                t = 0.0 - t
            end
            mut w = 0.0
            if t < 1.0 then
                w = 1.0 - t
            end
            tmp[u32(x)] = w
            ww = ww + w
            x = x + i32(1)
        end
        x = i32(0)
        while x < xmax do
            if ww != 0.0 then
                tmp[u32(x)] = tmp[u32(x)] / ww
            end
            x = x + i32(1)
        end
        x = i32(0)
        while u32(x) < ksize do
            mut q = 0.0
            if x < xmax then
                q = tmp[u32(x)]
            end
            mut fx = i32(0)
            if q < 0.0 then
                fx = i32(0.0 - 0.5 + q * 4194304.0)
            else
                fx = i32(0.5 + q * 4194304.0)
            end
            kk[xx * ksize + u32(x)] = fx
            x = x + i32(1)
        end
        bounds[xx * u32(2)] = xmin
        bounds[xx * u32(2) + u32(1)] = xmax
        xx = xx + u32(1)
    end
end

fn clip8(v: i32) -> u8
    s = v >> u32(22)
    if s < i32(0) then
        return u8(0)
    end
    if s > i32(255) then
        return u8(255)
    end
    return u8(s)
end

fn hpass(src: u8[], sw: u32, c: u32, row0: u32, row1: u32, bh: i32[], kkh: i32[], kh: u32, nw: u32) -> u8[]
    mut tmp = array[u8]((row1 - row0) * nw * c)
    mut y = row0
    while y < row1 do
        mut xx = u32(0)
        while xx < nw do
            xmin = u32(bh[xx * u32(2)])
            xmax = u32(bh[xx * u32(2) + u32(1)])
            mut ch = u32(0)
            while ch < c do
                mut s = i32(2097152)
                mut x = u32(0)
                while x < xmax do
                    s = s + i32(src[(y * sw + xmin + x) * c + ch]) * kkh[xx * kh + x]
                    x = x + u32(1)
                end
                tmp[((y - row0) * nw + xx) * c + ch] = clip8(s)
                ch = ch + u32(1)
            end
            xx = xx + u32(1)
        end
        y = y + u32(1)
    end
    return tmp
end

fn vpass(src: u8[], sw: u32, c: u32, roff: u32, bv: i32[], kkv: i32[], kv: u32, nh: u32) -> u8[]
    mut out = array[u8](nh * sw * c)
    mut yy = u32(0)
    while yy < nh do
        ymin = u32(bv[yy * u32(2)]) - roff
        ymax = u32(bv[yy * u32(2) + u32(1)])
        mut xx = u32(0)
        while xx < sw * c do
            mut s = i32(2097152)
            mut y = u32(0)
            while y < ymax do
                s = s + i32(src[(ymin + y) * sw * c + xx]) * kkv[yy * kv + y]
                y = y + u32(1)
            end
            out[yy * sw * c + xx] = clip8(s)
            xx = xx + u32(1)
        end
        yy = yy + u32(1)
    end
    return out
end

pub fn bilinear(px: u8[], h: u32, w: u32, c: u32, nh: u32, nw: u32) -> u8[]
    if nh == h and nw == w then
        mut same = array[u8](len(px))
        mut i = u32(0)
        while i < len(px) do
            same[i] = px[i]
            i = i + u32(1)
        end
        return same
    end
    kh = u32(ceil(max(f64(w) / f64(nw), 1.0))) * u32(2) + u32(1)
    kv = u32(ceil(max(f64(h) / f64(nh), 1.0))) * u32(2) + u32(1)
    mut bh = array[i32](nw * u32(2))
    mut kkh = array[i32](nw * kh)
    mut bv = array[i32](nh * u32(2))
    mut kkv = array[i32](nh * kv)
    coeffs(w, nw, bh, kkh, kh)
    coeffs(h, nh, bv, kkv, kv)
    dy = i32(h) - i32(nh)
    dx = i32(w) - i32(nw)
    if dy > i32(0) and dy > dx * i32(2) then
        mid = vpass(px, w, c, u32(0), bv, kkv, kv, nh)
        if nw != w then
            return hpass(mid, w, c, u32(0), nh, bh, kkh, kh, nw)
        end
        return mid
    end
    first = u32(bv[0])
    last = u32(bv[nh * u32(2) - u32(2)] + bv[nh * u32(2) - u32(1)])
    if nw != w then
        tmp = hpass(px, w, c, first, last, bh, kkh, kh, nw)
        if nh != h then
            return vpass(tmp, nw, c, first, bv, kkv, kv, nh)
        end
        return tmp
    end
    return vpass(px, w, c, u32(0), bv, kkv, kv, nh)
end
