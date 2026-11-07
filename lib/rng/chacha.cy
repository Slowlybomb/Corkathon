fn rotl(x: u32, n: u32) -> u32
    return (x << n) | (x >> (u32(32) - n))
end

fn qr(s: u32[], a: u32, b: u32, c: u32, d: u32)
    s[a] = s[a] + s[b]
    s[d] = rotl(s[d] ^ s[a], u32(16))
    s[c] = s[c] + s[d]
    s[b] = rotl(s[b] ^ s[c], u32(12))
    s[a] = s[a] + s[b]
    s[d] = rotl(s[d] ^ s[a], u32(8))
    s[c] = s[c] + s[d]
    s[b] = rotl(s[b] ^ s[c], u32(7))
end

C0 = u32(1634760805)
C1 = u32(857760878)
C2 = u32(2036477234)
C3 = u32(1797285236)

pub fn block(key: u32[], nonce: u32[], ctr: u32, out: u32[], oo: u32,
             scr: u32[])
    mut s = scr
    s[u32(0)] = C0
    s[u32(1)] = C1
    s[u32(2)] = C2
    s[u32(3)] = C3
    mut i = u32(0)
    while i < u32(8) do
        s[u32(4) + i] = key[i]
        i = i + u32(1)
    end
    s[u32(12)] = ctr
    s[u32(13)] = nonce[u32(0)]
    s[u32(14)] = nonce[u32(1)]
    s[u32(15)] = nonce[u32(2)]
    mut k = u32(0)
    while k < u32(16) do
        scr[u32(16) + k] = s[k]
        k = k + u32(1)
    end
    mut w = scr
    mut r = u32(0)
    while r < u32(10) do
        qr(w, u32(16), u32(20), u32(24), u32(28))
        qr(w, u32(17), u32(21), u32(25), u32(29))
        qr(w, u32(18), u32(22), u32(26), u32(30))
        qr(w, u32(19), u32(23), u32(27), u32(31))
        qr(w, u32(16), u32(21), u32(26), u32(31))
        qr(w, u32(17), u32(22), u32(27), u32(28))
        qr(w, u32(18), u32(23), u32(24), u32(29))
        qr(w, u32(19), u32(20), u32(25), u32(30))
        r = r + u32(1)
    end
    mut j = u32(0)
    while j < u32(16) do
        out[oo + j] = scr[u32(16) + j] + scr[j]
        j = j + u32(1)
    end
end

pub fn key_from_seed(seed: u64, key: u32[])
    mut z = seed
    mut i = u32(0)
    while i < u32(8) do
        z = z + u64(11400714819323198485)
        mut x = z
        x = (x ^ (x >> u64(30))) * u64(13787848793156543929)
        x = (x ^ (x >> u64(27))) * u64(10723151780598845931)
        x = x ^ (x >> u64(31))
        key[i] = u32(x & u64(4294967295))
        i = i + u32(1)
    end
end
