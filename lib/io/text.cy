pub fn putstr(b: u8[], s: u8[])
    mut i = u32(0)
    while i < len(s) do
        push(b, s[i])
        i = i + u32(1)
    end
end

pub fn putch(b: u8[], c: u32)
    push(b, u8(c))
end

pub fn putint(b: u8[], v: u64)
    if v == u64(0) then
        push(b, u8(48))
        return
    end
    mut dg = array[u8](24)
    mut n = u32(0)
    mut x = v
    while x > u64(0) do
        dg[n] = u8(u64(48) + x % u64(10))
        x = x / u64(10)
        n = n + u32(1)
    end
    while n > u32(0) do
        n = n - u32(1)
        push(b, dg[n])
    end
end

pub fn putsci(b: u8[], x: f64, digits: u32)
    if x != x then
        push(b, u8(110))
        push(b, u8(97))
        push(b, u8(110))
        return
    end
    mut v = x
    if v < 0.0 then
        push(b, u8(45))
        v = 0.0 - v
    end
    if v == 0.0 then
        push(b, u8(48))
        return
    end
    if v > 1.7976931348623157e308 then
        push(b, u8(105))
        push(b, u8(110))
        push(b, u8(102))
        return
    end
    mut e = i32(0)
    while v >= 10.0 do
        v = v / 10.0
        e = e + i32(1)
    end
    while v < 1.0 do
        v = v * 10.0
        e = e - i32(1)
    end
    mut p10 = 1.0
    mut q = u32(1)
    while q < digits do
        p10 = p10 * 10.0
        q = q + u32(1)
    end
    mut m = u64(v * p10 + 0.5)
    if f64(m) >= p10 * 10.0 then
        m = m / u64(10)
        e = e + i32(1)
    end
    mut dg = array[u8](24)
    mut n = u32(0)
    mut z = m
    while n < digits do
        dg[n] = u8(u64(48) + z % u64(10))
        z = z / u64(10)
        n = n + u32(1)
    end
    push(b, dg[digits - u32(1)])
    if digits > u32(1) then
        push(b, u8(46))
        mut r = digits - u32(1)
        while r > u32(0) do
            r = r - u32(1)
            push(b, dg[r])
        end
    end
    push(b, u8(101))
    if e < i32(0) then
        push(b, u8(45))
        e = i32(0) - e
    else
        push(b, u8(43))
    end
    if e < i32(10) then
        push(b, u8(48))
    end
    putint(b, u64(e))
end

pub fn putfix(b: u8[], x: f64, dec: u32)
    if x != x then
        push(b, u8(110))
        push(b, u8(97))
        push(b, u8(110))
        return
    end
    mut v = x
    if v < 0.0 then
        push(b, u8(45))
        v = 0.0 - v
    end
    mut p10 = u64(1)
    mut q = u32(0)
    while q < dec do
        p10 = p10 * u64(10)
        q = q + u32(1)
    end
    m = u64(v * f64(p10) + 0.5)
    putint(b, m / p10)
    if dec > u32(0) then
        push(b, u8(46))
        mut frac = m % p10
        mut dg = array[u8](24)
        mut k = u32(0)
        while k < dec do
            dg[k] = u8(u64(48) + frac % u64(10))
            frac = frac / u64(10)
            k = k + u32(1)
        end
        while k > u32(0) do
            k = k - u32(1)
            push(b, dg[k])
        end
    end
end

pub fn padto(b: u8[], w: u32)
    mut ln = u32(0)
    mut i = len(b)
    while i > u32(0) and b[i - u32(1)] != u8(10) do
        ln = ln + u32(1)
        i = i - u32(1)
    end
    while ln < w do
        push(b, u8(32))
        ln = ln + u32(1)
    end
end
