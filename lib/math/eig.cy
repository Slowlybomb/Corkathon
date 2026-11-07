pub fn eigvals(a: f64[], d: u32, ev: f64[])
    mut dg = array[f64](d)
    mut e = array[f64](d)
    mut v = array[f64](d)
    mut p = array[f64](d)
    mut i = d - u32(1)
    while i >= u32(2) do
        l = i - u32(1)
        mut nrm = 0.0
        mut k = u32(0)
        while k <= l do
            v[k] = a[i * d + k]
            nrm = nrm + v[k] * v[k]
            k = k + u32(1)
        end
        nrm = sqrt(nrm)
        mut alpha = 0.0 - nrm
        if v[l] < 0.0 then
            alpha = nrm
        end
        if nrm == 0.0 then
            e[i] = 0.0
        else
            v[l] = v[l] - alpha
            mut vv = 0.0
            k = u32(0)
            while k <= l do
                vv = vv + v[k] * v[k]
                k = k + u32(1)
            end
            if vv == 0.0 then
                e[i] = a[i * d + l]
            else
                tau = 2.0 / vv
                mut j = u32(0)
                while j <= l do
                    mut s ~ 1e-14 = 0.0
                    k = u32(0)
                    while k <= l do
                        s = s + a[j * d + k] * v[k]
                        k = k + u32(1)
                    end
                    p[j] = tau * s
                    j = j + u32(1)
                end
                mut vp = 0.0
                k = u32(0)
                while k <= l do
                    vp = vp + v[k] * p[k]
                    k = k + u32(1)
                end
                kk = 0.5 * tau * vp
                k = u32(0)
                while k <= l do
                    p[k] = p[k] - kk * v[k]
                    k = k + u32(1)
                end
                j = u32(0)
                while j <= l do
                    vj = v[j]
                    pj = p[j]
                    k = u32(0)
                    while k <= l do
                        a[j * d + k] = a[j * d + k] - vj * p[k] - pj * v[k]
                        k = k + u32(1)
                    end
                    j = j + u32(1)
                end
                e[i] = alpha
            end
        end
        dg[i] = a[i * d + i]
        i = i - u32(1)
    end
    if d >= u32(2) then
        dg[1] = a[d + u32(1)]
        e[1] = a[d]
    end
    dg[0] = a[0]
    e[0] = 0.0
    tqli(dg, e, d)
    sort(dg, d)
    i = u32(0)
    while i < d do
        ev[i] = dg[i]
        i = i + u32(1)
    end
end

fn pyth(a: f64, b: f64) -> f64
    aa = abs(a)
    ab = abs(b)
    if aa > ab then
        r = ab / aa
        return aa * sqrt(1.0 + r * r)
    end
    if ab == 0.0 then
        return 0.0
    end
    r = aa / ab
    return ab * sqrt(1.0 + r * r)
end

fn sgn(a: f64, b: f64) -> f64
    if b >= 0.0 then
        return abs(a)
    end
    return 0.0 - abs(a)
end

fn tqli(dg: f64[], e: f64[], n: u32)
    mut i = u32(1)
    while i < n do
        e[i - u32(1)] = e[i]
        i = i + u32(1)
    end
    e[n - u32(1)] = 0.0
    mut l = u32(0)
    while l < n do
        mut iter = u32(0)
        mut done = false
        while not done do
            mut m = l
            mut found = false
            while m + u32(1) < n and not found do
                dd = abs(dg[m]) + abs(dg[m + u32(1)])
                if abs(e[m]) <= 1e-16 * dd then
                    found = true
                else
                    m = m + u32(1)
                end
            end
            if m == l or iter > u32(60) then
                done = true
            else
                iter = iter + u32(1)
                mut g = (dg[l + u32(1)] - dg[l]) / (2.0 * e[l])
                mut r = pyth(g, 1.0)
                g = dg[m] - dg[l] + e[l] / (g + sgn(r, g))
                mut s = 1.0
                mut c = 1.0
                mut p = 0.0
                mut ii = m
                mut under = false
                while ii > l and not under do
                    i2 = ii - u32(1)
                    f = s * e[i2]
                    b = c * e[i2]
                    r = pyth(f, g)
                    e[i2 + u32(1)] = r
                    if r == 0.0 then
                        dg[i2 + u32(1)] = dg[i2 + u32(1)] - p
                        e[m] = 0.0
                        under = true
                    else
                        s = f / r
                        c = g / r
                        g = dg[i2 + u32(1)] - p
                        r = (dg[i2] - g) * s + 2.0 * c * b
                        p = s * r
                        dg[i2 + u32(1)] = g + p
                        g = c * r - b
                        ii = ii - u32(1)
                    end
                end
                if not under then
                    dg[l] = dg[l] - p
                    e[l] = g
                    e[m] = 0.0
                end
            end
        end
        l = l + u32(1)
    end
end

pub fn sort(x: f64[], n: u32)
    mut gap = u32(1)
    while gap < n / u32(3) do
        gap = gap * u32(3) + u32(1)
    end
    while gap > u32(0) do
        mut i = gap
        while i < n do
            t = x[i]
            mut j = i
            while j >= gap and x[j - gap] > t do
                x[j] = x[j - gap]
                j = j - gap
            end
            x[j] = t
            i = i + u32(1)
        end
        gap = gap / u32(3)
    end
end

pub fn eigsym1(a: f64[], d: u32, ev: f64[], zt: f64[])
    mut e = array[f64](d)
    mut pv = array[f64](d)
    mut i = d - u32(1)
    while i >= u32(1) do
        l = i - u32(1)
        mut h = 0.0
        if l > u32(0) then
            mut scale = 0.0
            mut k = u32(0)
            while k <= l do
                scale = scale + abs(a[i * d + k])
                k = k + u32(1)
            end
            if scale == 0.0 then
                e[i] = a[i * d + l]
            else
                k = u32(0)
                while k <= l do
                    a[i * d + k] = a[i * d + k] / scale
                    h = h + a[i * d + k] * a[i * d + k]
                    k = k + u32(1)
                end
                mut f = a[i * d + l]
                mut g = sqrt(h)
                if f >= 0.0 then
                    g = 0.0 - g
                end
                e[i] = scale * g
                h = h - f * g
                a[i * d + l] = f - g
                f = 0.0
                mut j = u32(0)
                while j <= l do
                    a[j * d + i] = a[i * d + j] / h
                    pv[j] = 0.0
                    j = j + u32(1)
                end
                j = u32(0)
                while j <= l do
                    uj = a[i * d + j]
                    mut g2 = 0.0
                    mut k2 = u32(0)
                    while k2 < j do
                        ajk = a[j * d + k2]
                        g2 = g2 + ajk * a[i * d + k2]
                        pv[k2] = pv[k2] + ajk * uj
                        k2 = k2 + u32(1)
                    end
                    pv[j] = pv[j] + g2 + a[j * d + j] * uj
                    j = j + u32(1)
                end
                j = u32(0)
                while j <= l do
                    e[j] = pv[j] / h
                    f = f + e[j] * a[i * d + j]
                    j = j + u32(1)
                end
                hh = f / (h + h)
                j = u32(0)
                while j <= l do
                    f2 = a[i * d + j]
                    g3 = e[j] - hh * f2
                    e[j] = g3
                    mut k3 = u32(0)
                    while k3 <= j do
                        a[j * d + k3] = a[j * d + k3] - (f2 * e[k3] + g3 * a[i * d + k3])
                        k3 = k3 + u32(1)
                    end
                    j = j + u32(1)
                end
            end
        else
            e[i] = a[i * d + l]
        end
        ev[i] = h
        i = i - u32(1)
    end
    ev[0] = 0.0
    e[0] = 0.0
    i = u32(0)
    while i < d do
        if ev[i] != 0.0 and i > u32(0) then
            mut j = u32(0)
            while j < i do
                pv[j] = 0.0
                j = j + u32(1)
            end
            mut k = u32(0)
            while k < i do
                aik = a[i * d + k]
                j = u32(0)
                while j < i do
                    pv[j] = pv[j] + aik * a[k * d + j]
                    j = j + u32(1)
                end
                k = k + u32(1)
            end
            k = u32(0)
            while k < i do
                aki = a[k * d + i]
                j = u32(0)
                while j < i do
                    a[k * d + j] = a[k * d + j] - pv[j] * aki
                    j = j + u32(1)
                end
                k = k + u32(1)
            end
        end
        ev[i] = a[i * d + i]
        a[i * d + i] = 1.0
        mut j2 = u32(0)
        while j2 < i do
            a[j2 * d + i] = 0.0
            a[i * d + j2] = 0.0
            j2 = j2 + u32(1)
        end
        i = i + u32(1)
    end
    i = u32(0)
    while i < d do
        mut j = u32(0)
        while j < d do
            zt[j * d + i] = a[i * d + j]
            j = j + u32(1)
        end
        i = i + u32(1)
    end
    i = u32(1)
    while i < d do
        e[i - u32(1)] = e[i]
        i = i + u32(1)
    end
    e[d - u32(1)] = 0.0
    mut l = u32(0)
    while l < d do
        mut iter = u32(0)
        mut more = true
        while more do
            mut m = l
            mut found = false
            while m + u32(1) < d and not found do
                dd = abs(ev[m]) + abs(ev[m + u32(1)])
                if abs(e[m]) <= 1e-15 * dd then
                    found = true
                else
                    m = m + u32(1)
                end
            end
            if m == l then
                more = false
            else
                iter = iter + u32(1)
                mut g = (ev[l + u32(1)] - ev[l]) / (2.0 * e[l])
                mut r = sqrt(g * g + 1.0)
                mut sr = r
                if g < 0.0 then
                    sr = 0.0 - r
                end
                g = ev[m] - ev[l] + e[l] / (g + sr)
                mut s = 1.0
                mut c = 1.0
                mut p = 0.0
                mut ii = m
                mut broke = false
                while ii > l and not broke do
                    i2 = ii - u32(1)
                    f = s * e[i2]
                    b = c * e[i2]
                    r = sqrt(f * f + g * g)
                    e[i2 + u32(1)] = r
                    if r == 0.0 then
                        ev[i2 + u32(1)] = ev[i2 + u32(1)] - p
                        e[m] = 0.0
                        broke = true
                    else
                        s = f / r
                        c = g / r
                        g = ev[i2 + u32(1)] - p
                        r = (ev[i2] - g) * s + 2.0 * c * b
                        p = s * r
                        ev[i2 + u32(1)] = g + p
                        g = c * r - b
                        mut k = u32(0)
                        while k < d do
                            fz = zt[(i2 + u32(1)) * d + k]
                            zt[(i2 + u32(1)) * d + k] = s * zt[i2 * d + k] + c * fz
                            zt[i2 * d + k] = c * zt[i2 * d + k] - s * fz
                            k = k + u32(1)
                        end
                        ii = ii - u32(1)
                    end
                end
                if not broke then
                    ev[l] = ev[l] - p
                    e[l] = g
                    e[m] = 0.0
                end
                if iter > u32(60) then
                    more = false
                end
            end
        end
        l = l + u32(1)
    end
end

pub fn eigsym(a: f64[], d: u32, ev: f64[], zt: f64[])
    if d <= u32(2048) then
        eigsym3(a, d, ev, zt)
    else
        eigsym1(a, d, ev, zt)
    end
end

fn rotblocks(nblk: u32, nr: u32, ri: u32[], rsn: f64[], rcs: f64[], w: f64[])
    mut kb = u32(0)
    while kb < nblk do
        mut r = u32(0)
        while r < nr do
            o1 = ri[r] * u32(8)
            sv = simd[f64, 4](rsn[r])
            cv = simd[f64, 4](rcs[r])
            a0 = simd[f64, 4](w, kb * u32(16384) + (o1 & u32(16380)))
            a1 = simd[f64, 4](w, kb * u32(16384) + ((o1 + u32(4)) & u32(16380)))
            b0 = simd[f64, 4](w, kb * u32(16384) + ((o1 + u32(8)) & u32(16380)))
            b1 = simd[f64, 4](w, kb * u32(16384) + ((o1 + u32(12)) & u32(16380)))
            store(w, kb * u32(16384) + ((o1 + u32(8)) & u32(16380)), sv * a0 + cv * b0)
            store(w, kb * u32(16384) + ((o1 + u32(12)) & u32(16380)), sv * a1 + cv * b1)
            store(w, kb * u32(16384) + (o1 & u32(16380)), cv * a0 - sv * b0)
            store(w, kb * u32(16384) + ((o1 + u32(4)) & u32(16380)), cv * a1 - sv * b1)
            r = r + u32(1)
        end
        kb = kb + u32(1)
    end
end

pub fn eigsym2(a: f64[], d: u32, ev: f64[], zt: f64[])
    mut e = array[f64](d)
    mut pv = array[f64](d)
    mut i = d - u32(1)
    while i >= u32(1) do
        l = i - u32(1)
        mut h = 0.0
        if l > u32(0) then
            mut scale = 0.0
            mut k = u32(0)
            while k <= l do
                scale = scale + abs(a[i * d + k])
                k = k + u32(1)
            end
            if scale == 0.0 then
                e[i] = a[i * d + l]
            else
                k = u32(0)
                while k <= l do
                    a[i * d + k] = a[i * d + k] / scale
                    h = h + a[i * d + k] * a[i * d + k]
                    k = k + u32(1)
                end
                mut f = a[i * d + l]
                mut g = sqrt(h)
                if f >= 0.0 then
                    g = 0.0 - g
                end
                e[i] = scale * g
                h = h - f * g
                a[i * d + l] = f - g
                f = 0.0
                mut j = u32(0)
                while j <= l do
                    a[j * d + i] = a[i * d + j] / h
                    pv[j] = 0.0
                    j = j + u32(1)
                end
                j = u32(0)
                while j <= l do
                    uj = a[i * d + j]
                    mut g2 = 0.0
                    mut k2 = u32(0)
                    while k2 < j do
                        ajk = a[j * d + k2]
                        g2 = g2 + ajk * a[i * d + k2]
                        pv[k2] = pv[k2] + ajk * uj
                        k2 = k2 + u32(1)
                    end
                    pv[j] = pv[j] + g2 + a[j * d + j] * uj
                    j = j + u32(1)
                end
                j = u32(0)
                while j <= l do
                    e[j] = pv[j] / h
                    f = f + e[j] * a[i * d + j]
                    j = j + u32(1)
                end
                hh = f / (h + h)
                j = u32(0)
                while j <= l do
                    f2 = a[i * d + j]
                    g3 = e[j] - hh * f2
                    e[j] = g3
                    mut k3 = u32(0)
                    while k3 <= j do
                        a[j * d + k3] = a[j * d + k3] - (f2 * e[k3] + g3 * a[i * d + k3])
                        k3 = k3 + u32(1)
                    end
                    j = j + u32(1)
                end
            end
        else
            e[i] = a[i * d + l]
        end
        ev[i] = h
        i = i - u32(1)
    end
    ev[0] = 0.0
    e[0] = 0.0
    i = u32(0)
    while i < d do
        if ev[i] != 0.0 and i > u32(0) then
            mut j = u32(0)
            while j < i do
                pv[j] = 0.0
                j = j + u32(1)
            end
            mut k = u32(0)
            while k < i do
                aik = a[i * d + k]
                j = u32(0)
                while j < i do
                    pv[j] = pv[j] + aik * a[k * d + j]
                    j = j + u32(1)
                end
                k = k + u32(1)
            end
            k = u32(0)
            while k < i do
                aki = a[k * d + i]
                j = u32(0)
                while j < i do
                    a[k * d + j] = a[k * d + j] - pv[j] * aki
                    j = j + u32(1)
                end
                k = k + u32(1)
            end
        end
        ev[i] = a[i * d + i]
        a[i * d + i] = 1.0
        mut j2 = u32(0)
        while j2 < i do
            a[j2 * d + i] = 0.0
            a[i * d + j2] = 0.0
            j2 = j2 + u32(1)
        end
        i = i + u32(1)
    end
    i = u32(0)
    while i < d do
        mut j = u32(0)
        while j < d do
            zt[j * d + i] = a[i * d + j]
            j = j + u32(1)
        end
        i = i + u32(1)
    end
    mut ri = array[u32](0)
    mut rsn = array[f64](0)
    mut rcs = array[f64](0)
    i = u32(1)
    while i < d do
        e[i - u32(1)] = e[i]
        i = i + u32(1)
    end
    e[d - u32(1)] = 0.0
    mut l = u32(0)
    while l < d do
        mut iter = u32(0)
        mut more = true
        while more do
            mut m = l
            mut found = false
            while m + u32(1) < d and not found do
                dd = abs(ev[m]) + abs(ev[m + u32(1)])
                if abs(e[m]) <= 1e-15 * dd then
                    found = true
                else
                    m = m + u32(1)
                end
            end
            if m == l then
                more = false
            else
                iter = iter + u32(1)
                mut g = (ev[l + u32(1)] - ev[l]) / (2.0 * e[l])
                mut r = sqrt(g * g + 1.0)
                mut sr = r
                if g < 0.0 then
                    sr = 0.0 - r
                end
                g = ev[m] - ev[l] + e[l] / (g + sr)
                mut s = 1.0
                mut c = 1.0
                mut p = 0.0
                mut ii = m
                mut broke = false
                while ii > l and not broke do
                    i2 = ii - u32(1)
                    f = s * e[i2]
                    b = c * e[i2]
                    r = sqrt(f * f + g * g)
                    e[i2 + u32(1)] = r
                    if r == 0.0 then
                        ev[i2 + u32(1)] = ev[i2 + u32(1)] - p
                        e[m] = 0.0
                        broke = true
                    else
                        s = f / r
                        c = g / r
                        g = ev[i2 + u32(1)] - p
                        r = (ev[i2] - g) * s + 2.0 * c * b
                        p = s * r
                        ev[i2 + u32(1)] = g + p
                        g = c * r - b
                        push(ri, i2)
                        push(rsn, s)
                        push(rcs, c)
                        ii = ii - u32(1)
                    end
                end
                if not broke then
                    ev[l] = ev[l] - p
                    e[l] = g
                    e[m] = 0.0
                end
                if iter > u32(60) then
                    more = false
                end
            end
        end
        l = l + u32(1)
    end
    nr = len(ri)
    nblk = (d + u32(7)) / u32(8)
    mut w = array[f64](nblk * u32(16384))
    mut ib = u32(0)
    while ib < d do
        mut k = u32(0)
        while k < d do
            w[(k / u32(8)) * u32(16384) + ib * u32(8) + k % u32(8)] = zt[ib * d + k]
            k = k + u32(1)
        end
        ib = ib + u32(1)
    end
    rotblocks(nblk, nr, ri, rsn, rcs, w)
    ib = u32(0)
    while ib < d do
        mut k = u32(0)
        while k < d do
            zt[ib * d + k] = w[(k / u32(8)) * u32(16384) + ib * u32(8) + k % u32(8)]
            k = k + u32(1)
        end
        ib = ib + u32(1)
    end
end

fn hmatvec(n: u32, b: f64[], i: u32, h: f64, pv: f64[])
    mut j = u32(0)
    while j < n do
        mut s ~ 1e-15 = 0.0
        mut k = u32(0)
        while k < n do
            s = s + b[j * u32(2048) + k] * b[i * u32(2048) + k]
            k = k + u32(1)
        end
        pv[j] = s / h
        j = j + u32(1)
    end
end

fn hrank2(n: u32, b: f64[], uv: f64[], e: f64[])
    mut j = u32(0)
    while j < n do
        uj = uv[j]
        qj = e[j]
        mut k = u32(0)
        while k < n do
            b[j * u32(2048) + (k & u32(2047))] = b[j * u32(2048) + (k & u32(2047))] - (uj * e[k] + qj * uv[k])
            k = k + u32(1)
        end
        j = j + u32(1)
    end
end

fn hqacc(nbk: u32, i: u32, b: f64[], pv: f64[])
    mut jb = u32(0)
    while jb < nbk do
        mut x = u32(0)
        while x < u32(64) do
            pv[jb * u32(64) + (x & u32(63))] = 0.0
            x = x + u32(1)
        end
        mut k = u32(0)
        while k < i do
            bik = b[i * u32(2048) + k]
            x = u32(0)
            while x < u32(64) do
                pv[jb * u32(64) + (x & u32(63))] = pv[jb * u32(64) + (x & u32(63))] + bik * b[k * u32(2048) + jb * u32(64) + x]
                x = x + u32(1)
            end
            k = k + u32(1)
        end
        jb = jb + u32(1)
    end
end

fn hqupd(i: u32, b: f64[], pv: f64[], cv: f64[])
    mut k = u32(0)
    while k < i do
        bki = cv[k]
        mut j = u32(0)
        while j < i do
            b[k * u32(2048) + (j & u32(2047))] = b[k * u32(2048) + (j & u32(2047))] - pv[j] * bki
            j = j + u32(1)
        end
        k = k + u32(1)
    end
end

pub fn eigsym3(a: f64[], d: u32, ev: f64[], zt: f64[])
    mut e = array[f64](d)
    mut pv = array[f64](u32(2048))
    mut uv = array[f64](u32(2048))
    mut hb = array[f64](d * u32(2048))
    mut i = u32(0)
    while i < d do
        mut j = u32(0)
        while j < d do
            hb[i * u32(2048) + j] = a[i * d + j]
            j = j + u32(1)
        end
        i = i + u32(1)
    end
    i = d - u32(1)
    while i >= u32(1) do
        l = i - u32(1)
        mut h = 0.0
        if l > u32(0) then
            mut scale = 0.0
            mut k = u32(0)
            while k <= l do
                scale = scale + abs(hb[i * u32(2048) + k])
                k = k + u32(1)
            end
            if scale == 0.0 then
                e[i] = hb[i * u32(2048) + l]
            else
                k = u32(0)
                while k <= l do
                    hb[i * u32(2048) + k] = hb[i * u32(2048) + k] / scale
                    h = h + hb[i * u32(2048) + k] * hb[i * u32(2048) + k]
                    k = k + u32(1)
                end
                mut f = hb[i * u32(2048) + l]
                mut g = sqrt(h)
                if f >= 0.0 then
                    g = 0.0 - g
                end
                e[i] = scale * g
                h = h - f * g
                hb[i * u32(2048) + l] = f - g
                hmatvec(l + u32(1), hb, i, h, pv)
                f = 0.0
                mut j = u32(0)
                while j <= l do
                    hb[j * u32(2048) + i] = hb[i * u32(2048) + j] / h
                    e[j] = pv[j]
                    f = f + e[j] * hb[i * u32(2048) + j]
                    j = j + u32(1)
                end
                hh = f / (h + h)
                j = u32(0)
                while j <= l do
                    e[j] = e[j] - hh * hb[i * u32(2048) + j]
                    j = j + u32(1)
                end
                j = u32(0)
                while j <= l do
                    uv[j] = hb[i * u32(2048) + j]
                    j = j + u32(1)
                end
                hrank2(l + u32(1), hb, uv, e)
            end
        else
            e[i] = hb[i * u32(2048) + l]
        end
        ev[i] = h
        i = i - u32(1)
    end
    ev[0] = 0.0
    e[0] = 0.0
    i = u32(0)
    while i < d do
        if ev[i] != 0.0 and i > u32(0) then
            nbk = (i + u32(63)) / u32(64)
            hqacc(nbk, i, hb, pv)
            mut kc = u32(0)
            while kc < i do
                uv[kc] = hb[kc * u32(2048) + i]
                kc = kc + u32(1)
            end
            hqupd(i, hb, pv, uv)
        end
        ev[i] = hb[i * u32(2048) + i]
        hb[i * u32(2048) + i] = 1.0
        mut j2 = u32(0)
        while j2 < i do
            hb[j2 * u32(2048) + i] = 0.0
            hb[i * u32(2048) + j2] = 0.0
            j2 = j2 + u32(1)
        end
        i = i + u32(1)
    end
    i = u32(0)
    while i < d do
        mut j = u32(0)
        while j < d do
            zt[j * d + i] = hb[i * u32(2048) + j]
            j = j + u32(1)
        end
        i = i + u32(1)
    end
    mut ri = array[u32](0)
    mut rsn = array[f64](0)
    mut rcs = array[f64](0)
    i = u32(1)
    while i < d do
        e[i - u32(1)] = e[i]
        i = i + u32(1)
    end
    e[d - u32(1)] = 0.0
    mut l = u32(0)
    while l < d do
        mut iter = u32(0)
        mut more = true
        while more do
            mut m = l
            mut found = false
            while m + u32(1) < d and not found do
                dd = abs(ev[m]) + abs(ev[m + u32(1)])
                if abs(e[m]) <= 1e-15 * dd then
                    found = true
                else
                    m = m + u32(1)
                end
            end
            if m == l then
                more = false
            else
                iter = iter + u32(1)
                mut g = (ev[l + u32(1)] - ev[l]) / (2.0 * e[l])
                mut r = sqrt(g * g + 1.0)
                mut sr = r
                if g < 0.0 then
                    sr = 0.0 - r
                end
                g = ev[m] - ev[l] + e[l] / (g + sr)
                mut s = 1.0
                mut c = 1.0
                mut p = 0.0
                mut ii = m
                mut broke = false
                while ii > l and not broke do
                    i2 = ii - u32(1)
                    f = s * e[i2]
                    b = c * e[i2]
                    r = sqrt(f * f + g * g)
                    e[i2 + u32(1)] = r
                    if r == 0.0 then
                        ev[i2 + u32(1)] = ev[i2 + u32(1)] - p
                        e[m] = 0.0
                        broke = true
                    else
                        s = f / r
                        c = g / r
                        g = ev[i2 + u32(1)] - p
                        r = (ev[i2] - g) * s + 2.0 * c * b
                        p = s * r
                        ev[i2 + u32(1)] = g + p
                        g = c * r - b
                        push(ri, i2)
                        push(rsn, s)
                        push(rcs, c)
                        ii = ii - u32(1)
                    end
                end
                if not broke then
                    ev[l] = ev[l] - p
                    e[l] = g
                    e[m] = 0.0
                end
                if iter > u32(60) then
                    more = false
                end
            end
        end
        l = l + u32(1)
    end
    nr = len(ri)
    nblk = (d + u32(7)) / u32(8)
    mut w = array[f64](nblk * u32(16384))
    mut ib = u32(0)
    while ib < d do
        mut k = u32(0)
        while k < d do
            w[(k / u32(8)) * u32(16384) + ib * u32(8) + k % u32(8)] = zt[ib * d + k]
            k = k + u32(1)
        end
        ib = ib + u32(1)
    end
    rotblocks(nblk, nr, ri, rsn, rcs, w)
    ib = u32(0)
    while ib < d do
        mut k = u32(0)
        while k < d do
            zt[ib * d + k] = w[(k / u32(8)) * u32(16384) + ib * u32(8) + k % u32(8)]
            k = k + u32(1)
        end
        ib = ib + u32(1)
    end
end

pub fn eigtest(d: u32) -> f64
    mut a = array[f64](d * d)
    mut a0 = array[f64](d * d)
    mut i = u32(0)
    while i < d do
        mut j = u32(0)
        while j <= i do
            v = f64((u64(i * u32(7919) + j * u32(104729)) * u64(2654435761)) % u64(10007)) / 10007.0 - 0.5
            a[i * d + j] = v
            a[j * d + i] = v
            j = j + u32(1)
        end
        i = i + u32(1)
    end
    i = u32(0)
    while i < d * d do
        a0[i] = a[i]
        i = i + u32(1)
    end
    mut ev = array[f64](d)
    mut zt = array[f64](d * d)
    eigsym(a, d, ev, zt)
    mut res = 0.0
    mut orth = 0.0
    mut c = u32(0)
    while c < d do
        i = u32(0)
        while i < d do
            mut s = 0.0
            mut k = u32(0)
            while k < d do
                s = s + a0[i * d + k] * zt[c * d + k]
                k = k + u32(1)
            end
            res = max(res, abs(s - ev[c] * zt[c * d + i]))
            i = i + u32(1)
        end
        mut c2 = u32(0)
        while c2 < d do
            mut s2 = 0.0
            mut k2 = u32(0)
            while k2 < d do
                s2 = s2 + zt[c * d + k2] * zt[c2 * d + k2]
                k2 = k2 + u32(1)
            end
            if c == c2 then
                s2 = s2 - 1.0
            end
            orth = max(orth, abs(s2))
            c2 = c2 + u32(1)
        end
        c = c + u32(1)
    end
    return max(res, orth)
end

pub fn eig2test(d: u32, mode: u32) -> f64
    mut a = array[f64](d * d)
    mut i = u32(0)
    while i < d do
        mut j = u32(0)
        while j <= i do
            v = f64((u64(i * u32(7919) + j * u32(104729)) * u64(2654435761)) % u64(10007)) / 10007.0 - 0.5
            a[i * d + j] = v
            a[j * d + i] = v
            j = j + u32(1)
        end
        i = i + u32(1)
    end
    mut a2 = array[f64](d * d)
    i = u32(0)
    while i < d * d do
        a2[i] = a[i]
        i = i + u32(1)
    end
    mut ev = array[f64](d)
    mut zt = array[f64](d * d)
    mut ev2 = array[f64](d)
    mut zt2 = array[f64](d * d)
    if mode != u32(2) then
        eigsym1(a, d, ev, zt)
    end
    if mode != u32(1) then
        eigsym2(a2, d, ev2, zt2)
    end
    if mode != u32(0) then
        return ev[0] + ev2[0]
    end
    mut dv = 0.0
    mut dz = 0.0
    i = u32(0)
    while i < d do
        dv = max(dv, abs(ev[i] - ev2[i]))
        i = i + u32(1)
    end
    i = u32(0)
    while i < d * d do
        dz = max(dz, abs(zt[i] - zt2[i]))
        i = i + u32(1)
    end
    return dv + dz
end

pub fn eig3test(d: u32, mode: u32) -> f64
    mut a = array[f64](d * d)
    mut i = u32(0)
    while i < d do
        mut j = u32(0)
        while j <= i do
            v = f64((u64(i * u32(7919) + j * u32(104729)) * u64(2654435761)) % u64(10007)) / 10007.0 - 0.5
            a[i * d + j] = v
            a[j * d + i] = v
            j = j + u32(1)
        end
        i = i + u32(1)
    end
    mut a0 = array[f64](d * d)
    mut a2 = array[f64](d * d)
    i = u32(0)
    while i < d * d do
        a0[i] = a[i]
        a2[i] = a[i]
        i = i + u32(1)
    end
    mut ev = array[f64](d)
    mut zt = array[f64](d * d)
    mut ev3 = array[f64](d)
    mut zt3 = array[f64](d * d)
    if mode != u32(2) then
        eigsym1(a, d, ev, zt)
    end
    if mode != u32(1) then
        eigsym3(a2, d, ev3, zt3)
    end
    if mode != u32(0) then
        return ev[0] + ev3[0]
    end
    mut s1 = array[f64](d)
    mut s3 = array[f64](d)
    sortcopy(d, ev, s1)
    sortcopy(d, ev3, s3)
    mut dv = 0.0
    i = u32(0)
    while i < d do
        dv = max(dv, abs(s1[i] - s3[i]))
        i = i + u32(1)
    end
    mut res = 0.0
    mut orth = 0.0
    mut c = u32(0)
    while c < d do
        i = u32(0)
        while i < d do
            mut s = 0.0
            mut k = u32(0)
            while k < d do
                s = s + a0[i * d + k] * zt3[c * d + k]
                k = k + u32(1)
            end
            res = max(res, abs(s - ev3[c] * zt3[c * d + i]))
            i = i + u32(1)
        end
        mut c2 = u32(0)
        while c2 < d do
            mut s2 = 0.0
            mut k2 = u32(0)
            while k2 < d do
                s2 = s2 + zt3[c * d + k2] * zt3[c2 * d + k2]
                k2 = k2 + u32(1)
            end
            if c == c2 then
                s2 = s2 - 1.0
            end
            orth = max(orth, abs(s2))
            c2 = c2 + u32(1)
        end
        c = c + u32(1)
    end
    return dv + max(res, orth) * 1000.0
end

fn sortcopy(d: u32, x: f64[], y: f64[])
    mut i = u32(0)
    while i < d do
        v = x[i]
        mut j = i
        while j > u32(0) and y[j - u32(1)] > v do
            y[j] = y[j - u32(1)]
            j = j - u32(1)
        end
        y[j] = v
        i = i + u32(1)
    end
end

pub fn eig13(d: u32) -> f64
    mut a = array[f64](d * d)
    mut i = u32(0)
    while i < d do
        mut j = u32(0)
        while j <= i do
            v = f64((u64(i * u32(7919) + j * u32(104729)) * u64(2654435761)) % u64(10007)) / 10007.0 - 0.5
            a[i * d + j] = v
            a[j * d + i] = v
            j = j + u32(1)
        end
        i = i + u32(1)
    end
    mut a2 = array[f64](d * d)
    i = u32(0)
    while i < d * d do
        a2[i] = a[i]
        i = i + u32(1)
    end
    mut ev = array[f64](d)
    mut zt = array[f64](d * d)
    mut ev3 = array[f64](d)
    mut zt3 = array[f64](d * d)
    eigsym1(a, d, ev, zt)
    eigsym3(a2, d, ev3, zt3)
    mut dm = 0.0
    i = u32(0)
    while i < d do
        dm = max(dm, abs(ev[i] - ev3[i]))
        i = i + u32(1)
    end
    i = u32(0)
    while i < d * d do
        dm = max(dm, abs(zt[i] - zt3[i]))
        i = i + u32(1)
    end
    return dm
end
