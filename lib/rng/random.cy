mut cc = require("chacha.cy")
mut fast = require("fast.cy")
mut m = require("../math/scalar.cy")

pub type Stream
    key: u32[]
    nonce: u32[]
    mut buf: u32[]
    mut scr: u32[]
    mut at: u32[]
end

pub fn stream(seed: u64) -> Stream
    mut k = array[u32](u32(8))
    cc.key_from_seed(seed, k)
    mut n = array[u32](u32(3))
    mut b = array[u32](u32(16))
    mut sc = array[u32](u32(32))
    mut a = array[u32](u32(1))
    a[u32(0)] = u32(4294967295)
    return Stream(key: k, nonce: n, buf: b, scr: sc, at: a)
end

pub fn word(st: Stream, i: u32) -> u32
    mut blk = i / u32(16)
    if st.at[u32(0)] != blk then
        cc.block(st.key, st.nonce, blk, st.buf, u32(0), st.scr)
        st.at[u32(0)] = blk
    end
    return st.buf[i % u32(16)]
end

pub fn uniform(st: Stream, i: u32) -> f32
    return f32(word(st, i) >> u32(8)) * f32(5.9604645e-08)
end

pub fn normal2(st: Stream, i: u32, out: f32[], oo: u32)
    mut u1 = uniform(st, i * u32(2)) + f32(5.9604645e-08)
    mut u2 = uniform(st, i * u32(2) + u32(1))
    mut r = sqrt(f32(-2.0) * m.log(u1))
    mut th = f32(6.2831853) * u2
    out[oo] = r * m.cos(th)
    out[oo + u32(1)] = r * m.sin(th)
end

pub fn normal(st: Stream, i: u32) -> f32
    mut t = array[f32](u32(2))
    normal2(st, i / u32(2), t, u32(0))
    return t[i % u32(2)]
end

pub fn below(st: Stream, i: u32, n: u32) -> u32
    if n == u32(0) then
        return u32(0)
    end
    mut lim = u32(4294967295) - (u32(4294967295) % n) - u32(1)
    mut k = u32(0)
    while k < u32(20) do
        mut w = word(st, i * u32(20) + k)
        if w <= lim then
            return w % n
        end
        k = k + u32(1)
    end
    return word(st, i * u32(20)) % n
end

fn below_fast(seed: u32, i: u32, n: u32) -> u32
    if n == u32(0) then
        return u32(0)
    end
    mut lim = u32(4294967295) - (u32(4294967295) % n) - u32(1)
    mut k = u32(0)
    while k < u32(20) do
        mut w = fast.word(seed, i * u32(20) + k)
        if w <= lim then
            return w % n
        end
        k = k + u32(1)
    end
    return fast.word(seed, i * u32(20)) % n
end

pub fn shuffle(st: Stream, perm: u32[], n: u32, epoch: u32)
    mut seed = st.key[u32(0)]
    mut i = u32(0)
    while i < n do
        perm[i] = i
        i = i + u32(1)
    end
    mut j = n
    while j > u32(1) do
        j = j - u32(1)
        mut r = below_fast(seed, epoch * n + j, j + u32(1))
        mut t = perm[j]
        perm[j] = perm[r]
        perm[r] = t
    end
end
