pub fn corr_q(dh2: f32[], z: f32[], nb: u32, nf: u32, dm: u32, nt: u32,
              kk: u32, q: f32[])
    mut ng = nf * dm
    mut np = nt + kk
    mut nk = u32(16)
    if nk > nb then
        nk = nb
    end
    mut per = (nb + nk - u32(1)) / nk
    mut qp = array[f32](nk * nf * kk)
    mut ch = u32(0)
    while ch < nk do
        mut ba = ch * per
        mut bb = ba + per
        if bb > nb then
            bb = nb
        end
        mut fi = u32(0)
        while fi < nf do
            mut qo = (ch * nf + fi) * kk
            mut k = u32(0)
            while k + u32(8) <= kk do
                mut a0 = simd[f32, 8](f32(0.0))
                mut a1 = simd[f32, 8](f32(0.0))
                mut a2 = simd[f32, 8](f32(0.0))
                mut a3 = simd[f32, 8](f32(0.0))
                mut a4 = simd[f32, 8](f32(0.0))
                mut a5 = simd[f32, 8](f32(0.0))
                mut a6 = simd[f32, 8](f32(0.0))
                mut a7 = simd[f32, 8](f32(0.0))
                mut bi = ba
                while bi < bb do
                    mut di = u32(0)
                    while di < dm do
                        mut gi = fi * dm + di
                        mut go = (bi * ng + gi) * nt
                        mut zo = (bi * ng + gi) * np + k
                        mut t = u32(0)
                        while t + u32(8) <= nt do
                            mut dv = simd[f32, 8](dh2, go + t)
                            a0 = fma(dv, simd[f32, 8](z, zo + t + u32(0)), a0)
                            a1 = fma(dv, simd[f32, 8](z, zo + t + u32(1)), a1)
                            a2 = fma(dv, simd[f32, 8](z, zo + t + u32(2)), a2)
                            a3 = fma(dv, simd[f32, 8](z, zo + t + u32(3)), a3)
                            a4 = fma(dv, simd[f32, 8](z, zo + t + u32(4)), a4)
                            a5 = fma(dv, simd[f32, 8](z, zo + t + u32(5)), a5)
                            a6 = fma(dv, simd[f32, 8](z, zo + t + u32(6)), a6)
                            a7 = fma(dv, simd[f32, 8](z, zo + t + u32(7)), a7)
                            t = t + u32(8)
                        end
                        while t < nt do
                            mut dv2 = dh2[go + t]
                            qp[qo + k + u32(0)] = qp[qo + k + u32(0)] + dv2 * z[zo + t + u32(0)]
                            qp[qo + k + u32(1)] = qp[qo + k + u32(1)] + dv2 * z[zo + t + u32(1)]
                            qp[qo + k + u32(2)] = qp[qo + k + u32(2)] + dv2 * z[zo + t + u32(2)]
                            qp[qo + k + u32(3)] = qp[qo + k + u32(3)] + dv2 * z[zo + t + u32(3)]
                            qp[qo + k + u32(4)] = qp[qo + k + u32(4)] + dv2 * z[zo + t + u32(4)]
                            qp[qo + k + u32(5)] = qp[qo + k + u32(5)] + dv2 * z[zo + t + u32(5)]
                            qp[qo + k + u32(6)] = qp[qo + k + u32(6)] + dv2 * z[zo + t + u32(6)]
                            qp[qo + k + u32(7)] = qp[qo + k + u32(7)] + dv2 * z[zo + t + u32(7)]
                            t = t + u32(1)
                        end
                        di = di + u32(1)
                    end
                    bi = bi + u32(1)
                end
                qp[qo + k + u32(0)] = qp[qo + k + u32(0)] + hsum(a0)
                qp[qo + k + u32(1)] = qp[qo + k + u32(1)] + hsum(a1)
                qp[qo + k + u32(2)] = qp[qo + k + u32(2)] + hsum(a2)
                qp[qo + k + u32(3)] = qp[qo + k + u32(3)] + hsum(a3)
                qp[qo + k + u32(4)] = qp[qo + k + u32(4)] + hsum(a4)
                qp[qo + k + u32(5)] = qp[qo + k + u32(5)] + hsum(a5)
                qp[qo + k + u32(6)] = qp[qo + k + u32(6)] + hsum(a6)
                qp[qo + k + u32(7)] = qp[qo + k + u32(7)] + hsum(a7)
                k = k + u32(8)
            end
            while k < kk do
                mut cv = simd[f32, 8](f32(0.0))
                mut b2 = ba
                while b2 < bb do
                    mut d2 = u32(0)
                    while d2 < dm do
                        mut g2 = fi * dm + d2
                        mut go2 = (b2 * ng + g2) * nt
                        mut zo2 = (b2 * ng + g2) * np + k
                        mut t2 = u32(0)
                        while t2 + u32(8) <= nt do
                            cv = fma(simd[f32, 8](dh2, go2 + t2),
                                     simd[f32, 8](z, zo2 + t2), cv)
                            t2 = t2 + u32(8)
                        end
                        while t2 < nt do
                            qp[qo + k] = qp[qo + k] + dh2[go2 + t2] * z[zo2 + t2]
                            t2 = t2 + u32(1)
                        end
                        d2 = d2 + u32(1)
                    end
                    b2 = b2 + u32(1)
                end
                qp[qo + k] = qp[qo + k] + hsum(cv)
                k = k + u32(1)
            end
            fi = fi + u32(1)
        end
        ch = ch + u32(1)
    end
    mut fq = u32(0)
    while fq < nf * kk do
        mut s = f32(0.0)
        mut cq = u32(0)
        while cq < nk do
            s = s + qp[cq * nf * kk + fq]
            cq = cq + u32(1)
        end
        q[fq] = s
        fq = fq + u32(1)
    end
end

pub fn corr_pw(dh2: f32[], nb: u32, nf: u32, dm: u32, nt: u32, kk: u32,
               w1: f32[], dp: f32[], wr: f32[], pwo: f32[])
    mut ng = nf * dm
    mut lpad = (kk - u32(1)) / u32(2)
    mut np2 = nt + u32(2) * kk
    mut off = lpad + u32(1)
    mut i = u32(0)
    while i < nb * ng do
        mut so = i * nt
        mut dq = i * np2 + kk
        mut t = u32(0)
        while t + u32(8) <= nt do
            store(dp, dq + t, simd[f32, 8](dh2, so + t))
            t = t + u32(8)
        end
        while t < nt do
            dp[dq + t] = dh2[so + t]
            t = t + u32(1)
        end
        i = i + u32(1)
    end
    mut f0 = u32(0)
    while f0 < nf do
        mut j = u32(0)
        while j < kk do
            wr[f0 * kk + j] = w1[f0 * kk + kk - u32(1) - j]
            j = j + u32(1)
        end
        f0 = f0 + u32(1)
    end
    mut bi = u32(0)
    while bi < nb do
        mut gi = u32(0)
        while gi < ng do
            mut fi = gi / dm
            mut wo = fi * kk
            mut po = (bi * ng + gi) * np2 + off
            mut oo = (bi * ng + gi) * nt
            mut t2 = u32(0)
            while t2 + u32(32) <= nt do
                mut a0 = simd[f32, 8](f32(0.0))
                mut a1 = simd[f32, 8](f32(0.0))
                mut a2 = simd[f32, 8](f32(0.0))
                mut a3 = simd[f32, 8](f32(0.0))
                mut j2 = u32(0)
                while j2 < kk do
                    mut wv = simd[f32, 8](wr[wo + j2])
                    mut pj = po + t2 + j2
                    a0 = fma(wv, simd[f32, 8](dp, pj + u32(0)), a0)
                    a1 = fma(wv, simd[f32, 8](dp, pj + u32(8)), a1)
                    a2 = fma(wv, simd[f32, 8](dp, pj + u32(16)), a2)
                    a3 = fma(wv, simd[f32, 8](dp, pj + u32(24)), a3)
                    j2 = j2 + u32(1)
                end
                store(pwo, oo + t2 + u32(0), a0)
                store(pwo, oo + t2 + u32(8), a1)
                store(pwo, oo + t2 + u32(16), a2)
                store(pwo, oo + t2 + u32(24), a3)
                t2 = t2 + u32(32)
            end
            while t2 + u32(8) <= nt do
                mut av = simd[f32, 8](f32(0.0))
                mut j3 = u32(0)
                while j3 < kk do
                    av = fma(simd[f32, 8](wr[wo + j3]),
                             simd[f32, 8](dp, po + t2 + j3), av)
                    j3 = j3 + u32(1)
                end
                store(pwo, oo + t2, av)
                t2 = t2 + u32(8)
            end
            while t2 < nt do
                mut sc = f32(0.0)
                mut j4 = u32(0)
                while j4 < kk do
                    sc = sc + wr[wo + j4] * dp[po + t2 + j4]
                    j4 = j4 + u32(1)
                end
                pwo[oo + t2] = sc
                t2 = t2 + u32(1)
            end
            gi = gi + u32(1)
        end
        bi = bi + u32(1)
    end
end

pub fn dw2_from_pw(pwo: f32[], dh2: f32[], x: f32[], b0: u32, nb: u32,
                   nc: u32, nt: u32, nf: u32, dm: u32,
                   av: f32[], bv: f32[], dw2: f32[])
    mut ng = nf * dm
    mut nk = u32(16)
    if nk > nb then
        nk = nb
    end
    mut per = (nb + nk - u32(1)) / nk
    mut acc = array[f32](nk * ng * nc)
    mut ch = u32(0)
    while ch < nk do
        mut ba = ch * per
        mut bb = ba + per
        if bb > nb then
            bb = nb
        end
        mut c4 = u32(0)
        while c4 + u32(4) <= nc do
            mut gi = u32(0)
            while gi < ng do
                mut q0 = simd[f32, 8](f32(0.0))
                mut q1 = simd[f32, 8](f32(0.0))
                mut q2 = simd[f32, 8](f32(0.0))
                mut q3 = simd[f32, 8](f32(0.0))
                mut bi = ba
                while bi < bb do
                    mut po = (bi * ng + gi) * nt
                    mut xo = (b0 + bi) * nc * nt + c4 * nt
                    mut t = u32(0)
                    while t + u32(8) <= nt do
                        mut pv = simd[f32, 8](pwo, po + t)
                        q0 = fma(pv, simd[f32, 8](x, xo + t), q0)
                        q1 = fma(pv, simd[f32, 8](x, xo + nt + t), q1)
                        q2 = fma(pv, simd[f32, 8](x, xo + u32(2) * nt + t), q2)
                        q3 = fma(pv, simd[f32, 8](x, xo + u32(3) * nt + t), q3)
                        t = t + u32(8)
                    end
                    while t < nt do
                        mut pz = pwo[po + t]
                        acc[(ch * ng + gi) * nc + c4] =
                            acc[(ch * ng + gi) * nc + c4] + pz * x[xo + t]
                        acc[(ch * ng + gi) * nc + c4 + u32(1)] =
                            acc[(ch * ng + gi) * nc + c4 + u32(1)] + pz * x[xo + nt + t]
                        acc[(ch * ng + gi) * nc + c4 + u32(2)] =
                            acc[(ch * ng + gi) * nc + c4 + u32(2)] + pz * x[xo + u32(2) * nt + t]
                        acc[(ch * ng + gi) * nc + c4 + u32(3)] =
                            acc[(ch * ng + gi) * nc + c4 + u32(3)] + pz * x[xo + u32(3) * nt + t]
                        t = t + u32(1)
                    end
                    bi = bi + u32(1)
                end
                mut ao = (ch * ng + gi) * nc + c4
                acc[ao] = acc[ao] + hsum(q0)
                acc[ao + u32(1)] = acc[ao + u32(1)] + hsum(q1)
                acc[ao + u32(2)] = acc[ao + u32(2)] + hsum(q2)
                acc[ao + u32(3)] = acc[ao + u32(3)] + hsum(q3)
                gi = gi + u32(1)
            end
            c4 = c4 + u32(4)
        end
        while c4 < nc do
            mut g3 = u32(0)
            while g3 < ng do
                mut av8 = simd[f32, 8](f32(0.0))
                mut b3 = ba
                while b3 < bb do
                    mut po2 = (b3 * ng + g3) * nt
                    mut xo2 = (b0 + b3) * nc * nt + c4 * nt
                    mut t2 = u32(0)
                    while t2 + u32(8) <= nt do
                        av8 = fma(simd[f32, 8](pwo, po2 + t2),
                                  simd[f32, 8](x, xo2 + t2), av8)
                        t2 = t2 + u32(8)
                    end
                    while t2 < nt do
                        acc[(ch * ng + g3) * nc + c4] =
                            acc[(ch * ng + g3) * nc + c4] + pwo[po2 + t2] * x[xo2 + t2]
                        t2 = t2 + u32(1)
                    end
                    b3 = b3 + u32(1)
                end
                acc[(ch * ng + g3) * nc + c4] =
                    acc[(ch * ng + g3) * nc + c4] + hsum(av8)
                g3 = g3 + u32(1)
            end
            c4 = c4 + u32(1)
        end
        ch = ch + u32(1)
    end
    mut g2 = u32(0)
    while g2 < ng do
        mut fi = g2 / dm
        mut tv = simd[f32, 8](f32(0.0))
        mut ts = f32(0.0)
        mut bq = u32(0)
        while bq < nb do
            mut go = (bq * ng + g2) * nt
            mut u = u32(0)
            while u + u32(8) <= nt do
                tv = tv + simd[f32, 8](dh2, go + u)
                u = u + u32(8)
            end
            while u < nt do
                ts = ts + dh2[go + u]
                u = u + u32(1)
            end
            bq = bq + u32(1)
        end
        mut tsum = hsum(tv) + ts
        mut c2 = u32(0)
        while c2 < nc do
            mut a2 = f32(0.0)
            mut cq = u32(0)
            while cq < nk do
                a2 = a2 + acc[(cq * ng + g2) * nc + c2]
                cq = cq + u32(1)
            end
            dw2[g2 * nc + c2] = dw2[g2 * nc + c2] + av[fi] * a2 + bv[fi] * tsum
            c2 = c2 + u32(1)
        end
        g2 = g2 + u32(1)
    end
end

pub fn dw1_and_scale(q: f32[], mk: f32[], r: f32[], w1: f32[], s2: f32[],
                     dh2: f32[], nb: u32, nc: u32, nt: u32, nf: u32, dm: u32,
                     kk: u32,
                     gamma: f32[], mean: f32[], ivar: f32[],
                     dw1: f32[], dgam: f32[], dbet: f32[])
    mut ng = nf * dm
    mut n = nb * nc * nt
    mut fn2 = f32(i32(n))
    mut fi = u32(0)
    while fi < nf do
        mut wo = fi * kk
        mut sd = f32(0.0)
        mut di = u32(0)
        while di < dm do
            mut gi = fi * dm + di
            mut tv = simd[f32, 8](f32(0.0))
            mut ts = f32(0.0)
            mut bi = u32(0)
            while bi < nb do
                mut go = (bi * ng + gi) * nt
                mut u = u32(0)
                while u + u32(8) <= nt do
                    tv = tv + simd[f32, 8](dh2, go + u)
                    u = u + u32(8)
                end
                while u < nt do
                    ts = ts + dh2[go + u]
                    u = u + u32(1)
                end
                bi = bi + u32(1)
            end
            sd = sd + s2[gi] * (hsum(tv) + ts)
            di = di + u32(1)
        end
        mut sh = f32(0.0)
        mut k = u32(0)
        while k < kk do
            sh = sh + w1[wo + k] * q[wo + k]
            k = k + u32(1)
        end
        mut iv = ivar[fi]
        mut mu = mean[fi]
        mut sx = iv * (sh - mu * sd)
        dgam[fi] = dgam[fi] + sx
        dbet[fi] = dbet[fi] + sd
        mut c1 = iv * gamma[fi]
        mut c3 = f32(0.0) - (iv * iv / fn2) * (gamma[fi] * sx)
        mut c2 = f32(0.0) - (iv / fn2) * (gamma[fi] * sd) - c3 * mu
        mut k2 = u32(0)
        while k2 < kk do
            mut rw = f32(0.0)
            mut l = u32(0)
            while l < kk do
                rw = rw + w1[wo + l] * r[k2 * kk + l]
                l = l + u32(1)
            end
            dw1[wo + k2] = dw1[wo + k2] + c1 * q[wo + k2]
                         + c2 * fn2 * mk[k2] + c3 * fn2 * rw
            k2 = k2 + u32(1)
        end
        fi = fi + u32(1)
    end
end
