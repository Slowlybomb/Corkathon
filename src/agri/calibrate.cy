mut D = require("data.cy")
mut M = require("model.cy")
mut TR = require("train.cy")
mut PR = require("predict.cy")
mut TF = require("../../lib/geo/tiff.cy")
mut U = require("../../lib/geo/utm.cy")
mut TX = require("../../lib/io/text.cy")
mut BY = require("../../lib/io/bytes.cy")

fn band(dir: u8[], name: u8[], e0: f64, n0: f64, npx: u32, res: f64) -> TF.Tiff
    mut p = array[u8](0)
    D.cat(p, dir)
    D.cat(p, name)
    D.cat(p, bytes(".tif"))
    d = readfile(p)
    g = TF.decode_window(d, u32(0), u32(0), u32(1), u32(1))
    return TF.decode_window(d, u32((e0 - g.x0) / res), u32((g.y0 - n0) / res), npx, npx)
end

pub fn main(e0m: u32, n0m: u32, npatch: u32) -> u32
    t0 = clock()
    dir = bytes("data/cork/s2/S2A_29UNT_20230530_0_L2A/")
    zone = u32(29)
    dd = D.doy(u32(20230530))
    e0 = f64(e0m)
    n0 = f64(n0m)
    npx = npatch * D.N
    h20 = npx / u32(2)
    mut b10 = array[f32](u32(4) * npx * npx)
    mut b20 = array[f32](u32(7) * h20 * h20)
    mut bi = u32(0)
    while bi < u32(11) do
        mut nm = bytes("B02")
        if bi == u32(1) then
            nm = bytes("B03")
        end
        if bi == u32(2) then
            nm = bytes("B04")
        end
        if bi == u32(3) then
            nm = bytes("B08")
        end
        if bi == u32(4) then
            nm = bytes("B05")
        end
        if bi == u32(5) then
            nm = bytes("B06")
        end
        if bi == u32(6) then
            nm = bytes("B07")
        end
        if bi == u32(7) then
            nm = bytes("B8A")
        end
        if bi == u32(8) then
            nm = bytes("B11")
        end
        if bi == u32(9) then
            nm = bytes("B12")
        end
        if bi == u32(10) then
            nm = bytes("SCL")
        end
        if bi < u32(4) then
            t = band(dir, nm, e0, n0, npx, 10.0)
            mut q = u32(0)
            while q < npx * npx do
                b10[bi * npx * npx + q] = t.px[q]
                q = q + u32(1)
            end
        else
            t = band(dir, nm, e0, n0, h20, 20.0)
            mut q = u32(0)
            while q < h20 * h20 do
                b20[(bi - u32(4)) * h20 * h20 + q] = t.px[q]
                q = q + u32(1)
            end
        end
        bi = bi + u32(1)
    end
    TR.sayf(bytes("calibration area bands read, seconds: "), clock() - t0, u32(1))
    md = PR.load_model(bytes("out/model.bin"))
    df = md.df
    nw = md.nw
    msoil = D.NSOIL + nw
    mut pq = array[f32](44)
    D.unmix_prep(md.em, pq)
    mut p = md.p
    mut norm = md.norm
    mut laws = md.laws
    mut coefs = md.coefs
    mut bs = md.bs
    mut ymu = md.ymu
    mut ysd = md.ysd
    soil = D.load_soil(bytes("data/corkcal/soil/"))
    m = D.NSOIL
    d2 = df * df
    mut g = array[f64](d2)
    mut ge = array[f64](d2)
    mut xy = array[f64](df * m)
    mut xye = array[f64](df * m)
    mut yy = array[f64](m)
    mut yye = array[f64](m)
    np = D.NPIX
    mut refl = array[f32](D.NBAND * np)
    mut x = array[f32](D.NBASE * np)
    mut gm = array[f32](np * M.NG)
    mut xb = array[f32](TR.NB * D.NBASE * np)
    act = TR.NB * M.NFEAT * np
    mut f1 = array[f32](act)
    mut f2 = array[f32](act)
    mut f3 = array[f32](act)
    mut f4 = array[f32](act)
    mut gmb = array[f32](TR.NB * np * M.NG)
    mut phi = array[f32](df * np)
    mut slot = array[u32](TR.NB)
    mut okb = array[u32](TR.NB * np)
    mut ws = array[f32](np)
    mut fpl = array[u32](np)
    mut cells = array[u32](D.MAXFP)
    mut facc = array[f32](D.MAXFP * df)
    mut fws = array[f32](D.MAXFP)
    mut row = array[f32](df)
    mut ty = array[f32](m)
    mut one = array[f32](1)
    one[0] = f32(1.0)
    mut ntr = u32(0)
    mut nte = u32(0)
    mut filled = u32(0)
    nt = npatch * npatch
    mut k = u32(0)
    while k <= nt do
        mut flush = k == nt
        if k < nt then
            pi = k / npatch
            pj = k % npatch
            mut pp = u32(0)
            mut good = u32(0)
            while pp < np do
                y10 = pi * D.N + pp / D.N
                x10 = pj * D.N + pp % D.N
                q10 = y10 * npx + x10
                q20 = (y10 / u32(2)) * h20 + x10 / u32(2)
                mut b = u32(0)
                while b < u32(4) do
                    refl[b * np + pp] = b10[b * npx * npx + q10] / f32(10000.0)
                    b = b + u32(1)
                end
                b = u32(0)
                while b < u32(6) do
                    refl[(u32(4) + b) * np + pp] = b20[b * h20 * h20 + q20] / f32(10000.0)
                    b = b + u32(1)
                end
                sc = u32(b20[u32(6) * h20 * h20 + q20])
                ok = sc == u32(4) or sc == u32(5)
                okb[filled * np + pp] = u32(ok)
                good = good + u32(ok)
                pp = pp + u32(1)
            end
            if good * u32(2) > np then
                D.base_channels(refl, u32(0), dd, norm, pq, xb, filled * D.NBASE * np)
                mut q = u32(0)
                while q < D.NBASE * np do
                    x[q] = xb[filled * D.NBASE * np + q]
                    q = q + u32(1)
                end
                M.grammar(x, u32(0), gm)
                q = u32(0)
                while q < np * M.NG do
                    gmb[filled * np * M.NG + q] = gm[q]
                    q = q + u32(1)
                end
                slot[filled] = k
                filled = filled + u32(1)
                if filled == TR.NB then
                    flush = true
                end
            end
        end
        if flush and filled > u32(0) then
            TR.conv_bank(xb, p, f1, f2, f3, f4, filled)
            mut s = u32(0)
            while s < filled do
                kk = slot[s]
                pi = kk / npatch
                pj = kk % npatch
                held = ((pi / u32(8)) + (pj / u32(8))) % u32(2) == u32(1)
                mut q = u32(0)
                while q < np * M.NG do
                    gm[q] = gmb[s * np * M.NG + q]
                    q = q + u32(1)
                end
                TR.build_phi(xb, f1, f2, f3, f4, s, gm, laws, coefs, phi)
                pe = e0 + f64(pj * D.N) * 10.0
                pn = n0 - f64(pi * D.N) * 10.0
                side = f64(D.N) * 10.0
                c00 = U.to_latlon(pe, pn, zone, false)
                c01 = U.to_latlon(pe + side, pn, zone, false)
                c10 = U.to_latlon(pe, pn - side, zone, false)
                c11 = U.to_latlon(pe + side, pn - side, zone, false)
                mut nfp = u32(0)
                mut pp = u32(0)
                while pp < np do
                    u = (f64(pp % D.N) + 0.5) / f64(D.N)
                    v = (f64(pp / D.N) + 0.5) / f64(D.N)
                    la = (c00.0 * (1.0 - u) + c01.0 * u) * (1.0 - v) + (c10.0 * (1.0 - u) + c11.0 * u) * v
                    lo = (c00.1 * (1.0 - u) + c01.1 * u) * (1.0 - v) + (c10.1 * (1.0 - u) + c11.1 * u) * v
                    fx = (lo - soil.x0[0]) / soil.dx[0]
                    fy = (soil.y0[0] - la) / soil.dy[0]
                    mut f = D.NOFP
                    if okb[s * np + pp] == u32(1) and fx >= 0.0 and fy >= 0.0 and fx < f64(soil.w[0]) and fy < f64(soil.h[0]) then
                        cell = u32(fy) * soil.w[0] + u32(fx)
                        mut c = u32(0)
                        while c < nfp and f == D.NOFP do
                            if cells[c] == cell then
                                f = c
                            end
                            c = c + u32(1)
                        end
                        if f == D.NOFP and nfp < D.MAXFP then
                            cells[nfp] = cell
                            f = nfp
                            nfp = nfp + u32(1)
                        end
                    end
                    fpl[pp] = f
                    ws[pp] = phi[u32(16) * np + pp] + f32(0.05)
                    pp = pp + u32(1)
                end
                TR.fp_means(phi, df, ws, fpl, nfp, facc, fws)
                mut f = u32(0)
                while f < nfp do
                    rr = cells[f] / soil.w[0]
                    cc = cells[f] % soil.w[0]
                    la = soil.y0[0] - (f64(rr) + 0.5) * soil.dy[0]
                    lo = soil.x0[0] + (f64(cc) + 0.5) * soil.dx[0]
                    mut valid = fws[f] > f32(5.0)
                    mut t = u32(0)
                    while t < m do
                        raw = D.soil_at(soil, t, la, lo)
                        if raw <= f32(0.0) then
                            valid = false
                        end
                        ty[t] = (raw / f32(10.0) - ymu[u32(1) + t]) / ysd[u32(1) + t]
                        t = t + u32(1)
                    end
                    if valid then
                        mut c = u32(0)
                        while c < df do
                            row[c] = facc[f * df + c]
                            c = c + u32(1)
                        end
                        if held then
                            M.gram_add(ge, row, u32(1), df, one)
                            M.rhs_add(xye, yye, row, ty, u32(1), df, m, one)
                            nte = nte + u32(1)
                        else
                            M.gram_add(g, row, u32(1), df, one)
                            M.rhs_add(xy, yy, row, ty, u32(1), df, m, one)
                            ntr = ntr + u32(1)
                        end
                    end
                    f = f + u32(1)
                end
                s = s + u32(1)
            end
            filled = u32(0)
        end
        k = k + u32(1)
    end
    M.symmetrize(g, df)
    M.symmetrize(ge, df)
    mut off = array[f64](df * m)
    mut a = u32(0)
    while a < df do
        mut t = u32(0)
        while t < m do
            off[a * m + t] = f64(bs[a * msoil + t])
            t = t + u32(1)
        end
        a = a + u32(1)
    end
    mut beta = array[f64](df * m)
    mut lk = array[u32](m)
    mut sse = array[f64](m)
    mut cert = array[f64](m)
    w = M.solve_offset(g, xy, yy, ge, xye, yye, df, m, off, beta, lk, sse, cert)
    mut r = array[u8](0)
    TX.putstr(r, bytes("IRISH RECALIBRATION of the soil heads (closed form, stacked on the Bavarian model)"))
    TX.putch(r, u32(10))
    TX.putstr(r, bytes("  footprints: train "))
    TX.putint(r, u64(ntr))
    TX.putstr(r, bytes(", held-out (checkerboard of 3.84 km blocks) "))
    TX.putint(r, u64(nte))
    TX.putstr(r, bytes(", worst certificate "))
    TX.putsci(r, w, u32(2))
    TX.putch(r, u32(10))
    mut t = u32(0)
    while t < m do
        sst = yye[t] - xye[t] * xye[t] / max(ge[0], 1.0)
        s0 = M.heldout_sse(off, m, t, ge, xye, yye, df)
        TX.putstr(r, bytes("    "))
        TR.target_name(r, t + u32(1))
        TX.putstr(r, bytes(": Bavarian heads R2 "))
        TX.putfix(r, 1.0 - s0 / max(sst, 1e-12), u32(3))
        TX.putstr(r, bytes(" -> recalibrated R2 "))
        TX.putfix(r, 1.0 - sse[t] / max(sst, 1e-12), u32(3))
        TX.putch(r, u32(10))
        t = t + u32(1)
    end
    TR.say(r)
    mut outb = array[u8](0)
    a = u32(0)
    while a < df * m do
        mut v = array[u8](4)
        BY.putu32le(v, u32(0), tobits(f32(beta[a])))
        for c in v do
            push(outb, c)
        end
        a = a + u32(1)
    end
    wb = writefile("out/cork_soil_heads.bin", outb)
    wr = writefile("out/cork/recalibration.txt", r)
    TR.sayf(bytes("seconds: "), clock() - t0, u32(1))
    return ntr
end
