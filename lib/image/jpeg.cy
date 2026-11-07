mut BY = require("../io/bytes.cy")

pub type Gray
    w: u32
    h: u32
    px: u8[]
end

fn fail() -> Gray
    return Gray(w: u32(0), h: u32(0), px: array[u8](0))
end

fn be16(d: u8[], p: u32) -> u32
    return (u32(d[p]) << u32(8)) | u32(d[p + u32(1)])
end

fn cosd(x: f64) -> f64
    pi = 3.14159265358979323846
    mut v = x
    while v > pi do
        v = v - 2.0 * pi
    end
    while v < 0.0 - pi do
        v = v + 2.0 * pi
    end
    v2 = v * v
    mut term = 1.0
    mut sum = 1.0
    mut k = u32(1)
    while k <= u32(20) do
        term = 0.0 - term * v2 / (f64(2 * k - u32(1)) * f64(2 * k))
        sum = sum + term
        k = k + u32(1)
    end
    return sum
end

fn zigzag() -> u32[]
    mut z = array[u32](64)
    mut k = u32(0)
    mut s = u32(0)
    while s < u32(15) do
        mut i = u32(0)
        while i <= s do
            mut r = i
            mut c = s - i
            if s % u32(2) == u32(0) then
                r = s - i
                c = i
            end
            if r < u32(8) and c < u32(8) then
                z[k] = r * u32(8) + c
                k = k + u32(1)
            end
            i = i + u32(1)
        end
        s = s + u32(1)
    end
    return z
end

fn idct_table() -> f64[]
    mut ct = array[f64](64)
    pi = 3.14159265358979323846
    mut x = u32(0)
    while x < u32(8) do
        mut u = u32(0)
        while u < u32(8) do
            mut cu = 1.0
            if u == u32(0) then
                cu = 0.70710678118654752440
            end
            ct[x * u32(8) + u] = 0.5 * cu * cosd(f64(u32(2) * x + u32(1)) * f64(u) * pi / 16.0)
            u = u + u32(1)
        end
        x = x + u32(1)
    end
    return ct
end

fn bit(st: u32[], d: u8[]) -> u32
    if st[2] == u32(0) then
        mut b = u32(0)
        if st[4] == u32(0) and st[0] < st[3] then
            b = u32(d[st[0]])
            st[0] = st[0] + u32(1)
            if b == u32(255) then
                nb = u32(d[st[0]])
                if nb == u32(0) then
                    st[0] = st[0] + u32(1)
                else
                    st[4] = u32(1)
                    st[0] = st[0] - u32(1)
                    b = u32(0)
                end
            end
        end
        st[1] = b
        st[2] = u32(8)
    end
    st[2] = st[2] - u32(1)
    return (st[1] >> st[2]) & u32(1)
end

fn bits(st: u32[], d: u8[], n: u32) -> u32
    mut v = u32(0)
    mut i = u32(0)
    while i < n do
        v = (v << u32(1)) | bit(st, d)
        i = i + u32(1)
    end
    return v
end

fn extend(v: u32, s: u32) -> i32
    if s == u32(0) then
        return i32(0)
    end
    if v < (u32(1) << (s - u32(1))) then
        return i32(v) - i32(u32(1) << s) + i32(1)
    end
    return i32(v)
end

fn hdecode(st: u32[], d: u8[], t: u32, mincode: i32[], maxcode: i32[], valptr: u32[], vals: u32[]) -> u32
    mut code = i32(bit(st, d))
    mut len = u32(1)
    while len < u32(17) and code > maxcode[t * u32(17) + len] do
        code = (code << u32(1)) | i32(bit(st, d))
        len = len + u32(1)
    end
    if len >= u32(17) then
        return u32(0)
    end
    return vals[t * u32(256) + valptr[t * u32(17) + len] + u32(code - mincode[t * u32(17) + len])]
end

fn block(st: u32[], d: u8[], td: u32, ta: u32, q: u32[], qo: u32, mincode: i32[], maxcode: i32[], valptr: u32[], vals: u32[], dc: i32[], ci: u32, blk: f64[])
    mut k = u32(0)
    while k < u32(64) do
        blk[k] = 0.0
        k = k + u32(1)
    end
    t = hdecode(st, d, td, mincode, maxcode, valptr, vals)
    diff = extend(bits(st, d, t), t)
    dc[ci] = dc[ci] + diff
    blk[0] = f64(dc[ci]) * f64(q[qo])
    mut kk = u32(1)
    while kk < u32(64) do
        rs = hdecode(st, d, u32(4) + ta, mincode, maxcode, valptr, vals)
        r = rs >> u32(4)
        s = rs & u32(15)
        if s == u32(0) then
            if r == u32(15) then
                kk = kk + u32(16)
            else
                kk = u32(64)
            end
        else
            kk = kk + r
            if kk < u32(64) then
                blk[kk] = f64(extend(bits(st, d, s), s)) * f64(q[qo + kk])
            end
            kk = kk + u32(1)
        end
    end
end

pub fn decode_gray(d: u8[], o: u32, n: u32) -> Gray
    if n < u32(4) or u32(d[o]) != u32(255) or u32(d[o + u32(1)]) != u32(216) then
        return fail()
    end
    zz = zigzag()
    ct = idct_table()
    mut q = array[u32](256)
    mut mincode = array[i32](8 * 17)
    mut maxcode = array[i32](8 * 17)
    mut valptr = array[u32](8 * 17)
    mut vals = array[u32](8 * 256)
    mut e0 = u32(0)
    while e0 < u32(8 * 17) do
        maxcode[e0] = i32(-1)
        e0 = e0 + u32(1)
    end
    mut width = u32(0)
    mut height = u32(0)
    mut nf = u32(0)
    mut cid = array[u32](4)
    mut hs = array[u32](4)
    mut vs = array[u32](4)
    mut tq = array[u32](4)
    mut restart = u32(0)
    mut out = array[u8](0)
    mut done = false
    mut ok = true
    end_ = o + n
    mut p = o + u32(2)
    while not done and ok and p + u32(4) <= end_ do
        if u32(d[p]) != u32(255) then
            ok = false
        else
            m = u32(d[p + u32(1)])
            if m == u32(255) then
                p = p + u32(1)
            else
                if m == u32(216) or (m >= u32(208) and m <= u32(215)) then
                    p = p + u32(2)
                else
                    if m == u32(217) then
                        done = true
                    else
                        ln = be16(d, p + u32(2))
                        seg = p + u32(4)
                        segend = p + u32(2) + ln
                        if m == u32(219) then
                            mut s = seg
                            while s < segend do
                                pq = u32(d[s]) >> u32(4)
                                t = u32(d[s]) & u32(3)
                                s = s + u32(1)
                                mut k = u32(0)
                                while k < u32(64) do
                                    if pq == u32(0) then
                                        q[t * u32(64) + k] = u32(d[s])
                                        s = s + u32(1)
                                    else
                                        q[t * u32(64) + k] = be16(d, s)
                                        s = s + u32(2)
                                    end
                                    k = k + u32(1)
                                end
                            end
                        end
                        if m == u32(192) or m == u32(193) then
                            height = be16(d, seg + u32(1))
                            width = be16(d, seg + u32(3))
                            nf = u32(d[seg + u32(5)])
                            if nf > u32(4) then
                                ok = false
                            else
                                mut c = u32(0)
                                while c < nf do
                                    cid[c] = u32(d[seg + u32(6) + u32(3) * c])
                                    hs[c] = u32(d[seg + u32(7) + u32(3) * c]) >> u32(4)
                                    vs[c] = u32(d[seg + u32(7) + u32(3) * c]) & u32(15)
                                    tq[c] = u32(d[seg + u32(8) + u32(3) * c]) & u32(3)
                                    c = c + u32(1)
                                end
                            end
                        end
                        if m == u32(194) or m == u32(195) or m >= u32(197) and m <= u32(207) and m != u32(200) and m != u32(204) then
                            ok = false
                        end
                        if m == u32(196) then
                            mut s = seg
                            while s < segend do
                                t = (u32(d[s]) >> u32(4)) * u32(4) + (u32(d[s]) & u32(3))
                                mut cnt = array[u32](17)
                                mut total = u32(0)
                                mut l = u32(1)
                                while l <= u32(16) do
                                    cnt[l] = u32(d[s + l])
                                    total = total + cnt[l]
                                    l = l + u32(1)
                                end
                                mut v = u32(0)
                                while v < total and v < u32(256) do
                                    vals[t * u32(256) + v] = u32(d[s + u32(17) + v])
                                    v = v + u32(1)
                                end
                                mut code = i32(0)
                                mut k = u32(0)
                                mut l2 = u32(1)
                                while l2 <= u32(16) do
                                    if cnt[l2] == u32(0) then
                                        maxcode[t * u32(17) + l2] = i32(-1)
                                    else
                                        valptr[t * u32(17) + l2] = k
                                        mincode[t * u32(17) + l2] = code
                                        code = code + i32(cnt[l2])
                                        k = k + cnt[l2]
                                        maxcode[t * u32(17) + l2] = code - i32(1)
                                    end
                                    code = code << u32(1)
                                    l2 = l2 + u32(1)
                                end
                                s = s + u32(17) + total
                            end
                        end
                        if m == u32(221) then
                            restart = be16(d, seg)
                        end
                        if m == u32(218) then
                            ns = u32(d[seg])
                            mut sc = array[u32](4)
                            mut std = array[u32](4)
                            mut sta = array[u32](4)
                            mut j = u32(0)
                            while j < ns do
                                sid = u32(d[seg + u32(1) + u32(2) * j])
                                mut c = u32(0)
                                while c < nf do
                                    if cid[c] == sid then
                                        sc[j] = c
                                    end
                                    c = c + u32(1)
                                end
                                std[j] = u32(d[seg + u32(2) + u32(2) * j]) >> u32(4)
                                sta[j] = u32(d[seg + u32(2) + u32(2) * j]) & u32(3)
                                j = j + u32(1)
                            end
                            out = scan(d, segend, end_, width, height, nf, hs, vs, tq, ns, sc, std, sta, restart, q, mincode, maxcode, valptr, vals, zz, ct)
                            done = true
                        end
                        p = segend
                    end
                end
            end
        end
    end
    if not ok or len(out) == u32(0) then
        return fail()
    end
    return Gray(w: width, h: height, px: out)
end

fn scan(d: u8[], at: u32, end_: u32, width: u32, height: u32, nf: u32, hs: u32[], vs: u32[], tq: u32[], ns: u32, sc: u32[], std: u32[], sta: u32[], restart: u32, q: u32[], mincode: i32[], maxcode: i32[], valptr: u32[], vals: u32[], zz: u32[], ct: f64[]) -> u8[]
    mut hmax = u32(1)
    mut vmax = u32(1)
    mut c = u32(0)
    while c < nf do
        hmax = max(hmax, hs[c])
        vmax = max(vmax, vs[c])
        c = c + u32(1)
    end
    mut lw = (width * hs[0] + hmax - u32(1)) / hmax
    mut lh = (height * vs[0] + vmax - u32(1)) / vmax
    mut mcux = u32(0)
    mut mcuy = u32(0)
    if ns == u32(1) then
        cw = (width * hs[sc[0]] + hmax - u32(1)) / hmax
        chh = (height * vs[sc[0]] + vmax - u32(1)) / vmax
        mcux = (cw + u32(7)) / u32(8)
        mcuy = (chh + u32(7)) / u32(8)
    else
        mcux = (width + u32(8) * hmax - u32(1)) / (u32(8) * hmax)
        mcuy = (height + u32(8) * vmax - u32(1)) / (u32(8) * vmax)
    end
    mut pw = mcux * u32(8) * hs[0]
    mut ph = mcuy * u32(8) * vs[0]
    if ns == u32(1) then
        pw = mcux * u32(8)
        ph = mcuy * u32(8)
    end
    mut plane = array[u8](pw * ph)
    mut has0 = false
    mut j0 = u32(0)
    while j0 < ns do
        if sc[j0] == u32(0) then
            has0 = true
        end
        j0 = j0 + u32(1)
    end
    mut st = array[u32](5)
    st[0] = at
    st[3] = end_
    mut dc = array[i32](4)
    mut blk = array[f64](64)
    mut nat = array[f64](64)
    mut tmp = array[f64](64)
    nmcu = mcux * mcuy
    mut mi = u32(0)
    mut left = restart
    while mi < nmcu do
        if restart != u32(0) and left == u32(0) then
            st[2] = u32(0)
            st[4] = u32(0)
            while st[0] + u32(1) < end_ and not (u32(d[st[0]]) == u32(255) and u32(d[st[0] + u32(1)]) >= u32(208) and u32(d[st[0] + u32(1)]) <= u32(215)) do
                st[0] = st[0] + u32(1)
            end
            st[0] = st[0] + u32(2)
            mut z = u32(0)
            while z < u32(4) do
                dc[z] = i32(0)
                z = z + u32(1)
            end
            left = restart
        end
        mx = mi % mcux
        my = mi / mcux
        mut j = u32(0)
        while j < ns do
            ci = sc[j]
            mut bh = hs[ci]
            mut bv = vs[ci]
            if ns == u32(1) then
                bh = u32(1)
                bv = u32(1)
            end
            mut v = u32(0)
            while v < bv do
                mut hh = u32(0)
                while hh < bh do
                    block(st, d, std[j], sta[j], q, tq[ci] * u32(64), mincode, maxcode, valptr, vals, dc, ci, blk)
                    if ci == u32(0) then
                        mut k = u32(0)
                        while k < u32(64) do
                            nat[zz[k]] = blk[k]
                            k = k + u32(1)
                        end
                        mut y = u32(0)
                        while y < u32(8) do
                            mut x = u32(0)
                            while x < u32(8) do
                                mut s = 0.0
                                mut u = u32(0)
                                while u < u32(8) do
                                    s = s + ct[x * u32(8) + u] * nat[y * u32(8) + u]
                                    u = u + u32(1)
                                end
                                tmp[y * u32(8) + x] = s
                                x = x + u32(1)
                            end
                            y = y + u32(1)
                        end
                        bx = (mx * bh + hh) * u32(8)
                        by = (my * bv + v) * u32(8)
                        mut x2 = u32(0)
                        while x2 < u32(8) do
                            mut y2 = u32(0)
                            while y2 < u32(8) do
                                mut s = 128.0
                                mut vv = u32(0)
                                while vv < u32(8) do
                                    s = s + ct[y2 * u32(8) + vv] * tmp[vv * u32(8) + x2]
                                    vv = vv + u32(1)
                                end
                                mut pv = floor(s + 0.5)
                                pv = max(pv, 0.0)
                                pv = min(pv, 255.0)
                                plane[(by + y2) * pw + bx + x2] = u8(pv)
                                y2 = y2 + u32(1)
                            end
                            x2 = x2 + u32(1)
                        end
                    end
                    hh = hh + u32(1)
                end
                v = v + u32(1)
            end
            j = j + u32(1)
        end
        if restart != u32(0) then
            left = left - u32(1)
        end
        mi = mi + u32(1)
    end
    if not has0 then
        return array[u8](0)
    end
    mut out = array[u8](lw * lh)
    mut r = u32(0)
    while r < lh do
        mut c2 = u32(0)
        while c2 < lw do
            out[r * lw + c2] = plane[r * pw + c2]
            c2 = c2 + u32(1)
        end
        r = r + u32(1)
    end
    return out
end
