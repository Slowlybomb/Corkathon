mut FI = require("fileio.cy")

pub WINK = u32(32768)
TB = u32(10)

pub type Inflater
    mut st: u64[]
    mut src: u8[]
    mut ds: u32[]
    mut lb: u32[]
    mut le: u32[]
    mut db: u32[]
    mut de: u32[]
    mut lc: u32[]
    mut ls: u32[]
    mut dc: u32[]
    mut dsy: u32[]
    mut lt: u32[]
    mut dt: u32[]
    mut lens: u32[]
    mut order: u32[]
end

fn refill(st: u64[], src: u8[])
    st[0] = u64(0)
    st[3] = u64(0)
    if st[6] < st[7] then
        mut n = u64(len(src))
        if st[7] - st[6] < n then
            n = st[7] - st[6]
        end
        got = FI.read_at(st[5], st[6], src, u32(n))
        st[3] = u64(got)
        st[6] = st[6] + u64(got)
    end
end

fn byte(st: u64[], src: u8[]) -> u64
    if st[0] >= st[3] then
        refill(st, src)
    end
    if st[0] < st[3] then
        b = u64(src[u32(st[0])])
        st[0] = st[0] + u64(1)
        return b
    end
    st[8] = st[8] + u64(1)
    return u64(0)
end

fn fill(st: u64[], src: u8[], n: u64)
    while st[2] < n do
        st[1] = st[1] | (byte(st, src) << st[2])
        st[2] = st[2] + u64(8)
    end
end

fn bits(st: u64[], src: u8[], n: u32) -> u32
    if n == u32(0) then
        return u32(0)
    end
    fill(st, src, u64(n))
    v = st[1] & ((u64(1) << u64(n)) - u64(1))
    st[1] = st[1] >> u64(n)
    st[2] = st[2] - u64(n)
    return u32(v)
end

fn build(lens: u32[], o: u32, n: u32, count: u32[], symbol: u32[], tab: u32[]) -> i32
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
    mut z = u32(0)
    while z < len(tab) do
        tab[z] = u32(0)
        z = z + u32(1)
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
    mut next = array[u32](16)
    mut c2 = u32(0)
    mut l5 = u32(1)
    while l5 < u32(16) do
        next[l5] = c2
        c2 = (c2 + count[l5]) << u32(1)
        l5 = l5 + u32(1)
    end
    mut s3 = u32(0)
    while s3 < n do
        l = lens[o + s3]
        if l != u32(0) then
            cd = next[l]
            next[l] = next[l] + u32(1)
            if l <= TB then
                mut r = u32(0)
                mut k = u32(0)
                while k < l do
                    r = (r << u32(1)) | ((cd >> k) & u32(1))
                    k = k + u32(1)
                end
                mut f = r
                while f < (u32(1) << TB) do
                    tab[f] = (s3 << u32(4)) | l
                    f = f + (u32(1) << l)
                end
            end
        end
        s3 = s3 + u32(1)
    end
    return left
end

fn decode(st: u64[], src: u8[], count: u32[], symbol: u32[], tab: u32[]) -> i32
    fill(st, src, u64(TB))
    e = tab[u32(st[1] & u64(1023))]
    if e != u32(0) then
        l = e & u32(15)
        st[1] = st[1] >> u64(l)
        st[2] = st[2] - u64(l)
        return i32(e >> u32(4))
    end
    mut code = u32(0)
    mut fst = u32(0)
    mut index = u32(0)
    mut ln = u32(1)
    while ln < u32(16) do
        code = code | bits(st, src, u32(1))
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

pub fn open(h: u64, at: u64, n: u64, bufsize: u32) -> Inflater
    mut z = Inflater(st: array[u64](9), src: array[u8](bufsize), ds: array[u32](4), lb: array[u32](29), le: array[u32](29), db: array[u32](30), de: array[u32](30), lc: array[u32](16), ls: array[u32](320), dc: array[u32](16), dsy: array[u32](32), lt: array[u32](1024), dt: array[u32](1024), lens: array[u32](320), order: array[u32](19))
    z.st[5] = h
    z.st[6] = at
    z.st[7] = at + n
    mut b = u32(3)
    mut i = u32(0)
    while i < u32(28) do
        mut e = u32(0)
        if i >= u32(8) then
            e = i / u32(4) - u32(1)
        end
        z.lb[i] = b
        z.le[i] = e
        b = b + (u32(1) << e)
        i = i + u32(1)
    end
    z.lb[28] = u32(258)
    z.le[28] = u32(0)
    mut b2 = u32(1)
    mut i2 = u32(0)
    while i2 < u32(30) do
        mut e2 = u32(0)
        if i2 >= u32(4) then
            e2 = i2 / u32(2) - u32(1)
        end
        z.db[i2] = b2
        z.de[i2] = e2
        b2 = b2 + (u32(1) << e2)
        i2 = i2 + u32(1)
    end
    z.order[0] = u32(16)
    z.order[1] = u32(17)
    z.order[2] = u32(18)
    z.order[3] = u32(0)
    z.order[4] = u32(8)
    z.order[5] = u32(7)
    z.order[6] = u32(9)
    z.order[7] = u32(6)
    z.order[8] = u32(10)
    z.order[9] = u32(5)
    z.order[10] = u32(11)
    z.order[11] = u32(4)
    z.order[12] = u32(12)
    z.order[13] = u32(3)
    z.order[14] = u32(13)
    z.order[15] = u32(2)
    z.order[16] = u32(14)
    z.order[17] = u32(1)
    z.order[18] = u32(15)
    return z
end

pub fn done(z: Inflater) -> bool
    return z.ds[0] == u32(3)
end

pub fn error(z: Inflater) -> u32
    return z.ds[3]
end

fn header(z: Inflater) -> u32
    st = z.st
    src = z.src
    last = bits(st, src, u32(1))
    typ = bits(st, src, u32(2))
    z.ds[1] = last
    if typ == u32(0) then
        k = u32(st[2] & u64(7))
        st[1] = st[1] >> u64(k)
        st[2] = st[2] - u64(k)
        ln = bits(st, src, u32(16))
        nlen = bits(st, src, u32(16))
        if (ln ^ nlen) != u32(65535) then
            return u32(7)
        end
        z.ds[2] = ln
        z.ds[0] = u32(2)
        return u32(0)
    end
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
            z.lens[s] = l
            s = s + u32(1)
        end
        b1 = build(z.lens, u32(0), u32(288), z.lc, z.ls, z.lt)
        mut s2 = u32(0)
        while s2 < u32(30) do
            z.lens[s2] = u32(5)
            s2 = s2 + u32(1)
        end
        b2 = build(z.lens, u32(0), u32(30), z.dc, z.dsy, z.dt)
        z.ds[0] = u32(1)
        return u32(0)
    end
    if typ != u32(2) then
        return u32(15)
    end
    nlen2 = bits(st, src, u32(5)) + u32(257)
    ndist = bits(st, src, u32(5)) + u32(1)
    ncode = bits(st, src, u32(4)) + u32(4)
    if nlen2 > u32(286) or ndist > u32(30) then
        return u32(8)
    end
    mut i = u32(0)
    while i < u32(19) do
        z.lens[i] = u32(0)
        i = i + u32(1)
    end
    mut i2 = u32(0)
    while i2 < ncode do
        z.lens[z.order[i2]] = bits(st, src, u32(3))
        i2 = i2 + u32(1)
    end
    mut cc = array[u32](16)
    mut cs = array[u32](19)
    mut ct = array[u32](1024)
    if build(z.lens, u32(0), u32(19), cc, cs, ct) != i32(0) then
        return u32(9)
    end
    mut cl = array[u32](320)
    mut idx = u32(0)
    mut err = u32(0)
    while idx < nlen2 + ndist and err == u32(0) do
        sym = decode(st, src, cc, cs, ct)
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
                    rep = u32(3) + bits(st, src, u32(2))
                else
                    if sym == i32(17) then
                        rep = u32(3) + bits(st, src, u32(3))
                    else
                        rep = u32(11) + bits(st, src, u32(7))
                    end
                end
                if idx + rep > nlen2 + ndist then
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
    if err != u32(0) then
        return err
    end
    if cl[256] == u32(0) then
        return u32(13)
    end
    b3 = build(cl, u32(0), nlen2, z.lc, z.ls, z.lt)
    b4 = build(cl, nlen2, ndist, z.dc, z.dsy, z.dt)
    if b3 < i32(0) or b4 < i32(0) then
        return u32(14)
    end
    z.ds[0] = u32(1)
    return u32(0)
end

pub fn more(z: Inflater, win: u8[], p0: u32) -> u32
    st = z.st
    src = z.src
    ds = z.ds
    mut p = p0
    cap = len(win) - u32(260)
    while p < cap and ds[0] != u32(3) and ds[3] == u32(0) do
        if ds[0] == u32(0) then
            if ds[1] == u32(1) then
                ds[0] = u32(3)
            else
                ds[3] = header(z)
            end
        else
            if ds[0] == u32(2) then
                while ds[2] > u32(0) and p < cap do
                    win[p] = u8(bits(st, src, u32(8)))
                    p = p + u32(1)
                    ds[2] = ds[2] - u32(1)
                end
                if ds[2] == u32(0) then
                    ds[0] = u32(0)
                end
            else
                mut blk = true
                while blk and p < cap and ds[3] == u32(0) do
                    sym = decode(st, src, z.lc, z.ls, z.lt)
                    if sym < i32(256) then
                        if sym < i32(0) then
                            ds[3] = u32(1)
                        else
                            win[p] = u8(sym)
                            p = p + u32(1)
                        end
                    else
                        if sym == i32(256) then
                            blk = false
                            ds[0] = u32(0)
                        else
                            s = u32(sym) - u32(257)
                            if s >= u32(29) then
                                ds[3] = u32(2)
                            else
                                ln = z.lb[s] + bits(st, src, z.le[s])
                                dsym = decode(st, src, z.dc, z.dsy, z.dt)
                                if dsym < i32(0) or dsym >= i32(30) then
                                    ds[3] = u32(3)
                                else
                                    dist = z.db[u32(dsym)] + bits(st, src, z.de[u32(dsym)])
                                    if dist > p then
                                        ds[3] = u32(4)
                                    else
                                        mut k = u32(0)
                                        while k < ln do
                                            win[p] = win[p - dist]
                                            p = p + u32(1)
                                            k = k + u32(1)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        if st[8] > u64(0) and st[2] < st[8] * u64(8) then
            ds[3] = u32(5)
        end
    end
    return p
end

pub fn keep_from(p: u32, used: u32) -> u32
    mut k = used
    if p >= WINK and p - WINK < k then
        k = p - WINK
    end
    if p < WINK then
        k = u32(0)
    end
    return k
end

pub fn slide(win: u8[], from: u32, p: u32) -> u32
    if from == u32(0) then
        return p
    end
    mut k = u32(0)
    while from + k < p do
        win[k] = win[from + k]
        k = k + u32(1)
    end
    return p - from
end
