mut D = require("data.cy")
mut M = require("model.cy")
mut NT = require("net.cy")
mut RNG = require("../../lib/rng/random.cy")
mut TX = require("../../lib/io/text.cy")
mut BY = require("../../lib/io/bytes.cy")

extern "kernel32.dll" fn GetStdHandle(n: u32) -> u64
extern "kernel32.dll" fn WriteFile(h: u64, buf: u8[], n: u32, done: u32[], ov: u64) -> i32

pub NB = u32(16)
pub NLAW = u32(29)
pub NNEUR = u32(58)
pub DF = u32(301)
pub EDG = u32(293)
pub NPIXT = u32(19)
pub CTX = u32(214)
pub NEU = u32(235)

pub fn say(b: u8[])
    h = GetStdHandle(u32(4294967285))
    mut d = array[u32](1)
    mut r = WriteFile(h, b, len(b), d, u64(0))
end

pub fn sayf(label: u8[], v: f64, dec: u32)
    mut b = array[u8](0)
    TX.putstr(b, label)
    TX.putfix(b, v, dec)
    TX.putch(b, u32(10))
    say(b)
end

pub fn library_em(em: f64[])
    mut s = array[f64](40)
    mut soil = array[f64](10)
    mut grn = array[f64](10)
    mut dry = array[f64](10)
    mut wat = array[f64](10)
    soil[0] = 0.08
    soil[1] = 0.11
    soil[2] = 0.14
    soil[3] = 0.22
    soil[4] = 0.16
    soil[5] = 0.19
    soil[6] = 0.21
    soil[7] = 0.23
    soil[8] = 0.30
    soil[9] = 0.26
    grn[0] = 0.03
    grn[1] = 0.07
    grn[2] = 0.03
    grn[3] = 0.45
    grn[4] = 0.10
    grn[5] = 0.30
    grn[6] = 0.40
    grn[7] = 0.45
    grn[8] = 0.20
    grn[9] = 0.10
    dry[0] = 0.07
    dry[1] = 0.10
    dry[2] = 0.13
    dry[3] = 0.27
    dry[4] = 0.17
    dry[5] = 0.22
    dry[6] = 0.25
    dry[7] = 0.28
    dry[8] = 0.35
    dry[9] = 0.25
    wat[0] = 0.07
    wat[1] = 0.06
    wat[2] = 0.04
    wat[3] = 0.02
    wat[4] = 0.03
    wat[5] = 0.02
    wat[6] = 0.02
    wat[7] = 0.02
    wat[8] = 0.01
    wat[9] = 0.01
    mut b = u32(0)
    while b < u32(10) do
        em[b * u32(4)] = soil[b]
        em[b * u32(4) + u32(1)] = grn[b]
        em[b * u32(4) + u32(2)] = dry[b]
        em[b * u32(4) + u32(3)] = wat[b]
        b = b + u32(1)
    end
end

pub fn pick_dates(dir: u8[], want: u32, refl: f32[], out: u32[]) -> u32
    all = D.list_dates(dir)
    mut cand = array[u32](0)
    for dt in all do
        dd = D.doy(dt)
        if dd >= u32(91) and dd <= u32(304) then
            push(cand, dt)
        end
    end
    nc = len(cand)
    mut got = u32(0)
    if nc == u32(0) then
        return got
    end
    mut s = u32(0)
    while s < want do
        t = s * nc / want
        mut tries = u32(0)
        mut found = false
        while tries < u32(3) and not found do
            k = t + tries
            if k < nc then
                if D.load_refl(dir, cand[k], refl, u32(0)) then
                    found = true
                    mut dup = false
                    mut q = u32(0)
                    while q < got do
                        if out[q] == cand[k] then
                            dup = true
                        end
                        q = q + u32(1)
                    end
                    if not dup then
                        out[got] = cand[k]
                        got = got + u32(1)
                    end
                end
            end
            tries = tries + u32(1)
        end
        s = s + u32(1)
    end
    return got
end

pub fn conv_params(seed: u64) -> f32[]
    mut np = u32(0)
    mut l = u32(0)
    while l < M.NCONV do
        mut ci = M.NFEAT
        if l == u32(0) then
            ci = D.NBASE
        end
        np = np + M.NFEAT * ci * u32(9) + M.NFEAT
        l = l + u32(1)
    end
    mut p = array[f32](np)
    st = RNG.stream(seed)
    mut off = u32(0)
    mut r = u32(0)
    l = u32(0)
    while l < M.NCONV do
        mut ci = M.NFEAT
        if l == u32(0) then
            ci = D.NBASE
        end
        sd = sqrt(f32(2.0) / f32(ci * u32(9)))
        mut q = u32(0)
        while q < M.NFEAT * ci * u32(9) do
            p[off + q] = RNG.normal(st, r) * sd
            r = r + u32(1)
            q = q + u32(1)
        end
        off = off + M.NFEAT * ci * u32(9)
        q = u32(0)
        while q < M.NFEAT do
            p[off + q] = RNG.normal(st, r) * f32(0.1)
            r = r + u32(1)
            q = q + u32(1)
        end
        off = off + M.NFEAT
        l = l + u32(1)
    end
    return p
end

pub fn conv_bank(x: f32[], p: f32[], f1: f32[], f2: f32[], f3: f32[], f4: f32[], nb: u32)
    o1 = M.NFEAT * D.NBASE * u32(9)
    o2 = o1 + M.NFEAT
    o3 = o2 + M.NFEAT * M.NFEAT * u32(9)
    o4 = o3 + M.NFEAT
    o5 = o4 + M.NFEAT * M.NFEAT * u32(9)
    o6 = o5 + M.NFEAT
    o7 = o6 + M.NFEAT * M.NFEAT * u32(9)
    o8 = o7 + M.NFEAT
    NT.conv_fwd(x, p, f1, nb, D.NBASE, M.NFEAT, D.N, u32(3), u32(1), u32(0), o1, u32(1))
    NT.conv_fwd(f1, p, f2, nb, M.NFEAT, M.NFEAT, D.N, u32(3), u32(2), o2, o3, u32(1))
    NT.conv_fwd(f2, p, f3, nb, M.NFEAT, M.NFEAT, D.N, u32(3), u32(4), o4, o5, u32(1))
    NT.conv_fwd(f3, p, f4, nb, M.NFEAT, M.NFEAT, D.N, u32(3), u32(8), o6, o7, u32(1))
end

pub fn build_phi(x: f32[], f1: f32[], f2: f32[], f3: f32[], f4: f32[], s: u32, gm: f32[], laws: u32[], coefs: f64[], phi: f32[])
    np = D.NPIX
    xo = s * D.NBASE * np
    fo = s * M.NFEAT * np
    mut p = u32(0)
    while p < np do
        phi[p] = f32(1.0)
        p = p + u32(1)
    end
    mut c = u32(0)
    while c < D.NBASE do
        mut m = f32(0.0)
        p = u32(0)
        while p < np do
            v = x[xo + c * np + p]
            phi[(u32(1) + c) * np + p] = v
            m = m + v
            p = p + u32(1)
        end
        m = m / f32(np)
        p = u32(0)
        while p < np do
            phi[(CTX + c) * np + p] = m
            p = p + u32(1)
        end
        c = c + u32(1)
    end
    c = u32(0)
    while c < M.NFEAT do
        p = u32(0)
        while p < np do
            phi[(u32(22) + c) * np + p] = f1[fo + c * np + p]
            phi[(u32(70) + c) * np + p] = f2[fo + c * np + p]
            phi[(u32(118) + c) * np + p] = f3[fo + c * np + p]
            phi[(u32(166) + c) * np + p] = f4[fo + c * np + p]
            p = p + u32(1)
        end
        c = c + u32(1)
    end
    mut li = array[u32](4)
    mut lc = array[f64](4)
    mut li2 = array[u32](4)
    mut lc2 = array[f64](4)
    mut t = u32(0)
    while t < NLAW do
        mut k = u32(0)
        while k < u32(4) do
            li[k] = laws[(t * u32(2)) * u32(4) + k]
            lc[k] = coefs[(t * u32(2)) * u32(4) + k]
            li2[k] = laws[(t * u32(2) + u32(1)) * u32(4) + k]
            lc2[k] = coefs[(t * u32(2) + u32(1)) * u32(4) + k]
            k = k + u32(1)
        end
        p = u32(0)
        while p < np do
            v1 = M.law_value(gm, p * M.NG, li, lc)
            v2 = M.law_value(gm, p * M.NG, li2, lc2)
            phi[(NEU + t * u32(2)) * np + p] = v1
            phi[(NEU + t * u32(2) + u32(1)) * np + p] = v1 + v2
            p = p + u32(1)
        end
        t = t + u32(1)
    end
    if len(phi) >= (EDG + u32(8)) * np then
        edges(x, xo, phi)
    end
end

pub fn edges(x: f32[], xo: u32, phi: f32[])
    n = D.N
    np = D.NPIX
    mut mag = array[f32](np)
    mut e = u32(0)
    while e < u32(4) do
        mut ch = u32(10)
        if e == u32(1) then
            ch = u32(11)
        end
        if e == u32(2) then
            ch = u32(3)
        end
        if e == u32(3) then
            ch = u32(8)
        end
        base = xo + ch * np
        mut p = u32(0)
        while p < np do
            i = p / n
            j = p % n
            im = u32(max(i32(0), i32(i) - i32(1)))
            ip = min(n - u32(1), i + u32(1))
            jm = u32(max(i32(0), i32(j) - i32(1)))
            jp = min(n - u32(1), j + u32(1))
            gx = x[base + im * n + jp] + f32(2.0) * x[base + i * n + jp] + x[base + ip * n + jp] - x[base + im * n + jm] - f32(2.0) * x[base + i * n + jm] - x[base + ip * n + jm]
            gy = x[base + ip * n + jm] + f32(2.0) * x[base + ip * n + j] + x[base + ip * n + jp] - x[base + im * n + jm] - f32(2.0) * x[base + im * n + j] - x[base + im * n + jp]
            mag[p] = sqrt(gx * gx + gy * gy)
            phi[(EDG + e) * np + p] = mag[p]
            p = p + u32(1)
        end
        p = u32(0)
        while p < np do
            i = p / n
            j = p % n
            mut m = f32(0.0)
            mut a = u32(max(i32(0), i32(i) - i32(1)))
            while a <= min(n - u32(1), i + u32(1)) do
                mut b = u32(max(i32(0), i32(j) - i32(1)))
                while b <= min(n - u32(1), j + u32(1)) do
                    m = max(m, mag[a * n + b])
                    b = b + u32(1)
                end
                a = a + u32(1)
            end
            phi[(EDG + u32(4) + e) * np + p] = m
            p = p + u32(1)
        end
        e = e + u32(1)
    end
end

pub fn fp_means(phi: f32[], d: u32, w: f32[], fp: u32[], nfp: u32, acc: f32[], wsum: f32[])
    np = D.NPIX
    mut q = u32(0)
    while q < nfp * d do
        acc[q] = f32(0.0)
        q = q + u32(1)
    end
    q = u32(0)
    while q < nfp do
        wsum[q] = f32(0.0)
        q = q + u32(1)
    end
    mut p = u32(0)
    while p < np do
        if fp[p] < nfp then
            wsum[fp[p]] = wsum[fp[p]] + w[p]
        end
        p = p + u32(1)
    end
    mut c = u32(0)
    while c < d do
        p = u32(0)
        while p < np do
            f = fp[p]
            if f < nfp then
                acc[f * d + c] = acc[f * d + c] + w[p] * phi[c * np + p]
            end
            p = p + u32(1)
        end
        c = c + u32(1)
    end
    q = u32(0)
    while q < nfp do
        c = u32(0)
        while c < d do
            acc[q * d + c] = acc[q * d + c] / max(wsum[q], f32(0.000001))
            c = c + u32(1)
        end
        q = q + u32(1)
    end
end

pub fn fp_mean(phi: f32[], d: u32, w: f32[], fp: u32[], f: u32, row: f32[], ro: u32) -> f32
    np = D.NPIX
    mut ws = f32(0.0)
    mut p = u32(0)
    while p < np do
        if fp[p] == f then
            ws = ws + w[p]
        end
        p = p + u32(1)
    end
    mut c = u32(0)
    while c < d do
        mut s = f32(0.0)
        p = u32(0)
        while p < np do
            if fp[p] == f then
                s = s + w[p] * phi[c * np + p]
            end
            p = p + u32(1)
        end
        row[ro + c] = s / max(ws, f32(0.000001))
        c = c + u32(1)
    end
    return ws
end

fn app32(b: u8[], v: u32)
    push(b, u8(v & u32(255)))
    push(b, u8((v >> u32(8)) & u32(255)))
    push(b, u8((v >> u32(16)) & u32(255)))
    push(b, u8(v >> u32(24)))
end

fn appf(b: u8[], v: f32)
    app32(b, tobits(v))
end

fn appf_arr(b: u8[], a: f32[], n: u32)
    mut i = u32(0)
    while i < n do
        appf(b, a[i])
        i = i + u32(1)
    end
end

fn appd_arr(b: u8[], a: f64[], n: u32)
    mut i = u32(0)
    while i < n do
        appf(b, f32(a[i]))
        i = i + u32(1)
    end
end

pub fn term_name(o: u8[], i: u32)
    if i == u32(0) then
        TX.putstr(o, bytes("1"))
        return
    end
    mut k = i - u32(1)
    if k >= u32(42) then
        TX.putstr(o, bytes("soil*"))
        k = k - u32(42)
    else
        if k >= u32(21) then
            TX.putstr(o, bytes("box7:"))
            k = k - u32(21)
        end
    end
    if k == u32(0) then
        TX.putstr(o, bytes("B2"))
    end
    if k == u32(1) then
        TX.putstr(o, bytes("B3"))
    end
    if k == u32(2) then
        TX.putstr(o, bytes("B4"))
    end
    if k == u32(3) then
        TX.putstr(o, bytes("B8"))
    end
    if k == u32(4) then
        TX.putstr(o, bytes("B5"))
    end
    if k == u32(5) then
        TX.putstr(o, bytes("B6"))
    end
    if k == u32(6) then
        TX.putstr(o, bytes("B7"))
    end
    if k == u32(7) then
        TX.putstr(o, bytes("B8A"))
    end
    if k == u32(8) then
        TX.putstr(o, bytes("B11"))
    end
    if k == u32(9) then
        TX.putstr(o, bytes("B12"))
    end
    if k == u32(10) then
        TX.putstr(o, bytes("NDVI"))
    end
    if k == u32(11) then
        TX.putstr(o, bytes("NDMI"))
    end
    if k == u32(12) then
        TX.putstr(o, bytes("NDWI"))
    end
    if k == u32(13) then
        TX.putstr(o, bytes("NDRE"))
    end
    if k == u32(14) then
        TX.putstr(o, bytes("BSI"))
    end
    if k == u32(15) then
        TX.putstr(o, bytes("f_soil"))
    end
    if k == u32(16) then
        TX.putstr(o, bytes("f_green"))
    end
    if k == u32(17) then
        TX.putstr(o, bytes("f_dry"))
    end
    if k == u32(18) then
        TX.putstr(o, bytes("f_water"))
    end
    if k == u32(19) then
        TX.putstr(o, bytes("sin_doy"))
    end
    if k == u32(20) then
        TX.putstr(o, bytes("cos_doy"))
    end
end

pub fn target_name(o: u8[], t: u32)
    if t == u32(0) then
        TX.putstr(o, bytes("field boundary"))
        return
    end
    if t >= u32(25) then
        k = t - u32(25)
        if k == u32(0) then
            TX.putstr(o, bytes("air temperature"))
        end
        if k == u32(1) then
            TX.putstr(o, bytes("relative humidity"))
        end
        if k == u32(2) then
            TX.putstr(o, bytes("soil moisture 0-7cm"))
        end
        if k == u32(3) then
            TX.putstr(o, bytes("water balance 30d"))
        end
        return
    end
    k = t - u32(1)
    pr = k / u32(6)
    if pr == u32(0) then
        TX.putstr(o, bytes("pH "))
    end
    if pr == u32(1) then
        TX.putstr(o, bytes("organic carbon "))
    end
    if pr == u32(2) then
        TX.putstr(o, bytes("clay "))
    end
    if pr == u32(3) then
        TX.putstr(o, bytes("sand "))
    end
    dp = k % u32(6)
    if dp == u32(0) then
        TX.putstr(o, bytes("0-5cm"))
    end
    if dp == u32(1) then
        TX.putstr(o, bytes("5-15cm"))
    end
    if dp == u32(2) then
        TX.putstr(o, bytes("15-30cm"))
    end
    if dp == u32(3) then
        TX.putstr(o, bytes("30-60cm"))
    end
    if dp == u32(4) then
        TX.putstr(o, bytes("60-100cm"))
    end
    if dp == u32(5) then
        TX.putstr(o, bytes("100-200cm"))
    end
end

pub fn main(maxpatch: u32, dps: u32, nyr: u32) -> u32
    root = bytes("data/kaggle/munich480/")
    t0 = clock()
    soil = D.load_soil(bytes("data/bavaria/soil/"))
    wx = D.load_weather(bytes("data/bavaria/weather/"), u32(2016))
    cm = D.crop_map(bytes("data/kaggle/munich480/classes.txt"))
    tr_all = D.read_ids(bytes("data/kaggle/munich480/tileids/train_fold0.tileids"))
    ev_all = D.read_ids(bytes("data/kaggle/munich480/tileids/eval.tileids"))
    mut tr = array[u32](0)
    mut ev = array[u32](0)
    mut i = u32(0)
    while i < len(tr_all) and len(tr) < maxpatch do
        mut dirchk = D.patch_dir(root, u32(2016), tr_all[i])
        push(dirchk, u8(121))
        push(dirchk, u8(46))
        push(dirchk, u8(116))
        push(dirchk, u8(105))
        push(dirchk, u8(102))
        if len(readfile(dirchk)) > u32(0) then
            push(tr, tr_all[i])
        end
        i = i + u32(1)
    end
    i = u32(0)
    while i < len(ev_all) and len(ev) < maxpatch / u32(3) do
        mut dirchk = D.patch_dir(root, u32(2016), ev_all[i])
        push(dirchk, u8(121))
        push(dirchk, u8(46))
        push(dirchk, u8(116))
        push(dirchk, u8(105))
        push(dirchk, u8(102))
        if len(readfile(dirchk)) > u32(0) then
            push(ev, ev_all[i])
        end
        i = i + u32(1)
    end
    sayf(bytes("train patches available: "), f64(len(tr)), u32(0))
    sayf(bytes("eval patches available:  "), f64(len(ev)), u32(0))
    sayf(bytes("weather grid points:     "), f64(wx.np), u32(0))

    mut refl = array[f32](D.NBAND * D.NPIX)
    mut dates = array[u32](16)
    mut norm = array[f32](20)
    mut em = array[f64](40)
    library_em(em)
    mut lib = array[f64](40)
    library_em(lib)
    mut sum = array[f64](10)
    mut sq = array[f64](10)
    mut cnt = 0.0
    mut samp = array[f32](0)
    i = u32(0)
    while i < len(tr) do
        dir = D.patch_dir(root, u32(2016), tr[i])
        nd = pick_dates(dir, u32(2), refl, dates)
        mut k = u32(0)
        while k < nd do
            ok = D.load_refl(dir, dates[k], refl, u32(0))
            mut p = u32(0)
            while p < D.NPIX do
                mut b = u32(0)
                while b < D.NBAND do
                    v = f64(refl[b * D.NPIX + p])
                    sum[b] = sum[b] + v
                    sq[b] = sq[b] + v * v
                    b = b + u32(1)
                end
                cnt = cnt + 1.0
                if p % u32(97) == u32(0) then
                    b = u32(0)
                    while b < D.NBAND do
                        push(samp, refl[b * D.NPIX + p])
                        b = b + u32(1)
                    end
                end
                p = p + u32(1)
            end
            k = k + u32(1)
        end
        i = i + u32(40)
    end
    mut b = u32(0)
    while b < D.NBAND do
        mu = sum[b] / cnt
        norm[b] = f32(mu)
        norm[D.NBAND + b] = f32(sqrt(max(sq[b] / cnt - mu * mu, 1e-8)))
        b = b + u32(1)
    end
    ns = len(samp) / D.NBAND
    sayf(bytes("pass 0 pixels for endmembers: "), f64(ns), u32(0))
    mut pq = array[f32](44)
    mut ab = array[f32](4)
    mut it = u32(0)
    while it < u32(4) do
        D.unmix_prep(em, pq)
        mut ata = array[f64](16)
        mut atr = array[f64](40)
        mut s = u32(0)
        while s < ns do
            D.unmix(pq, samp, s * D.NBAND, u32(1), ab)
            mut a = u32(0)
            while a < u32(4) do
                mut c = u32(0)
                while c < u32(4) do
                    ata[a * u32(4) + c] = ata[a * u32(4) + c] + f64(ab[a] * ab[c])
                    c = c + u32(1)
                end
                b = u32(0)
                while b < D.NBAND do
                    atr[a * D.NBAND + b] = atr[a * D.NBAND + b] + f64(ab[a] * samp[s * D.NBAND + b])
                    b = b + u32(1)
                end
                a = a + u32(1)
            end
            s = s + u32(1)
        end
        mut l = array[f64](16)
        mu = M.mean_diag(ata, u32(4))
        bad = M.factor_ridge(ata, u32(4), mu, l)
        mut col = array[f64](40)
        mut sol = array[f64](40)
        b = u32(0)
        while b < D.NBAND do
            mut a = u32(0)
            while a < u32(4) do
                col[a * D.NBAND + b] = atr[a * D.NBAND + b] + mu * lib[b * u32(4) + a]
                a = a + u32(1)
            end
            M.chol_solve(l, u32(4), col, D.NBAND, b, sol)
            a = u32(0)
            while a < u32(4) do
                em[b * u32(4) + a] = max(0.005, sol[a * D.NBAND + b])
                a = a + u32(1)
            end
            b = b + u32(1)
        end
        it = it + u32(1)
    end
    D.unmix_prep(em, pq)
    say(bytes("endmember spectra (B2 B3 B4 B8 B5 B6 B7 B8A B11 B12):\n"))
    mut a2 = u32(0)
    while a2 < u32(4) do
        mut o = array[u8](0)
        if a2 == u32(0) then
            TX.putstr(o, bytes("  soil  "))
        end
        if a2 == u32(1) then
            TX.putstr(o, bytes("  green "))
        end
        if a2 == u32(2) then
            TX.putstr(o, bytes("  dry   "))
        end
        if a2 == u32(3) then
            TX.putstr(o, bytes("  water "))
        end
        b = u32(0)
        while b < D.NBAND do
            TX.putfix(o, em[b * u32(4) + a2], u32(3))
            TX.putch(o, u32(32))
            b = b + u32(1)
        end
        TX.putch(o, u32(10))
        say(o)
        a2 = a2 + u32(1)
    end

    mut x = array[f32](D.NBASE * D.NPIX)
    mut gm = array[f32](D.NPIX * M.NG)
    ng2 = M.NG * M.NG
    mut mt = array[f64](u32(3) * ng2)
    mut me = array[f64](u32(3) * ng2)
    mut bt = array[f64](M.NG * NLAW)
    mut be = array[f64](M.NG * NLAW)
    mut yyt = array[f64](NLAW)
    mut yye = array[f64](NLAW)
    mut sumy = array[f64](NLAW)
    mut sumyy = array[f64](NLAW)
    mut ny = array[f64](3)
    mut cropn = array[f64](D.NCROP)
    mut wrbn = array[f64](256)
    mut grow = array[f32](M.NG)
    mut wsoil = array[f32](D.NPIX)
    mut wxo = array[f64](4)
    mut nsamp1 = u32(0)
    mut split = u32(0)
    while split < u32(2) do
        mut ids = tr
        if split == u32(1) then
            ids = ev
        end
        i = u32(0)
        while i < len(ids) * nyr do
            yr = u32(2016) + i / len(ids)
            dir = D.patch_dir(root, yr, ids[i % len(ids)])
            pt = D.load_patch(dir, cm, soil)
            if pt.ok then
                nd = pick_dates(dir, u32(2), refl, dates)
                mut k = u32(0)
                while k < nd do
                    dd = D.doy(dates[k])
                    okw = D.weather_at(wx, pt.lat, pt.lon, yr, dd, wxo)
                    if okw and D.load_refl(dir, dates[k], refl, u32(0)) then
                        D.base_channels(refl, u32(0), dd, norm, pq, x, u32(0))
                        M.grammar(x, u32(0), gm)
                        nsamp1 = nsamp1 + u32(1)
                        mut p = u32(0)
                        while p < D.NPIX do
                            if (p / D.N) % u32(3) == u32(1) and (p % D.N) % u32(3) == u32(1) then
                                y = f64(pt.bnd[p])
                                mut a = u32(0)
                                while a < M.NG do
                                    ga = f64(gm[p * M.NG + a])
                                    if split == u32(0) then
                                        bt[a * NLAW] = bt[a * NLAW] + ga * y
                                    else
                                        be[a * NLAW] = be[a * NLAW] + ga * y
                                    end
                                    mut c = u32(0)
                                    while c < M.NG do
                                        if split == u32(0) then
                                            mt[a * M.NG + c] = mt[a * M.NG + c] + ga * f64(gm[p * M.NG + c])
                                        else
                                            me[a * M.NG + c] = me[a * M.NG + c] + ga * f64(gm[p * M.NG + c])
                                        end
                                        c = c + u32(1)
                                    end
                                    a = a + u32(1)
                                end
                                if split == u32(0) then
                                    yyt[0] = yyt[0] + y * y
                                    cropn[pt.crop[p]] = cropn[pt.crop[p]] + 1.0
                                else
                                    yye[0] = yye[0] + y * y
                                end
                            end
                            wsoil[p] = x[u32(15) * D.NPIX + p] + f32(0.05)
                            p = p + u32(1)
                        end
                        mut f = u32(0)
                        while f < pt.nfp do
                            if pt.fpok[f] == u32(1) then
                                mut ws = f32(0.0)
                                mut a = u32(0)
                                while a < M.NG do
                                    grow[a] = f32(0.0)
                                    a = a + u32(1)
                                end
                                p = u32(0)
                                while p < D.NPIX do
                                    if pt.fp[p] == f then
                                        ws = ws + wsoil[p]
                                        a = u32(0)
                                        while a < M.NG do
                                            grow[a] = grow[a] + wsoil[p] * gm[p * M.NG + a]
                                            a = a + u32(1)
                                        end
                                    end
                                    p = p + u32(1)
                                end
                                if ws > f32(0.0) then
                                    if split == u32(0) then
                                        wrbn[pt.wrb[f]] = wrbn[pt.wrb[f]] + 1.0
                                        ny[1] = ny[1] + 1.0
                                    end
                                    a = u32(0)
                                    while a < M.NG do
                                        ga = f64(grow[a] / ws)
                                        mut t = u32(0)
                                        while t < D.NSOIL do
                                            y = f64(pt.soil[f * D.NSOIL + t])
                                            if split == u32(0) then
                                                bt[a * NLAW + u32(1) + t] = bt[a * NLAW + u32(1) + t] + ga * y
                                            else
                                                be[a * NLAW + u32(1) + t] = be[a * NLAW + u32(1) + t] + ga * y
                                            end
                                            t = t + u32(1)
                                        end
                                        mut c = u32(0)
                                        while c < M.NG do
                                            gc = f64(grow[c] / ws)
                                            if split == u32(0) then
                                                mt[ng2 + a * M.NG + c] = mt[ng2 + a * M.NG + c] + ga * gc
                                            else
                                                me[ng2 + a * M.NG + c] = me[ng2 + a * M.NG + c] + ga * gc
                                            end
                                            c = c + u32(1)
                                        end
                                        a = a + u32(1)
                                    end
                                    mut t = u32(0)
                                    while t < D.NSOIL do
                                        y = f64(pt.soil[f * D.NSOIL + t])
                                        if split == u32(0) then
                                            yyt[u32(1) + t] = yyt[u32(1) + t] + y * y
                                            sumy[u32(1) + t] = sumy[u32(1) + t] + y
                                            sumyy[u32(1) + t] = sumyy[u32(1) + t] + y * y
                                        else
                                            yye[u32(1) + t] = yye[u32(1) + t] + y * y
                                        end
                                        t = t + u32(1)
                                    end
                                end
                            end
                            f = f + u32(1)
                        end
                        mut a = u32(0)
                        while a < M.NG do
                            mut s = f32(0.0)
                            p = u32(0)
                            while p < D.NPIX do
                                s = s + gm[p * M.NG + a]
                                p = p + u32(1)
                            end
                            grow[a] = s / f32(D.NPIX)
                            a = a + u32(1)
                        end
                        if split == u32(0) then
                            ny[2] = ny[2] + 1.0
                        end
                        a = u32(0)
                        while a < M.NG do
                            ga = f64(grow[a])
                            mut t = u32(0)
                            while t < D.NWX do
                                if split == u32(0) then
                                    bt[a * NLAW + u32(25) + t] = bt[a * NLAW + u32(25) + t] + ga * wxo[t]
                                else
                                    be[a * NLAW + u32(25) + t] = be[a * NLAW + u32(25) + t] + ga * wxo[t]
                                end
                                t = t + u32(1)
                            end
                            mut c = u32(0)
                            while c < M.NG do
                                if split == u32(0) then
                                    mt[u32(2) * ng2 + a * M.NG + c] = mt[u32(2) * ng2 + a * M.NG + c] + ga * f64(grow[c])
                                else
                                    me[u32(2) * ng2 + a * M.NG + c] = me[u32(2) * ng2 + a * M.NG + c] + ga * f64(grow[c])
                                end
                                c = c + u32(1)
                            end
                            a = a + u32(1)
                        end
                        mut t = u32(0)
                        while t < D.NWX do
                            if split == u32(0) then
                                yyt[u32(25) + t] = yyt[u32(25) + t] + wxo[t] * wxo[t]
                                sumy[u32(25) + t] = sumy[u32(25) + t] + wxo[t]
                                sumyy[u32(25) + t] = sumyy[u32(25) + t] + wxo[t] * wxo[t]
                            else
                                yye[u32(25) + t] = yye[u32(25) + t] + wxo[t] * wxo[t]
                            end
                            t = t + u32(1)
                        end
                    end
                    k = k + u32(1)
                end
            end
            i = i + u32(1)
        end
        split = split + u32(1)
    end
    sayf(bytes("pass 1 samples (laws): "), f64(nsamp1), u32(0))
    sayf(bytes("pass 1 seconds: "), clock() - t0, u32(1))

    mut laws = array[u32](NLAW * u32(2) * u32(4))
    mut coefs = array[f64](NLAW * u32(2) * u32(4))
    mut lawr2 = array[f64](NLAW * u32(2))
    mut bi = array[u32](4)
    mut bc = array[f64](4)
    mut br = array[f64](M.NG)
    mut ber = array[f64](M.NG)
    mut mtg = array[f64](ng2)
    mut meg = array[f64](ng2)
    mut btt = array[f64](M.NG)
    mut bee = array[f64](M.NG)
    mut rep = array[u8](0)
    TX.putstr(rep, bytes("LAW NEURONS (fitted on train patches, scored on held-out patches)\n"))
    mut t = u32(0)
    while t < NLAW do
        mut grp = u32(0)
        if t >= u32(1) then
            grp = u32(1)
        end
        if t >= u32(25) then
            grp = u32(2)
        end
        mut q = u32(0)
        while q < ng2 do
            mtg[q] = mt[grp * ng2 + q]
            meg[q] = me[grp * ng2 + q]
            q = q + u32(1)
        end
        q = u32(0)
        while q < M.NG do
            btt[q] = bt[q * NLAW + t]
            bee[q] = be[q * NLAW + t]
            q = q + u32(1)
        end
        ne = meg[0]
        sst = yye[t] - bee[0] * bee[0] / max(ne, 1.0)
        e1 = M.law_search(mtg, btt, meg, bee, yye[t], bi, bc)
        q = u32(0)
        while q < u32(4) do
            laws[(t * u32(2)) * u32(4) + q] = bi[q]
            coefs[(t * u32(2)) * u32(4) + q] = bc[q]
            q = q + u32(1)
        end
        yr = M.residual_moments(mtg, btt, yyt[t], bi, bc, br)
        yre = M.residual_moments(meg, bee, yye[t], bi, bc, ber)
        mut bi2 = array[u32](4)
        mut bc2 = array[f64](4)
        e2 = M.law_search(mtg, br, meg, ber, yre, bi2, bc2)
        q = u32(0)
        while q < u32(4) do
            laws[(t * u32(2) + u32(1)) * u32(4) + q] = bi2[q]
            coefs[(t * u32(2) + u32(1)) * u32(4) + q] = bc2[q]
            q = q + u32(1)
        end
        r1 = 1.0 - e1 / max(sst, 1e-12)
        r2 = 1.0 - e2 / max(sst, 1e-12)
        lawr2[t * u32(2)] = r1
        lawr2[t * u32(2) + u32(1)] = r2
        TX.putstr(rep, bytes("  "))
        target_name(rep, t)
        TX.putstr(rep, bytes(": R2 "))
        TX.putfix(rep, r1, u32(3))
        TX.putstr(rep, bytes(" -> "))
        TX.putfix(rep, r2, u32(3))
        TX.putstr(rep, bytes(" with layer 2 | y = "))
        TX.putsci(rep, bc[0], u32(3))
        mut z = u32(0)
        while z < bi[0] do
            TX.putstr(rep, bytes(" + "))
            TX.putsci(rep, bc[z + u32(1)], u32(3))
            TX.putstr(rep, bytes("*"))
            term_name(rep, bi[z + u32(1)])
            z = z + u32(1)
        end
        TX.putstr(rep, bytes(" | residual: "))
        z = u32(0)
        while z < bi2[0] do
            TX.putstr(rep, bytes(" + "))
            TX.putsci(rep, bc2[z + u32(1)], u32(3))
            TX.putstr(rep, bytes("*"))
            term_name(rep, bi2[z + u32(1)])
            z = z + u32(1)
        end
        TX.putch(rep, u32(10))
        t = t + u32(1)
    end
    say(rep)
    sayf(bytes("laws done, seconds: "), clock() - t0, u32(1))

    mut wrbmap = array[u32](256)
    mut wrbcodes = array[u32](0)
    mut c2 = u32(0)
    while c2 < u32(256) do
        wrbmap[c2] = u32(255)
        if wrbn[c2] >= 20.0 then
            wrbmap[c2] = len(wrbcodes)
            push(wrbcodes, c2)
        end
        c2 = c2 + u32(1)
    end
    nw = len(wrbcodes)
    sayf(bytes("WRB soil groups in region: "), f64(nw), u32(0))
    mut cw = array[f32](D.NCROP)
    mut totc = 0.0
    c2 = u32(0)
    while c2 < D.NCROP do
        totc = totc + cropn[c2]
        c2 = c2 + u32(1)
    end
    c2 = u32(0)
    while c2 < D.NCROP do
        cw[c2] = f32(sqrt(totc / f64(D.NCROP) / max(cropn[c2], 1.0)))
        cw[c2] = min(cw[c2], f32(10.0))
        c2 = c2 + u32(1)
    end
    mut ymu = array[f32](NLAW)
    mut ysd = array[f32](NLAW)
    t = u32(1)
    while t < NLAW do
        mut nn = ny[1]
        if t >= u32(25) then
            nn = ny[2]
        end
        mu = sumy[t] / max(nn, 1.0)
        ymu[t] = f32(mu)
        ysd[t] = f32(sqrt(max(sumyy[t] / max(nn, 1.0) - mu * mu, 1e-12)))
        t = t + u32(1)
    end

    msoil = D.NSOIL + nw
    df2 = DF * DF
    mut gp = array[f64](df2)
    mut gpe = array[f64](df2)
    mut gs = array[f64](df2)
    mut gse = array[f64](df2)
    mut gw = array[f64](df2)
    mut gwe = array[f64](df2)
    mut xyp = array[f64](DF * NPIXT)
    mut xype = array[f64](DF * NPIXT)
    mut xys = array[f64](DF * msoil)
    mut xyse = array[f64](DF * msoil)
    mut xyw = array[f64](DF * D.NWX)
    mut xywe = array[f64](DF * D.NWX)
    mut yyp = array[f64](NPIXT)
    mut yype = array[f64](NPIXT)
    mut yys = array[f64](msoil)
    mut yyse = array[f64](msoil)
    mut yyw = array[f64](D.NWX)
    mut yywe = array[f64](D.NWX)
    p = conv_params(u64(20261107))
    mut xb = array[f32](NB * D.NBASE * D.NPIX)
    act = NB * M.NFEAT * D.NPIX
    mut f1 = array[f32](act)
    mut f2 = array[f32](act)
    mut f3 = array[f32](act)
    mut f4 = array[f32](act)
    mut gmb = array[f32](NB * D.NPIX * M.NG)
    mut phi = array[f32](DF * D.NPIX)
    mut rows = array[f32](u32(256) * DF)
    mut ry = array[f32](u32(256) * NPIXT)
    mut rw = array[f32](u32(256))
    mut srow = array[f32](D.MAXFP * DF)
    mut sy = array[f32](D.MAXFP * msoil)
    mut sw = array[f32](D.MAXFP)
    mut wrow = array[f32](DF)
    mut wy = array[f32](D.NWX)
    mut one = array[f32](1)
    one[0] = f32(1.0)
    mut slot_split = array[u32](NB)
    mut slot_crop = array[u32](NB * D.NPIX)
    mut slot_bnd = array[u32](NB * D.NPIX)
    mut slot_fp = array[u32](NB * D.NPIX)
    mut slot_soil = array[f32](NB * D.MAXFP * D.NSOIL)
    mut slot_wrb = array[u32](NB * D.MAXFP)
    mut slot_ok = array[u32](NB * D.MAXFP)
    mut slot_nfp = array[u32](NB)
    mut slot_wx = array[f64](NB * u32(4))
    mut nsamp2 = u32(0)
    mut filled = u32(0)
    mut ti = u32(0)
    nbase = len(tr) + len(ev)
    mut total = nbase * nyr
    mut sel = array[u32](16)
    while ti <= total do
        mut flush = ti == total
        if ti < total then
            mut pid = u32(0)
            mut sp = u32(0)
            tb = ti % nbase
            yr = u32(2016) + ti / nbase
            if tb < len(tr) then
                pid = tr[tb]
            else
                pid = ev[tb - len(tr)]
                sp = u32(1)
            end
            dir = D.patch_dir(root, yr, pid)
            pt = D.load_patch(dir, cm, soil)
            if pt.ok then
                mut want = dps
                if sp == u32(1) then
                    want = u32(2)
                end
                nd = pick_dates(dir, want, refl, sel)
                mut k = u32(0)
                while k < nd do
                    dd = D.doy(sel[k])
                    okw = D.weather_at(wx, pt.lat, pt.lon, yr, dd, wxo)
                    if okw and D.load_refl(dir, sel[k], refl, u32(0)) then
                        D.base_channels(refl, u32(0), dd, norm, pq, xb, filled * D.NBASE * D.NPIX)
                        mut q = u32(0)
                        while q < D.NBASE * D.NPIX do
                            x[q] = xb[filled * D.NBASE * D.NPIX + q]
                            q = q + u32(1)
                        end
                        M.grammar(x, u32(0), gm)
                        q = u32(0)
                        while q < D.NPIX * M.NG do
                            gmb[filled * D.NPIX * M.NG + q] = gm[q]
                            q = q + u32(1)
                        end
                        slot_split[filled] = sp
                        q = u32(0)
                        while q < D.NPIX do
                            slot_crop[filled * D.NPIX + q] = pt.crop[q]
                            slot_bnd[filled * D.NPIX + q] = pt.bnd[q]
                            slot_fp[filled * D.NPIX + q] = pt.fp[q]
                            q = q + u32(1)
                        end
                        q = u32(0)
                        while q < D.MAXFP * D.NSOIL do
                            slot_soil[filled * D.MAXFP * D.NSOIL + q] = pt.soil[q]
                            q = q + u32(1)
                        end
                        q = u32(0)
                        while q < D.MAXFP do
                            slot_wrb[filled * D.MAXFP + q] = pt.wrb[q]
                            slot_ok[filled * D.MAXFP + q] = pt.fpok[q]
                            q = q + u32(1)
                        end
                        slot_nfp[filled] = pt.nfp
                        q = u32(0)
                        while q < u32(4) do
                            slot_wx[filled * u32(4) + q] = wxo[q]
                            q = q + u32(1)
                        end
                        filled = filled + u32(1)
                        if filled == NB then
                            flush = true
                        end
                    end
                    if flush and filled > u32(0) and k + u32(1) < nd then
                        conv_bank(xb, p, f1, f2, f3, f4, filled)
                        nsamp2 = nsamp2 + filled
                        mut s = u32(0)
                        while s < filled do
                            accumulate(xb, f1, f2, f3, f4, gmb, s, laws, coefs, phi, rows, ry, rw, srow, sy, sw, wrow, wy, one,
                                       slot_split, slot_crop, slot_bnd, slot_fp, slot_soil, slot_wrb, slot_ok, slot_nfp, slot_wx,
                                       cw, wrbmap, nw, ymu, ysd, gp, gpe, gs, gse, gw, gwe, xyp, xype, xys, xyse, xyw, xywe, yyp, yype, yys, yyse, yyw, yywe)
                            s = s + u32(1)
                        end
                        filled = u32(0)
                        flush = false
                    end
                    k = k + u32(1)
                end
            end
        end
        if flush and filled > u32(0) then
            conv_bank(xb, p, f1, f2, f3, f4, filled)
            nsamp2 = nsamp2 + filled
            mut s = u32(0)
            while s < filled do
                accumulate(xb, f1, f2, f3, f4, gmb, s, laws, coefs, phi, rows, ry, rw, srow, sy, sw, wrow, wy, one,
                           slot_split, slot_crop, slot_bnd, slot_fp, slot_soil, slot_wrb, slot_ok, slot_nfp, slot_wx,
                           cw, wrbmap, nw, ymu, ysd, gp, gpe, gs, gse, gw, gwe, xyp, xype, xys, xyse, xyw, xywe, yyp, yype, yys, yyse, yyw, yywe)
                s = s + u32(1)
            end
            filled = u32(0)
        end
        if ti % u32(500) == u32(0) then
            mut o = array[u8](0)
            TX.putstr(o, bytes("pass 2: patch "))
            TX.putint(o, u64(ti))
            TX.putstr(o, bytes(" / "))
            TX.putint(o, u64(total))
            TX.putstr(o, bytes(", samples "))
            TX.putint(o, u64(nsamp2))
            TX.putstr(o, bytes(", "))
            TX.putfix(o, clock() - t0, u32(0))
            TX.putstr(o, bytes(" s\n"))
            say(o)
        end
        ti = ti + u32(1)
    end
    M.symmetrize(gp, DF)
    M.symmetrize(gpe, DF)
    M.symmetrize(gs, DF)
    M.symmetrize(gse, DF)
    M.symmetrize(gw, DF)
    M.symmetrize(gwe, DF)
    sayf(bytes("pass 2 samples: "), f64(nsamp2), u32(0))
    sayf(bytes("pass 2 seconds: "), clock() - t0, u32(1))

    mut betap = array[f64](DF * NPIXT)
    mut betas = array[f64](DF * msoil)
    mut betaw = array[f64](DF * D.NWX)
    mut lkp = array[u32](NPIXT)
    mut lks = array[u32](msoil)
    mut lkw = array[u32](D.NWX)
    mut ssep = array[f64](NPIXT)
    mut sses = array[f64](msoil)
    mut ssew = array[f64](D.NWX)
    mut cp = array[f64](NPIXT)
    mut cs = array[f64](msoil)
    mut cwt = array[f64](D.NWX)
    say(bytes("solve pixel heads\n"))
    w1 = M.solve_heads(gp, xyp, DF, NPIXT, gpe, xype, yype, betap, lkp, ssep, cp)
    say(bytes("stacking\n"))
    mut blaws = array[f64](DF * msoil)
    mut blaww = array[f64](DF * D.NWX)
    t = u32(0)
    while t < D.NSOIL + D.NWX do
        mut lt = u32(1) + t
        if t >= D.NSOIL then
            lt = u32(25) + t - D.NSOIL
        end
        a0 = -f64(ymu[lt]) / f64(ysd[lt])
        an = NEU + lt * u32(2) + u32(1)
        if t < D.NSOIL then
            blaws[t] = a0
            blaws[an * msoil + t] = 1.0 / f64(ysd[lt])
        else
            tw = t - D.NSOIL
            blaww[tw] = a0
            blaww[an * D.NWX + tw] = 1.0 / f64(ysd[lt])
        end
        t = t + u32(1)
    end
    say(bytes("solve soil heads (stacked on laws)\n"))
    w2 = M.solve_offset(gs, xys, yys, gse, xyse, yyse, DF, msoil, blaws, betas, lks, sses, cs)
    say(bytes("solve weather heads (stacked on laws)\n"))
    w3 = M.solve_offset(gw, xyw, yyw, gwe, xywe, yywe, DF, D.NWX, blaww, betaw, lkw, ssew, cwt)
    mut r = array[u8](0)
    TX.putstr(r, bytes("\nRIDGE HEADS (exact solves; certificate = relative residual of the normal equations)\n"))
    TX.putstr(r, bytes("  worst certificate: pixel heads "))
    TX.putsci(r, w1, u32(2))
    TX.putstr(r, bytes(", soil heads "))
    TX.putsci(r, w2, u32(2))
    TX.putstr(r, bytes(", weather heads "))
    TX.putsci(r, w3, u32(2))
    TX.putstr(r, bytes("\n  held-out R2 by target (footprint level for soil, patch level for weather):\n"))
    t = u32(0)
    while t < D.NSOIL do
        sst = yyse[t] - xyse[t] * xyse[t] / max(gse[0], 1.0)
        TX.putstr(r, bytes("    "))
        target_name(r, t + u32(1))
        TX.putstr(r, bytes(": stacked R2 "))
        TX.putfix(r, 1.0 - sses[t] / max(sst, 1e-12), u32(3))
        TX.putstr(r, bytes(" (law alone "))
        TX.putfix(r, lawr2[(t + u32(1)) * u32(2) + u32(1)], u32(3))
        TX.putstr(r, bytes("), lambda "))
        TX.putsci(r, M.lambda_at(lks[t]), u32(2))
        TX.putstr(r, bytes(" x mean diag\n"))
        t = t + u32(1)
    end
    t = u32(0)
    while t < D.NWX do
        sst = yywe[t] - xywe[t] * xywe[t] / max(gwe[0], 1.0)
        TX.putstr(r, bytes("    "))
        target_name(r, t + u32(25))
        TX.putstr(r, bytes(": stacked R2 "))
        TX.putfix(r, 1.0 - ssew[t] / max(sst, 1e-12), u32(3))
        TX.putstr(r, bytes(" (law alone "))
        TX.putfix(r, lawr2[(t + u32(25)) * u32(2) + u32(1)], u32(3))
        TX.putstr(r, bytes(")\n"))
        t = t + u32(1)
    end
    say(r)

    mut lsoil = array[f64](df2)
    mut lwx = array[f64](df2)
    bad1 = M.factor_ridge(gs, DF, M.lambda_at(lks[0]) * M.mean_diag(gs, DF), lsoil)
    bad2 = M.factor_ridge(gw, DF, M.lambda_at(lkw[0]) * M.mean_diag(gw, DF), lwx)
    mut out = array[u8](0)
    TX.putstr(out, bytes("AGRI"))
    app32(out, u32(1))
    app32(out, DF)
    app32(out, nw)
    app32(out, len(p))
    appf_arr(out, norm, u32(20))
    appd_arr(out, em, u32(40))
    mut z = u32(0)
    while z < nw do
        app32(out, wrbcodes[z])
        z = z + u32(1)
    end
    appf_arr(out, p, len(p))
    z = u32(0)
    while z < len(laws) do
        app32(out, laws[z])
        z = z + u32(1)
    end
    appd_arr(out, coefs, len(coefs))
    appf_arr(out, ymu, NLAW)
    appf_arr(out, ysd, NLAW)
    appd_arr(out, betap, DF * NPIXT)
    appd_arr(out, betas, DF * msoil)
    appd_arr(out, betaw, DF * D.NWX)
    mut s2 = array[f64](msoil + D.NWX)
    t = u32(0)
    while t < msoil do
        s2[t] = sses[t] / max(gse[0], 1.0)
        t = t + u32(1)
    end
    t = u32(0)
    while t < D.NWX do
        s2[msoil + t] = ssew[t] / max(gwe[0], 1.0)
        t = t + u32(1)
    end
    appd_arr(out, s2, msoil + D.NWX)
    appd_arr(out, lsoil, df2)
    appd_arr(out, lwx, df2)
    appf_arr(out, cw, D.NCROP)
    wrote = writefile("out/model.bin", out)
    mut fin = array[u8](0)
    TX.putstr(fin, rep)
    TX.putstr(fin, r)
    wr2 = writefile("out/train_report.txt", fin)
    sayf(bytes("model bytes written: "), f64(wrote), u32(0))
    sayf(bytes("total seconds: "), clock() - t0, u32(1))
    return nsamp2
end

pub fn accumulate(xb: f32[], f1: f32[], f2: f32[], f3: f32[], f4: f32[], gmb: f32[], s: u32, laws: u32[], coefs: f64[], phi: f32[],
                  rows: f32[], ry: f32[], rw: f32[], srow: f32[], sy: f32[], sw: f32[], wrow: f32[], wy: f32[], one: f32[],
                  slot_split: u32[], slot_crop: u32[], slot_bnd: u32[], slot_fp: u32[], slot_soil: f32[], slot_wrb: u32[], slot_ok: u32[],
                  slot_nfp: u32[], slot_wx: f64[], cw: f32[], wrbmap: u32[], nw: u32, ymu: f32[], ysd: f32[],
                  gp: f64[], gpe: f64[], gs: f64[], gse: f64[], gw: f64[], gwe: f64[], xyp: f64[], xype: f64[], xys: f64[], xyse: f64[],
                  xyw: f64[], xywe: f64[], yyp: f64[], yype: f64[], yys: f64[], yyse: f64[], yyw: f64[], yywe: f64[])
    np = D.NPIX
    mut gm = array[f32](np * M.NG)
    mut q = u32(0)
    while q < np * M.NG do
        gm[q] = gmb[s * np * M.NG + q]
        q = q + u32(1)
    end
    build_phi(xb, f1, f2, f3, f4, s, gm, laws, coefs, phi)
    msoil = D.NSOIL + nw
    ev = slot_split[s] == u32(1)
    mut nr = u32(0)
    mut p = u32(0)
    while p < np do
        if (p / D.N) % u32(3) == u32(1) and (p % D.N) % u32(3) == u32(1) then
            mut c = u32(0)
            while c < DF do
                rows[nr * DF + c] = phi[c * np + p]
                c = c + u32(1)
            end
            crop = slot_crop[s * np + p]
            ry[nr * NPIXT] = f32(slot_bnd[s * np + p])
            c = u32(0)
            while c < D.NCROP do
                ry[nr * NPIXT + u32(1) + c] = f32(u32(c == crop))
                c = c + u32(1)
            end
            rw[nr] = cw[crop]
            nr = nr + u32(1)
        end
        p = p + u32(1)
    end
    if ev then
        M.gram_add(gpe, rows, nr, DF, rw)
        M.rhs_add(xype, yype, rows, ry, nr, DF, NPIXT, rw)
    else
        M.gram_add(gp, rows, nr, DF, rw)
        M.rhs_add(xyp, yyp, rows, ry, nr, DF, NPIXT, rw)
    end
    mut ws = array[f32](np)
    p = u32(0)
    while p < np do
        ws[p] = phi[u32(16) * np + p] + f32(0.05)
        p = p + u32(1)
    end
    mut fpl = array[u32](np)
    p = u32(0)
    while p < np do
        fpl[p] = slot_fp[s * np + p]
        p = p + u32(1)
    end
    mut ns = u32(0)
    nfs = slot_nfp[s]
    mut facc = array[f32](D.MAXFP * DF)
    mut fws = array[f32](D.MAXFP)
    fp_means(phi, DF, ws, fpl, nfs, facc, fws)
    mut f = u32(0)
    while f < nfs do
        if slot_ok[s * D.MAXFP + f] == u32(1) and wrbmap[slot_wrb[s * D.MAXFP + f]] != u32(255) then
            wsum = fws[f]
            mut cc = u32(0)
            while cc < DF do
                srow[ns * DF + cc] = facc[f * DF + cc]
                cc = cc + u32(1)
            end
            if wsum > f32(0.0) then
                mut t = u32(0)
                while t < D.NSOIL do
                    sy[ns * msoil + t] = (slot_soil[(s * D.MAXFP + f) * D.NSOIL + t] - ymu[u32(1) + t]) / ysd[u32(1) + t]
                    t = t + u32(1)
                end
                wc = wrbmap[slot_wrb[s * D.MAXFP + f]]
                t = u32(0)
                while t < nw do
                    sy[ns * msoil + D.NSOIL + t] = f32(u32(t == wc))
                    t = t + u32(1)
                end
                sw[ns] = f32(1.0)
                ns = ns + u32(1)
            end
        end
        f = f + u32(1)
    end
    if ns > u32(0) then
        if ev then
            M.gram_add(gse, srow, ns, DF, sw)
            M.rhs_add(xyse, yyse, srow, sy, ns, DF, msoil, sw)
        else
            M.gram_add(gs, srow, ns, DF, sw)
            M.rhs_add(xys, yys, srow, sy, ns, DF, msoil, sw)
        end
    end
    mut c = u32(0)
    while c < DF do
        mut a = f32(0.0)
        p = u32(0)
        while p < np do
            a = a + phi[c * np + p]
            p = p + u32(1)
        end
        wrow[c] = a / f32(np)
        c = c + u32(1)
    end
    mut t = u32(0)
    while t < D.NWX do
        wy[t] = (f32(slot_wx[s * u32(4) + t]) - ymu[u32(25) + t]) / ysd[u32(25) + t]
        t = t + u32(1)
    end
    if ev then
        M.gram_add(gwe, wrow, u32(1), DF, one)
        M.rhs_add(xywe, yywe, wrow, wy, u32(1), DF, D.NWX, one)
    else
        M.gram_add(gw, wrow, u32(1), DF, one)
        M.rhs_add(xyw, yyw, wrow, wy, u32(1), DF, D.NWX, one)
    end
end
