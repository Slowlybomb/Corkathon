pub fn rb(tp: u32[], d: u8[]) -> u32
    if tp[0] >= tp[1] then
        tp[2] = u32(1)
        return u32(0)
    end
    b = u32(d[tp[0]])
    tp[0] = tp[0] + u32(1)
    return b
end

pub fn rvar(tp: u32[], d: u8[]) -> u64
    mut r = u64(0)
    mut sh = u64(0)
    mut more = true
    while more and tp[2] == u32(0) and sh < u64(64) do
        b = rb(tp, d)
        r = r | (u64(b & u32(127)) << sh)
        sh = sh + u64(7)
        more = (b & u32(128)) != u32(0)
    end
    return r
end

pub fn zz(v: u64) -> i64
    return i64(v >> u64(1)) ^ (i64(0) - i64(v & u64(1)))
end

pub fn rint(tp: u32[], d: u8[]) -> i64
    return zz(rvar(tp, d))
end

pub fn rbin(tp: u32[], d: u8[]) -> u32
    n = u32(rvar(tp, d))
    at = tp[0]
    if u64(tp[0]) + u64(n) > u64(tp[1]) then
        tp[2] = u32(1)
        tp[0] = tp[1]
    else
        tp[0] = tp[0] + n
    end
    return at
end

pub fn field(tp: u32[], d: u8[], last: i64) -> (u32, i64)
    h = rb(tp, d)
    if h == u32(0) then
        return (u32(0), i64(0))
    end
    typ = h & u32(15)
    delta = h >> u32(4)
    if delta == u32(0) then
        return (typ, rint(tp, d))
    end
    return (typ, last + i64(delta))
end

pub fn list_head(tp: u32[], d: u8[]) -> (u32, u32)
    h = rb(tp, d)
    mut n = h >> u32(4)
    if n == u32(15) then
        n = u32(rvar(tp, d))
    end
    return (n, h & u32(15))
end

pub fn skip(tp: u32[], d: u8[], typ: u32)
    if typ == u32(3) then
        b = rb(tp, d)
    end
    if typ == u32(4) or typ == u32(5) or typ == u32(6) then
        v = rvar(tp, d)
    end
    if typ == u32(7) then
        if tp[0] + u32(8) > tp[1] then
            tp[2] = u32(1)
            tp[0] = tp[1]
        else
            tp[0] = tp[0] + u32(8)
        end
    end
    if typ == u32(8) then
        at = rbin(tp, d)
    end
    if typ == u32(9) or typ == u32(10) then
        lh = list_head(tp, d)
        mut i = u32(0)
        while i < lh.0 and tp[2] == u32(0) do
            if lh.1 == u32(1) or lh.1 == u32(2) then
                b2 = rb(tp, d)
            else
                skip(tp, d, lh.1)
            end
            i = i + u32(1)
        end
    end
    if typ == u32(11) then
        n = u32(rvar(tp, d))
        if n > u32(0) then
            kv = rb(tp, d)
            mut j = u32(0)
            while j < n and tp[2] == u32(0) do
                skip(tp, d, kv >> u32(4))
                skip(tp, d, kv & u32(15))
                j = j + u32(1)
            end
        end
    end
    if typ == u32(12) then
        skip_struct(tp, d)
    end
end

pub fn skip_struct(tp: u32[], d: u8[])
    mut last = i64(0)
    mut more = true
    while more and tp[2] == u32(0) do
        f = field(tp, d, last)
        if f.0 == u32(0) then
            more = false
        else
            last = f.1
            skip(tp, d, f.0)
        end
    end
end
