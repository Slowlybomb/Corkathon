mut D = require("data.cy")
mut M = require("model.cy")
mut TR = require("train.cy")
mut TF = require("../../lib/geo/tiff.cy")
mut PNG = require("../../lib/image/png_rgb.cy")
mut BY = require("../../lib/io/bytes.cy")
mut NT = require("net.cy")
mut RNG = require("../../lib/rng/random.cy")
mut TX = require("../../lib/io/text.cy")
mut SD = require("../../lib/io/strtod.cy")
mut U = require("../../lib/geo/utm.cy")

pub NOUT = u32(31)
pub NMAP = u32(9)
pub NF2 = u32(24)
pub NCH = u32(44)
SC = u32(4)
WIN = u32(600)

pub type Model
    mut df: u32
    mut nw: u32
    mut norm: f32[]
    mut em: f64[]
    mut wrb: u32[]
    mut p: f32[]
    mut laws: u32[]
    mut coefs: f64[]
    mut ymu: f32[]
    mut ysd: f32[]
    mut bp: f32[]
    mut bs: f32[]
    mut bw: f32[]
    mut s2: f32[]
    mut ls: f64[]
    mut lw: f64[]
    mut cw: f32[]
    mut s2on: u32
    mut df2: u32
    mut p2: f32[]
    mut b2p: f32[]
    mut b2s: f32[]
    mut b2w: f32[]
end

fn rf(d: u8[], at: u32[], n: u32) -> f32[]
    mut a = array[f32](n)
    mut i = u32(0)
    while i < n do
        a[i] = BY.f32le(d, at[0])
        at[0] = at[0] + u32(4)
        i = i + u32(1)
    end
    return a
end

fn rd64(d: u8[], at: u32[], n: u32) -> f64[]
    mut a = array[f64](n)
    mut i = u32(0)
    while i < n do
        a[i] = f64(BY.f32le(d, at[0]))
        at[0] = at[0] + u32(4)
        i = i + u32(1)
    end
    return a
end

fn ru(d: u8[], at: u32[], n: u32) -> u32[]
    mut a = array[u32](n)
    mut i = u32(0)
    while i < n do
        a[i] = BY.u32le(d, at[0])
        at[0] = at[0] + u32(4)
        i = i + u32(1)
    end
    return a
end

pub fn load_model(path: u8[]) -> Model
    mut d = readfile(path)
    if len(d) == u32(0) then
        d = readfile(bytes("models/agri.bin"))
    end
    mut at = array[u32](1)
    at[0] = u32(8)
    df = BY.u32le(d, at[0])
    nw = BY.u32le(d, at[0] + u32(4))
    np = BY.u32le(d, at[0] + u32(8))
    at[0] = at[0] + u32(12)
    norm = rf(d, at, u32(20))
    em = rd64(d, at, u32(40))
    wrb = ru(d, at, nw)
    p = rf(d, at, np)
    nl = TR.NLAW * u32(8)
    laws = ru(d, at, nl)
    coefs = rd64(d, at, nl)
    ymu = rf(d, at, TR.NLAW)
    ysd = rf(d, at, TR.NLAW)
    msoil = D.NSOIL + nw
    bp = rf(d, at, df * TR.NPIXT)
    bs = rf(d, at, df * msoil)
    bw = rf(d, at, df * D.NWX)
    s2 = rf(d, at, msoil + D.NWX)
    ls = rd64(d, at, df * df)
    lw = rd64(d, at, df * df)
    mut cw = array[f32](D.NCROP)
    if at[0] + D.NCROP * u32(4) <= len(d) then
        cw = rf(d, at, D.NCROP)
    end
    mut s2on = u32(0)
    mut df2 = u32(0)
    mut p2 = array[f32](0)
    mut b2p = array[f32](0)
    mut b2s = array[f32](0)
    mut b2w = array[f32](0)
    if at[0] + u32(12) <= len(d) then
        s2on = BY.u32le(d, at[0])
        df2 = BY.u32le(d, at[0] + u32(4))
        n2 = BY.u32le(d, at[0] + u32(8))
        at[0] = at[0] + u32(12)
        p2 = rf(d, at, n2)
        b2p = rf(d, at, df2 * TR.NPIXT)
        b2s = rf(d, at, df2 * msoil)
        b2w = rf(d, at, df2 * D.NWX)
    end
    return Model(df: df, nw: nw, norm: norm, em: em, wrb: wrb, p: p, laws: laws, coefs: coefs, ymu: ymu, ysd: ysd,
                 bp: bp, bs: bs, bw: bw, s2: s2, ls: ls, lw: lw, cw: cw, s2on: s2on, df2: df2, p2: p2, b2p: b2p, b2s: b2s, b2w: b2w)
end

pub fn heads(phi: f32[], bp: f32[], bs: f32[], bw: f32[], df: u32, nw: u32, ymu: f32[], ysd: f32[], out: f32[])
    np = D.NPIX
    msoil = D.NSOIL + nw
    cpu do
        mut p = u32(0)
        while p < np do
            mut acc = f32(0.0)
            mut c = u32(0)
            while c < df do
                acc = acc + phi[c * np + p] * bp[c * TR.NPIXT]
                c = c + u32(1)
            end
            out[p * NOUT] = acc
            mut best = f32(-1000000.0)
            mut bk = u32(0)
            mut k = u32(0)
            while k < D.NCROP do
                mut a = f32(0.0)
                c = u32(0)
                while c < df do
                    a = a + phi[c * np + p] * bp[c * TR.NPIXT + u32(1) + k]
                    c = c + u32(1)
                end
                if a > best then
                    best = a
                    bk = k
                end
                k = k + u32(1)
            end
            out[p * NOUT + u32(1)] = f32(bk)
            best = f32(-1000000.0)
            bk = u32(0)
            k = u32(0)
            while k < nw do
                mut a = f32(0.0)
                c = u32(0)
                while c < df do
                    a = a + phi[c * np + p] * bs[c * msoil + D.NSOIL + k]
                    c = c + u32(1)
                end
                if a > best then
                    best = a
                    bk = k
                end
                k = k + u32(1)
            end
            out[p * NOUT + u32(2)] = f32(bk)
            mut t = u32(0)
            while t < D.NSOIL do
                mut a = f32(0.0)
                c = u32(0)
                while c < df do
                    a = a + phi[c * np + p] * bs[c * msoil + t]
                    c = c + u32(1)
                end
                out[p * NOUT + u32(3) + t] = M.clamp_soil(t, a * ysd[u32(1) + t] + ymu[u32(1) + t])
                t = t + u32(1)
            end
            t = u32(0)
            while t < D.NWX do
                mut a = f32(0.0)
                c = u32(0)
                while c < df do
                    a = a + phi[c * np + p] * bw[c * D.NWX + t]
                    c = c + u32(1)
                end
                out[p * NOUT + u32(27) + t] = M.clamp_weather(t, a * ysd[u32(25) + t] + ymu[u32(25) + t])
                t = t + u32(1)
            end
            p = p + u32(1)
        end
    end
end

pub fn texture(clay: f32, sand: f32) -> u32
    silt = f32(100.0) - clay - sand
    if clay >= f32(40.0) then
        if silt >= f32(40.0) then
            return u32(10)
        end
        if sand <= f32(45.0) then
            return u32(11)
        end
        return u32(9)
    end
    if clay >= f32(35.0) and sand > f32(45.0) then
        return u32(9)
    end
    if clay >= f32(27.0) then
        if sand <= f32(20.0) then
            return u32(8)
        end
        if sand <= f32(45.0) then
            return u32(7)
        end
        return u32(6)
    end
    if clay >= f32(20.0) and silt < f32(28.0) and sand > f32(45.0) then
        return u32(6)
    end
    if silt >= f32(80.0) and clay < f32(12.0) then
        return u32(5)
    end
    if silt >= f32(50.0) then
        return u32(4)
    end
    if clay >= f32(7.0) and silt >= f32(28.0) and sand <= f32(52.0) then
        return u32(3)
    end
    if silt + f32(1.5) * clay < f32(15.0) then
        return u32(0)
    end
    if silt + f32(2.0) * clay < f32(30.0) then
        return u32(1)
    end
    return u32(2)
end

fn lerp3(out: u8[], o: u32, v: f32, c: u32[], n: u32)
    x = max(f32(0.0), min(f32(1.0), v)) * f32(n - u32(1))
    k = min(u32(x), n - u32(2))
    t = x - f32(k)
    mut i = u32(0)
    while i < u32(3) do
        a = f32(c[k * u32(3) + i])
        b = f32(c[(k + u32(1)) * u32(3) + i])
        out[o + i] = u8(a + (b - a) * t)
        i = i + u32(1)
    end
end

fn ramp(kind: u32) -> u32[]
    mut c = array[u32](15)
    if kind == u32(0) then
        c[0] = u32(68)
        c[1] = u32(1)
        c[2] = u32(84)
        c[3] = u32(59)
        c[4] = u32(82)
        c[5] = u32(139)
        c[6] = u32(33)
        c[7] = u32(145)
        c[8] = u32(140)
        c[9] = u32(94)
        c[10] = u32(201)
        c[11] = u32(98)
        c[12] = u32(253)
        c[13] = u32(231)
        c[14] = u32(37)
    end
    if kind == u32(1) then
        c[0] = u32(165)
        c[1] = u32(0)
        c[2] = u32(38)
        c[3] = u32(244)
        c[4] = u32(109)
        c[5] = u32(67)
        c[6] = u32(255)
        c[7] = u32(255)
        c[8] = u32(191)
        c[9] = u32(116)
        c[10] = u32(173)
        c[11] = u32(209)
        c[12] = u32(49)
        c[13] = u32(54)
        c[14] = u32(149)
    end
    if kind == u32(2) then
        c[0] = u32(165)
        c[1] = u32(0)
        c[2] = u32(38)
        c[3] = u32(253)
        c[4] = u32(174)
        c[5] = u32(97)
        c[6] = u32(255)
        c[7] = u32(255)
        c[8] = u32(191)
        c[9] = u32(166)
        c[10] = u32(217)
        c[11] = u32(106)
        c[12] = u32(0)
        c[13] = u32(104)
        c[14] = u32(55)
    end
    if kind == u32(3) then
        c[0] = u32(0)
        c[1] = u32(0)
        c[2] = u32(4)
        c[3] = u32(87)
        c[4] = u32(16)
        c[5] = u32(110)
        c[6] = u32(188)
        c[7] = u32(55)
        c[8] = u32(84)
        c[9] = u32(249)
        c[10] = u32(142)
        c[11] = u32(9)
        c[12] = u32(252)
        c[13] = u32(255)
        c[14] = u32(164)
    end
    if kind == u32(4) then
        c[0] = u32(247)
        c[1] = u32(251)
        c[2] = u32(255)
        c[3] = u32(198)
        c[4] = u32(219)
        c[5] = u32(239)
        c[6] = u32(107)
        c[7] = u32(174)
        c[8] = u32(214)
        c[9] = u32(33)
        c[10] = u32(113)
        c[11] = u32(181)
        c[12] = u32(8)
        c[13] = u32(48)
        c[14] = u32(107)
    end
    return c
end

fn cat_color(out: u8[], o: u32, k: u32)
    mut r = u32(128)
    mut g = u32(128)
    mut b = u32(128)
    h = (k * u32(2654435761)) >> u32(8)
    if k > u32(0) then
        r = u32(60) + (h & u32(127)) + (k * u32(37)) % u32(68)
        g = u32(60) + ((h >> u32(7)) & u32(127)) + (k * u32(71)) % u32(68)
        b = u32(60) + ((h >> u32(14)) & u32(127)) + (k * u32(113)) % u32(68)
    end
    out[o] = u8(min(r, u32(255)))
    out[o + u32(1)] = u8(min(g, u32(255)))
    out[o + u32(2)] = u8(min(b, u32(255)))
end

fn name_path(dir: u8[], base: u8[], ext: u8[]) -> u8[]
    mut p = array[u8](0)
    D.cat(p, dir)
    D.cat(p, base)
    D.cat(p, ext)
    return p
end

pub fn render(cv: f32[], w: u32, h: u32, ch: u32, kind: u32, lo: f32, hi: f32, dir: u8[], name: u8[]) -> u32
    mut img = array[u8](w * h * u32(3))
    cm = ramp(kind)
    mut q = u32(0)
    while q < w * h do
        o = q * u32(3)
        if cv[q * NCH + u32(43)] < f32(0.5) then
            img[o] = u8(30)
            img[o + u32(1)] = u8(30)
            img[o + u32(2)] = u8(30)
        else
            v = cv[q * NCH + ch]
            if kind >= u32(10) then
                cat_color(img, o, u32(v) + kind - u32(10))
            else
                lerp3(img, o, (v - lo) / (hi - lo), cm, u32(5))
            end
        end
        q = q + u32(1)
    end
    return writefile(name_path(dir, name, bytes(".png")), PNG.encode(img, w, h))
end

pub fn render_rgb(cv: f32[], w: u32, h: u32, mode: u32, bth: f32, dir: u8[], name: u8[]) -> u32
    mut img = array[u8](w * h * u32(3))
    mut q = u32(0)
    while q < w * h do
        o = q * u32(3)
        if cv[q * NCH + u32(43)] < f32(0.5) then
            img[o] = u8(30)
            img[o + u32(1)] = u8(30)
            img[o + u32(2)] = u8(30)
        else
            mut r = cv[q * NCH] * f32(3.2)
            mut g = cv[q * NCH + u32(1)] * f32(3.2)
            mut b = cv[q * NCH + u32(2)] * f32(3.2)
            if mode == u32(1) then
                sh = f32(1.0) - min(f32(1.0), max(f32(0.0), cv[q * NCH + u32(5)]) / (f32(2.0) * bth))
                r = r * sh
                g = g * sh
                b = b * sh
            end
            if mode == u32(2) then
                r = cv[q * NCH + u32(36)] + cv[q * NCH + u32(38)]
                g = cv[q * NCH + u32(37)] + cv[q * NCH + u32(38)]
                b = cv[q * NCH + u32(39)]
            end
            img[o] = u8(min(f32(255.0), max(f32(0.0), sqrt(min(r, f32(1.0))) * f32(255.0))))
            img[o + u32(1)] = u8(min(f32(255.0), max(f32(0.0), sqrt(min(g, f32(1.0))) * f32(255.0))))
            img[o + u32(2)] = u8(min(f32(255.0), max(f32(0.0), sqrt(min(b, f32(1.0))) * f32(255.0))))
        end
        q = q + u32(1)
    end
    return writefile(name_path(dir, name, bytes(".png")), PNG.encode(img, w, h))
end

pub fn export(cv: f32[], w: u32, h: u32, c0: u32, nb: u32, x0: f64, y0: f64, px: f64, epsg: u32, dir: u8[], name: u8[]) -> u32
    mut a = array[f32](w * h * nb)
    mut q = u32(0)
    while q < w * h do
        mut b = u32(0)
        while b < nb do
            mut v = cv[q * NCH + c0 + b]
            if cv[q * NCH + u32(43)] < f32(0.5) then
                v = f32(-9999.0)
            end
            a[q * nb + b] = v
            b = b + u32(1)
        end
        q = q + u32(1)
    end
    return writefile(name_path(dir, name, bytes(".tif")), TF.encode_f32(a, w, h, nb, x0, y0, px, px, epsg, f32(-9999.0)))
end

pub fn zones(cv: f32[], w: u32, h: u32, var: u32, zc: u32, bth: f32, usecrop: u32)
    mut lab = array[u32](w * h)
    mut stack = array[u32](w * h)
    mut members = array[u32](w * h)
    mut next = u32(1)
    mut q = u32(0)
    while q < w * h do
        cv[q * NCH + zc] = f32(0.0)
        q = q + u32(1)
    end
    q = u32(0)
    while q < w * h do
        qi = (q / w) % D.N
        qj = (q % w) % D.N
        qring = usecrop == u32(1) and (qi < u32(2) or qj < u32(2) or qi + u32(2) >= D.N or qj + u32(2) >= D.N)
        ok = not qring and cv[q * NCH + u32(43)] > f32(0.5) and cv[q * NCH + u32(5)] < bth and (usecrop == u32(0) or cv[q * NCH + u32(6)] > f32(0.5))
        if ok and lab[q] == u32(0) then
            crop = cv[q * NCH + u32(6)]
            mut top = u32(1)
            stack[0] = q
            lab[q] = next
            mut nm = u32(0)
            while top > u32(0) do
                top = top - u32(1)
                c = stack[top]
                members[nm] = c
                nm = nm + u32(1)
                ci = c / w
                cj = c % w
                mut k = u32(0)
                while k < u32(4) do
                    mut nb = w * h
                    if k == u32(0) and ci > u32(0) then
                        nb = c - w
                    end
                    if k == u32(1) and ci + u32(1) < h then
                        nb = c + w
                    end
                    if k == u32(2) and cj > u32(0) then
                        nb = c - u32(1)
                    end
                    if k == u32(3) and cj + u32(1) < w then
                        nb = c + u32(1)
                    end
                    if nb < w * h then
                        ni = (nb / w) % D.N
                        nj = (nb % w) % D.N
                        nring = usecrop == u32(1) and (ni < u32(2) or nj < u32(2) or ni + u32(2) >= D.N or nj + u32(2) >= D.N)
                        if not nring and lab[nb] == u32(0) and cv[nb * NCH + u32(43)] > f32(0.5) and cv[nb * NCH + u32(5)] < bth and (usecrop == u32(0) or cv[nb * NCH + u32(6)] == crop) then
                            lab[nb] = next
                            stack[top] = nb
                            top = top + u32(1)
                        end
                    end
                    k = k + u32(1)
                end
            end
            if nm >= u32(25) then
                mut s = 0.0
                mut ss = 0.0
                mut m = u32(0)
                while m < nm do
                    v = f64(cv[members[m] * NCH + var])
                    s = s + v
                    ss = ss + v * v
                    m = m + u32(1)
                end
                mu = s / f64(nm)
                sd = sqrt(max(ss / f64(nm) - mu * mu, 1e-12))
                m = u32(0)
                while m < nm do
                    z = (f64(cv[members[m] * NCH + var]) - mu) / sd
                    mut zn = 2.0
                    if z < -0.43 then
                        zn = 1.0
                    end
                    if z > 0.43 then
                        zn = 3.0
                    end
                    cv[members[m] * NCH + zc] = f32(zn)
                    m = m + u32(1)
                end
            end
            next = next + u32(1)
        end
        q = q + u32(1)
    end
end

pub fn render_zones(cv: f32[], w: u32, h: u32, zc: u32, dir: u8[], name: u8[]) -> u32
    mut img = array[u8](w * h * u32(3))
    mut q = u32(0)
    while q < w * h do
        o = q * u32(3)
        z = u32(cv[q * NCH + zc])
        mut r = u32(45)
        mut g = u32(45)
        mut b = u32(45)
        if z == u32(1) then
            r = u32(215)
            g = u32(48)
            b = u32(39)
        end
        if z == u32(2) then
            r = u32(254)
            g = u32(224)
            b = u32(139)
        end
        if z == u32(3) then
            r = u32(26)
            g = u32(152)
            b = u32(80)
        end
        img[o] = u8(r)
        img[o + u32(1)] = u8(g)
        img[o + u32(2)] = u8(b)
        q = q + u32(1)
    end
    return writefile(name_path(dir, name, bytes(".png")), PNG.encode(img, w, h))
end

pub fn quad_patch(l: f64[], df: u32, phi: f32[], fp: u32[], f: u32, w: f32[]) -> f64
    mut v = array[f64](df)
    mut ws = 0.0
    np = D.NPIX
    mut p = u32(0)
    while p < np do
        if f == u32(65535) or fp[p] == f then
            ws = ws + f64(w[p])
            mut c = u32(0)
            while c < df do
                v[c] = v[c] + f64(w[p]) * f64(phi[c * np + p])
                c = c + u32(1)
            end
        end
        p = p + u32(1)
    end
    mut c = u32(0)
    while c < df do
        v[c] = v[c] / max(ws, 1e-9)
        c = c + u32(1)
    end
    return M.quad_inv(l, df, v)
end

pub fn main(mode: u32, maxpatch: u32) -> u32
    root = bytes("data/kaggle/munich480/")
    t0 = clock()
    md = load_model(bytes("out/model.bin"))
    df = md.df
    nw = md.nw
    msoil = D.NSOIL + nw
    soil = D.load_soil(bytes("data/bavaria/soil/"))
    cm = D.crop_map(bytes("data/kaggle/munich480/classes.txt"))
    mut pq = array[f32](44)
    D.unmix_prep(md.em, pq)
    mut p = md.p
    mut norm = md.norm
    mut laws = md.laws
    mut coefs = md.coefs
    mut bp = md.bp
    mut bs = md.bs
    mut bw = md.bw
    mut ymu = md.ymu
    mut ysd = md.ysd
    mut ls = md.ls
    mut lw = md.lw
    mut s2 = md.s2
    s2on = md.s2on
    df2 = md.df2
    mut p2 = md.p2
    mut b2p = md.b2p
    mut b2s = md.b2s
    mut b2w = md.b2w
    mut phib = array[f32](TR.NB * df * D.NPIX)
    mut outb = array[f32](TR.NB * D.NPIX * NOUT)
    mut mapsb = array[f32](TR.NB * NMAP * D.NPIX)
    mut g1 = array[f32](TR.NB * NF2 * D.NPIX)
    mut g2 = array[f32](TR.NB * NF2 * D.NPIX)
    mut psi = array[f32](max(df2, u32(1)) * D.NPIX)
    mut ids = array[u32](0)
    if mode == u32(1) then
        all = D.read_ids(bytes("data/kaggle/munich480/tileids/eval.tileids"))
        for id in all do
            push(ids, id)
        end
    else
        listing = readfile(bytes("data/kaggle/munich480/data16/"))
        mut v = u32(0)
        mut have = false
        for c in listing do
            if c >= u8(48) and c <= u8(57) then
                v = v * u32(10) + u32(c) - u32(48)
                have = true
            else
                if have then
                    push(ids, v)
                end
                v = u32(0)
                have = false
            end
        end
    end
    mut refl = array[f32](D.NBAND * D.NPIX)
    mut sel = array[u32](16)
    mut tally = array[u32](400)
    mut dcode = array[u32](400)
    mut nd = u32(0)
    mut i = u32(0)
    while i < len(ids) and i < u32(4000) do
        dir = D.patch_dir(root, u32(2016), ids[i])
        dl = D.list_dates(dir)
        for dt in dl do
            dd = D.doy(dt)
            if dd >= u32(150) and dd <= u32(260) then
                if D.load_refl(dir, dt, refl, u32(0)) then
                    mut k = u32(0)
                    mut f = nd
                    while k < nd do
                        if dcode[k] == dt then
                            f = k
                        end
                        k = k + u32(1)
                    end
                    if f == nd and nd < u32(400) then
                        dcode[nd] = dt
                        nd = nd + u32(1)
                    end
                    if f < u32(400) then
                        tally[f] = tally[f] + u32(1)
                    end
                end
            end
        end
        i = i + u32(97)
    end
    mut best = u32(0)
    mut date = u32(0)
    i = u32(0)
    while i < nd do
        if tally[i] > best then
            best = tally[i]
            date = dcode[i]
        end
        i = i + u32(1)
    end
    TR.sayf(bytes("render date (most clear patches): "), f64(date), u32(0))

    mut px0 = array[f64](0)
    mut py0 = array[f64](0)
    mut pid = array[u32](0)
    i = u32(0)
    while i < len(ids) and len(pid) < maxpatch do
        mut yp = D.patch_dir(root, u32(2016), ids[i])
        D.cat(yp, bytes("y.tif"))
        t = TF.read(yp)
        if t.err == u32(0) and t.w == D.N then
            push(px0, t.x0)
            push(py0, t.y0)
            push(pid, ids[i])
        end
        i = i + u32(1)
    end
    npt = len(pid)
    mut xmin = 1e18
    mut xmax = -1e18
    mut ymin = 1e18
    mut ymax = -1e18
    i = u32(0)
    while i < npt do
        xmin = min(xmin, px0[i])
        xmax = max(xmax, px0[i] + 480.0)
        ymin = min(ymin, py0[i] - 480.0)
        ymax = max(ymax, py0[i])
        i = i + u32(1)
    end
    cw = u32((xmax - xmin) / 40.0)
    chh = u32((ymax - ymin) / 40.0)
    TR.sayf(bytes("patches: "), f64(npt), u32(0))
    TR.sayf(bytes("region width km: "), (xmax - xmin) / 1000.0, u32(1))
    TR.sayf(bytes("region height km: "), (ymax - ymin) / 1000.0, u32(1))
    gw = cw / u32(12)
    gh = chh / u32(12)
    mut occ = array[u32](gw * gh)
    i = u32(0)
    while i < npt do
        gx = u32((px0[i] - xmin) / 480.0)
        gy = u32((ymax - py0[i]) / 480.0)
        if gx < gw and gy < gh then
            occ[gy * gw + gx] = u32(1)
        end
        i = i + u32(1)
    end
    mut bx = u32(0)
    mut by = u32(0)
    mut bo = u32(0)
    mut gy = u32(0)
    while gy + u32(12) <= gh do
        mut gx = u32(0)
        while gx + u32(12) <= gw do
            mut s = u32(0)
            mut a = u32(0)
            while a < u32(12) do
                mut b = u32(0)
                while b < u32(12) do
                    s = s + occ[(gy + a) * gw + gx + b]
                    b = b + u32(1)
                end
                a = a + u32(1)
            end
            if s > bo then
                bo = s
                bx = gx
                by = gy
            end
            gx = gx + u32(1)
        end
        gy = gy + u32(1)
    end
    wx0 = xmin + f64(bx) * 480.0
    wy0 = ymax - f64(by) * 480.0
    TR.sayf(bytes("detail window patches: "), f64(bo), u32(0))

    mut cv = array[f32](cw * chh * NCH)
    mut dv = array[f32](WIN * WIN * NCH)
    mut usum = array[f64](8)
    mut x = array[f32](D.NBASE * D.NPIX)
    mut gm = array[f32](D.NPIX * M.NG)
    mut xb = array[f32](TR.NB * D.NBASE * D.NPIX)
    act = TR.NB * M.NFEAT * D.NPIX
    mut f1 = array[f32](act)
    mut f2 = array[f32](act)
    mut f3 = array[f32](act)
    mut f4 = array[f32](act)
    mut gmb = array[f32](TR.NB * D.NPIX * M.NG)
    mut phi = array[f32](df * D.NPIX)
    mut out = array[f32](D.NPIX * NOUT)
    mut slot = array[u32](TR.NB)
    mut slot_refl = array[f32](TR.NB * D.NBAND * D.NPIX)
    mut ws = array[f32](D.NPIX)
    mut tp = 0.0
    mut fpos = 0.0
    mut fneg = 0.0
    mut tps = array[f64](20)
    mut fps = array[f64](20)
    mut fns = array[f64](20)
    mut cok = 0.0
    mut ctot = 0.0
    mut sse = array[f64](8)
    mut sst1 = array[f64](8)
    mut sst2 = array[f64](8)
    mut cnt = array[f64](8)
    mut cover = array[f64](8)
    mut wok = 0.0
    mut wtot = 0.0
    mut filled = u32(0)
    mut done = u32(0)
    mut pi = u32(0)
    while pi <= npt do
        mut flush = pi == npt
        if pi < npt then
            dir = D.patch_dir(root, u32(2016), pid[pi])
            mut use = date
            if mode == u32(1) then
                n1 = TR.pick_dates(dir, u32(1), refl, sel)
                use = u32(0)
                if n1 > u32(0) then
                    use = sel[0]
                end
            end
            if use > u32(0) then
                if D.load_refl(dir, use, refl, u32(0)) then
                    D.base_channels(refl, u32(0), D.doy(use), norm, pq, xb, filled * D.NBASE * D.NPIX)
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
                    q = u32(0)
                    while q < D.NBAND * D.NPIX do
                        slot_refl[filled * D.NBAND * D.NPIX + q] = refl[q]
                        q = q + u32(1)
                    end
                    slot[filled] = pi
                    filled = filled + u32(1)
                    if filled == TR.NB then
                        flush = true
                    end
                end
            end
        end
        if flush and filled > u32(0) then
            TR.conv_bank(xb, p, f1, f2, f3, f4, filled)
            infer_batch(xb, f1, f2, f3, f4, gmb, filled, laws, coefs, bp, bs, bw, df, nw, ymu, ysd, s2on, p2, b2p, b2s, b2w, df2, phib, outb, mapsb, g1, g2, gm, phi, out, psi)
            mut s = u32(0)
            while s < filled do
                k = slot[s]
                mut q = u32(0)
                while q < df * D.NPIX do
                    phi[q] = phib[s * df * D.NPIX + q]
                    q = q + u32(1)
                end
                q = u32(0)
                while q < D.NPIX * NOUT do
                    out[q] = outb[s * D.NPIX * NOUT + q]
                    q = q + u32(1)
                end
                q = u32(0)
                while q < D.NPIX do
                    ws[q] = phi[u32(16) * D.NPIX + q] + f32(0.05)
                    q = q + u32(1)
                end
                mut nofp = array[u32](D.NPIX)
                qs = quad_patch(ls, df, phi, nofp, u32(65535), ws)
                mut one = array[f32](D.NPIX)
                q = u32(0)
                while q < D.NPIX do
                    one[q] = f32(1.0)
                    q = q + u32(1)
                end
                qw = quad_patch(lw, df, phi, nofp, u32(65535), one)
                sph = f32(sqrt(f64(s2[0]) * (1.0 + qs))) * ysd[1]
                smo = f32(sqrt(f64(s2[msoil + u32(2)]) * (1.0 + qw))) * ysd[27]
                if mode == u32(1) then
                    dir = D.patch_dir(root, u32(2016), pid[k])
                    pt = D.load_patch(dir, cm, soil)
                    mut pp = u32(0)
                    while pp < D.NPIX do
                        tb = pt.bnd[pp] == u32(1)
                        ri = pp / D.N
                        rj = pp % D.N
                        inner = ri >= u32(2) and rj >= u32(2) and ri + u32(2) < D.N and rj + u32(2) < D.N
                        mut th = u32(0)
                        while th < u32(20) and inner do
                            pbt = out[pp * NOUT] > f32(th + u32(1)) * f32(0.025)
                            if pbt and tb then
                                tps[th] = tps[th] + 1.0
                            end
                            if pbt and not tb then
                                fps[th] = fps[th] + 1.0
                            end
                            if tb and not pbt then
                                fns[th] = fns[th] + 1.0
                            end
                            th = th + u32(1)
                        end
                        pb = out[pp * NOUT] > f32(0.5)
                        if pb and tb then
                            tp = tp + 1.0
                        end
                        if pb and not tb then
                            fpos = fpos + 1.0
                        end
                        if tb and not pb then
                            fneg = fneg + 1.0
                        end
                        if u32(out[pp * NOUT + u32(1)]) == pt.crop[pp] then
                            cok = cok + 1.0
                        end
                        ctot = ctot + 1.0
                        pp = pp + u32(1)
                    end
                    mut f = u32(0)
                    while f < pt.nfp do
                        if pt.fpok[f] == u32(1) then
                            mut sw = 0.0
                            mut pm = array[f64](4)
                            mut wv = array[f64](16)
                            pp = u32(0)
                            while pp < D.NPIX do
                                if pt.fp[pp] == f then
                                    sw = sw + f64(ws[pp])
                                    mut j = u32(0)
                                    while j < u32(4) do
                                        pm[j] = pm[j] + f64(ws[pp]) * f64(out[pp * NOUT + u32(3) + j * u32(6)])
                                        j = j + u32(1)
                                    end
                                end
                                pp = pp + u32(1)
                            end
                            if sw > 0.0 then
                                qf = quad_patch(ls, df, phi, pt.fp, f, ws)
                                mut j = u32(0)
                                while j < u32(4) do
                                    pr = pm[j] / sw
                                    tv = f64(pt.soil[f * D.NSOIL + j * u32(6)])
                                    sse[j] = sse[j] + (pr - tv) * (pr - tv)
                                    sst1[j] = sst1[j] + tv
                                    sst2[j] = sst2[j] + tv * tv
                                    cnt[j] = cnt[j] + 1.0
                                    sig = sqrt(f64(s2[j * u32(6)]) * (1.0 + qf)) * f64(ysd[u32(1) + j * u32(6)])
                                    if abs(pr - tv) <= 1.96 * sig then
                                        cover[j] = cover[j] + 1.0
                                    end
                                    j = j + u32(1)
                                end
                            end
                        end
                        f = f + u32(1)
                    end
                else
                    ox = u32((px0[k] - xmin) / 10.0)
                    oy = u32((ymax - py0[k]) / 10.0)
                    mut pp = u32(0)
                    while pp < D.NPIX do
                        i10 = oy + pp / D.N
                        j10 = ox + pp % D.N
                        ro = s * D.NBAND * D.NPIX
                        b4 = slot_refl[ro + u32(2) * D.NPIX + pp]
                        b3 = slot_refl[ro + D.NPIX + pp]
                        b2 = slot_refl[ro + pp]
                        mut vals = array[f32](NCH)
                        vals[0] = b4
                        vals[1] = b3
                        vals[2] = b2
                        vals[3] = xb[s * D.NBASE * D.NPIX + u32(10) * D.NPIX + pp]
                        vals[4] = xb[s * D.NBASE * D.NPIX + u32(11) * D.NPIX + pp]
                        ri = pp / D.N
                        rj = pp % D.N
                        edge = ri < u32(2) or rj < u32(2) or ri + u32(2) >= D.N or rj + u32(2) >= D.N
                        vals[5] = out[pp * NOUT]
                        if edge then
                            vals[5] = f32(0.0)
                        end
                        vals[6] = out[pp * NOUT + u32(1)]
                        vals[7] = f32(md.wrb[u32(out[pp * NOUT + u32(2)])])
                        mut t = u32(0)
                        while t < u32(28) do
                            vals[u32(8) + t] = out[pp * NOUT + u32(3) + t]
                            t = t + u32(1)
                        end
                        t = u32(0)
                        while t < u32(4) do
                            vals[u32(36) + t] = xb[s * D.NBASE * D.NPIX + (u32(15) + t) * D.NPIX + pp]
                            t = t + u32(1)
                        end
                        vals[40] = f32(texture(vals[20], vals[26]))
                        vals[41] = sph
                        vals[42] = smo
                        vals[43] = f32(1.0)
                        ci = i10 / SC
                        cj = j10 / SC
                        if ci < chh and cj < cw then
                            cat = (i10 % SC == u32(2)) and (j10 % SC == u32(2))
                            t = u32(0)
                            while t < NCH do
                                if t == u32(6) or t == u32(7) or t == u32(40) then
                                    if cat then
                                        cv[(ci * cw + cj) * NCH + t] = vals[t]
                                    end
                                else
                                    cv[(ci * cw + cj) * NCH + t] = cv[(ci * cw + cj) * NCH + t] + vals[t] / f32(SC * SC)
                                end
                                t = t + u32(1)
                            end
                            cv[(ci * cw + cj) * NCH + u32(43)] = f32(1.0)
                        end
                        dxp = px0[k] + f64(pp % D.N) * 10.0 - wx0
                        dyp = wy0 - (py0[k] - f64(pp / D.N) * 10.0)
                        if dxp >= 0.0 and dyp >= 0.0 and dxp < f64(WIN) * 10.0 and dyp < f64(WIN) * 10.0 then
                            di = u32(dyp / 10.0)
                            dj = u32(dxp / 10.0)
                            t = u32(0)
                            while t < NCH do
                                dv[(di * WIN + dj) * NCH + t] = vals[t]
                                t = t + u32(1)
                            end
                        end
                        pp = pp + u32(1)
                    end
                end
                done = done + u32(1)
                s = s + u32(1)
            end
            filled = u32(0)
        end
        if pi % u32(1000) == u32(0) then
            mut o = array[u8](0)
            TX.putstr(o, bytes("predict: patch "))
            TX.putint(o, u64(pi))
            TX.putstr(o, bytes(" / "))
            TX.putint(o, u64(npt))
            TX.putstr(o, bytes(", "))
            TX.putfix(o, clock() - t0, u32(0))
            TX.putstr(o, bytes(" s\n"))
            TR.say(o)
        end
        pi = pi + u32(1)
    end
    if mode == u32(1) then
        mut r = array[u8](0)
        TX.putstr(r, bytes("HELD-OUT EVALUATION (eval patches, one clear date each)\n"))
        prec = tp / max(tp + fpos, 1.0)
        rec = tp / max(tp + fneg, 1.0)
        TX.putstr(r, bytes("  field boundary: precision "))
        TX.putfix(r, prec, u32(3))
        TX.putstr(r, bytes(", recall "))
        TX.putfix(r, rec, u32(3))
        TX.putstr(r, bytes(", F1 "))
        TX.putfix(r, 2.0 * prec * rec / max(prec + rec, 1e-9), u32(3))
        mut bestf = 0.0
        mut bestt = u32(0)
        mut th = u32(0)
        while th < u32(20) do
            pr2 = tps[th] / max(tps[th] + fps[th], 1.0)
            rc2 = tps[th] / max(tps[th] + fns[th], 1.0)
            f12 = 2.0 * pr2 * rc2 / max(pr2 + rc2, 1e-9)
            if f12 > bestf then
                bestf = f12
                bestt = th
            end
            th = th + u32(1)
        end
        TX.putstr(r, bytes(" (threshold 0.5)\n  field boundary at the best held-out threshold "))
        TX.putfix(r, f64(bestt + u32(1)) * 0.025, u32(3))
        TX.putstr(r, bytes(": precision "))
        TX.putfix(r, tps[bestt] / max(tps[bestt] + fps[bestt], 1.0), u32(3))
        TX.putstr(r, bytes(", recall "))
        TX.putfix(r, tps[bestt] / max(tps[bestt] + fns[bestt], 1.0), u32(3))
        TX.putstr(r, bytes(", F1 "))
        TX.putfix(r, bestf, u32(3))
        mut tf = array[u8](0)
        TX.putfix(tf, f64(bestt + u32(1)) * 0.025, u32(3))
        wt = writefile("out/boundary_threshold.txt", tf)
        TX.putstr(r, bytes("\n  crop type pixel accuracy: "))
        TX.putfix(r, cok / max(ctot, 1.0), u32(3))
        TX.putstr(r, bytes("\n  soil 0-5cm at 250 m footprints (R2, share of truths inside the 95% interval):\n"))
        mut j = u32(0)
        while j < u32(4) do
            mu = sst1[j] / max(cnt[j], 1.0)
            sst = sst2[j] - cnt[j] * mu * mu
            TX.putstr(r, bytes("    "))
            TR.target_name(r, u32(1) + j * u32(6))
            TX.putstr(r, bytes(": R2 "))
            TX.putfix(r, 1.0 - sse[j] / max(sst, 1e-12), u32(3))
            TX.putstr(r, bytes(", 95% coverage "))
            TX.putfix(r, cover[j] / max(cnt[j], 1.0), u32(3))
            TX.putstr(r, bytes(", footprints "))
            TX.putint(r, u64(cnt[j]))
            TX.putch(r, u32(10))
            j = j + u32(1)
        end
        TR.say(r)
        return writefile("out/eval_report.txt", r)
    end
    dir = bytes("out/maps/")
    bth = read_threshold()
    mut n = u32(0)
    n = n + render_rgb(cv, cw, chh, u32(0), bth, dir, bytes("region_rgb"))
    n = n + render_rgb(cv, cw, chh, u32(1), bth, dir, bytes("region_boundaries"))
    n = n + render_rgb(cv, cw, chh, u32(2), bth, dir, bytes("region_unmixing"))
    n = n + render(cv, cw, chh, u32(3), u32(2), f32(-0.1), f32(0.9), dir, bytes("region_ndvi"))
    n = n + render(cv, cw, chh, u32(4), u32(1), f32(-0.3), f32(0.5), dir, bytes("region_ndmi"))
    n = n + render(cv, cw, chh, u32(6), u32(10), f32(0.0), f32(1.0), dir, bytes("region_crop"))
    n = n + render(cv, cw, chh, u32(7), u32(12), f32(0.0), f32(1.0), dir, bytes("region_wrb"))
    n = n + render(cv, cw, chh, u32(40), u32(13), f32(0.0), f32(1.0), dir, bytes("region_texture"))
    n = n + render(cv, cw, chh, u32(8), u32(1), f32(5.0), f32(7.5), dir, bytes("region_ph_0-5cm"))
    n = n + render(cv, cw, chh, u32(13), u32(1), f32(5.0), f32(7.5), dir, bytes("region_ph_100-200cm"))
    n = n + render(cv, cw, chh, u32(14), u32(0), f32(5.0), f32(60.0), dir, bytes("region_soc_0-5cm"))
    n = n + render(cv, cw, chh, u32(20), u32(0), f32(5.0), f32(40.0), dir, bytes("region_clay_0-5cm"))
    n = n + render(cv, cw, chh, u32(26), u32(0), f32(10.0), f32(60.0), dir, bytes("region_sand_0-5cm"))
    n = n + render(cv, cw, chh, u32(32), u32(3), f32(5.0), f32(28.0), dir, bytes("region_temperature"))
    n = n + render(cv, cw, chh, u32(33), u32(4), f32(40.0), f32(100.0), dir, bytes("region_humidity"))
    n = n + render(cv, cw, chh, u32(34), u32(4), f32(0.1), f32(0.5), dir, bytes("region_soil_moisture"))
    n = n + render(cv, cw, chh, u32(35), u32(1), f32(-80.0), f32(80.0), dir, bytes("region_water_balance"))
    n = n + render(cv, cw, chh, u32(41), u32(3), f32(0.0), f32(1.0), dir, bytes("region_uncertainty_ph"))
    n = n + export(cv, cw, chh, u32(8), u32(24), xmin, ymax, 40.0, D.ZONE + u32(32600), dir, bytes("region_soil_40m"))
    n = n + export(cv, cw, chh, u32(32), u32(4), xmin, ymax, 40.0, D.ZONE + u32(32600), dir, bytes("region_weather_40m"))
    n = n + export(cv, cw, chh, u32(3), u32(5), xmin, ymax, 40.0, D.ZONE + u32(32600), dir, bytes("region_surface_40m"))
    zones(dv, WIN, WIN, u32(3), u32(41), bth, u32(1))
    n = n + render_zones(dv, WIN, WIN, u32(41), dir, bytes("detail_zones_ndvi"))
    zones(dv, WIN, WIN, u32(14), u32(42), bth, u32(1))
    n = n + render_zones(dv, WIN, WIN, u32(42), dir, bytes("detail_zones_soc"))
    n = n + render_rgb(dv, WIN, WIN, u32(0), bth, dir, bytes("detail_rgb"))
    n = n + render_rgb(dv, WIN, WIN, u32(1), bth, dir, bytes("detail_boundaries"))
    n = n + render_rgb(dv, WIN, WIN, u32(2), bth, dir, bytes("detail_unmixing"))
    n = n + render(dv, WIN, WIN, u32(3), u32(2), f32(-0.1), f32(0.9), dir, bytes("detail_ndvi"))
    n = n + render(dv, WIN, WIN, u32(6), u32(10), f32(0.0), f32(1.0), dir, bytes("detail_crop"))
    n = n + render(dv, WIN, WIN, u32(8), u32(1), f32(5.0), f32(7.5), dir, bytes("detail_ph_0-5cm"))
    n = n + render(dv, WIN, WIN, u32(14), u32(0), f32(5.0), f32(60.0), dir, bytes("detail_soc_0-5cm"))
    n = n + render(dv, WIN, WIN, u32(34), u32(4), f32(0.1), f32(0.5), dir, bytes("detail_soil_moisture"))
    n = n + render(dv, WIN, WIN, u32(35), u32(1), f32(-80.0), f32(80.0), dir, bytes("detail_water_balance"))
    n = n + export(dv, WIN, WIN, u32(8), u32(24), wx0, wy0, 10.0, D.ZONE + u32(32600), dir, bytes("detail_soil_10m"))
    n = n + export(dv, WIN, WIN, u32(32), u32(4), wx0, wy0, 10.0, D.ZONE + u32(32600), dir, bytes("detail_weather_10m"))
    n = n + export(dv, WIN, WIN, u32(3), u32(5), wx0, wy0, 10.0, D.ZONE + u32(32600), dir, bytes("detail_surface_10m"))
    n = n + export_raw(dv, WIN, WIN, u32(8), u32(24), wx0, wy0, 10.0, D.ZONE + u32(32600), dir, bytes("detail_soil_10m"), soil_names())
    n = n + export_raw(dv, WIN, WIN, u32(32), u32(4), wx0, wy0, 10.0, D.ZONE + u32(32600), dir, bytes("detail_weather_10m"), weather_names())
    n = n + export_raw(dv, WIN, WIN, u32(3), u32(5), wx0, wy0, 10.0, D.ZONE + u32(32600), dir, bytes("detail_surface_10m"), surface_names())
    TR.sayf(bytes("bytes written: "), f64(n), u32(0))
    TR.sayf(bytes("seconds: "), clock() - t0, u32(1))
    return done
end

pub fn export_raw(cv: f32[], w: u32, h: u32, c0: u32, nb: u32, x0: f64, y0: f64, px: f64, epsg: u32, dir: u8[], name: u8[], names: u8[]) -> u32
    mut a = array[u8](w * h * nb * u32(4))
    mut q = u32(0)
    while q < w * h do
        mut b = u32(0)
        while b < nb do
            mut v = cv[q * NCH + c0 + b]
            if cv[q * NCH + u32(43)] < f32(0.5) then
                v = f32(-9999.0)
            end
            BY.putu32le(a, (q * nb + b) * u32(4), tobits(v))
            b = b + u32(1)
        end
        q = q + u32(1)
    end
    n1 = writefile(name_path(dir, name, bytes(".f32")), a)
    zone = epsg % u32(100)
    tl = U.to_latlon(x0, y0, zone, epsg > u32(32700))
    br = U.to_latlon(x0 + f64(w) * px, y0 - f64(h) * px, zone, epsg > u32(32700))
    mut j = array[u8](0)
    TX.putstr(j, bytes("{\"width\": "))
    TX.putint(j, u64(w))
    TX.putstr(j, bytes(", \"height\": "))
    TX.putint(j, u64(h))
    TX.putstr(j, bytes(", \"bands\": "))
    TX.putint(j, u64(nb))
    TX.putstr(j, bytes(", \"band_names\": [\""))
    for c in names do
        if c == u8(44) then
            TX.putstr(j, bytes("\", \""))
        else
            push(j, c)
        end
    end
    TX.putstr(j, bytes("\"], \"dtype\": \"float32 little-endian\", \"layout\": \"row-major from the top-left, bands interleaved per pixel\", \"nodata\": -9999, \"crs\": \"EPSG:"))
    TX.putint(j, u64(epsg))
    TX.putstr(j, bytes("\", \"origin_x\": "))
    TX.putfix(j, x0, u32(2))
    TX.putstr(j, bytes(", \"origin_y\": "))
    TX.putfix(j, y0, u32(2))
    TX.putstr(j, bytes(", \"pixel_size_m\": "))
    TX.putfix(j, px, u32(2))
    TX.putstr(j, bytes(", \"top_left_lat\": "))
    TX.putfix(j, tl.0, u32(6))
    TX.putstr(j, bytes(", \"top_left_lon\": "))
    TX.putfix(j, tl.1, u32(6))
    TX.putstr(j, bytes(", \"bottom_right_lat\": "))
    TX.putfix(j, br.0, u32(6))
    TX.putstr(j, bytes(", \"bottom_right_lon\": "))
    TX.putfix(j, br.1, u32(6))
    TX.putstr(j, bytes("}\n"))
    return n1 + writefile(name_path(dir, name, bytes(".json")), j)
end

pub fn soil_names() -> u8[]
    return bytes("ph_0-5cm,ph_5-15cm,ph_15-30cm,ph_30-60cm,ph_60-100cm,ph_100-200cm,soc_gkg_0-5cm,soc_gkg_5-15cm,soc_gkg_15-30cm,soc_gkg_30-60cm,soc_gkg_60-100cm,soc_gkg_100-200cm,clay_pct_0-5cm,clay_pct_5-15cm,clay_pct_15-30cm,clay_pct_30-60cm,clay_pct_60-100cm,clay_pct_100-200cm,sand_pct_0-5cm,sand_pct_5-15cm,sand_pct_15-30cm,sand_pct_30-60cm,sand_pct_60-100cm,sand_pct_100-200cm")
end

pub fn weather_names() -> u8[]
    return bytes("temperature_c,humidity_pct,soil_moisture_m3m3,water_balance_30d_mm")
end

pub fn surface_names() -> u8[]
    return bytes("ndvi,ndmi,boundary_score,crop_class,wrb_code")
end

pub fn read_threshold() -> f32
    d = readfile("out/boundary_threshold.txt")
    mut o = array[u64](1)
    if len(d) > u32(0) then
        if SD.parse_f64(d, u32(0), len(d), o) == u32(1) then
            return f32(frombits(o[0]))
        end
    end
    return f32(0.3)
end


pub fn conv2_params(seed: u64) -> f32[]
    n1 = NF2 * NMAP * u32(9)
    n2 = NF2 * NF2 * u32(9)
    mut p = array[f32](n1 + NF2 + n2 + NF2)
    st = RNG.stream(seed)
    mut q = u32(0)
    while q < n1 do
        p[q] = RNG.normal(st, q) * sqrt(f32(2.0) / f32(NMAP * u32(9)))
        q = q + u32(1)
    end
    q = u32(0)
    while q < NF2 do
        p[n1 + q] = RNG.normal(st, n1 + q) * f32(0.1)
        q = q + u32(1)
    end
    q = u32(0)
    while q < n2 do
        p[n1 + NF2 + q] = RNG.normal(st, n1 + NF2 + q) * sqrt(f32(2.0) / f32(NF2 * u32(9)))
        q = q + u32(1)
    end
    q = u32(0)
    while q < NF2 do
        p[n1 + NF2 + n2 + q] = RNG.normal(st, n1 + n2 + NF2 + q) * f32(0.1)
        q = q + u32(1)
    end
    return p
end

pub fn conv2(maps: f32[], p2: f32[], g1: f32[], g2: f32[], nb: u32)
    n1 = NF2 * NMAP * u32(9)
    n2 = NF2 * NF2 * u32(9)
    NT.conv_fwd(maps, p2, g1, nb, NMAP, NF2, D.N, u32(3), u32(2), u32(0), n1, u32(1))
    NT.conv_fwd(g1, p2, g2, nb, NF2, NF2, D.N, u32(3), u32(4), n1 + NF2, n1 + NF2 + n2, u32(1))
end

pub fn maps_from_out(out: f32[], ymu: f32[], ysd: f32[], maps: f32[], s: u32)
    np = D.NPIX
    mut p = u32(0)
    while p < np do
        o = (s * NMAP) * np + p
        maps[o] = out[p * NOUT]
        maps[o + np] = (out[p * NOUT + u32(3)] - ymu[1]) / ysd[1]
        maps[o + u32(2) * np] = (out[p * NOUT + u32(9)] - ymu[7]) / ysd[7]
        maps[o + u32(3) * np] = (out[p * NOUT + u32(15)] - ymu[13]) / ysd[13]
        maps[o + u32(4) * np] = (out[p * NOUT + u32(21)] - ymu[19]) / ysd[19]
        mut k = u32(0)
        while k < u32(4) do
            maps[o + (u32(5) + k) * np] = (out[p * NOUT + u32(27) + k] - ymu[u32(25) + k]) / ysd[u32(25) + k]
            k = k + u32(1)
        end
        p = p + u32(1)
    end
end

pub fn build_psi(phib: f32[], maps: f32[], g1: f32[], g2: f32[], s: u32, df: u32, psi: f32[])
    np = D.NPIX
    mut c = u32(0)
    while c < df do
        mut p = u32(0)
        while p < np do
            psi[c * np + p] = phib[(s * df + c) * np + p]
            p = p + u32(1)
        end
        c = c + u32(1)
    end
    mut k = u32(0)
    while k < NMAP do
        mut m = f32(0.0)
        mut p = u32(0)
        while p < np do
            v = maps[(s * NMAP + k) * np + p]
            psi[(df + k) * np + p] = v
            m = m + v
            p = p + u32(1)
        end
        m = m / f32(np)
        p = u32(0)
        while p < np do
            psi[(df + NMAP + NF2 * u32(2) + k) * np + p] = m
            p = p + u32(1)
        end
        k = k + u32(1)
    end
    k = u32(0)
    while k < NF2 do
        mut p = u32(0)
        while p < np do
            psi[(df + NMAP + k) * np + p] = g1[(s * NF2 + k) * np + p]
            psi[(df + NMAP + NF2 + k) * np + p] = g2[(s * NF2 + k) * np + p]
            p = p + u32(1)
        end
        k = k + u32(1)
    end
end

pub fn infer_batch(xb: f32[], f1: f32[], f2: f32[], f3: f32[], f4: f32[], gmb: f32[], filled: u32,
                   laws: u32[], coefs: f64[], bp: f32[], bs: f32[], bw: f32[], df: u32, nw: u32, ymu: f32[], ysd: f32[],
                   s2on: u32, p2: f32[], b2p: f32[], b2s: f32[], b2w: f32[], df2: u32,
                   phib: f32[], outb: f32[], maps: f32[], g1: f32[], g2: f32[], gm: f32[], phi: f32[], out: f32[], psi: f32[])
    np = D.NPIX
    mut s = u32(0)
    while s < filled do
        mut q = u32(0)
        while q < np * M.NG do
            gm[q] = gmb[s * np * M.NG + q]
            q = q + u32(1)
        end
        TR.build_phi(xb, f1, f2, f3, f4, s, gm, laws, coefs, phi)
        heads(phi, bp, bs, bw, df, nw, ymu, ysd, out)
        q = u32(0)
        while q < df * np do
            phib[s * df * np + q] = phi[q]
            q = q + u32(1)
        end
        q = u32(0)
        while q < np * NOUT do
            outb[s * np * NOUT + q] = out[q]
            q = q + u32(1)
        end
        if s2on >= u32(1) then
            maps_from_out(out, ymu, ysd, maps, s)
        end
        s = s + u32(1)
    end
    if s2on >= u32(1) then
        conv2(maps, p2, g1, g2, filled)
    end
    if s2on == u32(1) then
        s = u32(0)
        while s < filled do
            build_psi(phib, maps, g1, g2, s, df, psi)
            heads(psi, b2p, b2s, b2w, df2, nw, ymu, ysd, out)
            mut q = u32(0)
            while q < np * NOUT do
                outb[s * np * NOUT + q] = out[q]
                q = q + u32(1)
            end
            s = s + u32(1)
        end
    end
end

