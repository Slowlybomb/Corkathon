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
    mut len = u32(0)
    while len < u32(16) do
        count[len] = u32(0)
        len = len + u32(1)
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
        ln = lens[o + s2]
        if ln != u32(0) then
            symbol[offs[ln]] = s2
            offs[ln] = offs[ln] + u32(1)
        end
        s2 = s2 + u32(1)
    end
    return left
end

fn decode(st: u64[], src: u8[], count: u32[], symbol: u32[]) -> i32
    mut code = u32(0)
    mut first = u32(0)
    mut index = u32(0)
    mut len = u32(1)
    while len < u32(16) do
        code = code | need(st, src, u32(1))
        cnt = count[len]
        if code < first + cnt then
            return i32(symbol[index + code - first])
        end
        index = index + cnt
        first = (first + cnt) << u32(1)
        code = code << u32(1)
        len = len + u32(1)
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

fn codes(st: u64[], src: u8[], lc: u32[], ls: u32[], dc: u32[], ds: u32[], lb: u32[], le: u32[], db: u32[], de: u32[], out: u8[], cap: u32, op: u32[]) -> u32
    mut p = op[0]
    mut done = false
    mut err = u32(0)
    while not done and err == u32(0) do
        sym = decode(st, src, lc, ls)
        if sym < i32(0) then
            err = u32(1)
        else
            if sym < i32(256) then
                if p < cap then
                    out[p] = u8(sym)
                end
                p = p + u32(1)
            else
                if sym == i32(256) then
                    done = true
                else
                    s = u32(sym) - u32(257)
                    if s >= u32(29) then
                        err = u32(2)
                    else
                        len = lb[s] + need(st, src, le[s])
                        dsym = decode(st, src, dc, ds)
                        if dsym < i32(0) or dsym >= i32(30) then
                            err = u32(3)
                        else
                            dist = db[u32(dsym)] + need(st, src, de[u32(dsym)])
                            if dist > p then
                                err = u32(4)
                            else
                                mut k = u32(0)
                                while k < len do
                                    if p < cap then
                                        out[p] = out[p - dist]
                                    end
                                    p = p + u32(1)
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

pub fn inflate(src: u8[], o: u32, n: u32, out: u8[], cap: u32) -> u32
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
                len = u32(src[p]) | (u32(src[p + u32(1)]) << u32(8))
                nlen = u32(src[p + u32(2)]) | (u32(src[p + u32(3)]) << u32(8))
                if (len ^ nlen) != u32(65535) or u64(p) + u64(4) + u64(len) > st[3] then
                    err = u32(7)
                else
                    mut k = u32(0)
                    while k < len do
                        if op[0] + k < cap then
                            out[op[0] + k] = src[p + u32(4) + k]
                        end
                        k = k + u32(1)
                    end
                    op[0] = op[0] + len
                    st[0] = u64(p) + u64(4) + u64(len)
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
                err = codes(st, src, lc, ls, dc, ds, lb, le, db, de, out, cap, op)
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
                                        err = codes(st, src, lc, ls, dc, ds, lb, le, db, de, out, cap, op)
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
    if err != u32(0) then
        return cap + u32(1) + err
    end
    return op[0]
end

pub fn crc_table() -> u32[]
    mut t = array[u32](256)
    mut n = u32(0)
    while n < u32(256) do
        mut c = n
        mut k = u32(0)
        while k < u32(8) do
            if (c & u32(1)) == u32(1) then
                c = u32(3988292384) ^ (c >> u32(1))
            else
                c = c >> u32(1)
            end
            k = k + u32(1)
        end
        t[n] = c
        n = n + u32(1)
    end
    return t
end

pub fn crc32(t: u32[], d: u8[], o: u32, n: u32) -> u32
    mut c = u32(4294967295)
    mut i = u32(0)
    while i < n do
        c = t[(c ^ u32(d[o + i])) & u32(255)] ^ (c >> u32(8))
        i = i + u32(1)
    end
    return c ^ u32(4294967295)
end

pub fn gzip_data(src: u8[], o: u32) -> u32
    if u32(src[o]) != u32(31) or u32(src[o + u32(1)]) != u32(139) or u32(src[o + u32(2)]) != u32(8) then
        return u32(0)
    end
    flg = u32(src[o + u32(3)])
    mut p = o + u32(10)
    if (flg & u32(4)) != u32(0) then
        xlen = u32(src[p]) | (u32(src[p + u32(1)]) << u32(8))
        p = p + u32(2) + xlen
    end
    if (flg & u32(8)) != u32(0) then
        while src[p] != u8(0) do
            p = p + u32(1)
        end
        p = p + u32(1)
    end
    if (flg & u32(16)) != u32(0) then
        while src[p] != u8(0) do
            p = p + u32(1)
        end
        p = p + u32(1)
    end
    if (flg & u32(2)) != u32(0) then
        p = p + u32(2)
    end
    return p
end
