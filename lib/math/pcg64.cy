fn mixh(value: u32, hc: u32[]) -> u32
    mut v = value ^ hc[0]
    hc[0] = hc[0] * u32(2468251765)
    v = v * hc[0]
    return v ^ (v >> u32(16))
end

fn mix(x: u32, y: u32) -> u32
    r = u32(3389127133) * x - u32(1232336661) * y
    return r ^ (r >> u32(16))
end

fn mulhi64(a: u64, b: u64) -> u64
    m = u64(4294967295)
    a0 = a & m
    a1 = a >> u64(32)
    b0 = b & m
    b1 = b >> u64(32)
    p00 = a0 * b0
    p01 = a0 * b1
    p10 = a1 * b0
    p11 = a1 * b1
    mid = (p00 >> u64(32)) + (p01 & m) + (p10 & m)
    return p11 + (p01 >> u64(32)) + (p10 >> u64(32)) + (mid >> u64(32))
end

fn step(st: u64[])
    mh = u64(2549297995355413924)
    ml = u64(4865540595714422341)
    lo = st[1]
    hi = st[0]
    nlo = lo * ml
    nhi = mulhi64(lo, ml) + hi * ml + lo * mh
    clo = nlo + st[3]
    mut carry = u64(0)
    if clo < nlo then
        carry = u64(1)
    end
    st[1] = clo
    st[0] = nhi + st[2] + carry
end

pub fn pcg64_seed(seed: u64) -> u64[]
    mut ent = array[u32](2)
    ent[0] = u32(seed & u64(4294967295))
    ent[1] = u32(seed >> u64(32))
    mut ne = u32(2)
    if ent[1] == u32(0) then
        ne = u32(1)
    end
    mut hc = array[u32](1)
    hc[0] = u32(1135663077)
    mut pool = array[u32](4)
    mut i = u32(0)
    while i < u32(4) do
        mut v = u32(0)
        if i < ne then
            v = ent[i]
        end
        pool[i] = mixh(v, hc)
        i = i + u32(1)
    end
    mut a = u32(0)
    while a < u32(4) do
        mut b = u32(0)
        while b < u32(4) do
            if a != b then
                pool[b] = mix(pool[b], mixh(pool[a], hc))
            end
            b = b + u32(1)
        end
        a = a + u32(1)
    end
    hc[0] = u32(2337405405)
    mut sw = array[u32](8)
    i = u32(0)
    while i < u32(8) do
        mut dv = pool[i & u32(3)] ^ hc[0]
        hc[0] = hc[0] * u32(1492356589)
        dv = dv * hc[0]
        sw[i] = dv ^ (dv >> u32(16))
        i = i + u32(1)
    end
    v0 = u64(sw[0]) | (u64(sw[1]) << u64(32))
    v1 = u64(sw[2]) | (u64(sw[3]) << u64(32))
    v2 = u64(sw[4]) | (u64(sw[5]) << u64(32))
    v3 = u64(sw[6]) | (u64(sw[7]) << u64(32))
    mut st = array[u64](6)
    st[2] = (v2 << u64(1)) | (v3 >> u64(63))
    st[3] = (v3 << u64(1)) | u64(1)
    st[0] = u64(0)
    st[1] = u64(0)
    step(st)
    lo = st[1] + v1
    mut carry = u64(0)
    if lo < st[1] then
        carry = u64(1)
    end
    st[1] = lo
    st[0] = st[0] + v0 + carry
    step(st)
    return st
end

pub fn pcg64_next64(st: u64[]) -> u64
    step(st)
    x = st[0] ^ st[1]
    rot = st[0] >> u64(58)
    return (x >> rot) | (x << ((u64(64) - rot) & u64(63)))
end

pub fn pcg64_next32(st: u64[]) -> u32
    if st[4] != u64(0) then
        st[4] = u64(0)
        return u32(st[5])
    end
    nx = pcg64_next64(st)
    st[4] = u64(1)
    st[5] = nx >> u64(32)
    return u32(nx & u64(4294967295))
end

pub fn interval(st: u64[], mx: u64) -> u64
    if mx == u64(0) then
        return u64(0)
    end
    mut mask = mx
    mask = mask | (mask >> u64(1))
    mask = mask | (mask >> u64(2))
    mask = mask | (mask >> u64(4))
    mask = mask | (mask >> u64(8))
    mask = mask | (mask >> u64(16))
    mask = mask | (mask >> u64(32))
    mut v = u64(0)
    mut go = true
    while go do
        if mx <= u64(4294967295) then
            v = u64(pcg64_next32(st)) & mask
        else
            v = pcg64_next64(st) & mask
        end
        go = v > mx
    end
    return v
end

pub fn permutation(st: u64[], n: u32) -> u32[]
    mut a = array[u32](n)
    mut i = u32(0)
    while i < n do
        a[i] = i
        i = i + u32(1)
    end
    i = n
    while i > u32(1) do
        i = i - u32(1)
        j = u32(interval(st, u64(i)))
        t = a[i]
        a[i] = a[j]
        a[j] = t
    end
    return a
end

pub fn random_f64(st: u64[]) -> f64
    return f64(pcg64_next64(st) >> u64(11)) * 1.1102230246251565e-16
end
