pub fn length(src: u8[], so: u32, sn: u32) -> u32
    mut r = u32(0)
    mut sh = u32(0)
    mut i = so
    mut more = true
    while more and i < so + sn and sh < u32(35) do
        b = u32(src[i])
        r = r | ((b & u32(127)) << sh)
        sh = sh + u32(7)
        i = i + u32(1)
        more = (b & u32(128)) != u32(0)
    end
    return r
end

pub fn decompress(src: u8[], so: u32, sn: u32, dst: u8[]) -> i64
    end_at = so + sn
    mut i = so
    mut want = u32(0)
    mut sh = u32(0)
    mut more = true
    while more and i < end_at do
        b = u32(src[i])
        want = want | ((b & u32(127)) << sh)
        sh = sh + u32(7)
        i = i + u32(1)
        more = (b & u32(128)) != u32(0)
    end
    if want > len(dst) then
        return i64(-1)
    end
    mut o = u32(0)
    mut err = i64(0)
    while i < end_at and err == i64(0) do
        t = u32(src[i])
        i = i + u32(1)
        kind = t & u32(3)
        if kind == u32(0) then
            mut n = (t >> u32(2)) + u32(1)
            if n > u32(60) then
                nb = n - u32(60)
                if i + nb > end_at then
                    err = i64(-2)
                else
                    mut v = u32(0)
                    mut k = u32(0)
                    while k < nb do
                        v = v | (u32(src[i + k]) << (u32(8) * k))
                        k = k + u32(1)
                    end
                    n = v + u32(1)
                    i = i + nb
                end
            end
            if err == i64(0) then
                if i + n > end_at or o + n > want then
                    err = i64(-3)
                else
                    mut k2 = u32(0)
                    while k2 < n do
                        dst[o + k2] = src[i + k2]
                        k2 = k2 + u32(1)
                    end
                    o = o + n
                    i = i + n
                end
            end
        else
            mut ln = u32(0)
            mut off = u32(0)
            if kind == u32(1) then
                if i + u32(1) > end_at then
                    err = i64(-4)
                else
                    ln = u32(4) + ((t >> u32(2)) & u32(7))
                    off = ((t >> u32(5)) << u32(8)) | u32(src[i])
                    i = i + u32(1)
                end
            else
                if kind == u32(2) then
                    if i + u32(2) > end_at then
                        err = i64(-4)
                    else
                        ln = u32(1) + (t >> u32(2))
                        off = u32(src[i]) | (u32(src[i + u32(1)]) << u32(8))
                        i = i + u32(2)
                    end
                else
                    if i + u32(4) > end_at then
                        err = i64(-4)
                    else
                        ln = u32(1) + (t >> u32(2))
                        off = u32(src[i]) | (u32(src[i + u32(1)]) << u32(8)) | (u32(src[i + u32(2)]) << u32(16)) | (u32(src[i + u32(3)]) << u32(24))
                        i = i + u32(4)
                    end
                end
            end
            if err == i64(0) then
                if off == u32(0) or off > o or o + ln > want then
                    err = i64(-5)
                else
                    mut k3 = u32(0)
                    while k3 < ln do
                        dst[o + k3] = dst[o + k3 - off]
                        k3 = k3 + u32(1)
                    end
                    o = o + ln
                end
            end
        end
    end
    if err != i64(0) then
        return err
    end
    if o != want then
        return i64(-6)
    end
    return i64(o)
end
