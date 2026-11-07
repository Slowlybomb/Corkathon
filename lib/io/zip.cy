mut BY = require("bytes.cy")
mut IN = require("inflate.cy")

pub type Zip
    count: u32
    info: u32[]
end

pub fn nameo(z: Zip, i: u32) -> u32
    return z.info[i * u32(7)]
end

pub fn namel(z: Zip, i: u32) -> u32
    return z.info[i * u32(7) + u32(1)]
end

pub fn size(z: Zip, i: u32) -> u32
    return z.info[i * u32(7) + u32(4)]
end

pub fn open(d: u8[]) -> Zip
    n = len(d)
    if n < u32(22) then
        return Zip(count: u32(0), info: array[u32](0))
    end
    mut e = n - u32(22)
    mut found = false
    mut lo = u32(0)
    if n > u32(65557) then
        lo = n - u32(65557)
    end
    while not found and e >= lo do
        if u32(d[e]) == u32(80) and u32(d[e + u32(1)]) == u32(75) and u32(d[e + u32(2)]) == u32(5) and u32(d[e + u32(3)]) == u32(6) then
            found = true
        else
            if e == u32(0) then
                lo = u32(1)
            else
                e = e - u32(1)
            end
        end
    end
    if not found then
        return Zip(count: u32(0), info: array[u32](0))
    end
    count = BY.u16le(d, e + u32(10))
    mut p = BY.u32le(d, e + u32(16))
    mut info = array[u32](count * u32(7))
    mut i = u32(0)
    mut ok = true
    while i < count and ok do
        if BY.u32le(d, p) != u32(33639248) then
            ok = false
        else
            nl = BY.u16le(d, p + u32(28))
            xl = BY.u16le(d, p + u32(30))
            cl = BY.u16le(d, p + u32(32))
            b = i * u32(7)
            info[b] = p + u32(46)
            info[b + u32(1)] = nl
            info[b + u32(2)] = BY.u16le(d, p + u32(10))
            info[b + u32(3)] = BY.u32le(d, p + u32(20))
            info[b + u32(4)] = BY.u32le(d, p + u32(24))
            info[b + u32(5)] = BY.u32le(d, p + u32(16))
            info[b + u32(6)] = BY.u32le(d, p + u32(42))
            p = p + u32(46) + nl + xl + cl
            i = i + u32(1)
        end
    end
    if not ok then
        return Zip(count: u32(0), info: array[u32](0))
    end
    return Zip(count: count, info: info)
end

pub fn extract(d: u8[], z: Zip, i: u32, tab: u32[]) -> u8[]
    b = i * u32(7)
    lh = z.info[b + u32(6)]
    if BY.u32le(d, lh) != u32(67324752) then
        return array[u8](0)
    end
    at = lh + u32(30) + BY.u16le(d, lh + u32(26)) + BY.u16le(d, lh + u32(28))
    n = z.info[b + u32(4)]
    method = z.info[b + u32(2)]
    mut out = array[u8](n)
    if method == u32(0) then
        mut k = u32(0)
        while k < n do
            out[k] = d[at + k]
            k = k + u32(1)
        end
    else
        if method != u32(8) then
            return array[u8](0)
        end
        got = IN.inflate(d, at, z.info[b + u32(3)], out, n)
        if got != n then
            return array[u8](0)
        end
    end
    if IN.crc32(tab, out, u32(0), n) != z.info[b + u32(5)] then
        return array[u8](0)
    end
    return out
end

pub fn named(d: u8[], z: Zip, i: u32, pre: u8[], suf: u8[]) -> bool
    o = z.info[i * u32(7)]
    nl = z.info[i * u32(7) + u32(1)]
    if nl < len(pre) + len(suf) then
        return false
    end
    mut k = u32(0)
    while k < len(pre) do
        if d[o + k] != pre[k] then
            return false
        end
        k = k + u32(1)
    end
    mut j = u32(0)
    while j < len(suf) do
        if d[o + nl - len(suf) + j] != suf[j] then
            return false
        end
        j = j + u32(1)
    end
    return true
end
