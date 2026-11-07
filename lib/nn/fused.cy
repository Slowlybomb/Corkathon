mut scl = require("../math/scalar.cy")

pub fn mix_pad(x: f32[], b0: u32, nb: u32, nc: u32, nt: u32,
               w2: f32[], nf: u32, dm: u32, kk: u32, z: f32[])
    mut lpad = (kk - u32(1)) / u32(2)
    mut np = nt + kk
    mut ng = nf * dm
    mut bi = u32(0)
    while bi < nb do
        mut gi = u32(0)
        while gi < ng do
            mut zo = (bi * ng + gi) * np + lpad
            mut wo = gi * nc
            mut xb = (b0 + bi) * nc * nt
            mut t = u32(0)
            while t + u32(32) <= nt do
                mut a0 = simd[f32, 8](f32(0.0))
                mut a1 = simd[f32, 8](f32(0.0))
                mut a2 = simd[f32, 8](f32(0.0))
                mut a3 = simd[f32, 8](f32(0.0))
                mut ci = u32(0)
                while ci < nc do
                    mut wv = simd[f32, 8](w2[wo + ci])
                    mut xo = xb + ci * nt + t
                    a0 = fma(wv, simd[f32, 8](x, xo + u32(0)), a0)
                    a1 = fma(wv, simd[f32, 8](x, xo + u32(8)), a1)
                    a2 = fma(wv, simd[f32, 8](x, xo + u32(16)), a2)
                    a3 = fma(wv, simd[f32, 8](x, xo + u32(24)), a3)
                    ci = ci + u32(1)
                end
                store(z, zo + t + u32(0), a0)
                store(z, zo + t + u32(8), a1)
                store(z, zo + t + u32(16), a2)
                store(z, zo + t + u32(24), a3)
                t = t + u32(32)
            end
            while t + u32(8) <= nt do
                mut av = simd[f32, 8](f32(0.0))
                mut c2 = u32(0)
                while c2 < nc do
                    av = fma(simd[f32, 8](w2[wo + c2]),
                             simd[f32, 8](x, xb + c2 * nt + t), av)
                    c2 = c2 + u32(1)
                end
                store(z, zo + t, av)
                t = t + u32(8)
            end
            while t < nt do
                mut sc = f32(0.0)
                mut c3 = u32(0)
                while c3 < nc do
                    sc = sc + w2[wo + c3] * x[xb + c3 * nt + t]
                    c3 = c3 + u32(1)
                end
                z[zo + t] = sc
                t = t + u32(1)
            end
            gi = gi + u32(1)
        end
        bi = bi + u32(1)
    end
end

pub fn pad_tail(x: f32[], b0: u32, nb: u32, nc: u32, nt: u32, kk: u32, xe: f32[])
    mut ne = nt + kk
    mut i = u32(0)
    while i < nb * nc do
        mut bi = i / nc
        mut ci = i % nc
        mut xo = (b0 + bi) * nc * nt + ci * nt
        mut eo = i * ne
        mut t = u32(0)
        while t + u32(8) <= nt do
            store(xe, eo + t, simd[f32, 8](x, xo + t))
            t = t + u32(8)
        end
        while t < nt do
            xe[eo + t] = x[xo + t]
            t = t + u32(1)
        end
        i = i + u32(1)
    end
end

pub fn corr_lags(xe: f32[], nrow: u32, nt: u32, kk: u32, pr: f32[])
    mut ne = nt + kk
    mut zi = u32(0)
    while zi + u32(8) <= kk * nt do
        store(pr, zi, simd[f32, 8](f32(0.0)))
        zi = zi + u32(8)
    end
    while zi < kk * nt do
        pr[zi] = f32(0.0)
        zi = zi + u32(1)
    end
    mut d0 = u32(0)
    while d0 + u32(4) <= kk do
        mut r0 = u32(0)
        while r0 < nrow do
            mut r1 = r0 + u32(32)
            if r1 > nrow then
                r1 = nrow
            end
            mut t = u32(0)
            while t + u32(8) <= nt do
                mut a0 = simd[f32, 8](pr, (d0 + u32(0)) * nt + t)
                mut a1 = simd[f32, 8](pr, (d0 + u32(1)) * nt + t)
                mut a2 = simd[f32, 8](pr, (d0 + u32(2)) * nt + t)
                mut a3 = simd[f32, 8](pr, (d0 + u32(3)) * nt + t)
                mut ri = r0
                while ri < r1 do
                    mut ro = ri * ne + t
                    mut xa = simd[f32, 8](xe, ro)
                    a0 = fma(xa, simd[f32, 8](xe, ro + d0 + u32(0)), a0)
                    a1 = fma(xa, simd[f32, 8](xe, ro + d0 + u32(1)), a1)
                    a2 = fma(xa, simd[f32, 8](xe, ro + d0 + u32(2)), a2)
                    a3 = fma(xa, simd[f32, 8](xe, ro + d0 + u32(3)), a3)
                    ri = ri + u32(1)
                end
                store(pr, (d0 + u32(0)) * nt + t, a0)
                store(pr, (d0 + u32(1)) * nt + t, a1)
                store(pr, (d0 + u32(2)) * nt + t, a2)
                store(pr, (d0 + u32(3)) * nt + t, a3)
                t = t + u32(8)
            end
            while t < nt do
                mut s0 = pr[(d0 + u32(0)) * nt + t]
                mut s1 = pr[(d0 + u32(1)) * nt + t]
                mut s2 = pr[(d0 + u32(2)) * nt + t]
                mut s3 = pr[(d0 + u32(3)) * nt + t]
                mut r2 = r0
                while r2 < r1 do
                    mut xv = xe[r2 * ne + t]
                    s0 = s0 + xv * xe[r2 * ne + t + d0 + u32(0)]
                    s1 = s1 + xv * xe[r2 * ne + t + d0 + u32(1)]
                    s2 = s2 + xv * xe[r2 * ne + t + d0 + u32(2)]
                    s3 = s3 + xv * xe[r2 * ne + t + d0 + u32(3)]
                    r2 = r2 + u32(1)
                end
                pr[(d0 + u32(0)) * nt + t] = s0
                pr[(d0 + u32(1)) * nt + t] = s1
                pr[(d0 + u32(2)) * nt + t] = s2
                pr[(d0 + u32(3)) * nt + t] = s3
                t = t + u32(1)
            end
            r0 = r0 + u32(32)
        end
        d0 = d0 + u32(4)
    end
    mut d = d0
    while d < kk do
        mut q0 = u32(0)
        while q0 < nrow do
            mut q1 = q0 + u32(32)
            if q1 > nrow then
                q1 = nrow
            end
            mut u = u32(0)
            while u + u32(8) <= nt do
                mut av = simd[f32, 8](pr, d * nt + u)
                mut qi = q0
                while qi < q1 do
                    av = fma(simd[f32, 8](xe, qi * ne + u),
                             simd[f32, 8](xe, qi * ne + u + d), av)
                    qi = qi + u32(1)
                end
                store(pr, d * nt + u, av)
                u = u + u32(8)
            end
            while u < nt do
                mut sv = pr[d * nt + u]
                mut q2 = q0
                while q2 < q1 do
                    sv = sv + xe[q2 * ne + u] * xe[q2 * ne + u + d]
                    q2 = q2 + u32(1)
                end
                pr[d * nt + u] = sv
                u = u + u32(1)
            end
            q0 = q0 + u32(32)
        end
        d = d + u32(1)
    end
end

pub fn col_sums(xe: f32[], nrow: u32, nt: u32, kk: u32, sm: f32[])
    mut ne = nt + kk
    mut t = u32(0)
    while t + u32(8) <= nt do
        mut av = simd[f32, 8](f32(0.0))
        mut ri = u32(0)
        while ri < nrow do
            av = av + simd[f32, 8](xe, ri * ne + t)
            ri = ri + u32(1)
        end
        store(sm, t, av)
        t = t + u32(8)
    end
    while t < nt do
        mut sc = f32(0.0)
        mut r2 = u32(0)
        while r2 < nrow do
            sc = sc + xe[r2 * ne + t]
            r2 = r2 + u32(1)
        end
        sm[t] = sc
        t = t + u32(1)
    end
end

pub fn bn_from_moments(pr: f32[], sm: f32[], nb: u32, nc: u32, nt: u32,
                       w1: f32[], nf: u32, kk: u32,
                       gamma: f32[], beta: f32[], mean: f32[], ivar: f32[],
                       rmean: f32[], rvar: f32[], mom: f32,
                       av: f32[], bv: f32[], r: f32[], mk: f32[])
    mut lpad = (kk - u32(1)) / u32(2)
    mut n = nb * nc * nt
    mut inv = f32(1.0) / f32(i32(n))
    mut ps = array[f32](nt + u32(1))
    mut i = u32(0)
    while i < nt do
        ps[i + u32(1)] = ps[i] + sm[i]
        i = i + u32(1)
    end
    mut k = u32(0)
    while k < kk do
        mut lo = u32(0)
        if k > lpad then
            lo = k - lpad
        end
        mut hi = nt
        if k + nt > lpad then
            if k + nt - lpad < nt then
                hi = k + nt - lpad
            end
        else
            hi = u32(0)
        end
        mk[k] = (ps[hi] - ps[lo]) * inv
        k = k + u32(1)
    end
    mut pq = array[f32](nt + u32(1))
    mut d = u32(0)
    while d < kk do
        mut j = u32(0)
        while j < nt do
            pq[j + u32(1)] = pq[j] + pr[d * nt + j]
            j = j + u32(1)
        end
        mut k2 = u32(0)
        while k2 + d < kk do
            mut lo2 = u32(0)
            if k2 > lpad then
                lo2 = k2 - lpad
            end
            mut hi2 = nt
            if k2 + nt > lpad then
                if k2 + nt - lpad < nt then
                    hi2 = k2 + nt - lpad
                end
            else
                hi2 = u32(0)
            end
            mut v = (pq[hi2] - pq[lo2]) * inv
            r[k2 * kk + k2 + d] = v
            r[(k2 + d) * kk + k2] = v
            k2 = k2 + u32(1)
        end
        d = d + u32(1)
    end
    mut f = u32(0)
    while f < nf do
        mut wo = f * kk
        mut mu = f32(0.0)
        mut k3 = u32(0)
        while k3 < kk do
            mu = mu + w1[wo + k3] * mk[k3]
            k3 = k3 + u32(1)
        end
        mut e2 = f32(0.0)
        mut k4 = u32(0)
        while k4 < kk do
            mut row = k4 * kk
            mut acc = simd[f32, 8](f32(0.0))
            mut l = u32(0)
            while l + u32(8) <= kk do
                acc = fma(simd[f32, 8](w1, wo + l), simd[f32, 8](r, row + l), acc)
                l = l + u32(8)
            end
            mut sc = f32(0.0)
            while l < kk do
                sc = sc + w1[wo + l] * r[row + l]
                l = l + u32(1)
            end
            e2 = e2 + w1[wo + k4] * (hsum(acc) + sc)
            k4 = k4 + u32(1)
        end
        mut var = e2 - mu * mu
        if var < f32(0.0) then
            var = f32(0.0)
        end
        mut iv = scl.rsqrt(var + f32(0.00001))
        mean[f] = mu
        ivar[f] = iv
        av[f] = gamma[f] * iv
        bv[f] = beta[f] - gamma[f] * mu * iv
        mut ub = var * f32(i32(n)) / f32(i32(n - u32(1)))
        rmean[f] = rmean[f] * (f32(1.0) - mom) + mu * mom
        rvar[f] = rvar[f] * (f32(1.0) - mom) + ub * mom
        f = f + u32(1)
    end
end

pub fn fused_conv(z: f32[], nb: u32, nf: u32, dm: u32, nt: u32, kk: u32,
                  w1: f32[], av: f32[], bv: f32[], s2: f32[], out: f32[])
    mut ng = nf * dm
    mut np = nt + kk
    mut bi = u32(0)
    while bi < nb do
        mut gi = u32(0)
        while gi < ng do
            mut fi = gi / dm
            mut wo = fi * kk
            mut zo = (bi * ng + gi) * np
            mut oo = (bi * ng + gi) * nt
            mut sv = simd[f32, 8](av[fi])
            mut ov = simd[f32, 8](bv[fi] * s2[gi])
            mut t = u32(0)
            while t + u32(32) <= nt do
                mut a0 = simd[f32, 8](f32(0.0))
                mut a1 = simd[f32, 8](f32(0.0))
                mut a2 = simd[f32, 8](f32(0.0))
                mut a3 = simd[f32, 8](f32(0.0))
                mut k = u32(0)
                while k < kk do
                    mut wv = simd[f32, 8](w1[wo + k])
                    mut zi = zo + t + k
                    a0 = fma(wv, simd[f32, 8](z, zi + u32(0)), a0)
                    a1 = fma(wv, simd[f32, 8](z, zi + u32(8)), a1)
                    a2 = fma(wv, simd[f32, 8](z, zi + u32(16)), a2)
                    a3 = fma(wv, simd[f32, 8](z, zi + u32(24)), a3)
                    k = k + u32(1)
                end
                store(out, oo + t + u32(0), fma(sv, a0, ov))
                store(out, oo + t + u32(8), fma(sv, a1, ov))
                store(out, oo + t + u32(16), fma(sv, a2, ov))
                store(out, oo + t + u32(24), fma(sv, a3, ov))
                t = t + u32(32)
            end
            while t + u32(8) <= nt do
                mut bvv = simd[f32, 8](f32(0.0))
                mut k2 = u32(0)
                while k2 < kk do
                    bvv = fma(simd[f32, 8](w1[wo + k2]),
                              simd[f32, 8](z, zo + t + k2), bvv)
                    k2 = k2 + u32(1)
                end
                store(out, oo + t, fma(sv, bvv, ov))
                t = t + u32(8)
            end
            while t < nt do
                mut sc = f32(0.0)
                mut k3 = u32(0)
                while k3 < kk do
                    sc = sc + w1[wo + k3] * z[zo + t + k3]
                    k3 = k3 + u32(1)
                end
                out[oo + t] = av[fi] * sc + bv[fi] * s2[gi]
                t = t + u32(1)
            end
            gi = gi + u32(1)
        end
        bi = bi + u32(1)
    end
end

pub fn group_sums(w2: f32[], ng: u32, nc: u32, s2: f32[])
    mut g = u32(0)
    while g < ng do
        mut acc = f32(0.0)
        mut c = u32(0)
        while c < nc do
            acc = acc + w2[g * nc + c]
            c = c + u32(1)
        end
        s2[g] = acc
        g = g + u32(1)
    end
end

pub fn infer_scale(rmean: f32[], rvar: f32[], gamma: f32[], beta: f32[],
                   nf: u32, av: f32[], bv: f32[], mean: f32[], ivar: f32[])
    mut f = u32(0)
    while f < nf do
        mut iv = scl.rsqrt(rvar[f] + f32(0.00001))
        mean[f] = rmean[f]
        ivar[f] = iv
        av[f] = gamma[f] * iv
        bv[f] = beta[f] - gamma[f] * rmean[f] * iv
        f = f + u32(1)
    end
end
