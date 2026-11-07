mut TH = require("thrift.cy")
mut BY = require("bytes.cy")

pub PH_TYPE = u32(0)
pub PH_USIZE = u32(1)
pub PH_CSIZE = u32(2)
pub PH_NV = u32(3)
pub PH_ENC = u32(4)
pub PH_DEFENC = u32(5)
pub PH_V2_NULLS = u32(6)
pub PH_V2_DEFLEN = u32(7)
pub PH_V2_REPLEN = u32(8)
pub PH_V2_COMP = u32(9)
pub PH_N = u32(10)

fn sub_data(tp: u32[], d: u8[], ph: i64[])
    mut last = i64(0)
    mut more = true
    while more and tp[2] == u32(0) do
        f = TH.field(tp, d, last)
        if f.0 == u32(0) then
            more = false
        else
            last = f.1
            if f.1 == i64(1) and f.0 == u32(5) then
                ph[PH_NV] = TH.rint(tp, d)
            else
                if f.1 == i64(2) and f.0 == u32(5) then
                    ph[PH_ENC] = TH.rint(tp, d)
                else
                    if f.1 == i64(3) and f.0 == u32(5) then
                        ph[PH_DEFENC] = TH.rint(tp, d)
                    else
                        TH.skip(tp, d, f.0)
                    end
                end
            end
        end
    end
end

fn sub_dict(tp: u32[], d: u8[], ph: i64[])
    mut last = i64(0)
    mut more = true
    while more and tp[2] == u32(0) do
        f = TH.field(tp, d, last)
        if f.0 == u32(0) then
            more = false
        else
            last = f.1
            if f.1 == i64(1) and f.0 == u32(5) then
                ph[PH_NV] = TH.rint(tp, d)
            else
                if f.1 == i64(2) and f.0 == u32(5) then
                    ph[PH_ENC] = TH.rint(tp, d)
                else
                    TH.skip(tp, d, f.0)
                end
            end
        end
    end
end

fn sub_v2(tp: u32[], d: u8[], ph: i64[])
    mut last = i64(0)
    mut more = true
    while more and tp[2] == u32(0) do
        f = TH.field(tp, d, last)
        if f.0 == u32(0) then
            more = false
        else
            last = f.1
            if f.0 == u32(5) and f.1 >= i64(1) and f.1 <= i64(6) then
                v = TH.rint(tp, d)
                if f.1 == i64(1) then
                    ph[PH_NV] = v
                end
                if f.1 == i64(2) then
                    ph[PH_V2_NULLS] = v
                end
                if f.1 == i64(4) then
                    ph[PH_ENC] = v
                end
                if f.1 == i64(5) then
                    ph[PH_V2_DEFLEN] = v
                end
                if f.1 == i64(6) then
                    ph[PH_V2_REPLEN] = v
                end
            else
                if f.1 == i64(7) and (f.0 == u32(1) or f.0 == u32(2)) then
                    ph[PH_V2_COMP] = i64(f.0 == u32(1))
                else
                    TH.skip(tp, d, f.0)
                end
            end
        end
    end
end

pub fn page_header(tp: u32[], d: u8[], ph: i64[]) -> bool
    mut i = u32(0)
    while i < PH_N do
        ph[i] = i64(-1)
        i = i + u32(1)
    end
    ph[PH_V2_COMP] = i64(1)
    mut last = i64(0)
    mut more = true
    while more and tp[2] == u32(0) do
        f = TH.field(tp, d, last)
        if f.0 == u32(0) then
            more = false
        else
            last = f.1
            if f.0 == u32(5) and f.1 >= i64(1) and f.1 <= i64(3) then
                v = TH.rint(tp, d)
                if f.1 == i64(1) then
                    ph[PH_TYPE] = v
                end
                if f.1 == i64(2) then
                    ph[PH_USIZE] = v
                end
                if f.1 == i64(3) then
                    ph[PH_CSIZE] = v
                end
            else
                if f.0 == u32(12) and f.1 == i64(5) then
                    sub_data(tp, d, ph)
                else
                    if f.0 == u32(12) and f.1 == i64(7) then
                        sub_dict(tp, d, ph)
                    else
                        if f.0 == u32(12) and f.1 == i64(8) then
                            sub_v2(tp, d, ph)
                        else
                            TH.skip(tp, d, f.0)
                        end
                    end
                end
            end
        end
    end
    return tp[2] == u32(0) and ph[PH_TYPE] >= i64(0) and ph[PH_CSIZE] >= i64(0) and ph[PH_USIZE] >= i64(0)
end

pub fn ones(d: u8[], at: u32, end_at: u32, n: u32) -> u32
    mut p = at
    mut got = u32(0)
    mut bad = false
    while got < n and p < end_at and not bad do
        mut h = u32(0)
        mut sh = u32(0)
        mut more = true
        while more and p < end_at do
            b = u32(d[p])
            h = h | ((b & u32(127)) << sh)
            sh = sh + u32(7)
            p = p + u32(1)
            more = (b & u32(128)) != u32(0)
        end
        if (h & u32(1)) == u32(0) then
            run = h >> u32(1)
            if p >= end_at or d[p] != u8(1) then
                bad = true
            end
            p = p + u32(1)
            got = got + run
        else
            groups = h >> u32(1)
            mut k = u32(0)
            while k < groups and not bad do
                if p + k >= end_at then
                    bad = true
                else
                    mut cnt = u32(8)
                    if n - got < u32(8) then
                        cnt = n - got
                    end
                    mask = (u32(1) << cnt) - u32(1)
                    if (u32(d[p + k]) & mask) != mask then
                        bad = true
                    end
                    got = got + cnt
                end
                k = k + u32(1)
            end
            p = p + groups
        end
    end
    if bad or got != n then
        return u32(4294967295)
    end
    return p
end

pub fn dict_values(d: u8[], at: u32, end_at: u32, bw: u32, n: u32, dict: u8[], ndict: u32, col: u8[], co: u32) -> u32
    mut p = at
    mut got = u32(0)
    mut bad = false
    wb = (bw + u32(7)) / u32(8)
    mask = (u64(1) << u64(bw)) - u64(1)
    while got < n and p < end_at and not bad do
        mut h = u32(0)
        mut sh = u32(0)
        mut more = true
        while more and p < end_at do
            b = u32(d[p])
            h = h | ((b & u32(127)) << sh)
            sh = sh + u32(7)
            p = p + u32(1)
            more = (b & u32(128)) != u32(0)
        end
        if (h & u32(1)) == u32(0) then
            run = h >> u32(1)
            mut v = u32(0)
            mut k = u32(0)
            while k < wb do
                v = v | (u32(d[p + k]) << (u32(8) * k))
                k = k + u32(1)
            end
            p = p + wb
            if v >= ndict or got + run > n then
                bad = true
            else
                x = dict[v]
                mut r = u32(0)
                while r < run do
                    col[co + got + r] = x
                    r = r + u32(1)
                end
                got = got + run
            end
        else
            groups = h >> u32(1)
            nbytes = groups * bw
            if p + nbytes > end_at then
                bad = true
            else
                mut acc = u64(0)
                mut have = u64(0)
                mut q = p
                mut j = u32(0)
                total = groups * u32(8)
                while j < total and not bad do
                    while have < u64(bw) do
                        acc = acc | (u64(d[q]) << have)
                        q = q + u32(1)
                        have = have + u64(8)
                    end
                    v2 = u32(acc & mask)
                    acc = acc >> u64(bw)
                    have = have - u64(bw)
                    if got < n then
                        if v2 >= ndict then
                            bad = true
                        else
                            col[co + got] = dict[v2]
                            got = got + u32(1)
                        end
                    end
                    j = j + u32(1)
                end
                p = p + nbytes
            end
        end
    end
    if bad or got != n then
        return u32(4294967295)
    end
    return p
end

pub fn plain_i32(d: u8[], at: u32, end_at: u32, n: u32, col: u8[], co: u32, rng: i64[]) -> u32
    if at + n * u32(4) > end_at then
        return u32(4294967295)
    end
    mut i = u32(0)
    while i < n do
        v = BY.i32le(d, at + i * u32(4))
        if i64(v) < rng[0] then
            rng[0] = i64(v)
        end
        if i64(v) > rng[1] then
            rng[1] = i64(v)
        end
        col[co + i] = u8(v)
        i = i + u32(1)
    end
    return at + n * u32(4)
end

pub type Footer
    mut ok: u32
    mut ncol: u32
    mut nrows: i64
    mut ngroups: u32
    mut names: u8[]
    mut name_at: u32[]
    mut name_len: u32[]
    mut rep: i32[]
    mut ptype: i32[]
    mut ctype: i32[]
    mut codec: i32[]
    mut nvals: i64[]
    mut first: i64[]
    mut csize: i64[]
end

fn schema_el(tp: u32[], d: u8[], ft: Footer)
    mut last = i64(0)
    mut more = true
    mut nm_at = u32(0)
    mut nm_len = u32(0)
    mut rp = i32(-1)
    mut pt = i32(-1)
    mut ct = i32(-1)
    mut kids = i32(-1)
    while more and tp[2] == u32(0) do
        f = TH.field(tp, d, last)
        if f.0 == u32(0) then
            more = false
        else
            last = f.1
            if f.0 == u32(5) and (f.1 == i64(1) or f.1 == i64(3) or f.1 == i64(5) or f.1 == i64(6)) then
                v = i32(TH.rint(tp, d))
                if f.1 == i64(1) then
                    pt = v
                end
                if f.1 == i64(3) then
                    rp = v
                end
                if f.1 == i64(5) then
                    kids = v
                end
                if f.1 == i64(6) then
                    ct = v
                end
            else
                if f.0 == u32(8) and f.1 == i64(4) then
                    nm_at = TH.rbin(tp, d)
                    nm_len = tp[0] - nm_at
                else
                    TH.skip(tp, d, f.0)
                end
            end
        end
    end
    if kids < i32(0) then
        push(ft.name_at, len(ft.names))
        push(ft.name_len, nm_len)
        mut k = u32(0)
        while k < nm_len do
            push(ft.names, d[nm_at + k])
            k = k + u32(1)
        end
        push(ft.rep, rp)
        push(ft.ptype, pt)
        push(ft.ctype, ct)
    end
end

fn col_meta(tp: u32[], d: u8[], ft: Footer)
    mut last = i64(0)
    mut more = true
    mut codec = i32(-1)
    mut nv = i64(-1)
    mut dpo = i64(-1)
    mut dio = i64(-1)
    mut cs = i64(-1)
    while more and tp[2] == u32(0) do
        f = TH.field(tp, d, last)
        if f.0 == u32(0) then
            more = false
        else
            last = f.1
            if f.1 == i64(4) and f.0 == u32(5) then
                codec = i32(TH.rint(tp, d))
            else
                if (f.0 == u32(6) or f.0 == u32(5)) and (f.1 == i64(5) or f.1 == i64(7) or f.1 == i64(9) or f.1 == i64(11)) then
                    v = TH.rint(tp, d)
                    if f.1 == i64(5) then
                        nv = v
                    end
                    if f.1 == i64(7) then
                        cs = v
                    end
                    if f.1 == i64(9) then
                        dpo = v
                    end
                    if f.1 == i64(11) then
                        dio = v
                    end
                else
                    TH.skip(tp, d, f.0)
                end
            end
        end
    end
    mut first = dpo
    if dio >= i64(0) and dio < dpo then
        first = dio
    end
    push(ft.codec, codec)
    push(ft.nvals, nv)
    push(ft.first, first)
    push(ft.csize, cs)
end

fn col_chunk(tp: u32[], d: u8[], ft: Footer)
    mut last = i64(0)
    mut more = true
    while more and tp[2] == u32(0) do
        f = TH.field(tp, d, last)
        if f.0 == u32(0) then
            more = false
        else
            last = f.1
            if f.1 == i64(3) and f.0 == u32(12) then
                col_meta(tp, d, ft)
            else
                TH.skip(tp, d, f.0)
            end
        end
    end
end

fn row_group(tp: u32[], d: u8[], ft: Footer)
    mut last = i64(0)
    mut more = true
    while more and tp[2] == u32(0) do
        f = TH.field(tp, d, last)
        if f.0 == u32(0) then
            more = false
        else
            last = f.1
            if f.1 == i64(1) and f.0 == u32(9) then
                lh = TH.list_head(tp, d)
                mut i = u32(0)
                while i < lh.0 and tp[2] == u32(0) do
                    col_chunk(tp, d, ft)
                    i = i + u32(1)
                end
            else
                TH.skip(tp, d, f.0)
            end
        end
    end
end

pub fn footer(d: u8[], at: u32, end_at: u32) -> Footer
    mut ft = Footer(ok: u32(0), ncol: u32(0), nrows: i64(-1), ngroups: u32(0), names: array[u8](0), name_at: array[u32](0), name_len: array[u32](0), rep: array[i32](0), ptype: array[i32](0), ctype: array[i32](0), codec: array[i32](0), nvals: array[i64](0), first: array[i64](0), csize: array[i64](0))
    mut tp = array[u32](3)
    tp[0] = at
    tp[1] = end_at
    mut last = i64(0)
    mut more = true
    while more and tp[2] == u32(0) do
        f = TH.field(tp, d, last)
        if f.0 == u32(0) then
            more = false
        else
            last = f.1
            if f.1 == i64(2) and f.0 == u32(9) then
                lh = TH.list_head(tp, d)
                mut i = u32(0)
                while i < lh.0 and tp[2] == u32(0) do
                    schema_el(tp, d, ft)
                    i = i + u32(1)
                end
            else
                if f.1 == i64(3) and f.0 == u32(6) then
                    ft.nrows = TH.rint(tp, d)
                else
                    if f.1 == i64(4) and f.0 == u32(9) then
                        lh2 = TH.list_head(tp, d)
                        ft.ngroups = lh2.0
                        mut g = u32(0)
                        while g < lh2.0 and tp[2] == u32(0) do
                            row_group(tp, d, ft)
                            g = g + u32(1)
                        end
                    else
                        TH.skip(tp, d, f.0)
                    end
                end
            end
        end
    end
    ft.ncol = len(ft.name_at)
    ft.ok = u32(tp[2] == u32(0))
    return ft
end

pub fn name_number(ft: Footer, i: u32) -> i64
    mut v = i64(0)
    mut k = u32(0)
    if ft.name_len[i] == u32(0) then
        return i64(-1)
    end
    while k < ft.name_len[i] do
        c = ft.names[ft.name_at[i] + k]
        if c < u8(48) or c > u8(57) then
            return i64(-1)
        end
        v = v * i64(10) + i64(c - u8(48))
        k = k + u32(1)
    end
    return v
end
