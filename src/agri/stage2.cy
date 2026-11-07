mut D = require("data.cy")
mut M = require("model.cy")
mut TR = require("train.cy")
mut PR = require("predict.cy")
mut TX = require("../../lib/io/text.cy")
mut BY = require("../../lib/io/bytes.cy")

fn app32(b: u8[], v: u32)
    push(b, u8(v & u32(255)))
    push(b, u8((v >> u32(8)) & u32(255)))
    push(b, u8((v >> u32(16)) & u32(255)))
    push(b, u8(v >> u32(24)))
end

fn appf_arr(b: u8[], a: f32[], n: u32)
    mut i = u32(0)
    while i < n do
        app32(b, tobits(a[i]))
        i = i + u32(1)
    end
end

fn appd_arr(b: u8[], a: f64[], n: u32)
    mut i = u32(0)
    while i < n do
        app32(b, tobits(f32(a[i])))
        i = i + u32(1)
    end
end

fn has_labels(root: u8[], id: u32) -> bool
    mut p = D.patch_dir(root, u32(2016), id)
    D.cat(p, bytes("y.tif"))
    return len(readfile(p)) > u32(0)
end

pub fn accumulate2(psi: f32[], d: u32, s: u32, rows: f32[], ry: f32[], rw: f32[], srow: f32[], sy: f32[], sw: f32[], wrow: f32[], wy: f32[], one: f32[],
                   ev: bool, crop: u32[], bnd: u32[], fp: u32[], soil: f32[], wrb: u32[], fok: u32[], nfp: u32, wxv: f64[],
                   cw: f32[], wrbmap: u32[], nw: u32, ymu: f32[], ysd: f32[],
                   gp: f64[], gpe: f64[], gs: f64[], gse: f64[], gw: f64[], gwe: f64[], xyp: f64[], xype: f64[], xys: f64[], xyse: f64[],
                   xyw: f64[], xywe: f64[], yyp: f64[], yype: f64[], yys: f64[], yyse: f64[], yyw: f64[], yywe: f64[])
    np = D.NPIX
    msoil = D.NSOIL + nw
    mut nr = u32(0)
    mut p = u32(0)
    while p < np do
        if (p / D.N) % u32(3) == u32(1) and (p % D.N) % u32(3) == u32(1) then
            mut c = u32(0)
            while c < d do
                rows[nr * d + c] = psi[c * np + p]
                c = c + u32(1)
            end
            cr = crop[p]
            ry[nr * TR.NPIXT] = f32(bnd[p])
            c = u32(0)
            while c < D.NCROP do
                ry[nr * TR.NPIXT + u32(1) + c] = f32(u32(c == cr))
                c = c + u32(1)
            end
            rw[nr] = cw[cr]
            nr = nr + u32(1)
        end
        p = p + u32(1)
    end
    if ev then
        M.gram_add(gpe, rows, nr, d, rw)
        M.rhs_add(xype, yype, rows, ry, nr, d, TR.NPIXT, rw)
    else
        M.gram_add(gp, rows, nr, d, rw)
        M.rhs_add(xyp, yyp, rows, ry, nr, d, TR.NPIXT, rw)
    end
    mut ws = array[f32](np)
    p = u32(0)
    while p < np do
        ws[p] = psi[u32(16) * np + p] + f32(0.05)
        p = p + u32(1)
    end
    mut ns = u32(0)
    mut facc = array[f32](D.MAXFP * d)
    mut fws = array[f32](D.MAXFP)
    TR.fp_means(psi, d, ws, fp, nfp, facc, fws)
    mut f = u32(0)
    while f < nfp do
        if fok[f] == u32(1) and wrbmap[wrb[f]] != u32(255) then
            wsum = fws[f]
            mut cc = u32(0)
            while cc < d do
                srow[ns * d + cc] = facc[f * d + cc]
                cc = cc + u32(1)
            end
            if wsum > f32(0.0) then
                mut t = u32(0)
                while t < D.NSOIL do
                    sy[ns * msoil + t] = (soil[f * D.NSOIL + t] - ymu[u32(1) + t]) / ysd[u32(1) + t]
                    t = t + u32(1)
                end
                wc = wrbmap[wrb[f]]
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
            M.gram_add(gse, srow, ns, d, sw)
            M.rhs_add(xyse, yyse, srow, sy, ns, d, msoil, sw)
        else
            M.gram_add(gs, srow, ns, d, sw)
            M.rhs_add(xys, yys, srow, sy, ns, d, msoil, sw)
        end
    end
    mut c = u32(0)
    while c < d do
        mut a = f32(0.0)
        p = u32(0)
        while p < np do
            a = a + psi[c * np + p]
            p = p + u32(1)
        end
        wrow[c] = a / f32(np)
        c = c + u32(1)
    end
    mut t = u32(0)
    while t < D.NWX do
        wy[t] = (f32(wxv[t]) - ymu[u32(25) + t]) / ysd[u32(25) + t]
        t = t + u32(1)
    end
    if ev then
        M.gram_add(gwe, wrow, u32(1), d, one)
        M.rhs_add(xywe, yywe, wrow, wy, u32(1), d, D.NWX, one)
    else
        M.gram_add(gw, wrow, u32(1), d, one)
        M.rhs_add(xyw, yyw, wrow, wy, u32(1), d, D.NWX, one)
    end
end

fn pad(b1: f32[], df: u32, df2: u32, m: u32) -> f64[]
    mut o = array[f64](df2 * m)
    mut a = u32(0)
    while a < df * m do
        o[a] = f64(b1[a])
        a = a + u32(1)
    end
    return o
end

fn r2line(r: u8[], label: u8[], sse1: f64, sse2: f64, sst: f64)
    TX.putstr(r, bytes("    "))
    TX.putstr(r, label)
    TX.putstr(r, bytes(": stage 1 R2 "))
    TX.putfix(r, 1.0 - sse1 / max(sst, 1e-12), u32(3))
    TX.putstr(r, bytes(" -> stage 2 R2 "))
    TX.putfix(r, 1.0 - sse2 / max(sst, 1e-12), u32(3))
    TX.putch(r, u32(10))
end

pub fn main(maxpatch: u32, dps: u32, nyr: u32) -> u32
    root = bytes("data/kaggle/munich480/")
    t0 = clock()
    md = PR.load_model(bytes("out/model.bin"))
    df = md.df
    nw = md.nw
    msoil = D.NSOIL + nw
    df2 = df + PR.NMAP + PR.NF2 * u32(2) + PR.NMAP
    soil = D.load_soil(bytes("data/bavaria/soil/"))
    wx = D.load_weather(bytes("data/bavaria/weather/"), u32(2016))
    cm = D.crop_map(bytes("data/kaggle/munich480/classes.txt"))
    tr_all = D.read_ids(bytes("data/kaggle/munich480/tileids/train_fold0.tileids"))
    ev_all = D.read_ids(bytes("data/kaggle/munich480/tileids/eval.tileids"))
    mut tr = array[u32](0)
    mut ev = array[u32](0)
    for id in tr_all do
        if len(tr) < maxpatch and has_labels(root, id) then
            push(tr, id)
        end
    end
    for id in ev_all do
        if len(ev) < maxpatch / u32(3) and has_labels(root, id) then
            push(ev, id)
        end
    end
    TR.sayf(bytes("stage 2: train patches "), f64(len(tr)), u32(0))
    TR.sayf(bytes("stage 2: eval patches  "), f64(len(ev)), u32(0))
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
    mut cw = md.cw
    mut wrbmap = array[u32](256)
    mut q = u32(0)
    while q < u32(256) do
        wrbmap[q] = u32(255)
        q = q + u32(1)
    end
    q = u32(0)
    while q < nw do
        wrbmap[md.wrb[q]] = q
        q = q + u32(1)
    end
    mut p2 = PR.conv2_params(u64(20261108))
    mut b2p = array[f32](0)
    mut b2s = array[f32](0)
    mut b2w = array[f32](0)
    d2 = df2 * df2
    mut gp = array[f64](d2)
    mut gpe = array[f64](d2)
    mut gs = array[f64](d2)
    mut gse = array[f64](d2)
    mut gw = array[f64](d2)
    mut gwe = array[f64](d2)
    mut xyp = array[f64](df2 * TR.NPIXT)
    mut xype = array[f64](df2 * TR.NPIXT)
    mut xys = array[f64](df2 * msoil)
    mut xyse = array[f64](df2 * msoil)
    mut xyw = array[f64](df2 * D.NWX)
    mut xywe = array[f64](df2 * D.NWX)
    mut yyp = array[f64](TR.NPIXT)
    mut yype = array[f64](TR.NPIXT)
    mut yys = array[f64](msoil)
    mut yyse = array[f64](msoil)
    mut yyw = array[f64](D.NWX)
    mut yywe = array[f64](D.NWX)
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
    mut phib = array[f32](TR.NB * df * np)
    mut outb = array[f32](TR.NB * np * PR.NOUT)
    mut mapsb = array[f32](TR.NB * PR.NMAP * np)
    mut g1 = array[f32](TR.NB * PR.NF2 * np)
    mut g2 = array[f32](TR.NB * PR.NF2 * np)
    mut phi = array[f32](df * np)
    mut out = array[f32](np * PR.NOUT)
    mut psi = array[f32](df2 * np)
    mut rows = array[f32](u32(256) * df2)
    mut ry = array[f32](u32(256) * TR.NPIXT)
    mut rw = array[f32](u32(256))
    mut srow = array[f32](D.MAXFP * df2)
    mut sy = array[f32](D.MAXFP * msoil)
    mut sw = array[f32](D.MAXFP)
    mut wrow = array[f32](df2)
    mut wy = array[f32](D.NWX)
    mut one = array[f32](1)
    one[0] = f32(1.0)
    mut sel = array[u32](16)
    mut wxo = array[f64](4)
    mut sl_ev = array[u32](TR.NB)
    mut sl_crop = array[u32](TR.NB * np)
    mut sl_bnd = array[u32](TR.NB * np)
    mut sl_fp = array[u32](TR.NB * np)
    mut sl_soil = array[f32](TR.NB * D.MAXFP * D.NSOIL)
    mut sl_wrb = array[u32](TR.NB * D.MAXFP)
    mut sl_ok = array[u32](TR.NB * D.MAXFP)
    mut sl_nfp = array[u32](TR.NB)
    mut sl_wx = array[f64](TR.NB * u32(4))
    mut c_crop = array[u32](np)
    mut c_bnd = array[u32](np)
    mut c_fp = array[u32](np)
    mut c_soil = array[f32](D.MAXFP * D.NSOIL)
    mut c_wrb = array[u32](D.MAXFP)
    mut c_ok = array[u32](D.MAXFP)
    mut c_wx = array[f64](4)
    nbase = len(tr) + len(ev)
    total = nbase * nyr
    mut filled = u32(0)
    mut nsamp = u32(0)
    mut ti = u32(0)
    while ti <= total do
        mut flush = ti == total
        if ti < total then
            tb = ti % nbase
            yr = u32(2016) + ti / nbase
            mut pid = u32(0)
            mut isev = false
            if tb < len(tr) then
                pid = tr[tb]
            else
                pid = ev[tb - len(tr)]
                isev = true
            end
            dir = D.patch_dir(root, yr, pid)
            pt = D.load_patch(dir, cm, soil)
            if pt.ok then
                mut want = dps
                if isev then
                    want = u32(2)
                end
                nd = TR.pick_dates(dir, want, refl, sel)
                mut k = u32(0)
                while k < nd and filled < TR.NB do
                    dd = D.doy(sel[k])
                    okw = D.weather_at(wx, pt.lat, pt.lon, yr, dd, wxo)
                    if okw and D.load_refl(dir, sel[k], refl, u32(0)) then
                        D.base_channels(refl, u32(0), dd, norm, pq, xb, filled * D.NBASE * np)
                        q = u32(0)
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
                        sl_ev[filled] = u32(isev)
                        q = u32(0)
                        while q < np do
                            sl_crop[filled * np + q] = pt.crop[q]
                            sl_bnd[filled * np + q] = pt.bnd[q]
                            sl_fp[filled * np + q] = pt.fp[q]
                            q = q + u32(1)
                        end
                        q = u32(0)
                        while q < D.MAXFP * D.NSOIL do
                            sl_soil[filled * D.MAXFP * D.NSOIL + q] = pt.soil[q]
                            q = q + u32(1)
                        end
                        q = u32(0)
                        while q < D.MAXFP do
                            sl_wrb[filled * D.MAXFP + q] = pt.wrb[q]
                            sl_ok[filled * D.MAXFP + q] = pt.fpok[q]
                            q = q + u32(1)
                        end
                        sl_nfp[filled] = pt.nfp
                        q = u32(0)
                        while q < u32(4) do
                            sl_wx[filled * u32(4) + q] = wxo[q]
                            q = q + u32(1)
                        end
                        filled = filled + u32(1)
                    end
                    k = k + u32(1)
                end
                if filled + dps > TR.NB then
                    flush = true
                end
            end
        end
        if flush and filled > u32(0) then
            TR.conv_bank(xb, p, f1, f2, f3, f4, filled)
            PR.infer_batch(xb, f1, f2, f3, f4, gmb, filled, laws, coefs, bp, bs, bw, df, nw, ymu, ysd, u32(2), p2, b2p, b2s, b2w, df2,
                           phib, outb, mapsb, g1, g2, gm, phi, out, psi)
            mut s = u32(0)
            while s < filled do
                PR.build_psi(phib, mapsb, g1, g2, s, df, psi)
                q = u32(0)
                while q < np do
                    c_crop[q] = sl_crop[s * np + q]
                    c_bnd[q] = sl_bnd[s * np + q]
                    c_fp[q] = sl_fp[s * np + q]
                    q = q + u32(1)
                end
                q = u32(0)
                while q < D.MAXFP * D.NSOIL do
                    c_soil[q] = sl_soil[s * D.MAXFP * D.NSOIL + q]
                    q = q + u32(1)
                end
                q = u32(0)
                while q < D.MAXFP do
                    c_wrb[q] = sl_wrb[s * D.MAXFP + q]
                    c_ok[q] = sl_ok[s * D.MAXFP + q]
                    q = q + u32(1)
                end
                q = u32(0)
                while q < u32(4) do
                    c_wx[q] = sl_wx[s * u32(4) + q]
                    q = q + u32(1)
                end
                accumulate2(psi, df2, s, rows, ry, rw, srow, sy, sw, wrow, wy, one, sl_ev[s] == u32(1), c_crop, c_bnd, c_fp, c_soil, c_wrb, c_ok,
                            sl_nfp[s], c_wx, cw, wrbmap, nw, ymu, ysd, gp, gpe, gs, gse, gw, gwe, xyp, xype, xys, xyse, xyw, xywe,
                            yyp, yype, yys, yyse, yyw, yywe)
                s = s + u32(1)
            end
            nsamp = nsamp + filled
            filled = u32(0)
        end
        if ti % u32(500) == u32(0) then
            mut o = array[u8](0)
            TX.putstr(o, bytes("stage 2 pass: patch "))
            TX.putint(o, u64(ti))
            TX.putstr(o, bytes(" / "))
            TX.putint(o, u64(total))
            TX.putstr(o, bytes(", samples "))
            TX.putint(o, u64(nsamp))
            TX.putstr(o, bytes(", "))
            TX.putfix(o, clock() - t0, u32(0))
            TX.putstr(o, bytes(" s"))
            TX.putch(o, u32(10))
            TR.say(o)
        end
        ti = ti + u32(1)
    end
    M.symmetrize(gp, df2)
    M.symmetrize(gpe, df2)
    M.symmetrize(gs, df2)
    M.symmetrize(gse, df2)
    M.symmetrize(gw, df2)
    M.symmetrize(gwe, df2)
    offp = pad(bp, df, df2, TR.NPIXT)
    offs = pad(bs, df, df2, msoil)
    offw = pad(bw, df, df2, D.NWX)
    mut bep = array[f64](df2 * TR.NPIXT)
    mut bes = array[f64](df2 * msoil)
    mut bew = array[f64](df2 * D.NWX)
    mut lkp = array[u32](TR.NPIXT)
    mut lks = array[u32](msoil)
    mut lkw = array[u32](D.NWX)
    mut ssep = array[f64](TR.NPIXT)
    mut sses = array[f64](msoil)
    mut ssew = array[f64](D.NWX)
    mut cp = array[f64](TR.NPIXT)
    mut cs = array[f64](msoil)
    mut cwt = array[f64](D.NWX)
    w1 = M.solve_offset(gp, xyp, yyp, gpe, xype, yype, df2, TR.NPIXT, offp, bep, lkp, ssep, cp)
    w2 = M.solve_offset(gs, xys, yys, gse, xyse, yyse, df2, msoil, offs, bes, lks, sses, cs)
    w3 = M.solve_offset(gw, xyw, yyw, gwe, xywe, yywe, df2, D.NWX, offw, bew, lkw, ssew, cwt)
    mut r = array[u8](0)
    TX.putstr(r, bytes("STAGE 2 (re-reads the stage-1 maps; stacked on stage 1, lambda chosen on held-out patches)"))
    TX.putch(r, u32(10))
    TX.putstr(r, bytes("  worst certificate: pixel "))
    TX.putsci(r, w1, u32(2))
    TX.putstr(r, bytes(", soil "))
    TX.putsci(r, w2, u32(2))
    TX.putstr(r, bytes(", weather "))
    TX.putsci(r, w3, u32(2))
    TX.putch(r, u32(10))
    mut t = u32(0)
    while t < TR.NPIXT do
        if t == u32(0) then
            sst = yype[t] - xype[t] * xype[t] / max(gpe[0], 1.0)
            r2line(r, bytes("field boundary (pixel)"), M.heldout_sse(offp, TR.NPIXT, t, gpe, xype, yype, df2), ssep[t], sst)
        end
        t = t + u32(1)
    end
    t = u32(0)
    while t < D.NSOIL do
        if t % u32(6) == u32(0) then
            sst = yyse[t] - xyse[t] * xyse[t] / max(gse[0], 1.0)
            mut lab = array[u8](0)
            TR.target_name(lab, t + u32(1))
            r2line(r, lab, M.heldout_sse(offs, msoil, t, gse, xyse, yyse, df2), sses[t], sst)
        end
        t = t + u32(1)
    end
    t = u32(0)
    while t < D.NWX do
        sst = yywe[t] - xywe[t] * xywe[t] / max(gwe[0], 1.0)
        mut lab = array[u8](0)
        TR.target_name(lab, t + u32(25))
        r2line(r, lab, M.heldout_sse(offw, D.NWX, t, gwe, xywe, yywe, df2), ssew[t], sst)
        t = t + u32(1)
    end
    TR.say(r)
    mut fileb = readfile(bytes("out/model.bin"))
    mut base = array[u8](0)
    nbase1 = u32(20) + u32(20 + 40) * u32(4) + nw * u32(4) + len(md.p) * u32(4) + TR.NLAW * u32(8) * u32(8) + TR.NLAW * u32(8) +
             df * (TR.NPIXT + msoil + D.NWX) * u32(4) + (msoil + D.NWX) * u32(4) + df * df * u32(8) + D.NCROP * u32(4)
    q = u32(0)
    while q < nbase1 and q < len(fileb) do
        push(base, fileb[q])
        q = q + u32(1)
    end
    app32(base, u32(1))
    app32(base, df2)
    app32(base, len(p2))
    appf_arr(base, p2, len(p2))
    appd_arr(base, bep, df2 * TR.NPIXT)
    appd_arr(base, bes, df2 * msoil)
    appd_arr(base, bew, df2 * D.NWX)
    wrote = writefile(bytes("out/model.bin"), base)
    mut rep = readfile(bytes("out/train_report.txt"))
    for c in r do
        push(rep, c)
    end
    wr2 = writefile(bytes("out/train_report.txt"), rep)
    TR.sayf(bytes("stage 2 samples: "), f64(nsamp), u32(0))
    TR.sayf(bytes("model bytes: "), f64(wrote), u32(0))
    TR.sayf(bytes("seconds: "), clock() - t0, u32(1))
    return nsamp
end
