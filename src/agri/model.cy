mut CH = require("../../lib/math/chol.cy")
mut D = require("data.cy")

pub NG = u32(58)
pub NFEAT = u32(48)
pub NCONV = u32(4)
pub NLAMBDA = u32(10)

pub fn lambda_at(k: u32) -> f64
    mut v = 0.000001
    mut i = u32(0)
    while i < k do
        v = v * 10.0
        i = i + u32(1)
    end
    return v
end

pub fn gram_add(g: f64[], x: f32[], rows: u32, d: u32, w: f32[])
    cpu do
        mut a = u32(0)
        while a < d do
            mut r = u32(0)
            while r < rows do
                xa = f64(x[r * d + a] * w[r])
                mut b = a
                while b < d do
                    g[a * d + b] = g[a * d + b] + xa * f64(x[r * d + b])
                    b = b + u32(1)
                end
                r = r + u32(1)
            end
            a = a + u32(1)
        end
    end
end

pub fn rhs_add(xy: f64[], yy: f64[], x: f32[], y: f32[], rows: u32, d: u32, m: u32, w: f32[])
    mut r = u32(0)
    while r < rows do
        wr = f64(w[r])
        mut t = u32(0)
        while t < m do
            yv = f64(y[r * m + t]) * wr
            yy[t] = yy[t] + yv * f64(y[r * m + t])
            mut a = u32(0)
            while a < d do
                xy[a * m + t] = xy[a * m + t] + f64(x[r * d + a]) * yv
                a = a + u32(1)
            end
            t = t + u32(1)
        end
        r = r + u32(1)
    end
end

pub fn symmetrize(g: f64[], d: u32)
    mut a = u32(0)
    while a < d do
        mut b = u32(0)
        while b < a do
            g[a * d + b] = g[b * d + a]
            b = b + u32(1)
        end
        a = a + u32(1)
    end
end

pub fn mean_diag(g: f64[], d: u32) -> f64
    mut s = 0.0
    mut a = u32(0)
    while a < d do
        s = s + g[a * d + a]
        a = a + u32(1)
    end
    return s / f64(d)
end

pub fn factor_ridge(g: f64[], d: u32, lam: f64, l: f64[]) -> u32
    mut a = u32(0)
    while a < d * d do
        l[a] = g[a]
        a = a + u32(1)
    end
    a = u32(0)
    while a < d do
        l[a * d + a] = l[a * d + a] + lam
        a = a + u32(1)
    end
    return CH.factor(l, d)
end

pub fn chol_solve(l: f64[], d: u32, b: f64[], m: u32, t: u32, out: f64[])
    mut y = array[f64](d)
    mut i = u32(0)
    while i < d do
        mut s = b[i * m + t]
        mut k = u32(0)
        while k < i do
            s = s - l[i * d + k] * y[k]
            k = k + u32(1)
        end
        y[i] = s / l[i * d + i]
        i = i + u32(1)
    end
    mut ii = d
    while ii > u32(0) do
        i2 = ii - u32(1)
        mut s = y[i2]
        mut k = i2 + u32(1)
        while k < d do
            s = s - l[k * d + i2] * out[k * m + t]
            k = k + u32(1)
        end
        out[i2 * m + t] = s / l[i2 * d + i2]
        ii = ii - u32(1)
    end
end

pub fn quad_inv(l: f64[], d: u32, v: f64[]) -> f64
    mut y = array[f64](d)
    mut q = 0.0
    mut i = u32(0)
    while i < d do
        mut s = v[i]
        mut k = u32(0)
        while k < i do
            s = s - l[i * d + k] * y[k]
            k = k + u32(1)
        end
        y[i] = s / l[i * d + i]
        q = q + y[i] * y[i]
        i = i + u32(1)
    end
    return q
end

pub fn heldout_sse(beta: f64[], m: u32, t: u32, ge: f64[], xye: f64[], yye: f64[], d: u32) -> f64
    mut s = yye[t]
    mut a = u32(0)
    while a < d do
        ba = beta[a * m + t]
        s = s - 2.0 * ba * xye[a * m + t]
        mut gb = 0.0
        mut b = u32(0)
        while b < d do
            gb = gb + ge[a * d + b] * beta[b * m + t]
            b = b + u32(1)
        end
        s = s + ba * gb
        a = a + u32(1)
    end
    return s
end

pub fn residual_cert(g: f64[], d: u32, lam: f64, beta: f64[], xy: f64[], m: u32, t: u32) -> f64
    mut num = 0.0
    mut den = 0.0
    mut a = u32(0)
    while a < d do
        mut s = lam * beta[a * m + t]
        mut b = u32(0)
        while b < d do
            s = s + g[a * d + b] * beta[b * m + t]
            b = b + u32(1)
        end
        r = s - xy[a * m + t]
        num = num + r * r
        den = den + xy[a * m + t] * xy[a * m + t]
        a = a + u32(1)
    end
    return sqrt(num / max(den, 1e-300))
end

pub fn residualize(g: f64[], xy: f64[], yy: f64[], d: u32, m: u32, t: u32, blaw: f64[])
    mut gb = array[f64](d)
    mut a = u32(0)
    while a < d do
        mut s = 0.0
        mut b = u32(0)
        while b < d do
            s = s + g[a * d + b] * blaw[b]
            b = b + u32(1)
        end
        gb[a] = s
        a = a + u32(1)
    end
    mut cross = 0.0
    mut quad = 0.0
    a = u32(0)
    while a < d do
        cross = cross + blaw[a] * xy[a * m + t]
        quad = quad + blaw[a] * gb[a]
        a = a + u32(1)
    end
    a = u32(0)
    while a < d do
        xy[a * m + t] = xy[a * m + t] - gb[a]
        a = a + u32(1)
    end
    yy[t] = yy[t] - 2.0 * cross + quad
end

pub fn solve_heads(g: f64[], xy: f64[], d: u32, m: u32, ge: f64[], xye: f64[], yye: f64[], beta: f64[], lamk: u32[], sse: f64[], cert: f64[]) -> f64
    mut l = array[f64](d * d)
    mut tmp = array[f64](d * m)
    md = mean_diag(g, d)
    mut t = u32(0)
    while t < m do
        sse[t] = 1e300
        t = t + u32(1)
    end
    mut k = u32(0)
    while k < NLAMBDA do
        lam = lambda_at(k) * md
        bad = factor_ridge(g, d, lam, l)
        if bad == u32(0) then
            t = u32(0)
            while t < m do
                chol_solve(l, d, xy, m, t, tmp)
                e = heldout_sse(tmp, m, t, ge, xye, yye, d)
                if e < sse[t] then
                    sse[t] = e
                    lamk[t] = k
                    mut a = u32(0)
                    while a < d do
                        beta[a * m + t] = tmp[a * m + t]
                        a = a + u32(1)
                    end
                end
                t = t + u32(1)
            end
        end
        k = k + u32(1)
    end
    mut worst = 0.0
    t = u32(0)
    while t < m do
        cert[t] = residual_cert(g, d, lambda_at(lamk[t]) * md, beta, xy, m, t)
        worst = max(worst, cert[t])
        t = t + u32(1)
    end
    return worst
end

fn small_solve(a: f64[], b: f64[], n: u32, x: f64[]) -> bool
    mut i = u32(0)
    while i < n do
        mut piv = i
        mut r = i + u32(1)
        while r < n do
            if abs(a[r * n + i]) > abs(a[piv * n + i]) then
                piv = r
            end
            r = r + u32(1)
        end
        if abs(a[piv * n + i]) < 1e-14 then
            return false
        end
        if piv != i then
            mut c = u32(0)
            while c < n do
                tv = a[i * n + c]
                a[i * n + c] = a[piv * n + c]
                a[piv * n + c] = tv
                c = c + u32(1)
            end
            tb = b[i]
            b[i] = b[piv]
            b[piv] = tb
        end
        r = i + u32(1)
        while r < n do
            f = a[r * n + i] / a[i * n + i]
            mut c = i
            while c < n do
                a[r * n + c] = a[r * n + c] - f * a[i * n + c]
                c = c + u32(1)
            end
            b[r] = b[r] - f * b[i]
            r = r + u32(1)
        end
        i = i + u32(1)
    end
    mut ii = n
    while ii > u32(0) do
        i2 = ii - u32(1)
        mut s = b[i2]
        mut c = i2 + u32(1)
        while c < n do
            s = s - a[i2 * n + c] * x[c]
            c = c + u32(1)
        end
        x[i2] = s / a[i2 * n + i2]
        ii = ii - u32(1)
    end
    return true
end

pub fn law_eval(idx: u32[], k: u32, mt: f64[], bt: f64[], me: f64[], be: f64[], yye: f64, coef: f64[]) -> f64
    n = k + u32(1)
    mut a = array[f64](16)
    mut b = array[f64](4)
    mut s = array[u32](4)
    s[0] = u32(0)
    mut i = u32(0)
    while i < k do
        s[i + u32(1)] = idx[i]
        i = i + u32(1)
    end
    tr = mt[0]
    i = u32(0)
    while i < n do
        mut j = u32(0)
        while j < n do
            a[i * n + j] = mt[s[i] * NG + s[j]]
            j = j + u32(1)
        end
        a[i * n + i] = a[i * n + i] + 1e-9 * tr
        b[i] = bt[s[i]]
        i = i + u32(1)
    end
    if not small_solve(a, b, n, coef) then
        return 1e300
    end
    mut sse = yye
    i = u32(0)
    while i < n do
        sse = sse - 2.0 * coef[i] * be[s[i]]
        mut j = u32(0)
        while j < n do
            sse = sse + coef[i] * me[s[i] * NG + s[j]] * coef[j]
            j = j + u32(1)
        end
        i = i + u32(1)
    end
    return sse
end

pub fn law_search(mt: f64[], bt: f64[], me: f64[], be: f64[], yye: f64, best_idx: u32[], best_coef: f64[]) -> f64
    mut idx = array[u32](3)
    mut coef = array[f64](4)
    mut best = 1e300
    mut a = u32(1)
    while a < NG do
        mut b = a
        while b < NG do
            mut c = b
            while c < NG do
                mut k = u32(3)
                idx[0] = a
                idx[1] = b
                idx[2] = c
                if b == a then
                    k = u32(1)
                else
                    if c == b then
                        k = u32(2)
                    end
                end
                if (k == u32(1) and b == a and c == a) or (k == u32(2) and c == b) or k == u32(3) then
                    e = law_eval(idx, k, mt, bt, me, be, yye, coef)
                    if e < best then
                        best = e
                        best_idx[0] = k
                        best_idx[1] = a
                        best_idx[2] = b
                        best_idx[3] = c
                        mut q = u32(0)
                        while q < u32(4) do
                            best_coef[q] = coef[q]
                            q = q + u32(1)
                        end
                    end
                end
                c = c + u32(1)
            end
            b = b + u32(1)
        end
        a = a + u32(1)
    end
    return best
end

pub fn residual_moments(mt: f64[], bt: f64[], yyt: f64, idx: u32[], coef: f64[], br: f64[]) -> f64
    k = idx[0]
    mut s = array[u32](4)
    s[0] = u32(0)
    mut i = u32(0)
    while i < k do
        s[i + u32(1)] = idx[i + u32(1)]
        i = i + u32(1)
    end
    n = k + u32(1)
    mut a = u32(0)
    while a < NG do
        mut v = bt[a]
        i = u32(0)
        while i < n do
            v = v - mt[a * NG + s[i]] * coef[i]
            i = i + u32(1)
        end
        br[a] = v
        a = a + u32(1)
    end
    mut yy = yyt
    i = u32(0)
    while i < n do
        yy = yy - 2.0 * coef[i] * bt[s[i]]
        mut j = u32(0)
        while j < n do
            yy = yy + coef[i] * mt[s[i] * NG + s[j]] * coef[j]
            j = j + u32(1)
        end
        i = i + u32(1)
    end
    return yy
end

pub fn law_value(g: f32[], go: u32, idx: u32[], coef: f64[]) -> f32
    k = idx[0]
    mut v = coef[0]
    mut i = u32(0)
    while i < k do
        v = v + coef[i + u32(1)] * f64(g[go + idx[i + u32(1)]])
        i = i + u32(1)
    end
    return f32(v)
end

pub fn grammar(x: f32[], xo: u32, gm: f32[])
    n = D.N
    n1 = n + u32(1)
    mut box = array[f32](D.NBASE * D.NPIX)
    mut sat = array[f64](n1 * n1)
    mut c = u32(0)
    while c < D.NBASE do
        mut i = u32(0)
        while i < n do
            mut row = 0.0
            mut j = u32(0)
            while j < n do
                row = row + f64(x[xo + c * D.NPIX + i * n + j])
                sat[(i + u32(1)) * n1 + j + u32(1)] = sat[i * n1 + j + u32(1)] + row
                j = j + u32(1)
            end
            i = i + u32(1)
        end
        mut p = u32(0)
        while p < D.NPIX do
            pi = p / n
            pj = p % n
            i0 = u32(max(i32(0), i32(pi) - i32(3)))
            i1 = min(n, pi + u32(4))
            j0 = u32(max(i32(0), i32(pj) - i32(3)))
            j1 = min(n, pj + u32(4))
            sm = sat[i1 * n1 + j1] - sat[i0 * n1 + j1] - sat[i1 * n1 + j0] + sat[i0 * n1 + j0]
            box[c * D.NPIX + p] = f32(sm / f64((i1 - i0) * (j1 - j0)))
            p = p + u32(1)
        end
        c = c + u32(1)
    end
    mut p = u32(0)
    while p < D.NPIX do
        o = p * NG
        gm[o] = f32(1.0)
        c = u32(0)
        while c < D.NBASE do
            gm[o + u32(1) + c] = x[xo + c * D.NPIX + p]
            gm[o + u32(22) + c] = box[c * D.NPIX + p]
            c = c + u32(1)
        end
        soil = x[xo + u32(15) * D.NPIX + p]
        c = u32(0)
        while c < u32(15) do
            gm[o + u32(43) + c] = soil * x[xo + c * D.NPIX + p]
            c = c + u32(1)
        end
        p = p + u32(1)
    end
end

pub fn solve_offset(g: f64[], xy: f64[], yy: f64[], ge: f64[], xye: f64[], yye: f64[], d: u32, m: u32, off: f64[], beta: f64[], lamk: u32[], sse: f64[], cert: f64[]) -> f64
    mut xyr = array[f64](d * m)
    mut xyer = array[f64](d * m)
    mut yyr = array[f64](m)
    mut yyer = array[f64](m)
    mut q = u32(0)
    while q < d * m do
        xyr[q] = xy[q]
        xyer[q] = xye[q]
        q = q + u32(1)
    end
    q = u32(0)
    while q < m do
        yyr[q] = yy[q]
        yyer[q] = yye[q]
        q = q + u32(1)
    end
    mut col = array[f64](d)
    mut t = u32(0)
    while t < m do
        mut a = u32(0)
        while a < d do
            col[a] = off[a * m + t]
            a = a + u32(1)
        end
        residualize(g, xyr, yyr, d, m, t, col)
        residualize(ge, xyer, yyer, d, m, t, col)
        t = t + u32(1)
    end
    w = solve_heads(g, xyr, d, m, ge, xyer, yyer, beta, lamk, sse, cert)
    t = u32(0)
    while t < m do
        if yyer[t] <= sse[t] then
            sse[t] = yyer[t]
            lamk[t] = NLAMBDA
            mut a = u32(0)
            while a < d do
                beta[a * m + t] = 0.0
                a = a + u32(1)
            end
        end
        t = t + u32(1)
    end
    q = u32(0)
    while q < d * m do
        beta[q] = beta[q] + off[q]
        q = q + u32(1)
    end
    return w
end

pub fn clamp_soil(t: u32, v: f32) -> f32
    pr = t / u32(6)
    mut lo = f32(3.5)
    mut hi = f32(9.5)
    if pr == u32(1) then
        lo = f32(0.0)
        hi = f32(600.0)
    end
    if pr >= u32(2) then
        lo = f32(0.0)
        hi = f32(100.0)
    end
    return max(lo, min(hi, v))
end

pub fn clamp_weather(k: u32, v: f32) -> f32
    mut lo = f32(-30.0)
    mut hi = f32(45.0)
    if k == u32(1) then
        lo = f32(0.0)
        hi = f32(100.0)
    end
    if k == u32(2) then
        lo = f32(0.0)
        hi = f32(0.7)
    end
    if k == u32(3) then
        lo = f32(-400.0)
        hi = f32(400.0)
    end
    return max(lo, min(hi, v))
end
