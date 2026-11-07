mut D = require("data.cy")
mut M = require("model.cy")
mut TR = require("train.cy")
mut PR = require("predict.cy")
mut TF = require("../../lib/geo/tiff.cy")
mut TX = require("../../lib/io/text.cy")
mut U = require("../../lib/geo/utm.cy")
mut BY = require("../../lib/io/bytes.cy")
mut EX = require("export.cy")

fn band_path(dir: u8[], name: u8[]) -> u8[]
    mut p = array[u8](0)
    D.cat(p, dir)
    D.cat(p, name)
    D.cat(p, bytes(".tif"))
    return p
end

fn read_win(dir: u8[], name: u8[], e0: f64, n0: f64, npx: u32, res: f64) -> TF.Tiff
    d = readfile(band_path(dir, name))
    g = TF.decode_window(d, u32(0), u32(0), u32(1), u32(1))
    cx = u32((e0 - g.x0) / res)
    cy = u32((g.y0 - n0) / res)
    return TF.decode_window(d, cx, cy, npx, npx)
end

fn meta_num(d: u8[], k: u32) -> u32
    mut field = u32(0)
    mut v = u32(0)
    for c in d do
        if c == u8(32) then
            field = field + u32(1)
        else
            if field == k and c >= u8(48) and c <= u8(57) then
                v = v * u32(10) + u32(c) - u32(48)
            end
        end
    end
    return v
end

pub fn main(e0m: u32, n0m: u32, npatch: u32) -> u32
    t0 = clock()
    dir = bytes("data/cork/s2/S2A_29UNT_20230530_0_L2A/")
    mut mp = array[u8](0)
    D.cat(mp, dir)
    D.cat(mp, bytes("meta.txt"))
    mt = readfile(mp)
    date = meta_num(mt, u32(0))
    epsg = meta_num(mt, u32(1))
    offset = f32(meta_num(mt, u32(2)))
    dd = D.doy(date)
    e0 = f64(e0m)
    n0 = f64(n0m)
    npx = npatch * D.N
    h20 = npx / u32(2)
    b02 = read_win(dir, bytes("B02"), e0, n0, npx, 10.0)
    b03 = read_win(dir, bytes("B03"), e0, n0, npx, 10.0)
    b04 = read_win(dir, bytes("B04"), e0, n0, npx, 10.0)
    b08 = read_win(dir, bytes("B08"), e0, n0, npx, 10.0)
    b05 = read_win(dir, bytes("B05"), e0, n0, h20, 20.0)
    b06 = read_win(dir, bytes("B06"), e0, n0, h20, 20.0)
    b07 = read_win(dir, bytes("B07"), e0, n0, h20, 20.0)
    b8a = read_win(dir, bytes("B8A"), e0, n0, h20, 20.0)
    b11 = read_win(dir, bytes("B11"), e0, n0, h20, 20.0)
    b12 = read_win(dir, bytes("B12"), e0, n0, h20, 20.0)
    scl = read_win(dir, bytes("SCL"), e0, n0, h20, 20.0)
    TR.sayf(bytes("scene date: "), f64(date), u32(0))
    TR.sayf(bytes("EPSG: "), f64(epsg), u32(0))
    TR.sayf(bytes("window origin E: "), b02.x0, u32(1))
    TR.sayf(bytes("window origin N: "), b02.y0, u32(1))
    TR.sayf(bytes("bands read, seconds: "), clock() - t0, u32(1))
    md = PR.load_model(bytes("out/model.bin"))
    df = md.df
    nw = md.nw
    mut pq = array[f32](44)
    D.unmix_prep(md.em, pq)
    mut p = md.p
    mut norm = md.norm
    mut laws = md.laws
    mut coefs = md.coefs
    mut bp = md.bp
    mut bs = md.bs
    mut irish = false
    mut ov = readfile(bytes("out/cork_soil_heads.bin"))
    if len(ov) == u32(0) then
        ov = readfile(bytes("models/cork_soil_heads.bin"))
    end
    if len(ov) == df * D.NSOIL * u32(4) then
        mut oa = u32(0)
        while oa < df do
            mut ot = u32(0)
            while ot < D.NSOIL do
                bs[oa * (D.NSOIL + nw) + ot] = BY.f32le(ov, (oa * D.NSOIL + ot) * u32(4))
                ot = ot + u32(1)
            end
            oa = oa + u32(1)
        end
        irish = true
        TR.say(bytes("using the Irish-recalibrated soil heads (cork_soil_heads.bin)\n"))
    end
    mut bw = md.bw
    mut ymu = md.ymu
    mut ysd = md.ysd
    mut ls = md.ls
    mut lw = md.lw
    mut s2 = md.s2
    mut s2on = md.s2on
    if irish then
        s2on = u32(0)
    end
    df2 = md.df2
    mut p2 = md.p2
    mut b2p = md.b2p
    mut b2s = md.b2s
    mut b2w = md.b2w
    mut phib = array[f32](TR.NB * df * D.NPIX)
    mut outb = array[f32](TR.NB * D.NPIX * PR.NOUT)
    mut mapsb = array[f32](TR.NB * PR.NMAP * D.NPIX)
    mut g1 = array[f32](TR.NB * PR.NF2 * D.NPIX)
    mut g2 = array[f32](TR.NB * PR.NF2 * D.NPIX)
    mut psi = array[f32](max(df2, u32(1)) * D.NPIX)
    mut b10 = array[f32](u32(4) * npx * npx)
    mut i = u32(0)
    while i < npx * npx do
        b10[i] = b02.px[i]
        b10[npx * npx + i] = b03.px[i]
        b10[u32(2) * npx * npx + i] = b04.px[i]
        b10[u32(3) * npx * npx + i] = b08.px[i]
        i = i + u32(1)
    end
    mut b20 = array[f32](u32(7) * h20 * h20)
    i = u32(0)
    while i < h20 * h20 do
        b20[i] = b05.px[i]
        b20[h20 * h20 + i] = b06.px[i]
        b20[u32(2) * h20 * h20 + i] = b07.px[i]
        b20[u32(3) * h20 * h20 + i] = b8a.px[i]
        b20[u32(4) * h20 * h20 + i] = b11.px[i]
        b20[u32(5) * h20 * h20 + i] = b12.px[i]
        b20[u32(6) * h20 * h20 + i] = scl.px[i]
        i = i + u32(1)
    end
    mut dv = array[f32](npx * npx * PR.NCH)
    mut refl = array[f32](D.NBAND * D.NPIX)
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
    mut out = array[f32](D.NPIX * PR.NOUT)
    mut slot = array[u32](TR.NB)
    mut slot_refl = array[f32](TR.NB * D.NBAND * D.NPIX)
    mut slot_ok = array[u32](TR.NB * D.NPIX)
    mut ws = array[f32](D.NPIX)
    mut nofp = array[u32](D.NPIX)
    mut dbest = array[i32](npx * npx)
    mut qd = u32(0)
    while qd < npx * npx do
        dbest[qd] = i32(-1)
        qd = qd + u32(1)
    end
    mut ps = u32(0)
    while ps < u32(2) do
    off = ps * (D.N / u32(2))
    npp = npatch - ps
    mut filled = u32(0)
    nt = npp * npp
    mut k = u32(0)
    while k <= nt do
        mut flush = k == nt
        if k < nt then
            pi = k / npp
            pj = k % npp
            mut pp = u32(0)
            while pp < D.NPIX do
                y10 = off + pi * D.N + pp / D.N
                x10 = off + pj * D.N + pp % D.N
                q10 = y10 * npx + x10
                q20 = (y10 / u32(2)) * h20 + x10 / u32(2)
                refl[pp] = (b10[q10] - offset) / f32(10000.0)
                refl[D.NPIX + pp] = (b10[npx * npx + q10] - offset) / f32(10000.0)
                refl[u32(2) * D.NPIX + pp] = (b10[u32(2) * npx * npx + q10] - offset) / f32(10000.0)
                refl[u32(3) * D.NPIX + pp] = (b10[u32(3) * npx * npx + q10] - offset) / f32(10000.0)
                mut b = u32(0)
                while b < u32(6) do
                    refl[(u32(4) + b) * D.NPIX + pp] = (b20[b * h20 * h20 + q20] - offset) / f32(10000.0)
                    b = b + u32(1)
                end
                sc = u32(b20[u32(6) * h20 * h20 + q20])
                good = sc != u32(0) and sc != u32(1) and sc != u32(3) and sc != u32(8) and sc != u32(9) and sc != u32(10) and sc != u32(11)
                slot_ok[filled * D.NPIX + pp] = u32(good)
                pp = pp + u32(1)
            end
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
            q = u32(0)
            while q < D.NBAND * D.NPIX do
                slot_refl[filled * D.NBAND * D.NPIX + q] = refl[q]
                q = q + u32(1)
            end
            slot[filled] = k
            filled = filled + u32(1)
            if filled == TR.NB then
                flush = true
            end
        end
        if flush and filled > u32(0) then
            TR.conv_bank(xb, p, f1, f2, f3, f4, filled)
            PR.infer_batch(xb, f1, f2, f3, f4, gmb, filled, laws, coefs, bp, bs, bw, df, nw, ymu, ysd, s2on, p2, b2p, b2s, b2w, df2, phib, outb, mapsb, g1, g2, gm, phi, out, psi)
            mut s = u32(0)
            while s < filled do
                kk = slot[s]
                pi = kk / npp
                pj = kk % npp
                mut q = u32(0)
                while q < df * D.NPIX do
                    phi[q] = phib[s * df * D.NPIX + q]
                    q = q + u32(1)
                end
                q = u32(0)
                while q < D.NPIX * PR.NOUT do
                    out[q] = outb[s * D.NPIX * PR.NOUT + q]
                    q = q + u32(1)
                end
                q = u32(0)
                while q < D.NPIX do
                    ws[q] = phi[u32(16) * D.NPIX + q] + f32(0.05)
                    q = q + u32(1)
                end
                qs = PR.quad_patch(ls, df, phi, nofp, u32(65535), ws)
                sph = f32(sqrt(f64(s2[0]) * (1.0 + qs))) * ysd[1]
                mut pp = u32(0)
                while pp < D.NPIX do
                    ri = pp / D.N
                    rj = pp % D.N
                    pix = (off + pi * D.N + ri) * npx + off + pj * D.N + rj
                    dist = min(min(i32(ri), i32(rj)), min(i32(D.N - u32(1) - ri), i32(D.N - u32(1) - rj)))
                    o = pix * PR.NCH
                    if dist > dbest[pix] then
                    dbest[pix] = dist
                    ro = s * D.NBAND * D.NPIX
                    dv[o] = slot_refl[ro + u32(2) * D.NPIX + pp]
                    dv[o + u32(1)] = slot_refl[ro + D.NPIX + pp]
                    dv[o + u32(2)] = slot_refl[ro + pp]
                    dv[o + u32(3)] = xb[s * D.NBASE * D.NPIX + u32(10) * D.NPIX + pp]
                    dv[o + u32(4)] = xb[s * D.NBASE * D.NPIX + u32(11) * D.NPIX + pp]
                    edge = dist < i32(2)
                    dv[o + u32(5)] = out[pp * PR.NOUT]
                    if edge then
                        dv[o + u32(5)] = f32(0.0)
                    end
                    dv[o + u32(6)] = out[pp * PR.NOUT + u32(1)]
                    dv[o + u32(7)] = f32(md.wrb[u32(out[pp * PR.NOUT + u32(2)])])
                    mut t = u32(0)
                    while t < u32(28) do
                        dv[o + u32(8) + t] = out[pp * PR.NOUT + u32(3) + t]
                        t = t + u32(1)
                    end
                    t = u32(0)
                    while t < u32(4) do
                        dv[o + u32(36) + t] = xb[s * D.NBASE * D.NPIX + (u32(15) + t) * D.NPIX + pp]
                        t = t + u32(1)
                    end
                    dv[o + u32(40)] = f32(PR.texture(dv[o + u32(20)], dv[o + u32(26)]))
                    dv[o + u32(41)] = sph
                    dv[o + u32(42)] = f32(0.0)
                    dv[o + u32(43)] = f32(slot_ok[s * D.NPIX + pp])
                    end
                    pp = pp + u32(1)
                end
                s = s + u32(1)
            end
            filled = u32(0)
        end
        k = k + u32(1)
    end
    ps = ps + u32(1)
    end
    TR.sayf(bytes("predicted, seconds: "), clock() - t0, u32(1))
    wxc = D.load_weather(bytes("data/cork/weather/"), date / u32(10000))
    mut wxok = false
    if wxc.np > u32(0) then
        z29 = epsg % u32(100)
        ctl = U.to_latlon(b02.x0, b02.y0, z29, false)
        ctr = U.to_latlon(b02.x0 + f64(npx) * 10.0, b02.y0, z29, false)
        cbl = U.to_latlon(b02.x0, b02.y0 - f64(npx) * 10.0, z29, false)
        cbr = U.to_latlon(b02.x0 + f64(npx) * 10.0, b02.y0 - f64(npx) * 10.0, z29, false)
        mut wo = array[f64](4)
        mut q = u32(0)
        while q < npx * npx do
            u = (f64(q % npx) + 0.5) / f64(npx)
            v = (f64(q / npx) + 0.5) / f64(npx)
            la = (ctl.0 * (1.0 - u) + ctr.0 * u) * (1.0 - v) + (cbl.0 * (1.0 - u) + cbr.0 * u) * v
            lo = (ctl.1 * (1.0 - u) + ctr.1 * u) * (1.0 - v) + (cbl.1 * (1.0 - u) + cbr.1 * u) * v
            if D.weather_at(wxc, la, lo, date / u32(10000), dd, wo) then
                mut c = u32(0)
                while c < u32(4) do
                    dv[q * PR.NCH + u32(32) + c] = f32(wo[c])
                    c = c + u32(1)
                end
                wxok = true
            end
            q = q + u32(1)
        end
    end
    if wxok then
        TR.say(bytes("weather layers: observed ERA5-Land for the scene date (Open-Meteo)\n"))
    end
    od = bytes("out/cork/textures/")
    gd = bytes("out/cork/geotiff/")
    EX.mkdir(bytes("out/cork"))
    EX.mkdir(od)
    EX.mkdir(gd)
    bth = quantile_threshold(dv, npx, npx, f32(0.85))
    TR.sayf(bytes("scene boundary threshold (85th percentile): "), f64(bth), u32(3))
    x0 = b02.x0
    y0 = b02.y0
    mut n = u32(0)
    n = n + PR.export(dv, npx, npx, u32(8), u32(24), x0, y0, 10.0, epsg, gd, bytes("cork_soil_10m"))
    n = n + PR.export(dv, npx, npx, u32(32), u32(4), x0, y0, 10.0, epsg, gd, bytes("cork_weather_10m"))
    n = n + PR.export(dv, npx, npx, u32(3), u32(5), x0, y0, 10.0, epsg, gd, bytes("cork_surface_10m"))
    mut lh = array[f32](2)
    n = n + PR.render_rgb(dv, npx, npx, u32(0), bth, od, bytes("cork_rgb"))
    n = n + PR.render_rgb(dv, npx, npx, u32(1), bth, od, bytes("cork_boundaries"))
    n = n + PR.render_rgb(dv, npx, npx, u32(2), bth, od, bytes("cork_unmixing"))
    n = n + PR.render(dv, npx, npx, u32(3), u32(2), f32(-0.1), f32(0.9), od, bytes("cork_ndvi"))
    n = n + PR.render(dv, npx, npx, u32(4), u32(1), f32(-0.3), f32(0.5), od, bytes("cork_ndmi"))
    stretch(dv, npx, npx, u32(8), lh)
    n = n + PR.render(dv, npx, npx, u32(8), u32(1), lh[0], lh[1], od, bytes("cork_ph_0-5cm"))
    stretch(dv, npx, npx, u32(14), lh)
    n = n + PR.render(dv, npx, npx, u32(14), u32(0), lh[0], lh[1], od, bytes("cork_soc_0-5cm"))
    stretch(dv, npx, npx, u32(26), lh)
    n = n + PR.render(dv, npx, npx, u32(26), u32(0), lh[0], lh[1], od, bytes("cork_sand_0-5cm"))
    stretch(dv, npx, npx, u32(34), lh)
    n = n + PR.render(dv, npx, npx, u32(34), u32(4), lh[0], lh[1], od, bytes("cork_soil_moisture"))
    stretch(dv, npx, npx, u32(35), lh)
    n = n + PR.render(dv, npx, npx, u32(35), u32(1), lh[0], lh[1], od, bytes("cork_water_balance"))
    stretch(dv, npx, npx, u32(32), lh)
    n = n + PR.render(dv, npx, npx, u32(32), u32(3), lh[0], lh[1], od, bytes("cork_temperature"))
    n = n + PR.render(dv, npx, npx, u32(6), u32(10), f32(0.0), f32(1.0), od, bytes("cork_crop"))
    PR.zones(dv, npx, npx, u32(3), u32(41), bth, u32(0))
    n = n + PR.render_zones(dv, npx, npx, u32(41), od, bytes("cork_zones_ndvi"))
    n = n + EX.package(bytes("out/cork/"), bytes("Cork, Ireland - Sentinel-2 L2A 2023-05-30, 10 m"), dv, npx, npx, x0, y0, 10.0, epsg, bytes("data/cork/dem/"), bytes("Soil layers: model with soil heads recalibrated on Irish SoilGrids (held-out R2 pH 0.19, organic carbon 0.20). Weather layers: observed ERA5-Land for the scene date via Open-Meteo, about 9 km, not model output. Crop classes are Bavarian (Munich480) classes and do not apply to Irish grassland. Boundary threshold: 85th percentile of the scene."))
    vr = validate(dv, npx, x0, y0, epsg % u32(100), bytes("data/cork/soil/"))
    TR.say(vr)
    n = n + writefile("out/cork/validation.txt", vr)
    TR.sayf(bytes("bytes written: "), f64(n), u32(0))
    TR.sayf(bytes("seconds: "), clock() - t0, u32(1))
    return n
end

pub fn validate(dv: f32[], npx: u32, x0: f64, y0: f64, zone: u32, soildir: u8[]) -> u8[]
    s = D.load_soil(soildir)
    w = s.w[0]
    h = s.h[0]
    mut acc = array[f64](w * h * u32(4))
    mut wsum = array[f64](w * h)
    mut cnt = array[u32](w * h)
    mut i = u32(0)
    while i < npx do
        mut j = u32(0)
        while j < npx do
            o = (i * npx + j) * PR.NCH
            if dv[o + u32(43)] > f32(0.5) then
                ll = U.to_latlon(x0 + (f64(j) + 0.5) * 10.0, y0 - (f64(i) + 0.5) * 10.0, zone, false)
                fx = (ll.1 - s.x0[0]) / s.dx[0]
                fy = (s.y0[0] - ll.0) / s.dy[0]
                if fx >= 0.0 and fy >= 0.0 and fx < f64(w) and fy < f64(h) then
                    cell = u32(fy) * w + u32(fx)
                    wt = f64(dv[o + u32(36)]) + 0.05
                    wsum[cell] = wsum[cell] + wt
                    cnt[cell] = cnt[cell] + u32(1)
                    mut k = u32(0)
                    while k < u32(4) do
                        acc[cell * u32(4) + k] = acc[cell * u32(4) + k] + wt * f64(dv[o + u32(8) + k * u32(6)])
                        k = k + u32(1)
                    end
                end
            end
            j = j + u32(1)
        end
        i = i + u32(1)
    end
    mut r = array[u8](0)
    TX.putstr(r, bytes("SOILGRIDS CHECK in the scene window, per 250 m cell, 0-5 cm (with recalibrated heads the window lies inside the calibration area, so this is partly in-sample; out/cork/recalibration.txt has the held-out figures)"))
    TX.putch(r, u32(10))
    mut k = u32(0)
    while k < u32(4) do
        mut n = 0.0
        mut sp = 0.0
        mut st = 0.0
        mut spp = 0.0
        mut stt = 0.0
        mut spt = 0.0
        mut sse = 0.0
        mut c = u32(0)
        while c < w * h do
            if cnt[c] >= u32(20) then
                la = s.y0[0] - (f64(c / w) + 0.5) * s.dy[0]
                lo = s.x0[0] + (f64(c % w) + 0.5) * s.dx[0]
                raw = D.soil_at(s, k * u32(6), la, lo)
                if raw > f32(0.0) then
                    tv = f64(raw) / 10.0
                    pv = acc[c * u32(4) + k] / wsum[c]
                    n = n + 1.0
                    sp = sp + pv
                    st = st + tv
                    spp = spp + pv * pv
                    stt = stt + tv * tv
                    spt = spt + pv * tv
                    sse = sse + (pv - tv) * (pv - tv)
                end
            end
            c = c + u32(1)
        end
        mt = st / max(n, 1.0)
        sst = stt - n * mt * mt
        cov = spt - sp * st / max(n, 1.0)
        vp = spp - sp * sp / max(n, 1.0)
        TX.putstr(r, bytes("  "))
        TR.target_name(r, u32(1) + k * u32(6))
        TX.putstr(r, bytes(": cells "))
        TX.putint(r, u64(n))
        TX.putstr(r, bytes(", SoilGrids mean "))
        TX.putfix(r, mt, u32(2))
        TX.putstr(r, bytes(", model mean "))
        TX.putfix(r, sp / max(n, 1.0), u32(2))
        TX.putstr(r, bytes(", R2 "))
        TX.putfix(r, 1.0 - sse / max(sst, 1e-12), u32(3))
        TX.putstr(r, bytes(", correlation "))
        TX.putfix(r, cov / sqrt(max(vp * sst, 1e-24)), u32(3))
        TX.putch(r, u32(10))
        k = k + u32(1)
    end
    return r
end

fn quantile_threshold(cv: f32[], w: u32, h: u32, frac: f32) -> f32
    mut hist = array[u32](400)
    mut n = u32(0)
    mut q = u32(0)
    while q < w * h do
        qi = (q / w) % D.N
        qj = (q % w) % D.N
        ring = qi < u32(2) or qj < u32(2) or qi + u32(2) >= D.N or qj + u32(2) >= D.N
        if not ring and cv[q * PR.NCH + u32(43)] > f32(0.5) then
            v = cv[q * PR.NCH + u32(5)]
            b = u32(max(f32(0.0), min(f32(399.0), (v + f32(1.0)) * f32(100.0))))
            hist[b] = hist[b] + u32(1)
            n = n + u32(1)
        end
        q = q + u32(1)
    end
    target = u32(f32(n) * frac)
    mut acc = u32(0)
    mut b = u32(0)
    while b < u32(400) and acc < target do
        acc = acc + hist[b]
        b = b + u32(1)
    end
    return f32(b) / f32(100.0) - f32(1.0)
end

fn stretch(cv: f32[], w: u32, h: u32, ch: u32, lohi: f32[])
    mut n = 0.0
    mut sm = 0.0
    mut sq = 0.0
    mut q = u32(0)
    while q < w * h do
        if cv[q * PR.NCH + u32(43)] > f32(0.5) then
            v = f64(cv[q * PR.NCH + ch])
            n = n + 1.0
            sm = sm + v
            sq = sq + v * v
        end
        q = q + u32(1)
    end
    mu = sm / max(n, 1.0)
    sd = sqrt(max(sq / max(n, 1.0) - mu * mu, 1e-12))
    lohi[0] = f32(mu - 2.0 * sd)
    lohi[1] = f32(mu + 2.0 * sd)
end
