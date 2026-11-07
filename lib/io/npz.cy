mut BY = require("bytes.cy")
mut IN = require("inflate.cy")

pub type Members
    mut n: u32
    mut name_at: u32[]
    mut name_len: u32[]
    mut method: u32[]
    mut crc: u32[]
    mut csize: u64[]
    mut usize: u64[]
    mut local: u64[]
end

pub type Npy
    mut ok: bool
    mut descr: u8[]
    mut fortran: bool
    mut shape: u64[]
    mut data: u8[]
    mut at: u32
end

fn sig(d: u8[], p: u32, s: u32) -> bool
    return BY.u32le(d, p) == s
end

fn find_eocd(d: u8[]) -> u32
    n = len(d)
    if n < u32(22) then
        return u32(4294967295)
    end
    mut lo = u32(0)
    if n > u32(65557) then
        lo = n - u32(65557)
    end
    mut e = n - u32(22)
    mut found = u32(4294967295)
    while found == u32(4294967295) and e >= lo do
        if sig(d, e, u32(101010256)) then
            found = e
        else
            if e == u32(0) then
                lo = u32(1)
            else
                e = e - u32(1)
            end
        end
    end
    return found
end

pub fn members(d: u8[]) -> Members
    mut out = Members(n: u32(0), name_at: array[u32](0), name_len: array[u32](0), method: array[u32](0), crc: array[u32](0), csize: array[u64](0), usize: array[u64](0), local: array[u64](0))
    e = find_eocd(d)
    if e == u32(4294967295) then
        return out
    end
    mut count = u64(BY.u16le(d, e + u32(10)))
    mut cd = u64(BY.u32le(d, e + u32(16)))
    if e >= u32(20) and sig(d, e - u32(20), u32(117853008)) then
        z64 = u32(BY.u64le(d, e - u32(20) + u32(8)))
        if sig(d, z64, u32(101075792)) then
            count = BY.u64le(d, z64 + u32(32))
            cd = BY.u64le(d, z64 + u32(48))
        end
    end
    mut p = u32(cd)
    mut i = u64(0)
    mut ok = true
    while i < count and ok do
        if not sig(d, p, u32(33639248)) then
            ok = false
        else
            nl = BY.u16le(d, p + u32(28))
            xl = BY.u16le(d, p + u32(30))
            cl = BY.u16le(d, p + u32(32))
            mut cs = u64(BY.u32le(d, p + u32(20)))
            mut us = u64(BY.u32le(d, p + u32(24)))
            mut lh = u64(BY.u32le(d, p + u32(42)))
            mut x = p + u32(46) + nl
            xe = x + xl
            while x + u32(4) <= xe do
                id = BY.u16le(d, x)
                sz = BY.u16le(d, x + u32(2))
                if id == u32(1) then
                    mut q = x + u32(4)
                    if us == u64(4294967295) then
                        us = BY.u64le(d, q)
                        q = q + u32(8)
                    end
                    if cs == u64(4294967295) then
                        cs = BY.u64le(d, q)
                        q = q + u32(8)
                    end
                    if lh == u64(4294967295) then
                        lh = BY.u64le(d, q)
                    end
                end
                x = x + u32(4) + sz
            end
            push(out.name_at, p + u32(46))
            push(out.name_len, nl)
            push(out.method, BY.u16le(d, p + u32(10)))
            push(out.crc, BY.u32le(d, p + u32(16)))
            push(out.csize, cs)
            push(out.usize, us)
            push(out.local, lh)
            out.n = out.n + u32(1)
            p = p + u32(46) + nl + xl + cl
            i = i + u64(1)
        end
    end
    return out
end

pub fn named(d: u8[], m: Members, i: u32, s: u8[]) -> bool
    if m.name_len[i] != len(s) then
        return false
    end
    mut k = u32(0)
    mut same = true
    while k < len(s) do
        if d[m.name_at[i] + k] != s[k] then
            same = false
        end
        k = k + u32(1)
    end
    return same
end

pub fn extract(d: u8[], m: Members, i: u32, check: bool) -> u8[]
    lh = u32(m.local[i])
    if not sig(d, lh, u32(67324752)) then
        return array[u8](0)
    end
    at = lh + u32(30) + BY.u16le(d, lh + u32(26)) + BY.u16le(d, lh + u32(28))
    n = u32(m.usize[i])
    mut out = array[u8](n)
    if m.method[i] == u32(0) then
        mut k = u32(0)
        while k < n do
            out[k] = d[at + k]
            k = k + u32(1)
        end
    else
        if m.method[i] != u32(8) then
            return array[u8](0)
        end
        got = IN.inflate(d, at, u32(m.csize[i]), out, n)
        if got != n then
            return array[u8](0)
        end
    end
    if check then
        tab = IN.crc_table()
        if IN.crc32(tab, out, u32(0), n) != m.crc[i] then
            return array[u8](0)
        end
    end
    return out
end

pub fn head(d: u8[], m: Members, i: u32, cap: u32) -> u8[]
    lh = u32(m.local[i])
    if not sig(d, lh, u32(67324752)) then
        return array[u8](0)
    end
    at = lh + u32(30) + BY.u16le(d, lh + u32(26)) + BY.u16le(d, lh + u32(28))
    mut out = array[u8](cap)
    if m.method[i] == u32(0) then
        mut k = u32(0)
        while k < cap do
            out[k] = d[at + k]
            k = k + u32(1)
        end
    else
        got = IN.inflate(d, at, u32(m.csize[i]), out, cap)
    end
    return out
end

fn skip_to(b: u8[], p: u32, e: u32, c: u8) -> u32
    mut q = p
    while q < e and b[q] != c do
        q = q + u32(1)
    end
    return q
end

pub fn npy(b: u8[]) -> Npy
    mut r = Npy(ok: false, descr: array[u8](0), fortran: false, shape: array[u64](0), data: b, at: u32(0))
    if len(b) < u32(12) or b[0] != u8(147) or b[1] != u8(78) then
        return r
    end
    major = u32(b[6])
    mut hl = BY.u16le(b, u32(8))
    mut hs = u32(10)
    if major >= u32(2) then
        hl = BY.u32le(b, u32(8))
        hs = u32(12)
    end
    he = hs + hl
    mut p = hs
    while p + u32(6) < he do
        if b[p] == u8(39) and b[p + u32(1)] == u8(100) and b[p + u32(2)] == u8(101) and b[p + u32(3)] == u8(115) then
            q1 = skip_to(b, p + u32(7), he, u8(39))
            q2 = skip_to(b, q1 + u32(1), he, u8(39))
            mut k = q1 + u32(1)
            while k < q2 do
                push(r.descr, b[k])
                k = k + u32(1)
            end
            p = q2
        end
        if b[p] == u8(39) and b[p + u32(1)] == u8(102) and b[p + u32(2)] == u8(111) then
            q = skip_to(b, p + u32(14), he, u8(58))
            mut k2 = q + u32(1)
            while k2 < he and b[k2] == u8(32) do
                k2 = k2 + u32(1)
            end
            r.fortran = b[k2] == u8(84)
        end
        if b[p] == u8(39) and b[p + u32(1)] == u8(115) and b[p + u32(2)] == u8(104) then
            q = skip_to(b, p, he, u8(40))
            qe = skip_to(b, q, he, u8(41))
            mut v = u64(0)
            mut have = false
            mut k3 = q + u32(1)
            while k3 <= qe do
                c = b[k3]
                if c >= u8(48) and c <= u8(57) then
                    v = v * u64(10) + u64(c - u8(48))
                    have = true
                else
                    if have then
                        push(r.shape, v)
                    end
                    v = u64(0)
                    have = false
                end
                k3 = k3 + u32(1)
            end
            p = qe
        end
        p = p + u32(1)
    end
    r.at = he
    r.ok = len(r.descr) > u32(0)
    return r
end

pub fn elements(r: Npy) -> u64
    mut n = u64(1)
    for s in r.shape do
        n = n * s
    end
    return n
end
