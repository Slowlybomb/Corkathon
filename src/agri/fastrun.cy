mut D = require("data.cy")
mut M = require("model.cy")
mut PR = require("predict.cy")
mut FA = require("fast.cy")
mut EX = require("export.cy")
mut TF = require("../../lib/geo/tiff.cy")
mut TX = require("../../lib/io/text.cy")
mut BY = require("../../lib/io/bytes.cy")

fn say(b: u8[])
    mut o = array[u8](0)
    for c in b do
        push(o, c)
    end
    push(o, u8(10))
    w = writefile("out/fastrun_log.txt", o)
end

fn band(dir: u8[], name: u8[], e0: f64, n0: f64, npx: u32, res: f64) -> TF.Tiff
    mut p = array[u8](0)
    D.cat(p, dir)
    D.cat(p, name)
    D.cat(p, bytes(".tif"))
    d = readfile(p)
    g = TF.decode_window(d, u32(0), u32(0), u32(1), u32(1))
    return TF.decode_window(d, u32((e0 - g.x0) / res), u32((g.y0 - n0) / res), npx, npx)
end

fn put_f32s(path: u8[], a: f32[], n: u32) -> u32
    mut b = array[u8](n * u32(4))
    mut i = u32(0)
    while i < n do
        BY.putu32le(b, i * u32(4), tobits(a[i]))
        i = i + u32(1)
    end
    return writefile(path, b)
end

fn p85(cv: f32[], n: u32) -> f32
    mut hist = array[u32](400)
    mut m = u32(0)
    mut q = u32(0)
    while q < n do
        if cv[q * PR.NCH + u32(43)] > f32(0.5) then
            hb = u32(max(f32(0.0), min(f32(399.0), (cv[q * PR.NCH + u32(5)] + f32(1.0)) * f32(100.0))))
            hist[hb] = hist[hb] + u32(1)
            m = m + u32(1)
        end
        q = q + u32(1)
    end
    target = u32(f32(m) * f32(0.85))
    mut acc = u32(0)
    mut b = u32(0)
    while b < u32(400) and acc < target do
        acc = acc + hist[b]
        b = b + u32(1)
    end
    return f32(b) / f32(100.0) - f32(1.0)
end

pub fn main(e0m: u32, n0m: u32, nchunk: u32, chunk: u32, golden: u32) -> f64
    t0 = clock()
    dir = bytes("data/cork/s2/S2A_29UNT_20230530_0_L2A/")
    mg = FA.MARGIN
    W = nchunk * chunk
    A = W + u32(2) * mg
    A2 = A / u32(2)
    ea = f64(e0m) - f64(mg) * 10.0
    na = f64(n0m) + f64(mg) * 10.0
    mut b10 = array[f32](u32(4) * A * A)
    mut b20 = array[f32](u32(7) * A2 * A2)
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
            t = band(dir, nm, ea, na, A, 10.0)
            mut q = u32(0)
            while q < A * A do
                b10[bi * A * A + q] = t.px[q]
                q = q + u32(1)
            end
        else
            t = band(dir, nm, ea, na, A2, 20.0)
            mut q = u32(0)
            while q < A2 * A2 do
                b20[(bi - u32(4)) * A2 * A2 + q] = t.px[q]
                q = q + u32(1)
            end
        end
        bi = bi + u32(1)
    end
    tread = clock() - t0
    md = PR.load_model(bytes("out/model.bin"))
    df = md.df
    nw = md.nw
    msoil = D.NSOIL + nw
    mut bs = md.bs
    mut s2on = md.s2on
    mut irish = false
    mut ov = readfile(bytes("out/cork_soil_heads.bin"))
    if len(ov) == u32(0) then
        ov = readfile(bytes("models/cork_soil_heads.bin"))
    end
    if golden == u32(0) and len(ov) == df * D.NSOIL * u32(4) then
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
        irish = true
    end
    mut pq = array[f32](44)
    D.unmix_prep(md.em, pq)
    mut norm = md.norm
    mut p = md.p
    mut laws = md.laws
    mut coefs = array[f32](len(md.coefs))
    mut q = u32(0)
    while q < len(md.coefs) do
        coefs[q] = f32(md.coefs[q])
        q = q + u32(1)
    end
    mut b1 = FA.combine(md.bp, bs, md.bw, df, nw)
    mut b2 = array[f32](1)
    if s2on == u32(1) then
        b2 = FA.combine(md.b2p, md.b2s, md.b2w, md.df2, nw)
    end
    mut p2 = md.p2
    if len(p2) == u32(0) then
        p2 = array[f32](1)
    end
    mut ymu = md.ymu
    mut ysd = md.ysd
    S = chunk + u32(2) * mg
    P = S * S
    mut refl = array[f32](u32(10) * P)
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
    mut out = array[f32](FA.NO * P)
    mut maps = array[f32](u32(9) * P)
    mut g1 = array[f32](u32(24) * P)
    mut g2 = array[f32](u32(24) * P)
    mut mc = array[f32](u32(9) * P)
    mut psi = array[f32]((df + u32(66)) * P)
    doy = D.doy(u32(20230530))
    mut cv = array[f32](W * W * PR.NCH)
    mut tsum = 0.0
    mut tbest = 1e9
    mut tfirst = 0.0
    mut nt = u32(0)
    mut ci = u32(0)
    while ci < nchunk do
        mut cj = u32(0)
        while cj < nchunk do
            tc = clock()
            mut pp = u32(0)
            while pp < P do
                yy = ci * chunk + pp / S
                xx = cj * chunk + pp % S
                q10 = yy * A + xx
                q20 = (yy / u32(2)) * A2 + xx / u32(2)
                mut b = u32(0)
                while b < u32(4) do
                    refl[b * P + pp] = b10[b * A * A + q10] / f32(10000.0)
                    b = b + u32(1)
                end
                b = u32(0)
                while b < u32(6) do
                    refl[(u32(4) + b) * P + pp] = b20[b * A2 * A2 + q20] / f32(10000.0)
                    b = b + u32(1)
                end
                pp = pp + u32(1)
            end
            FA.run_chunk(refl, S, doy, df, nw, s2on, norm, pq, p, laws, coefs, b1, b2, p2, ymu, ysd,
                         x, bx, cx, tmp, f1, f2, f3, f4, nr, mag, mx, phi, sc, out, maps, g1, g2, mc, psi)
            mut r = u32(0)
            while r < chunk do
                mut c = u32(0)
                while c < chunk do
                    sp = (r + mg) * S + c + mg
                    gy = ci * chunk + r
                    gx = cj * chunk + c
                    o = (gy * W + gx) * PR.NCH
                    cv[o] = refl[u32(2) * P + sp]
                    cv[o + u32(1)] = refl[P + sp]
                    cv[o + u32(2)] = refl[sp]
                    cv[o + u32(3)] = x[u32(10) * P + sp]
                    cv[o + u32(4)] = x[u32(11) * P + sp]
                    cv[o + u32(5)] = out[sp]
                    cv[o + u32(6)] = out[P + sp]
                    cv[o + u32(7)] = f32(md.wrb[u32(out[u32(2) * P + sp])])
                    mut k = u32(0)
                    while k < u32(28) do
                        cv[o + u32(8) + k] = out[(u32(3) + k) * P + sp]
                        k = k + u32(1)
                    end
                    k = u32(0)
                    while k < u32(4) do
                        cv[o + u32(36) + k] = x[(u32(15) + k) * P + sp]
                        k = k + u32(1)
                    end
                    cv[o + u32(40)] = f32(PR.texture(cv[o + u32(20)], cv[o + u32(26)]))
                    q20 = ((gy + mg) / u32(2)) * A2 + (gx + mg) / u32(2)
                    scl = u32(b20[u32(6) * A2 * A2 + q20])
                    good = scl != u32(0) and scl != u32(1) and scl != u32(3) and scl != u32(8) and scl != u32(9) and scl != u32(10) and scl != u32(11)
                    cv[o + u32(43)] = f32(u32(good))
                    c = c + u32(1)
                end
                r = r + u32(1)
            end
            dt = clock() - tc
            if nt > u32(0) then
                tsum = tsum + dt
                tbest = min(tbest, dt)
            else
                tfirst = dt
            end
            if golden == u32(1) and nt == u32(0) then
                mut g = u32(0)
                g = g + put_f32s(bytes("out/golden/input_refl.f32"), refl, u32(10) * P)
                g = g + put_f32s(bytes("out/golden/expected_out.f32"), out, FA.NO * P)
                g = g + put_f32s(bytes("out/golden/expected_features.f32"), phi, df * P)
            end
            nt = nt + u32(1)
            cj = cj + u32(1)
        end
        ci = ci + u32(1)
    end
    thr = p85(cv, W * W)
    mut lg = array[u8](0)
    TX.putstr(lg, bytes("fast engine: "))
    TX.putint(lg, u64(nt))
    TX.putstr(lg, bytes(" chunks of "))
    TX.putint(lg, u64(chunk))
    TX.putstr(lg, bytes(" x "))
    TX.putint(lg, u64(chunk))
    TX.putstr(lg, bytes(" (computed as "))
    TX.putint(lg, u64(S))
    TX.putstr(lg, bytes(" x "))
    TX.putint(lg, u64(S))
    TX.putstr(lg, bytes(" with the margin), stage 2 "))
    TX.putint(lg, u64(s2on))
    TX.putstr(lg, bytes("; band read "))
    TX.putfix(lg, tread, u32(2))
    if nt > u32(1) then
        TX.putstr(lg, bytes(" s; per chunk after the first: mean "))
        TX.putfix(lg, tsum / f64(nt - u32(1)) * 1000.0, u32(1))
        TX.putstr(lg, bytes(" ms, best "))
        TX.putfix(lg, tbest * 1000.0, u32(1))
        TX.putstr(lg, bytes(" ms; "))
        TX.putfix(lg, f64(chunk * chunk) / max(tbest, 1e-9) / 1000000.0, u32(2))
        TX.putstr(lg, bytes(" Mpixel/s at best"))
    else
        TX.putstr(lg, bytes(" s; one chunk, including GPU warm-up: "))
        TX.putfix(lg, tfirst * 1000.0, u32(1))
        TX.putstr(lg, bytes(" ms"))
        tbest = tfirst
    end
    TX.putstr(lg, bytes("; zones threshold (85th percentile of the boundary score) "))
    TX.putfix(lg, f64(thr), u32(3))
    if golden == u32(1) then
        push(lg, u8(10))
        w0 = writefile("out/golden/run.txt", lg)
    else
        say(lg)
        mut od = bytes("out/cork_fast/")
        EX.mkdir(bytes("out/cork_fast"))
        EX.mkdir(bytes("out/cork_fast/textures"))
        PR.zones(cv, W, W, u32(3), u32(41), thr, u32(0))
        mut nts = array[u8](0)
        D.cat(nts, bytes("Computed by the fast chunk engine (src/agri/fast.cy). "))
        if irish then
            D.cat(nts, bytes("Soil layers: soil heads recalibrated on Irish SoilGrids. "))
        end
        D.cat(nts, bytes("Weather layers: the model's own weather heads, learnt from Bavarian seasons, not observed values; for Ireland use the ERA5-Land layers of out/cork/. Crop classes are Bavarian (Munich480) classes. Boundary threshold: 85th percentile of the scene."))
        wrote = EX.package(od, bytes("Cork - fast chunk engine"), cv, W, W, f64(e0m), f64(n0m), 10.0, u32(32629), bytes("data/cork/dem/"), nts)
        w2 = PR.render(cv, W, W, u32(8), u32(1), f32(5.0), f32(6.2), bytes("out/cork_fast/textures/"), bytes("ph_0-5cm"))
        w3 = PR.render_zones(cv, W, W, u32(41), bytes("out/cork_fast/textures/"), bytes("zones_ndvi"))
    end
    return tbest * 1000.0
end
