pub type Jpg
    err: u32
    w: u32
    h: u32
    c: u32
    px: u8[]
end

fn fail(code: u32) -> Jpg
    return Jpg(err: code, w: u32(0), h: u32(0), c: u32(0), px: array[u8](0))
end

fn be16(d: u8[], p: u32) -> u32
    return (u32(d[p]) << u32(8)) | u32(d[p + u32(1)])
end

fn natural() -> u32[]
    mut z = array[u32](80)
    z[0] = u32(0)
    z[1] = u32(1)
    z[2] = u32(8)
    z[3] = u32(16)
    z[4] = u32(9)
    z[5] = u32(2)
    z[6] = u32(3)
    z[7] = u32(10)
    z[8] = u32(17)
    z[9] = u32(24)
    z[10] = u32(32)
    z[11] = u32(25)
    z[12] = u32(18)
    z[13] = u32(11)
    z[14] = u32(4)
    z[15] = u32(5)
    z[16] = u32(12)
    z[17] = u32(19)
    z[18] = u32(26)
    z[19] = u32(33)
    z[20] = u32(40)
    z[21] = u32(48)
    z[22] = u32(41)
    z[23] = u32(34)
    z[24] = u32(27)
    z[25] = u32(20)
    z[26] = u32(13)
    z[27] = u32(6)
    z[28] = u32(7)
    z[29] = u32(14)
    z[30] = u32(21)
    z[31] = u32(28)
    z[32] = u32(35)
    z[33] = u32(42)
    z[34] = u32(49)
    z[35] = u32(56)
    z[36] = u32(57)
    z[37] = u32(50)
    z[38] = u32(43)
    z[39] = u32(36)
    z[40] = u32(29)
    z[41] = u32(22)
    z[42] = u32(15)
    z[43] = u32(23)
    z[44] = u32(30)
    z[45] = u32(37)
    z[46] = u32(44)
    z[47] = u32(51)
    z[48] = u32(58)
    z[49] = u32(59)
    z[50] = u32(52)
    z[51] = u32(45)
    z[52] = u32(38)
    z[53] = u32(31)
    z[54] = u32(39)
    z[55] = u32(46)
    z[56] = u32(53)
    z[57] = u32(60)
    z[58] = u32(61)
    z[59] = u32(54)
    z[60] = u32(47)
    z[61] = u32(55)
    z[62] = u32(62)
    z[63] = u32(63)
    mut i = u32(64)
    while i < u32(80) do
        z[i] = u32(63)
        i = i + u32(1)
    end
    return z
end

fn fill(st: u64[], d: u8[])
    while st[2] < u64(25) do
        mut b = u64(0)
        if st[4] == u64(0) and st[0] < st[3] then
            b = u64(d[u32(st[0])])
            st[0] = st[0] + u64(1)
            if b == u64(255) then
                mut nb = u64(0)
                if st[0] < st[3] then
                    nb = u64(d[u32(st[0])])
                end
                if nb == u64(0) then
                    st[0] = st[0] + u64(1)
                else
                    st[4] = u64(1)
                    st[0] = st[0] - u64(1)
                    b = u64(0)
                end
            end
        end
        st[1] = ((st[1] << u64(8)) | b) & u64(1099511627775)
        st[2] = st[2] + u64(8)
    end
end

fn receive(st: u64[], d: u8[], s: u32) -> u32
    if s == u32(0) then
        return u32(0)
    end
    fill(st, d)
    v = u32((st[1] >> (st[2] - u64(s))) & ((u64(1) << u64(s)) - u64(1)))
    st[2] = st[2] - u64(s)
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

fn hdec(st: u64[], d: u8[], t: u32, maxcode: i32[], valptr: i32[], vals: u8[]) -> u32
    fill(st, d)
    peek = i32((st[1] >> (st[2] - u64(16))) & u64(65535))
    mut l = u32(1)
    mut code = peek >> u32(15)
    while l <= u32(16) and code > maxcode[t * u32(18) + l] do
        l = l + u32(1)
        if l <= u32(16) then
            code = peek >> (u32(16) - l)
        end
    end
    if l > u32(16) then
        st[2] = st[2] - u64(16)
        return u32(0)
    end
    st[2] = st[2] - u64(l)
    return u32(vals[t * u32(256) + u32(valptr[t * u32(18) + l] + code)])
end

fn descale(x: i32, n: u32) -> i32
    return (x + (i32(1) << (n - u32(1)))) >> n
end

fn limit(x: i32) -> u32
    m = x & i32(1023)
    if m < i32(128) then
        return u32(m + i32(128))
    end
    if m < i32(512) then
        return u32(255)
    end
    if m < i32(896) then
        return u32(0)
    end
    return u32(m - i32(896))
end

fn idct(coef: i32[], q: i32[], qo: u32, ws: i32[], out: u8[], o: u32, stride: u32)
    mut c = u32(0)
    while c < u32(8) do
        if coef[c + u32(8)] == i32(0) and coef[c + u32(16)] == i32(0) and coef[c + u32(24)] == i32(0) and coef[c + u32(32)] == i32(0) and coef[c + u32(40)] == i32(0) and coef[c + u32(48)] == i32(0) and coef[c + u32(56)] == i32(0) then
            dc = (coef[c] * q[qo + c]) << u32(2)
            mut r = u32(0)
            while r < u32(8) do
                ws[r * u32(8) + c] = dc
                r = r + u32(1)
            end
        else
            z2 = coef[c + u32(16)] * q[qo + c + u32(16)]
            z3 = coef[c + u32(48)] * q[qo + c + u32(48)]
            z1 = (z2 + z3) * i32(4433)
            t2 = z1 + z3 * i32(-15137)
            t3 = z1 + z2 * i32(6270)
            z2b = coef[c] * q[qo + c]
            z3b = coef[c + u32(32)] * q[qo + c + u32(32)]
            t0 = (z2b + z3b) << u32(13)
            t1 = (z2b - z3b) << u32(13)
            t10 = t0 + t3
            t13 = t0 - t3
            t11 = t1 + t2
            t12 = t1 - t2
            mut o0 = coef[c + u32(56)] * q[qo + c + u32(56)]
            mut o1 = coef[c + u32(40)] * q[qo + c + u32(40)]
            mut o2 = coef[c + u32(24)] * q[qo + c + u32(24)]
            mut o3 = coef[c + u32(8)] * q[qo + c + u32(8)]
            y1 = o0 + o3
            y2 = o1 + o2
            mut y3 = o0 + o2
            mut y4 = o1 + o3
            y5 = (y3 + y4) * i32(9633)
            o0 = o0 * i32(2446)
            o1 = o1 * i32(16819)
            o2 = o2 * i32(25172)
            o3 = o3 * i32(12299)
            ya = y1 * i32(-7373)
            yb = y2 * i32(-20995)
            y3 = y3 * i32(-16069) + y5
            y4 = y4 * i32(-3196) + y5
            o0 = o0 + ya + y3
            o1 = o1 + yb + y4
            o2 = o2 + yb + y3
            o3 = o3 + ya + y4
            ws[c] = descale(t10 + o3, u32(11))
            ws[c + u32(56)] = descale(t10 - o3, u32(11))
            ws[c + u32(8)] = descale(t11 + o2, u32(11))
            ws[c + u32(48)] = descale(t11 - o2, u32(11))
            ws[c + u32(16)] = descale(t12 + o1, u32(11))
            ws[c + u32(40)] = descale(t12 - o1, u32(11))
            ws[c + u32(24)] = descale(t13 + o0, u32(11))
            ws[c + u32(32)] = descale(t13 - o0, u32(11))
        end
        c = c + u32(1)
    end
    mut r = u32(0)
    while r < u32(8) do
        b = r * u32(8)
        z2 = ws[b + u32(2)]
        z3 = ws[b + u32(6)]
        z1 = (z2 + z3) * i32(4433)
        t2 = z1 + z3 * i32(-15137)
        t3 = z1 + z2 * i32(6270)
        t0 = (ws[b] + ws[b + u32(4)]) << u32(13)
        t1 = (ws[b] - ws[b + u32(4)]) << u32(13)
        t10 = t0 + t3
        t13 = t0 - t3
        t11 = t1 + t2
        t12 = t1 - t2
        mut o0 = ws[b + u32(7)]
        mut o1 = ws[b + u32(5)]
        mut o2 = ws[b + u32(3)]
        mut o3 = ws[b + u32(1)]
        y1 = o0 + o3
        y2 = o1 + o2
        mut y3 = o0 + o2
        mut y4 = o1 + o3
        y5 = (y3 + y4) * i32(9633)
        o0 = o0 * i32(2446)
        o1 = o1 * i32(16819)
        o2 = o2 * i32(25172)
        o3 = o3 * i32(12299)
        ya = y1 * i32(-7373)
        yb = y2 * i32(-20995)
        y3 = y3 * i32(-16069) + y5
        y4 = y4 * i32(-3196) + y5
        o0 = o0 + ya + y3
        o1 = o1 + yb + y4
        o2 = o2 + yb + y3
        o3 = o3 + ya + y4
        base = o + r * stride
        out[base] = u8(limit(descale(t10 + o3, u32(18))))
        out[base + u32(7)] = u8(limit(descale(t10 - o3, u32(18))))
        out[base + u32(1)] = u8(limit(descale(t11 + o2, u32(18))))
        out[base + u32(6)] = u8(limit(descale(t11 - o2, u32(18))))
        out[base + u32(2)] = u8(limit(descale(t12 + o1, u32(18))))
        out[base + u32(5)] = u8(limit(descale(t12 - o1, u32(18))))
        out[base + u32(3)] = u8(limit(descale(t13 + o0, u32(18))))
        out[base + u32(4)] = u8(limit(descale(t13 - o0, u32(18))))
        r = r + u32(1)
    end
end

fn block(st: u64[], d: u8[], td: u32, ta: u32, zz: u32[], maxcode: i32[], valptr: i32[], vals: u8[], dc: i32[], ci: u32, coef: i32[]) -> u32
    mut k = u32(0)
    while k < u32(64) do
        coef[k] = i32(0)
        k = k + u32(1)
    end
    t = hdec(st, d, td, maxcode, valptr, vals)
    if t > u32(15) then
        return u32(0)
    end
    dc[ci] = dc[ci] + extend(receive(st, d, t), t)
    coef[0] = dc[ci]
    mut kk = u32(1)
    while kk < u32(64) do
        rs = hdec(st, d, u32(4) + ta, maxcode, valptr, vals)
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
                coef[zz[kk]] = extend(receive(st, d, s), s)
            end
            kk = kk + u32(1)
        end
    end
    return u32(1)
end

fn upsample(pl: u8[], off: u32, stride: u32, dw: u32, dh: u32, hr: u32, vr: u32, w: u32, h: u32, out: u8[], oo: u32)
    mut y = u32(0)
    while y < h do
        mut x = u32(0)
        if hr == u32(1) and vr == u32(1) then
            while x < w do
                out[oo + y * w + x] = pl[off + y * stride + x]
                x = x + u32(1)
            end
        end
        if hr == u32(2) and vr == u32(1) and dw > u32(2) then
            r0 = off + y * stride
            while x < w do
                i = x >> u32(1)
                cur = i32(pl[r0 + i])
                mut v = cur
                if (x & u32(1)) == u32(0) then
                    if i == u32(0) then
                        v = cur
                    else
                        v = (cur * i32(3) + i32(pl[r0 + i - u32(1)]) + i32(1)) >> u32(2)
                    end
                else
                    if i == dw - u32(1) then
                        v = cur
                    else
                        v = (cur * i32(3) + i32(pl[r0 + i + u32(1)]) + i32(2)) >> u32(2)
                    end
                end
                out[oo + y * w + x] = u8(v)
                x = x + u32(1)
            end
        end
        if hr == u32(1) and vr == u32(2) then
            iy = y >> u32(1)
            mut ny = iy
            mut bias = i32(1)
            if (y & u32(1)) == u32(0) then
                if iy > u32(0) then
                    ny = iy - u32(1)
                end
            else
                bias = i32(2)
                if iy + u32(1) < dh then
                    ny = iy + u32(1)
                end
            end
            while x < w do
                out[oo + y * w + x] = u8((i32(pl[off + iy * stride + x]) * i32(3) + i32(pl[off + ny * stride + x]) + bias) >> u32(2))
                x = x + u32(1)
            end
        end
        if hr == u32(2) and vr == u32(2) and dw > u32(2) then
            iy = y >> u32(1)
            mut ny = iy
            if (y & u32(1)) == u32(0) then
                if iy > u32(0) then
                    ny = iy - u32(1)
                end
            else
                if iy + u32(1) < dh then
                    ny = iy + u32(1)
                end
            end
            r0 = off + iy * stride
            r1 = off + ny * stride
            while x < w do
                i = x >> u32(1)
                this = i32(pl[r0 + i]) * i32(3) + i32(pl[r1 + i])
                mut v = i32(0)
                if (x & u32(1)) == u32(0) then
                    if i == u32(0) then
                        v = (this * i32(4) + i32(8)) >> u32(4)
                    else
                        last = i32(pl[r0 + i - u32(1)]) * i32(3) + i32(pl[r1 + i - u32(1)])
                        v = (this * i32(3) + last + i32(8)) >> u32(4)
                    end
                else
                    if i == dw - u32(1) then
                        v = (this * i32(4) + i32(7)) >> u32(4)
                    else
                        nxt = i32(pl[r0 + i + u32(1)]) * i32(3) + i32(pl[r1 + i + u32(1)])
                        v = (this * i32(3) + nxt + i32(7)) >> u32(4)
                    end
                end
                out[oo + y * w + x] = u8(v)
                x = x + u32(1)
            end
        end
        if not (hr == u32(1) and vr == u32(1)) and not (hr == u32(2) and vr == u32(1) and dw > u32(2)) and not (hr == u32(1) and vr == u32(2)) and not (hr == u32(2) and vr == u32(2) and dw > u32(2)) then
            while x < w do
                out[oo + y * w + x] = pl[off + (y / vr) * stride + x / hr]
                x = x + u32(1)
            end
        end
        y = y + u32(1)
    end
end

pub fn decode(d: u8[], o: u32, n: u32) -> Jpg
    if n < u32(4) or u32(d[o]) != u32(255) or u32(d[o + u32(1)]) != u32(216) then
        return fail(u32(1))
    end
    zz = natural()
    mut q = array[i32](256)
    mut maxcode = array[i32](8 * 18)
    mut valptr = array[i32](8 * 18)
    mut vals = array[u8](8 * 256)
    mut e0 = u32(0)
    while e0 < u32(8 * 18) do
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
    mut saw_jfif = false
    mut saw_adobe = false
    mut adobe_tr = u32(0)
    mut have_sof = false
    mut planes = array[u8](0)
    mut poff = array[u32](4)
    mut pstride = array[u32](4)
    mut pdw = array[u32](4)
    mut pdh = array[u32](4)
    mut pbw = array[u32](4)
    mut pbh = array[u32](4)
    mut hmax = u32(1)
    mut vmax = u32(1)
    mut mcux = u32(0)
    mut mcuy = u32(0)
    end_ = o + n
    mut p = o + u32(2)
    mut done = false
    mut err = u32(0)
    mut scans = u32(0)
    while not done and err == u32(0) and p + u32(4) <= end_ do
        if u32(d[p]) != u32(255) then
            err = u32(1)
        else
            m = u32(d[p + u32(1)])
            if m == u32(255) then
                p = p + u32(1)
            else
                if m == u32(216) or m == u32(1) or (m >= u32(208) and m <= u32(215)) then
                    p = p + u32(2)
                else
                    if m == u32(217) then
                        done = true
                    else
                        ln = be16(d, p + u32(2))
                        seg = p + u32(4)
                        mut segend = p + u32(2) + ln
                        if segend > end_ then
                            err = u32(1)
                        end
                        if err == u32(0) and m == u32(219) then
                            mut s = seg
                            while s < segend do
                                pq = u32(d[s]) >> u32(4)
                                t = u32(d[s]) & u32(3)
                                s = s + u32(1)
                                mut k = u32(0)
                                while k < u32(64) do
                                    if pq == u32(0) then
                                        q[t * u32(64) + zz[k]] = i32(d[s])
                                        s = s + u32(1)
                                    else
                                        q[t * u32(64) + zz[k]] = i32(be16(d, s))
                                        s = s + u32(2)
                                    end
                                    k = k + u32(1)
                                end
                            end
                        end
                        if err == u32(0) and (m == u32(192) or m == u32(193)) then
                            if u32(d[seg]) != u32(8) then
                                err = u32(4)
                            else
                                height = be16(d, seg + u32(1))
                                width = be16(d, seg + u32(3))
                                nf = u32(d[seg + u32(5)])
                                if nf != u32(1) and nf != u32(3) then
                                    err = u32(4)
                                else
                                    mut c = u32(0)
                                    while c < nf do
                                        cid[c] = u32(d[seg + u32(6) + u32(3) * c])
                                        hs[c] = u32(d[seg + u32(7) + u32(3) * c]) >> u32(4)
                                        vs[c] = u32(d[seg + u32(7) + u32(3) * c]) & u32(15)
                                        tq[c] = u32(d[seg + u32(8) + u32(3) * c]) & u32(3)
                                        c = c + u32(1)
                                    end
                                    have_sof = true
                                end
                            end
                        end
                        if err == u32(0) and (m == u32(194) or m == u32(195) or (m >= u32(197) and m <= u32(207) and m != u32(200) and m != u32(204))) then
                            err = u32(4)
                        end
                        if err == u32(0) and m == u32(196) then
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
                                    vals[t * u32(256) + v] = d[s + u32(17) + v]
                                    v = v + u32(1)
                                end
                                mut code = i32(0)
                                mut k = i32(0)
                                mut l2 = u32(1)
                                while l2 <= u32(16) do
                                    if cnt[l2] == u32(0) then
                                        maxcode[t * u32(18) + l2] = i32(-1)
                                    else
                                        valptr[t * u32(18) + l2] = k - code
                                        code = code + i32(cnt[l2])
                                        k = k + i32(cnt[l2])
                                        maxcode[t * u32(18) + l2] = code - i32(1)
                                    end
                                    code = code << u32(1)
                                    l2 = l2 + u32(1)
                                end
                                s = s + u32(17) + total
                            end
                        end
                        if err == u32(0) and m == u32(221) then
                            restart = be16(d, seg)
                        end
                        if err == u32(0) and m == u32(224) and ln >= u32(7) and u32(d[seg]) == u32(74) and u32(d[seg + u32(1)]) == u32(70) then
                            saw_jfif = true
                        end
                        if err == u32(0) and m == u32(238) and ln >= u32(14) and u32(d[seg]) == u32(65) and u32(d[seg + u32(1)]) == u32(100) then
                            saw_adobe = true
                            adobe_tr = u32(d[seg + u32(11)])
                        end
                        if err == u32(0) and m == u32(218) then
                            if not have_sof then
                                err = u32(1)
                            else
                                if scans == u32(0) then
                                    hmax = u32(1)
                                    vmax = u32(1)
                                    mut c = u32(0)
                                    while c < nf do
                                        hmax = max(hmax, hs[c])
                                        vmax = max(vmax, vs[c])
                                        c = c + u32(1)
                                    end
                                    if width == u32(0) or height == u32(0) or hmax > u32(4) or vmax > u32(4) then
                                        err = u32(4)
                                    else
                                        mcux = (width + hmax * u32(8) - u32(1)) / (hmax * u32(8))
                                        mcuy = (height + vmax * u32(8) - u32(1)) / (vmax * u32(8))
                                        mut total = u32(0)
                                        c = u32(0)
                                        while c < nf do
                                            pdw[c] = (width * hs[c] + hmax - u32(1)) / hmax
                                            pdh[c] = (height * vs[c] + vmax - u32(1)) / vmax
                                            pbw[c] = mcux * hs[c]
                                            pbh[c] = mcuy * vs[c]
                                            pstride[c] = pbw[c] * u32(8)
                                            poff[c] = total
                                            total = total + pstride[c] * pbh[c] * u32(8)
                                            c = c + u32(1)
                                        end
                                        planes = array[u8](total)
                                    end
                                end
                                if err == u32(0) then
                                    scans = scans + u32(1)
                                    ns = u32(d[seg])
                                    mut sc = array[u32](4)
                                    mut std = array[u32](4)
                                    mut sta = array[u32](4)
                                    mut j = u32(0)
                                    while j < ns and j < u32(4) do
                                        sid = u32(d[seg + u32(1) + u32(2) * j])
                                        mut c = u32(0)
                                        while c < nf do
                                            if cid[c] == sid then
                                                sc[j] = c
                                            end
                                            c = c + u32(1)
                                        end
                                        std[j] = u32(d[seg + u32(2) + u32(2) * j]) >> u32(4)
                                        sta[j] = u32(d[seg + u32(2) + u32(2) * j]) & u32(15)
                                        j = j + u32(1)
                                    end
                                    mut stt = array[u64](5)
                                    stt[0] = u64(segend)
                                    stt[3] = u64(end_)
                                    mut dcp = array[i32](4)
                                    mut coef = array[i32](64)
                                    mut ws = array[i32](64)
                                    mut mcu_total = mcux * mcuy
                                    if ns == u32(1) then
                                        c1 = sc[0]
                                        mcu_total = ((pdw[c1] + u32(7)) >> u32(3)) * ((pdh[c1] + u32(7)) >> u32(3))
                                    end
                                    mut mcu = u32(0)
                                    mut since = u32(0)
                                    while mcu < mcu_total and err == u32(0) do
                                        if restart > u32(0) and since == restart then
                                            stt[1] = u64(0)
                                            stt[2] = u64(0)
                                            mut pp = u32(stt[0])
                                            while pp + u32(1) < end_ and not (u32(d[pp]) == u32(255) and u32(d[pp + u32(1)]) >= u32(208) and u32(d[pp + u32(1)]) <= u32(215)) do
                                                pp = pp + u32(1)
                                            end
                                            stt[0] = u64(pp + u32(2))
                                            stt[4] = u64(0)
                                            dcp[0] = i32(0)
                                            dcp[1] = i32(0)
                                            dcp[2] = i32(0)
                                            dcp[3] = i32(0)
                                            since = u32(0)
                                        end
                                        if ns == u32(1) then
                                            c1 = sc[0]
                                            bw1 = (pdw[c1] + u32(7)) >> u32(3)
                                            bx = mcu % bw1
                                            by = mcu / bw1
                                            if block(stt, d, std[0], sta[0], zz, maxcode, valptr, vals, dcp, u32(0), coef) == u32(0) then
                                                err = u32(1)
                                            else
                                                idct(coef, q, tq[c1] * u32(64), ws, planes, poff[c1] + by * u32(8) * pstride[c1] + bx * u32(8), pstride[c1])
                                            end
                                        else
                                            mx = mcu % mcux
                                            my = mcu / mcux
                                            mut jj = u32(0)
                                            while jj < ns and err == u32(0) do
                                                c1 = sc[jj]
                                                mut vy = u32(0)
                                                while vy < vs[c1] and err == u32(0) do
                                                    mut hx = u32(0)
                                                    while hx < hs[c1] and err == u32(0) do
                                                        if block(stt, d, std[jj], sta[jj], zz, maxcode, valptr, vals, dcp, jj, coef) == u32(0) then
                                                            err = u32(1)
                                                        else
                                                            bx = mx * hs[c1] + hx
                                                            by = my * vs[c1] + vy
                                                            idct(coef, q, tq[c1] * u32(64), ws, planes, poff[c1] + by * u32(8) * pstride[c1] + bx * u32(8), pstride[c1])
                                                        end
                                                        hx = hx + u32(1)
                                                    end
                                                    vy = vy + u32(1)
                                                end
                                                jj = jj + u32(1)
                                            end
                                        end
                                        mcu = mcu + u32(1)
                                        since = since + u32(1)
                                    end
                                    mut pp2 = u32(stt[0])
                                    while pp2 + u32(1) < end_ and not (u32(d[pp2]) == u32(255) and u32(d[pp2 + u32(1)]) != u32(0) and u32(d[pp2 + u32(1)]) != u32(255) and not (u32(d[pp2 + u32(1)]) >= u32(208) and u32(d[pp2 + u32(1)]) <= u32(215))) do
                                        pp2 = pp2 + u32(1)
                                    end
                                    segend = pp2
                                end
                            end
                        end
                        p = segend
                    end
                end
            end
        end
    end
    if err != u32(0) then
        return fail(err)
    end
    if scans == u32(0) then
        return fail(u32(1))
    end
    if nf == u32(1) then
        mut px = array[u8](width * height)
        upsample(planes, poff[0], pstride[0], pdw[0], pdh[0], u32(1), u32(1), width, height, px, u32(0))
        return Jpg(err: u32(0), w: width, h: height, c: u32(1), px: px)
    end
    mut full = array[u8](width * height * u32(3))
    mut c = u32(0)
    while c < u32(3) do
        if hmax % hs[c] != u32(0) or vmax % vs[c] != u32(0) then
            return fail(u32(4))
        end
        upsample(planes, poff[c], pstride[c], pdw[c], pdh[c], hmax / hs[c], vmax / vs[c], width, height, full, c * width * height)
        c = c + u32(1)
    end
    mut ycc = true
    if saw_jfif then
        ycc = true
    else
        if saw_adobe then
            ycc = adobe_tr != u32(0)
        else
            if cid[0] == u32(82) and cid[1] == u32(71) and cid[2] == u32(66) then
                ycc = false
            end
        end
    end
    np = width * height
    mut px = array[u8](np * u32(3))
    mut i = u32(0)
    while i < np do
        yv = i32(full[i])
        cb = i32(full[np + i])
        cr = i32(full[np + np + i])
        if ycc then
            xr = cr - i32(128)
            xb = cb - i32(128)
            rr = yv + ((i32(91881) * xr + i32(32768)) >> u32(16))
            bb = yv + ((i32(116130) * xb + i32(32768)) >> u32(16))
            gg = yv + (((i32(-22554) * xb + i32(32768)) + (i32(-46802) * xr)) >> u32(16))
            px[i * u32(3)] = u8(max(i32(0), min(i32(255), rr)))
            px[i * u32(3) + u32(1)] = u8(max(i32(0), min(i32(255), gg)))
            px[i * u32(3) + u32(2)] = u8(max(i32(0), min(i32(255), bb)))
        else
            px[i * u32(3)] = u8(yv)
            px[i * u32(3) + u32(1)] = u8(cb)
            px[i * u32(3) + u32(2)] = u8(cr)
        end
        i = i + u32(1)
    end
    return Jpg(err: u32(0), w: width, h: height, c: u32(3), px: px)
end
