fn mul_small(a: u64[], n: u32, m: u64, add: u64) -> u32
    mut carry = add
    mut i = u32(0)
    while i < n do
        t = a[i] * m + carry
        a[i] = t & u64(4294967295)
        carry = t >> u64(32)
        i = i + u32(1)
    end
    mut k = n
    while carry > u64(0) do
        a[k] = carry & u64(4294967295)
        carry = carry >> u64(32)
        k = k + u32(1)
    end
    return k
end

fn big_bitlen(a: u64[], n: u32) -> u32
    if n == u32(0) then
        return u32(0)
    end
    return (n - u32(1)) * u32(32) + u32(64) - u32(clz(a[n - u32(1)]))
end

fn big_shl(a: u64[], n: u32, bits: u32) -> u32
    if n == u32(0) then
        return u32(0)
    end
    ls = bits >> u32(5)
    bs = bits & u32(31)
    mut i = n
    while i > u32(0) do
        i = i - u32(1)
        v = a[i] << bs
        a[i + ls + u32(1)] = a[i + ls + u32(1)] | (v >> u64(32))
        a[i + ls] = v & u64(4294967295)
    end
    mut z = u32(0)
    while z < ls do
        a[z] = u64(0)
        z = z + u32(1)
    end
    mut m = n + ls + u32(1)
    while m > u32(0) and a[m - u32(1)] == u64(0) do
        m = m - u32(1)
    end
    return m
end

fn big_shr1(a: u64[], n: u32) -> u32
    mut i = u32(0)
    while i < n do
        mut hi = u64(0)
        if i + u32(1) < n then
            hi = a[i + u32(1)] & u64(1)
        end
        a[i] = (a[i] >> u64(1)) | (hi << u64(31))
        i = i + u32(1)
    end
    mut m = n
    while m > u32(0) and a[m - u32(1)] == u64(0) do
        m = m - u32(1)
    end
    return m
end

fn big_ge(a: u64[], na: u32, b: u64[], nb: u32) -> bool
    if na != nb then
        return na > nb
    end
    mut i = na
    while i > u32(0) do
        i = i - u32(1)
        if a[i] != b[i] then
            return a[i] > b[i]
        end
    end
    return true
end

fn big_sub(a: u64[], na: u32, b: u64[], nb: u32) -> u32
    mut borrow = u64(0)
    mut i = u32(0)
    while i < na do
        mut bv = u64(0)
        if i < nb then
            bv = b[i]
        end
        t = a[i] + u64(4294967296) - bv - borrow
        a[i] = t & u64(4294967295)
        borrow = u64(1) - (t >> u64(32))
        i = i + u32(1)
    end
    mut m = na
    while m > u32(0) and a[m - u32(1)] == u64(0) do
        m = m - u32(1)
    end
    return m
end

fn big_pow10(a: u64[], k: u32) -> u32
    a[0] = u64(1)
    mut n = u32(1)
    mut left = k
    while left >= u32(9) do
        n = mul_small(a, n, u64(1000000000), u64(0))
        left = left - u32(9)
    end
    mut p = u64(1)
    mut j = u32(0)
    while j < left do
        p = p * u64(10)
        j = j + u32(1)
    end
    if left > u32(0) then
        n = mul_small(a, n, p, u64(0))
    end
    return n
end

fn round_pack(q: u64, sticky: bool, ex: i64) -> u64
    if q == u64(0) then
        return u64(0)
    end
    l = i64(64) - i64(clz(q))
    mut drop = i64(0)
    if l > i64(53) then
        drop = l - i64(53)
    end
    if ex + drop < i64(0) - i64(1074) then
        drop = i64(0) - i64(1074) - ex
    end
    if drop > i64(64) then
        return u64(0)
    end
    mut m = q
    mut e2 = ex
    if drop == i64(0) then
        k = i64(53) - l
        if k > i64(0) then
            m = q << k
            e2 = ex - k
        end
    else
        mut rem = q
        mut half = u64(1) << u64(63)
        m = u64(0)
        if drop < i64(64) then
            m = q >> drop
            rem = q & ((u64(1) << drop) - u64(1))
            half = u64(1) << (drop - i64(1))
        end
        e2 = ex + drop
        if rem > half or (rem == half and (sticky or (m & u64(1)) == u64(1))) then
            m = m + u64(1)
        end
    end
    if m >= (u64(1) << u64(52)) then
        ef = e2 + i64(52) + i64(1023)
        if ef >= i64(2047) then
            return u64(9218868437227405312)
        end
        return (u64(ef) << u64(52)) + (m - (u64(1) << u64(52)))
    end
    return m
end

fn big_to_f64(dg: u64[], nd: u32, e10: i64, sticky_in: bool) -> u64
    mut a = array[u64](480)
    mut i = u32(0)
    while i < nd do
        a[i] = dg[i]
        i = i + u32(1)
    end
    mut n = nd
    if e10 >= i64(0) then
        mut p = array[u64](480)
        np = big_pow10(p, u32(e10))
        mut r = array[u64](480)
        mut ia = u32(0)
        while ia < n do
            mut carry = u64(0)
            mut ib = u32(0)
            while ib < np do
                t = a[ia] * p[ib] + r[ia + ib] + carry
                r[ia + ib] = t & u64(4294967295)
                carry = t >> u64(32)
                ib = ib + u32(1)
            end
            mut k = ia + np
            while carry > u64(0) do
                t2 = r[k] + carry
                r[k] = t2 & u64(4294967295)
                carry = t2 >> u64(32)
                k = k + u32(1)
            end
            ia = ia + u32(1)
        end
        mut nr = n + np + u32(1)
        while nr > u32(0) and r[nr - u32(1)] == u64(0) do
            nr = nr - u32(1)
        end
        l = big_bitlen(r, nr)
        if l <= u32(64) then
            mut q = u64(0)
            if nr > u32(0) then
                q = r[0]
            end
            if nr > u32(1) then
                q = q | (r[1] << u64(32))
            end
            return round_pack(q, sticky_in, i64(0))
        end
        sh = l - u32(64)
        mut q = u64(0)
        mut j = u32(0)
        while j < u32(64) do
            bit = sh + j
            if ((r[bit >> u32(5)] >> u64(bit & u32(31))) & u64(1)) == u64(1) then
                q = q | (u64(1) << u64(j))
            end
            j = j + u32(1)
        end
        mut low = sticky_in
        j = u32(0)
        while j < sh and not low do
            if ((r[j >> u32(5)] >> u64(j & u32(31))) & u64(1)) == u64(1) then
                low = true
            end
            j = j + u32(1)
        end
        return round_pack(q, low, i64(sh))
    end
    mut den = array[u64](480)
    mut nden = big_pow10(den, u32(i64(0) - e10))
    ln = big_bitlen(a, n)
    ld = big_bitlen(den, nden)
    sc = i64(63) - (i64(ln) - i64(ld))
    if sc >= i64(0) then
        n = big_shl(a, n, u32(sc))
    else
        nden = big_shl(den, nden, u32(i64(0) - sc))
    end
    mut dk = array[u64](480)
    mut ndk = nden
    i = u32(0)
    while i < nden do
        dk[i] = den[i]
        i = i + u32(1)
    end
    ndk = big_shl(dk, ndk, u32(63))
    mut q = u64(0)
    mut kbit = u32(64)
    while kbit > u32(0) do
        kbit = kbit - u32(1)
        if big_ge(a, n, dk, ndk) then
            n = big_sub(a, n, dk, ndk)
            q = q | (u64(1) << u64(kbit))
        end
        ndk = big_shr1(dk, ndk)
    end
    return round_pack(q, sticky_in or n > u32(0), i64(0) - sc)
end

fn lower(c: u32) -> u32
    return c | u32(32)
end

fn is_word(b: u8[], p: u32, e: u32, w: u8[]) -> bool
    if e - p != len(w) then
        return false
    end
    mut i = u32(0)
    while i < len(w) do
        if lower(u32(b[p + i])) != u32(w[i]) then
            return false
        end
        i = i + u32(1)
    end
    return true
end

pub fn parse_f64(b: u8[], s: u32, e: u32, out: u64[]) -> u32
    mut p = s
    if p >= e then
        return u32(0)
    end
    mut neg = false
    if b[p] == u8(45) then
        neg = true
        p = p + u32(1)
    else
        if b[p] == u8(43) then
            p = p + u32(1)
        end
    end
    if p >= e then
        return u32(0)
    end
    mut sign = u64(0)
    if neg then
        sign = u64(1) << u64(63)
    end
    c0 = lower(u32(b[p]))
    if c0 == u32(105) or c0 == u32(110) then
        if is_word(b, p, e, bytes("inf")) or is_word(b, p, e, bytes("infinity")) then
            out[0] = sign | u64(9218868437227405312)
            return u32(1)
        end
        if is_word(b, p, e, bytes("nan")) then
            out[0] = sign | u64(9221120237041090560)
            return u32(1)
        end
        return u32(0)
    end
    mut d = u64(0)
    mut nsig = u32(0)
    mut frac = u32(0)
    mut seen_dot = false
    mut any = false
    mut ok = true
    mut stop = false
    while p < e and ok and not stop do
        c = u32(b[p])
        if c >= u32(48) and c <= u32(57) then
            any = true
            if seen_dot then
                frac = frac + u32(1)
            end
            if nsig > u32(0) or c != u32(48) then
                if nsig < u32(19) then
                    d = d * u64(10) + u64(c - u32(48))
                end
                nsig = nsig + u32(1)
            end
            p = p + u32(1)
        else
            if c == u32(46) and not seen_dot then
                seen_dot = true
                p = p + u32(1)
            else
                stop = true
            end
        end
    end
    if not any then
        return u32(0)
    end
    mut ex = i64(0)
    if p < e then
        if lower(u32(b[p])) != u32(101) then
            return u32(0)
        end
        p = p + u32(1)
        mut eneg = false
        if p < e and b[p] == u8(45) then
            eneg = true
            p = p + u32(1)
        else
            if p < e and b[p] == u8(43) then
                p = p + u32(1)
            end
        end
        if p >= e then
            return u32(0)
        end
        while p < e do
            c = u32(b[p])
            if c < u32(48) or c > u32(57) then
                return u32(0)
            end
            if ex < i64(100000) then
                ex = ex * i64(10) + i64(c - u32(48))
            end
            p = p + u32(1)
        end
        if eneg then
            ex = i64(0) - ex
        end
    end
    if nsig == u32(0) then
        out[0] = sign
        return u32(1)
    end
    e10 = ex - i64(frac)
    mag = i64(nsig) + e10
    if mag > i64(310) then
        out[0] = sign | u64(9218868437227405312)
        return u32(1)
    end
    if mag < i64(0) - i64(330) then
        out[0] = sign
        return u32(1)
    end
    if nsig <= u32(19) then
        if d < u64(9007199254740992) and e10 >= i64(0) - i64(22) and e10 <= i64(22) then
            mut v = f64(d)
            if e10 < i64(0) then
                v = v / pow10(u32(i64(0) - e10))
            else
                v = v * pow10(u32(e10))
            end
            out[0] = sign | tobits(v)
            return u32(1)
        end
        mut dl = array[u64](3)
        dl[0] = d & u64(4294967295)
        dl[1] = d >> u64(32)
        mut nl = u32(2)
        if dl[1] == u64(0) then
            nl = u32(1)
        end
        out[0] = sign | big_to_f64(dl, nl, e10, false)
        return u32(1)
    end
    mut dg = array[u64](480)
    mut nl = u32(1)
    mut kept = u32(0)
    mut dropped = u32(0)
    mut sticky = false
    mut q = s
    mut started = false
    while q < e and (u32(b[q]) != u32(101) and u32(b[q]) != u32(69)) do
        c = u32(b[q])
        if c >= u32(48) and c <= u32(57) then
            if started or c != u32(48) then
                started = true
                if kept < u32(770) then
                    nl = mul_small(dg, nl, u64(10), u64(c - u32(48)))
                    kept = kept + u32(1)
                else
                    dropped = dropped + u32(1)
                    if c != u32(48) then
                        sticky = true
                    end
                end
            end
        end
        q = q + u32(1)
    end
    mut e2 = e10 + i64(dropped)
    if sticky then
        nl = mul_small(dg, nl, u64(10), u64(1))
        e2 = e2 - i64(1)
    end
    out[0] = sign | big_to_f64(dg, nl, e2, false)
    return u32(1)
end

fn pow10(k: u32) -> f64
    mut v = 1.0
    mut i = u32(0)
    while i < k do
        v = v * 10.0
        i = i + u32(1)
    end
    return v
end
