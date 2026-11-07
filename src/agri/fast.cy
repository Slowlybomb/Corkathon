mut D = require("data.cy")
mut M = require("model.cy")
mut NT = require("net.cy")
mut U = require("../../lib/geo/utm.cy")

pub NO = u32(31)
pub MARGIN = u32(24)

pub fn k_base(refl: f32[], x: f32[], norm: f32[], pq: f32[], sd: f32, cd: f32, P: u32)
    total = u32(21) * P
    gpu do
        mut e = u32(0)
        while e < total do
            k = e / P
            p = e % P
            mut v = f32(0.0)
            if k < u32(10) then
                v = (refl[k * P + p] - norm[k]) / norm[u32(10) + k]
            end
            b2 = refl[p]
            b3 = refl[P + p]
            b4 = refl[u32(2) * P + p]
            b8 = refl[u32(3) * P + p]
            b5 = refl[u32(4) * P + p]
            b8a = refl[u32(7) * P + p]
            b11 = refl[u32(8) * P + p]
            if k == u32(10) then
                v = (b8 - b4) / (b8 + b4 + f32(0.000001))
            end
            if k == u32(11) then
                v = (b8a - b11) / (b8a + b11 + f32(0.000001))
            end
            if k == u32(12) then
                v = (b3 - b8) / (b3 + b8 + f32(0.000001))
            end
            if k == u32(13) then
                v = (b8a - b5) / (b8a + b5 + f32(0.000001))
            end
            if k == u32(14) then
                v = ((b11 + b4) - (b8 + b2)) / ((b11 + b4) + (b8 + b2) + f32(0.000001))
            end
            if k >= u32(15) and k < u32(19) then
                mut s = f32(0.0)
                mut mine = f32(0.0)
                mut i = u32(0)
                while i < u32(4) do
                    mut a = pq[u32(40) + i]
                    mut b = u32(0)
                    while b < u32(10) do
                        a = a + pq[i * u32(10) + b] * refl[b * P + p]
                        b = b + u32(1)
                    end
                    a = max(a, f32(0.0))
                    s = s + a
                    if i == k - u32(15) then
                        mine = a
                    end
                    i = i + u32(1)
                end
                if s > f32(0.0) then
                    v = mine / s
                else
                    v = f32(u32(k == u32(15)))
                end
            end
            if k == u32(19) then
                v = sd
            end
            if k == u32(20) then
                v = cd
            end
            x[e] = v
            e = e + u32(1)
        end
    end
end

pub fn k_boxh(src: f32[], dst: f32[], C: u32, S: u32, r: u32)
    total = C * S * S
    gpu do
        mut e = u32(0)
        while e < total do
            j = e % S
            row = e - j
            j0 = u32(max(i32(0), i32(j) - i32(r)))
            j1 = min(S - u32(1), j + r)
            mut acc = f32(0.0)
            mut jj = j0
            while jj <= j1 do
                acc = acc + src[row + jj]
                jj = jj + u32(1)
            end
            dst[e] = acc / f32(j1 - j0 + u32(1))
            e = e + u32(1)
        end
    end
end

pub fn k_boxv(src: f32[], dst: f32[], C: u32, S: u32, r: u32)
    total = C * S * S
    gpu do
        mut e = u32(0)
        while e < total do
            j = e % S
            i = (e / S) % S
            base = e - i * S
            i0 = u32(max(i32(0), i32(i) - i32(r)))
            i1 = min(S - u32(1), i + r)
            mut acc = f32(0.0)
            mut ii = i0
            while ii <= i1 do
                acc = acc + src[base + ii * S]
                ii = ii + u32(1)
            end
            dst[e] = acc / f32(i1 - i0 + u32(1))
            e = e + u32(1)
        end
    end
end

pub fn k_neur(x: f32[], bx: f32[], laws: u32[], coefs: f32[], nr: f32[], P: u32)
    total = u32(58) * P
    gpu do
        mut e = u32(0)
        while e < total do
            jn = e / P
            p = e % P
            t = jn / u32(2)
            mut v = f32(0.0)
            mut layer = u32(0)
            while layer <= jn % u32(2) do
                o = (t * u32(2) + layer) * u32(4)
                kk = laws[o]
                v = v + coefs[o]
                mut i = u32(0)
                while i < kk do
                    g = laws[o + u32(1) + i]
                    mut term = f32(1.0)
                    if g >= u32(1) and g <= u32(21) then
                        term = x[(g - u32(1)) * P + p]
                    end
                    if g >= u32(22) and g <= u32(42) then
                        term = bx[(g - u32(22)) * P + p]
                    end
                    if g >= u32(43) then
                        term = x[u32(15) * P + p] * x[(g - u32(43)) * P + p]
                    end
                    v = v + coefs[o + u32(1) + i] * term
                    i = i + u32(1)
                end
                layer = layer + u32(1)
            end
            nr[e] = v
            e = e + u32(1)
        end
    end
end

pub fn k_sobel(x: f32[], mag: f32[], S: u32)
    P = S * S
    total = u32(4) * P
    gpu do
        mut e = u32(0)
        while e < total do
            q = e / P
            p = e % P
            mut ch = u32(10)
            if q == u32(1) then
                ch = u32(11)
            end
            if q == u32(2) then
                ch = u32(3)
            end
            if q == u32(3) then
                ch = u32(8)
            end
            i = p / S
            j = p % S
            im = u32(max(i32(0), i32(i) - i32(1)))
            ip = min(S - u32(1), i + u32(1))
            jm = u32(max(i32(0), i32(j) - i32(1)))
            jp = min(S - u32(1), j + u32(1))
            o = ch * P
            gx = x[o + im * S + jp] + f32(2.0) * x[o + i * S + jp] + x[o + ip * S + jp] - x[o + im * S + jm] - f32(2.0) * x[o + i * S + jm] - x[o + ip * S + jm]
            gy = x[o + ip * S + jm] + f32(2.0) * x[o + ip * S + j] + x[o + ip * S + jp] - x[o + im * S + jm] - f32(2.0) * x[o + im * S + j] - x[o + im * S + jp]
            mag[e] = sqrt(gx * gx + gy * gy)
            e = e + u32(1)
        end
    end
end

pub fn k_max3(mag: f32[], mx: f32[], S: u32)
    P = S * S
    total = u32(4) * P
    gpu do
        mut e = u32(0)
        while e < total do
            q = e / P
            p = e % P
            i = p / S
            j = p % S
            mut m = f32(0.0)
            mut a = u32(max(i32(0), i32(i) - i32(1)))
            while a <= min(S - u32(1), i + u32(1)) do
                mut b = u32(max(i32(0), i32(j) - i32(1)))
                while b <= min(S - u32(1), j + u32(1)) do
                    m = max(m, mag[q * P + a * S + b])
                    b = b + u32(1)
                end
                a = a + u32(1)
            end
            mx[e] = m
            e = e + u32(1)
        end
    end
end

pub fn k_copy(src: f32[], dst: f32[], doff: u32, count: u32)
    gpu do
        mut e = u32(0)
        while e < count do
            dst[doff + e] = src[e]
            e = e + u32(1)
        end
    end
end

pub fn k_fill(dst: f32[], count: u32, v: f32)
    gpu do
        mut e = u32(0)
        while e < count do
            dst[e] = v
            e = e + u32(1)
        end
    end
end

pub fn k_heads(phi: f32[], B: f32[], sc: f32[], Dn: u32, Mo: u32, P: u32)
    total = Mo * P
    gpu do
        mut e = u32(0)
        while e < total do
            o = e / P
            p = e % P
            mut acc = f32(0.0)
            mut c = u32(0)
            while c < Dn do
                acc = acc + phi[c * P + p] * B[c * Mo + o]
                c = c + u32(1)
            end
            sc[e] = acc
            e = e + u32(1)
        end
    end
end

pub fn k_final(sc: f32[], out: f32[], ymu: f32[], ysd: f32[], nw: u32, P: u32)
    total = NO * P
    gpu do
        mut e = u32(0)
        while e < total do
            c = e / P
            p = e % P
            mut v = sc[p]
            if c == u32(1) then
                mut best = sc[P + p]
                mut bk = u32(0)
                mut k = u32(1)
                while k < u32(18) do
                    s = sc[(u32(1) + k) * P + p]
                    if s > best then
                        best = s
                        bk = k
                    end
                    k = k + u32(1)
                end
                v = f32(bk)
            end
            if c == u32(2) then
                mut best = sc[u32(43) * P + p]
                mut bk = u32(0)
                mut k = u32(1)
                while k < nw do
                    s = sc[(u32(43) + k) * P + p]
                    if s > best then
                        best = s
                        bk = k
                    end
                    k = k + u32(1)
                end
                v = f32(bk)
            end
            if c >= u32(3) and c < u32(27) then
                t = c - u32(3)
                v = M.clamp_soil(t, sc[(u32(19) + t) * P + p] * ysd[u32(1) + t] + ymu[u32(1) + t])
            end
            if c >= u32(27) then
                k = c - u32(27)
                v = M.clamp_weather(k, sc[(u32(43) + nw + k) * P + p] * ysd[u32(25) + k] + ymu[u32(25) + k])
            end
            out[e] = v
            e = e + u32(1)
        end
    end
end

pub fn k_maps(out: f32[], maps: f32[], ymu: f32[], ysd: f32[], P: u32)
    total = u32(9) * P
    gpu do
        mut e = u32(0)
        while e < total do
            k = e / P
            p = e % P
            mut v = out[p]
            if k >= u32(1) and k <= u32(4) then
                t = (k - u32(1)) * u32(6)
                v = (out[(u32(3) + t) * P + p] - ymu[u32(1) + t]) / ysd[u32(1) + t]
            end
            if k >= u32(5) then
                w = k - u32(5)
                v = (out[(u32(27) + w) * P + p] - ymu[u32(25) + w]) / ysd[u32(25) + w]
            end
            maps[e] = v
            e = e + u32(1)
        end
    end
end

pub fn combine(bp: f32[], bs: f32[], bw: f32[], df: u32, nw: u32) -> f32[]
    msoil = D.NSOIL + nw
    mo = u32(19) + msoil + D.NWX
    mut b = array[f32](df * mo)
    mut c = u32(0)
    while c < df do
        mut o = u32(0)
        while o < u32(19) do
            b[c * mo + o] = bp[c * u32(19) + o]
            o = o + u32(1)
        end
        o = u32(0)
        while o < msoil do
            b[c * mo + u32(19) + o] = bs[c * msoil + o]
            o = o + u32(1)
        end
        o = u32(0)
        while o < D.NWX do
            b[c * mo + u32(19) + msoil + o] = bw[c * D.NWX + o]
            o = o + u32(1)
        end
        c = c + u32(1)
    end
    return b
end

pub fn run_chunk(refl: f32[], S: u32, doy: u32, df: u32, nw: u32, s2on: u32,
                 norm: f32[], pq: f32[], p: f32[], laws: u32[], coefs: f32[], b1: f32[], b2: f32[], p2: f32[], ymu: f32[], ysd: f32[],
                 x: f32[], bx: f32[], cx: f32[], tmp: f32[], f1: f32[], f2: f32[], f3: f32[], f4: f32[], nr: f32[], mag: f32[], mx: f32[],
                 phi: f32[], sc: f32[], out: f32[], maps: f32[], g1: f32[], g2: f32[], mc: f32[], psi: f32[])
    P = S * S
    mo = u32(19) + D.NSOIL + nw + D.NWX
    ang = 2.0 * U.PI * f64(doy) / 365.25
    k_base(refl, x, norm, pq, f32(U.sin64(ang)), f32(U.cos64(ang)), P)
    k_boxh(x, tmp, u32(21), S, u32(3))
    k_boxv(tmp, bx, u32(21), S, u32(3))
    k_boxh(x, tmp, u32(21), S, MARGIN)
    k_boxv(tmp, cx, u32(21), S, MARGIN)
    o1 = M.NFEAT * D.NBASE * u32(9)
    o2 = o1 + M.NFEAT
    o3 = o2 + M.NFEAT * M.NFEAT * u32(9)
    o4 = o3 + M.NFEAT
    o5 = o4 + M.NFEAT * M.NFEAT * u32(9)
    o6 = o5 + M.NFEAT
    o7 = o6 + M.NFEAT * M.NFEAT * u32(9)
    NT.conv_fwd(x, p, f1, u32(1), D.NBASE, M.NFEAT, S, u32(3), u32(1), u32(0), o1, u32(1))
    NT.conv_fwd(f1, p, f2, u32(1), M.NFEAT, M.NFEAT, S, u32(3), u32(2), o2, o3, u32(1))
    NT.conv_fwd(f2, p, f3, u32(1), M.NFEAT, M.NFEAT, S, u32(3), u32(4), o4, o5, u32(1))
    NT.conv_fwd(f3, p, f4, u32(1), M.NFEAT, M.NFEAT, S, u32(3), u32(8), o6, o7, u32(1))
    k_neur(x, bx, laws, coefs, nr, P)
    k_fill(phi, P, f32(1.0))
    k_copy(x, phi, P, u32(21) * P)
    k_copy(f1, phi, u32(22) * P, u32(48) * P)
    k_copy(f2, phi, u32(70) * P, u32(48) * P)
    k_copy(f3, phi, u32(118) * P, u32(48) * P)
    k_copy(f4, phi, u32(166) * P, u32(48) * P)
    k_copy(cx, phi, u32(214) * P, u32(21) * P)
    k_copy(nr, phi, u32(235) * P, u32(58) * P)
    if df >= u32(301) then
        k_sobel(x, mag, S)
        k_max3(mag, mx, S)
        k_copy(mag, phi, u32(293) * P, u32(4) * P)
        k_copy(mx, phi, u32(297) * P, u32(4) * P)
    end
    k_heads(phi, b1, sc, df, mo, P)
    k_final(sc, out, ymu, ysd, nw, P)
    if s2on == u32(1) then
        k_maps(out, maps, ymu, ysd, P)
        n1 = u32(24) * u32(9) * u32(9)
        n2 = u32(24) * u32(24) * u32(9)
        NT.conv_fwd(maps, p2, g1, u32(1), u32(9), u32(24), S, u32(3), u32(2), u32(0), n1, u32(1))
        NT.conv_fwd(g1, p2, g2, u32(1), u32(24), u32(24), S, u32(3), u32(4), n1 + u32(24), n1 + u32(24) + n2, u32(1))
        k_boxh(maps, tmp, u32(9), S, MARGIN)
        k_boxv(tmp, mc, u32(9), S, MARGIN)
        k_copy(phi, psi, u32(0), df * P)
        k_copy(maps, psi, df * P, u32(9) * P)
        k_copy(g1, psi, (df + u32(9)) * P, u32(24) * P)
        k_copy(g2, psi, (df + u32(33)) * P, u32(24) * P)
        k_copy(mc, psi, (df + u32(57)) * P, u32(9) * P)
        k_heads(psi, b2, sc, df + u32(66), mo, P)
        k_final(sc, out, ymu, ysd, nw, P)
    end
end
