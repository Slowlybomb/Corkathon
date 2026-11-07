mut D = require("data.cy")
mut M = require("model.cy")
mut FA = require("fast.cy")
mut U = require("../../lib/geo/utm.cy")
mut BY = require("../../lib/io/bytes.cy")

pub NO = u32(31)
NLAW = u32(29)
NPIXT = u32(19)

fn axpy(y: f32[], yo: u32, x: f32[], xo: u32, w: f32, m: u32)
    mut j = u32(0)
    while j < m do
        y[yo + j] = y[yo + j] + w * x[xo + j]
        j = j + u32(1)
    end
end

fn conv_cpu(x: f32[], p: f32[], y: f32[], ci: u32, co: u32, n: u32, dil: u32, wo: u32, bo: u32, relu: u32)
    nn = n * n
    ni = i32(n)
    d = i32(dil)
    mut o = u32(0)
    while o < co do
        yb = o * nn
        bias = p[bo + o]
        mut q = u32(0)
        while q < nn do
            y[yb + q] = bias
            q = q + u32(1)
        end
        mut c = u32(0)
        while c < ci do
            xb = i32(c * nn)
            mut t = u32(0)
            while t < u32(9) do
                dy = i32(t / u32(3)) * d - d
                dx = i32(t % u32(3)) * d - d
                w = p[wo + (o * ci + c) * u32(9) + t]
                i0 = max(i32(0), i32(0) - dy)
                i1 = min(ni, ni - dy)
                j0 = max(i32(0), i32(0) - dx)
                j1 = min(ni, ni - dx)
                m = u32(j1 - j0)
                mut i = i0
                while i < i1 do
                    axpy(y, yb + u32(i * ni + j0), x, u32(xb + (i + dy) * ni + j0 + dx), w, m)
                    i = i + i32(1)
                end
                t = t + u32(1)
            end
            c = c + u32(1)
        end
        if relu == u32(1) then
            q = u32(0)
            while q < nn do
                y[yb + q] = max(y[yb + q], f32(0.0))
                q = q + u32(1)
            end
        end
        o = o + u32(1)
    end
end

fn heads_cpu(phi: f32[], B: f32[], sc: f32[], Dn: u32, Mo: u32, P: u32)
    mut o = u32(0)
    while o < Mo do
        sb = o * P
        mut q = u32(0)
        while q < P do
            sc[sb + q] = f32(0.0)
            q = q + u32(1)
        end
        mut c = u32(0)
        while c < Dn do
            axpy(sc, sb, phi, c * P, B[c * Mo + o], P)
            c = c + u32(1)
        end
        o = o + u32(1)
    end
end

fn run_chunk_cpu(refl: f32[], S: u32, doy: u32, df: u32, nw: u32, s2on: u32,
                 norm: f32[], pq: f32[], p: f32[], laws: u32[], coefs: f32[], b1: f32[], b2: f32[], p2: f32[], ymu: f32[], ysd: f32[],
                 x: f32[], bx: f32[], cx: f32[], tmp: f32[], f1: f32[], f2: f32[], f3: f32[], f4: f32[], nr: f32[], mag: f32[], mx: f32[],
                 phi: f32[], sc: f32[], out: f32[], maps: f32[], g1: f32[], g2: f32[], mc: f32[], psi: f32[])
    P = S * S
    mo = u32(19) + D.NSOIL + nw + D.NWX
    ang = 2.0 * U.PI * f64(doy) / 365.25
    FA.k_base(refl, x, norm, pq, f32(U.sin64(ang)), f32(U.cos64(ang)), P)
    FA.k_boxh(x, tmp, u32(21), S, u32(3))
    FA.k_boxv(tmp, bx, u32(21), S, u32(3))
    FA.k_boxh(x, tmp, u32(21), S, FA.MARGIN)
    FA.k_boxv(tmp, cx, u32(21), S, FA.MARGIN)
    o1 = M.NFEAT * D.NBASE * u32(9)
    o2 = o1 + M.NFEAT
    o3 = o2 + M.NFEAT * M.NFEAT * u32(9)
    o4 = o3 + M.NFEAT
    o5 = o4 + M.NFEAT * M.NFEAT * u32(9)
    o6 = o5 + M.NFEAT
    o7 = o6 + M.NFEAT * M.NFEAT * u32(9)
    conv_cpu(x, p, f1, D.NBASE, M.NFEAT, S, u32(1), u32(0), o1, u32(1))
    conv_cpu(f1, p, f2, M.NFEAT, M.NFEAT, S, u32(2), o2, o3, u32(1))
    conv_cpu(f2, p, f3, M.NFEAT, M.NFEAT, S, u32(4), o4, o5, u32(1))
    conv_cpu(f3, p, f4, M.NFEAT, M.NFEAT, S, u32(8), o6, o7, u32(1))
    FA.k_neur(x, bx, laws, coefs, nr, P)
    FA.k_fill(phi, P, f32(1.0))
    FA.k_copy(x, phi, P, u32(21) * P)
    FA.k_copy(f1, phi, u32(22) * P, u32(48) * P)
    FA.k_copy(f2, phi, u32(70) * P, u32(48) * P)
    FA.k_copy(f3, phi, u32(118) * P, u32(48) * P)
    FA.k_copy(f4, phi, u32(166) * P, u32(48) * P)
    FA.k_copy(cx, phi, u32(214) * P, u32(21) * P)
    FA.k_copy(nr, phi, u32(235) * P, u32(58) * P)
    if df >= u32(301) then
        FA.k_sobel(x, mag, S)
        FA.k_max3(mag, mx, S)
        FA.k_copy(mag, phi, u32(293) * P, u32(4) * P)
        FA.k_copy(mx, phi, u32(297) * P, u32(4) * P)
    end
    heads_cpu(phi, b1, sc, df, mo, P)
    FA.k_final(sc, out, ymu, ysd, nw, P)
    if s2on == u32(1) then
        FA.k_maps(out, maps, ymu, ysd, P)
        n1 = u32(24) * u32(9) * u32(9)
        n2 = u32(24) * u32(24) * u32(9)
        conv_cpu(maps, p2, g1, u32(9), u32(24), S, u32(2), u32(0), n1, u32(1))
        conv_cpu(g1, p2, g2, u32(24), u32(24), S, u32(4), n1 + u32(24), n1 + u32(24) + n2, u32(1))
        FA.k_boxh(maps, tmp, u32(9), S, FA.MARGIN)
        FA.k_boxv(tmp, mc, u32(9), S, FA.MARGIN)
        FA.k_copy(phi, psi, u32(0), df * P)
        FA.k_copy(maps, psi, df * P, u32(9) * P)
        FA.k_copy(g1, psi, (df + u32(9)) * P, u32(24) * P)
        FA.k_copy(g2, psi, (df + u32(33)) * P, u32(24) * P)
        FA.k_copy(mc, psi, (df + u32(57)) * P, u32(9) * P)
        heads_cpu(psi, b2, sc, df + u32(66), mo, P)
        FA.k_final(sc, out, ymu, ysd, nw, P)
    end
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

pub fn infer(d: u8[], ov: u8[], refl: f32[], S: u32, doy: u32, out: f32[]) -> f64
    mut at = array[u32](1)
    at[0] = u32(8)
    df = BY.u32le(d, at[0])
    nw = BY.u32le(d, at[0] + u32(4))
    np = BY.u32le(d, at[0] + u32(8))
    at[0] = at[0] + u32(12)
    msoil = D.NSOIL + nw
    mut norm = rf(d, at, u32(20))
    em = rd64(d, at, u32(40))
    wrb = ru(d, at, nw)
    mut p = rf(d, at, np)
    mut laws = ru(d, at, NLAW * u32(8))
    mut coefs = rf(d, at, NLAW * u32(8))
    mut ymu = rf(d, at, NLAW)
    mut ysd = rf(d, at, NLAW)
    bp = rf(d, at, df * NPIXT)
    mut bs = rf(d, at, df * msoil)
    bw = rf(d, at, df * D.NWX)
    at[0] = at[0] + (msoil + D.NWX) * u32(4) + u32(8) * df * df
    if at[0] + D.NCROP * u32(4) <= len(d) then
        at[0] = at[0] + D.NCROP * u32(4)
    end
    mut s2on = u32(0)
    mut df2 = u32(0)
    mut p2 = array[f32](1)
    mut b2p = array[f32](1)
    mut b2s = array[f32](1)
    mut b2w = array[f32](1)
    if at[0] + u32(12) <= len(d) then
        s2on = BY.u32le(d, at[0])
        df2 = BY.u32le(d, at[0] + u32(4))
        n2 = BY.u32le(d, at[0] + u32(8))
        at[0] = at[0] + u32(12)
        p2 = rf(d, at, n2)
        b2p = rf(d, at, df2 * NPIXT)
        b2s = rf(d, at, df2 * msoil)
        b2w = rf(d, at, df2 * D.NWX)
    end
    if len(ov) == df * D.NSOIL * u32(4) then
        mut oa = u32(0)
        while oa < df do
            mut ot = u32(0)
            while ot < D.NSOIL do
                bs[oa * msoil + ot] = BY.f32le(ov, (oa * D.NSOIL + ot) * u32(4))
                ot = ot + u32(1)
            end
            oa = oa + u32(1)
        end
        s2on = u32(0)
    end
    mut pq = array[f32](44)
    D.unmix_prep(em, pq)
    P = S * S
    mut b1 = FA.combine(bp, bs, bw, df, nw)
    mut b2 = array[f32](1)
    mut s2n = u32(1)
    if s2on == u32(1) then
        b2 = FA.combine(b2p, b2s, b2w, df2, nw)
        s2n = P
    end
    mut x = array[f32](u32(21) * P)
    mut bx = array[f32](u32(21) * P)
    mut cx = array[f32](u32(21) * P)
    mut tmp = array[f32](u32(21) * P)
    mut f1 = array[f32](u32(48) * P)
    mut f2 = array[f32](u32(48) * P)
    mut f3 = array[f32](u32(48) * P)
    mut f4 = array[f32](u32(48) * P)
    mut nr = array[f32](u32(58) * P)
    mut mag = array[f32](u32(4) * P)
    mut mx = array[f32](u32(4) * P)
    mut phi = array[f32](df * P)
    mo = u32(19) + msoil + D.NWX
    mut sc = array[f32](mo * P)
    mut maps = array[f32](u32(9) * s2n)
    mut g1 = array[f32](u32(24) * s2n)
    mut g2 = array[f32](u32(24) * s2n)
    mut mc = array[f32](u32(9) * s2n)
    mut psi = array[f32]((df + u32(66)) * s2n)
    t0 = clock()
    run_chunk_cpu(refl, S, doy, df, nw, s2on, norm, pq, p, laws, coefs, b1, b2, p2, ymu, ysd,
                  x, bx, cx, tmp, f1, f2, f3, f4, nr, mag, mx, phi, sc, out, maps, g1, g2, mc, psi)
    return clock() - t0
end
