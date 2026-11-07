WINK = u32(32768)

fn need(st: u64[], src: u8[], n: u32) -> u32
    mut buf = st[1]
    mut cnt = st[2]
    while cnt < u64(n) do
        mut b = u64(0)
        if st[0] < st[3] then
            b = u64(src[u32(st[0])])
        else
            st[4] = u64(1)
        end
        buf = buf | (b << cnt)
        st[0] = st[0] + u64(1)
        cnt = cnt + u64(8)
    end
    v = buf & ((u64(1) << u64(n)) - u64(1))
    st[1] = buf >> u64(n)
    st[2] = cnt - u64(n)
    return u32(v)
end

fn build(lens: u32[], o: u32, n: u32, count: u32[], symbol: u32[]) -> i32
    mut ln = u32(0)
    while ln < u32(16) do
        count[ln] = u32(0)
        ln = ln + u32(1)
    end
    mut s = u32(0)
    while s < n do
        count[lens[o + s]] = count[lens[o + s]] + u32(1)
        s = s + u32(1)
    end
    if count[0] == n then
        return i32(0)
    end
    mut left = i32(1)
    mut l2 = u32(1)
    while l2 < u32(16) do
        left = left * i32(2) - i32(count[l2])
        if left < i32(0) then
            return left
        end
        l2 = l2 + u32(1)
    end
    mut offs = array[u32](16)
    mut l3 = u32(1)
    while l3 < u32(15) do
        offs[l3 + u32(1)] = offs[l3] + count[l3]
        l3 = l3 + u32(1)
    end
    mut s2 = u32(0)
    while s2 < n do
        l = lens[o + s2]
        if l != u32(0) then
            symbol[offs[l]] = s2
            offs[l] = offs[l] + u32(1)
        end
        s2 = s2 + u32(1)
    end
    return left
end

fn decode(st: u64[], src: u8[], count: u32[], symbol: u32[]) -> i32
    mut code = u32(0)
    mut fst = u32(0)
    mut index = u32(0)
    mut ln = u32(1)
    while ln < u32(16) do
        code = code | need(st, src, u32(1))
        cnt = count[ln]
        if code < fst + cnt then
            return i32(symbol[index + code - fst])
        end
        index = index + cnt
        fst = (fst + cnt) << u32(1)
        code = code << u32(1)
        ln = ln + u32(1)
    end
    return i32(-10)
end

fn lentab(base: u32[], ext: u32[])
    mut b = u32(3)
    mut i = u32(0)
    while i < u32(28) do
        mut e = u32(0)
        if i >= u32(8) then
            e = i / u32(4) - u32(1)
        end
        base[i] = b
        ext[i] = e
        b = b + (u32(1) << e)
        i = i + u32(1)
    end
    base[28] = u32(258)
    ext[28] = u32(0)
end

fn disttab(base: u32[], ext: u32[])
    mut b = u32(1)
    mut i = u32(0)
    while i < u32(30) do
        mut e = u32(0)
        if i >= u32(4) then
            e = i / u32(2) - u32(1)
        end
        base[i] = b
        ext[i] = e
        b = b + (u32(1) << e)
        i = i + u32(1)
    end
end

fn sink(win: u8[], upto: u32, tot: u64[], skip: u32, dst: i16[], stats: f64[])
    mut i = u32(0)
    while i < upto do
        pos = tot[0] + u64(i)
        if pos >= u64(skip) and (pos - u64(skip)) % u64(8) == u64(0) and i + u32(8) <= upto then
            mut bits = u64(0)
            mut k = u32(0)
            while k < u32(8) do
                bits = bits | (u64(win[i + k]) << u64(k * u32(8)))
                k = k + u32(1)
            end
            v = frombits(bits)
            idx = (pos - u64(skip)) / u64(8)
            if idx < u64(len(dst)) then
                r = round(v)
                if r != v or r > 32767.0 or r < -32767.0 then
                    stats[0] = stats[0] + 1.0
                end
                stats[1] = min(stats[1], v)
                stats[2] = max(stats[2], v)
                dst[u32(idx)] = i16(max(min(r, 32767.0), -32767.0))
                stats[3] = stats[3] + 1.0
            end
            i = i + u32(8)
        else
            i = i + u32(1)
        end
    end
    tot[0] = tot[0] + u64(upto)
end

fn put(win: u8[], p: u32, tot: u64[], skip: u32, dst: i16[], stats: f64[]) -> u32
    if p == len(win) then
        keep = WINK
        sink(win, p - keep, tot, skip, dst, stats)
        mut k = u32(0)
        while k < keep do
            win[k] = win[p - keep + k]
            k = k + u32(1)
        end
        return keep
    end
    return p
end

fn codes(st: u64[], src: u8[], lc: u32[], ls: u32[], dc: u32[], ds: u32[], lb: u32[], le: u32[], db: u32[], de: u32[], win: u8[], op: u32[], tot: u64[], skip: u32, dst: i16[], stats: f64[]) -> u32
    mut p = op[0]
    mut done = false
    mut err = u32(0)
    while not done and err == u32(0) do
        sym = decode(st, src, lc, ls)
        if sym < i32(0) then
            err = u32(1)
        else
            if sym < i32(256) then
                win[p] = u8(sym)
                p = put(win, p + u32(1), tot, skip, dst, stats)
            else
                if sym == i32(256) then
                    done = true
                else
                    s = u32(sym) - u32(257)
                    if s >= u32(29) then
                        err = u32(2)
                    else
                        ln = lb[s] + need(st, src, le[s])
                        dsym = decode(st, src, dc, ds)
                        if dsym < i32(0) or dsym >= i32(30) then
                            err = u32(3)
                        else
                            dist = db[u32(dsym)] + need(st, src, de[u32(dsym)])
                            if dist > p then
                                err = u32(4)
                            else
                                mut k = u32(0)
                                while k < ln do
                                    win[p] = win[p - dist]
                                    p = put(win, p + u32(1), tot, skip, dst, stats)
                                    k = k + u32(1)
                                end
                            end
                        end
                    end
                end
            end
        end
        if st[4] != u64(0) then
            err = u32(5)
        end
    end
    op[0] = p
    return err
end

pub fn inflate_f64_i16(src: u8[], o: u32, n: u32, skip: u32, dst: i16[], stats: f64[], chunk: u32) -> u32
    mut st = array[u64](5)
    st[0] = u64(o)
    st[3] = u64(o) + u64(n)
    mut lb = array[u32](29)
    mut le = array[u32](29)
    mut db = array[u32](30)
    mut de = array[u32](30)
    lentab(lb, le)
    disttab(db, de)
    mut lc = array[u32](16)
    mut ls = array[u32](320)
    mut dc = array[u32](16)
    mut ds = array[u32](32)
    mut lens = array[u32](320)
    mut order = array[u32](19)
    order[0] = u32(16)
    order[1] = u32(17)
    order[2] = u32(18)
    order[3] = u32(0)
    order[4] = u32(8)
    order[5] = u32(7)
    order[6] = u32(9)
    order[7] = u32(6)
    order[8] = u32(10)
    order[9] = u32(5)
    order[10] = u32(11)
    order[11] = u32(4)
    order[12] = u32(12)
    order[13] = u32(3)
    order[14] = u32(13)
    order[15] = u32(2)
    order[16] = u32(14)
    order[17] = u32(1)
    order[18] = u32(15)
    mut win = array[u8](WINK + chunk)
    mut tot = array[u64](1)
    stats[0] = 0.0
    stats[1] = 1.0e300
    stats[2] = -1.0e300
    stats[3] = 0.0
    mut op = array[u32](1)
    mut last = u32(0)
    mut err = u32(0)
    while last == u32(0) and err == u32(0) do
        last = need(st, src, u32(1))
        typ = need(st, src, u32(2))
        if typ == u32(0) then
            st[1] = u64(0)
            st[2] = u64(0)
            p = u32(st[0])
            if u64(p) + u64(4) > st[3] then
                err = u32(6)
            else
                ln = u32(src[p]) | (u32(src[p + u32(1)]) << u32(8))
                nlen = u32(src[p + u32(2)]) | (u32(src[p + u32(3)]) << u32(8))
                if (ln ^ nlen) != u32(65535) or u64(p) + u64(4) + u64(ln) > st[3] then
                    err = u32(7)
                else
                    mut k = u32(0)
                    while k < ln do
                        win[op[0]] = src[p + u32(4) + k]
                        op[0] = put(win, op[0] + u32(1), tot, skip, dst, stats)
                        k = k + u32(1)
                    end
                    st[0] = u64(p) + u64(4) + u64(ln)
                end
            end
        else
            if typ == u32(1) then
                mut s = u32(0)
                while s < u32(288) do
                    mut l = u32(8)
                    if s >= u32(144) and s < u32(256) then
                        l = u32(9)
                    end
                    if s >= u32(256) and s < u32(280) then
                        l = u32(7)
                    end
                    lens[s] = l
                    s = s + u32(1)
                end
                b1 = build(lens, u32(0), u32(288), lc, ls)
                mut s2 = u32(0)
                while s2 < u32(30) do
                    lens[s2] = u32(5)
                    s2 = s2 + u32(1)
                end
                b2 = build(lens, u32(0), u32(30), dc, ds)
                err = codes(st, src, lc, ls, dc, ds, lb, le, db, de, win, op, tot, skip, dst, stats)
            else
                if typ == u32(2) then
                    nlen = need(st, src, u32(5)) + u32(257)
                    ndist = need(st, src, u32(5)) + u32(1)
                    ncode = need(st, src, u32(4)) + u32(4)
                    if nlen > u32(286) or ndist > u32(30) then
                        err = u32(8)
                    else
                        mut i = u32(0)
                        while i < u32(19) do
                            lens[i] = u32(0)
                            i = i + u32(1)
                        end
                        mut i2 = u32(0)
                        while i2 < ncode do
                            lens[order[i2]] = need(st, src, u32(3))
                            i2 = i2 + u32(1)
                        end
                        mut cc = array[u32](16)
                        mut cs = array[u32](19)
                        if build(lens, u32(0), u32(19), cc, cs) != i32(0) then
                            err = u32(9)
                        else
                            mut cl = array[u32](320)
                            mut idx = u32(0)
                            while idx < nlen + ndist and err == u32(0) do
                                sym = decode(st, src, cc, cs)
                                if sym < i32(0) then
                                    err = u32(10)
                                else
                                    if sym < i32(16) then
                                        cl[idx] = u32(sym)
                                        idx = idx + u32(1)
                                    else
                                        mut rep = u32(0)
                                        mut val = u32(0)
                                        if sym == i32(16) then
                                            if idx == u32(0) then
                                                err = u32(11)
                                            else
                                                val = cl[idx - u32(1)]
                                            end
                                            rep = u32(3) + need(st, src, u32(2))
                                        else
                                            if sym == i32(17) then
                                                rep = u32(3) + need(st, src, u32(3))
                                            else
                                                rep = u32(11) + need(st, src, u32(7))
                                            end
                                        end
                                        if idx + rep > nlen + ndist then
                                            err = u32(12)
                                        else
                                            mut r = u32(0)
                                            while r < rep do
                                                cl[idx] = val
                                                idx = idx + u32(1)
                                                r = r + u32(1)
                                            end
                                        end
                                    end
                                end
                            end
                            if err == u32(0) then
                                if cl[256] == u32(0) then
                                    err = u32(13)
                                else
                                    b3 = build(cl, u32(0), nlen, lc, ls)
                                    b4 = build(cl, nlen, ndist, dc, ds)
                                    if b3 < i32(0) or b4 < i32(0) then
                                        err = u32(14)
                                    else
                                        err = codes(st, src, lc, ls, dc, ds, lb, le, db, de, win, op, tot, skip, dst, stats)
                                    end
                                end
                            end
                        end
                    end
                else
                    err = u32(15)
                end
            end
        end
    end
    if err == u32(0) then
        sink(win, op[0], tot, skip, dst, stats)
    end
    return err
end
