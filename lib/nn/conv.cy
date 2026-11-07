pub fn time_bank(x: f32[], b0: u32, nb: u32, nc: u32, nt: u32,
                 w: f32[], nf: u32, kk: u32, out: f32[])
    mut lpad = (kk - u32(1)) / u32(2)
    mut np = nt + kk + u32(8)
    mut xp = array[f32](nb * nc * np)
    mut bi = u32(0)
    while bi < nb do
        mut pi = u32(0)
        while pi < nc do
            mut xo = (b0 + bi) * nc * nt + pi * nt
            mut pb = (bi * nc + pi) * np + lpad
            mut c0 = u32(0)
            while c0 + u32(8) <= nt do
                store(xp, pb + c0, simd[f32, 8](x, xo + c0))
                c0 = c0 + u32(8)
            end
            while c0 < nt do
                xp[pb + c0] = x[xo + c0]
                c0 = c0 + u32(1)
            end
            pi = pi + u32(1)
        end
        bi = bi + u32(1)
    end
    mut bj = u32(0)
    while bj < nb do
        mut fi = u32(0)
        while fi + u32(4) <= nf do
            mut ci = u32(0)
            while ci < nc do
                mut pc = (bj * nc + ci) * np
                mut wo = fi * kk
                mut t = u32(0)
                while t + u32(16) <= nt do
                    mut a0_0 = simd[f32, 8](f32(0.0))
                    mut a0_1 = simd[f32, 8](f32(0.0))
                    mut a1_0 = simd[f32, 8](f32(0.0))
                    mut a1_1 = simd[f32, 8](f32(0.0))
                    mut a2_0 = simd[f32, 8](f32(0.0))
                    mut a2_1 = simd[f32, 8](f32(0.0))
                    mut a3_0 = simd[f32, 8](f32(0.0))
                    mut a3_1 = simd[f32, 8](f32(0.0))
                    mut k = u32(0)
                    while k < kk do
                        mut xv0 = simd[f32, 8](xp, pc + t + k + u32(0))
                        mut xv1 = simd[f32, 8](xp, pc + t + k + u32(8))
                        mut wv0 = simd[f32, 8](w[wo + u32(0) * kk + k])
                        a0_0 = fma(wv0, xv0, a0_0)
                        a0_1 = fma(wv0, xv1, a0_1)
                        mut wv1 = simd[f32, 8](w[wo + u32(1) * kk + k])
                        a1_0 = fma(wv1, xv0, a1_0)
                        a1_1 = fma(wv1, xv1, a1_1)
                        mut wv2 = simd[f32, 8](w[wo + u32(2) * kk + k])
                        a2_0 = fma(wv2, xv0, a2_0)
                        a2_1 = fma(wv2, xv1, a2_1)
                        mut wv3 = simd[f32, 8](w[wo + u32(3) * kk + k])
                        a3_0 = fma(wv3, xv0, a3_0)
                        a3_1 = fma(wv3, xv1, a3_1)
                        k = k + u32(1)
                    end
                    store(out, ((bj * nf + fi + u32(0)) * nc + ci) * nt + t + u32(0), a0_0)
                    store(out, ((bj * nf + fi + u32(0)) * nc + ci) * nt + t + u32(8), a0_1)
                    store(out, ((bj * nf + fi + u32(1)) * nc + ci) * nt + t + u32(0), a1_0)
                    store(out, ((bj * nf + fi + u32(1)) * nc + ci) * nt + t + u32(8), a1_1)
                    store(out, ((bj * nf + fi + u32(2)) * nc + ci) * nt + t + u32(0), a2_0)
                    store(out, ((bj * nf + fi + u32(2)) * nc + ci) * nt + t + u32(8), a2_1)
                    store(out, ((bj * nf + fi + u32(3)) * nc + ci) * nt + t + u32(0), a3_0)
                    store(out, ((bj * nf + fi + u32(3)) * nc + ci) * nt + t + u32(8), a3_1)
                    t = t + u32(16)
                end
                mut fr = u32(0)
                while fr < u32(4) do
                mut t9 = t
                while t9 + u32(8) <= nt do
                    mut av = simd[f32, 8](f32(0.0))
                    mut k2 = u32(0)
                    while k2 < kk do
                        av = fma(simd[f32, 8](w[wo + fr * kk + k2]),
                                 simd[f32, 8](xp, pc + t9 + k2), av)
                        k2 = k2 + u32(1)
                    end
                    store(out, ((bj * nf + fi + fr) * nc + ci) * nt + t9, av)
                    t9 = t9 + u32(8)
                end
                while t9 < nt do
                    mut sc0 = f32(0.0)
                    mut k3 = u32(0)
                    while k3 < kk do
                        sc0 = sc0 + w[wo + fr * kk + k3] * xp[pc + t9 + k3]
                        k3 = k3 + u32(1)
                    end
                    out[((bj * nf + fi + fr) * nc + ci) * nt + t9] = sc0
                    t9 = t9 + u32(1)
                end
                fr = fr + u32(1)
                end
                ci = ci + u32(1)
            end
            fi = fi + u32(4)
        end
        while fi < nf do
            mut ci2 = u32(0)
            while ci2 < nc do
                mut pc2 = (bj * nc + ci2) * np
                mut wo2 = fi * kk
                mut t2 = u32(0)
                while t2 + u32(8) <= nt do
                    mut bv = simd[f32, 8](f32(0.0))
                    mut k4 = u32(0)
                    while k4 < kk do
                        bv = fma(simd[f32, 8](w[wo2 + k4]),
                                 simd[f32, 8](xp, pc2 + t2 + k4), bv)
                        k4 = k4 + u32(1)
                    end
                    store(out, ((bj * nf + fi) * nc + ci2) * nt + t2, bv)
                    t2 = t2 + u32(8)
                end
                while t2 < nt do
                    mut sc1 = f32(0.0)
                    mut k5 = u32(0)
                    while k5 < kk do
                        sc1 = sc1 + w[wo2 + k5] * xp[pc2 + t2 + k5]
                        k5 = k5 + u32(1)
                    end
                    out[((bj * nf + fi) * nc + ci2) * nt + t2] = sc1
                    t2 = t2 + u32(1)
                end
                ci2 = ci2 + u32(1)
            end
            fi = fi + u32(1)
        end
        bj = bj + u32(1)
    end
end

pub fn time_bank_dw(x: f32[], b0: u32, nb: u32, nc: u32, nt: u32,
                    dout: f32[], nf: u32, kk: u32, dw: f32[])
    mut lpad = (kk - u32(1)) / u32(2)
    mut np = nt + kk + u32(8)
    mut xp = array[f32](nb * nc * np)
    mut bi = u32(0)
    while bi < nb do
        mut ci = u32(0)
        while ci < nc do
            mut xo = (b0 + bi) * nc * nt + ci * nt
            mut pb = (bi * nc + ci) * np + lpad
            mut c0 = u32(0)
            while c0 + u32(8) <= nt do
                store(xp, pb + c0, simd[f32, 8](x, xo + c0))
                c0 = c0 + u32(8)
            end
            while c0 < nt do
                xp[pb + c0] = x[xo + c0]
                c0 = c0 + u32(1)
            end
            ci = ci + u32(1)
        end
        bi = bi + u32(1)
    end
    mut nch = u32(16)
    if nch > nb then
        nch = nb
    end
    mut per = (nb + nch - u32(1)) / nch
    mut dwp = array[f32](nch * nf * kk)
    mut ch = u32(0)
    while ch < nch do
        mut ba = ch * per
        mut bb = ba + per
        if bb > nb then
            bb = nb
        end
        mut fi = u32(0)
        while fi < nf do
            mut wo = (ch * nf + fi) * kk
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
                mut bj = ba
                while bj < bb do
                    mut cj = u32(0)
                    while cj < nc do
                        mut go = bj * nf * nc * nt + fi * nc * nt + cj * nt
                        mut pc = (bj * nc + cj) * np + k
                        mut t = u32(0)
                        while t + u32(8) <= nt do
                            mut dv = simd[f32, 8](dout, go + t)
                            a0 = fma(dv, simd[f32, 8](xp, pc + t + u32(0)), a0)
                            a1 = fma(dv, simd[f32, 8](xp, pc + t + u32(1)), a1)
                            a2 = fma(dv, simd[f32, 8](xp, pc + t + u32(2)), a2)
                            a3 = fma(dv, simd[f32, 8](xp, pc + t + u32(3)), a3)
                            a4 = fma(dv, simd[f32, 8](xp, pc + t + u32(4)), a4)
                            a5 = fma(dv, simd[f32, 8](xp, pc + t + u32(5)), a5)
                            a6 = fma(dv, simd[f32, 8](xp, pc + t + u32(6)), a6)
                            a7 = fma(dv, simd[f32, 8](xp, pc + t + u32(7)), a7)
                            t = t + u32(8)
                        end
                        while t < nt do
                            mut dv2 = dout[go + t]
                            dwp[wo + k + u32(0)] = dwp[wo + k + u32(0)] + dv2 * xp[pc + t + u32(0)]
                            dwp[wo + k + u32(1)] = dwp[wo + k + u32(1)] + dv2 * xp[pc + t + u32(1)]
                            dwp[wo + k + u32(2)] = dwp[wo + k + u32(2)] + dv2 * xp[pc + t + u32(2)]
                            dwp[wo + k + u32(3)] = dwp[wo + k + u32(3)] + dv2 * xp[pc + t + u32(3)]
                            dwp[wo + k + u32(4)] = dwp[wo + k + u32(4)] + dv2 * xp[pc + t + u32(4)]
                            dwp[wo + k + u32(5)] = dwp[wo + k + u32(5)] + dv2 * xp[pc + t + u32(5)]
                            dwp[wo + k + u32(6)] = dwp[wo + k + u32(6)] + dv2 * xp[pc + t + u32(6)]
                            dwp[wo + k + u32(7)] = dwp[wo + k + u32(7)] + dv2 * xp[pc + t + u32(7)]
                            t = t + u32(1)
                        end
                        cj = cj + u32(1)
                    end
                    bj = bj + u32(1)
                end
                dwp[wo + k + u32(0)] = dwp[wo + k + u32(0)] + hsum(a0)
                dwp[wo + k + u32(1)] = dwp[wo + k + u32(1)] + hsum(a1)
                dwp[wo + k + u32(2)] = dwp[wo + k + u32(2)] + hsum(a2)
                dwp[wo + k + u32(3)] = dwp[wo + k + u32(3)] + hsum(a3)
                dwp[wo + k + u32(4)] = dwp[wo + k + u32(4)] + hsum(a4)
                dwp[wo + k + u32(5)] = dwp[wo + k + u32(5)] + hsum(a5)
                dwp[wo + k + u32(6)] = dwp[wo + k + u32(6)] + hsum(a6)
                dwp[wo + k + u32(7)] = dwp[wo + k + u32(7)] + hsum(a7)
                k = k + u32(8)
            end
            while k < kk do
                mut av = simd[f32, 8](f32(0.0))
                mut acc = f32(0.0)
                mut b2 = ba
                while b2 < bb do
                    mut c2 = u32(0)
                    while c2 < nc do
                        mut go2 = b2 * nf * nc * nt + fi * nc * nt + c2 * nt
                        mut pc2 = (b2 * nc + c2) * np + k
                        mut t2 = u32(0)
                        while t2 + u32(8) <= nt do
                            av = fma(simd[f32, 8](dout, go2 + t2),
                                     simd[f32, 8](xp, pc2 + t2), av)
                            t2 = t2 + u32(8)
                        end
                        while t2 < nt do
                            acc = acc + dout[go2 + t2] * xp[pc2 + t2]
                            t2 = t2 + u32(1)
                        end
                        c2 = c2 + u32(1)
                    end
                    b2 = b2 + u32(1)
                end
                dwp[wo + k] = dwp[wo + k] + hsum(av) + acc
                k = k + u32(1)
            end
            fi = fi + u32(1)
        end
        ch = ch + u32(1)
    end
    mut cq = u32(0)
    while cq < nch do
        mut q = u32(0)
        while q < nf * kk do
            dw[q] = dw[q] + dwp[cq * nf * kk + q]
            q = q + u32(1)
        end
        cq = cq + u32(1)
    end
end

pub fn time_depth(x: f32[], nb: u32, ng: u32, nt: u32,
                  w: f32[], kk: u32, out: f32[])
    mut lpad = (kk - u32(1)) / u32(2)
    mut np = nt + kk + u32(8)
    mut xp = array[f32](nb * np)
    mut ostride = ng * nt
    mut bi = u32(0)
    while bi < nb do
        mut gi = u32(0)
        while gi < ng do
            mut xo = bi * ostride + gi * nt
            mut pb = bi * np
            mut c0 = u32(0)
            while c0 + u32(8) <= nt do
                store(xp, pb + lpad + c0, simd[f32, 8](x, xo + c0))
                c0 = c0 + u32(8)
            end
            while c0 < nt do
                xp[pb + lpad + c0] = x[xo + c0]
                c0 = c0 + u32(1)
            end
            mut wo = gi * kk
            mut t = u32(0)
            while t + u32(32) <= nt do
                mut a0 = simd[f32, 8](f32(0.0))
                mut a1 = simd[f32, 8](f32(0.0))
                mut a2 = simd[f32, 8](f32(0.0))
                mut a3 = simd[f32, 8](f32(0.0))
                mut k = u32(0)
                while k < kk do
                    mut wv = simd[f32, 8](w[wo + k])
                    a0 = fma(wv, simd[f32, 8](xp, pb + t + k + u32(0)), a0)
                    a1 = fma(wv, simd[f32, 8](xp, pb + t + k + u32(8)), a1)
                    a2 = fma(wv, simd[f32, 8](xp, pb + t + k + u32(16)), a2)
                    a3 = fma(wv, simd[f32, 8](xp, pb + t + k + u32(24)), a3)
                    k = k + u32(1)
                end
                store(out, xo + t + u32(0), a0)
                store(out, xo + t + u32(8), a1)
                store(out, xo + t + u32(16), a2)
                store(out, xo + t + u32(24), a3)
                t = t + u32(32)
            end
            while t + u32(8) <= nt do
                mut av = simd[f32, 8](f32(0.0))
                mut k2 = u32(0)
                while k2 < kk do
                    av = fma(simd[f32, 8](w[wo + k2]), simd[f32, 8](xp, pb + t + k2), av)
                    k2 = k2 + u32(1)
                end
                store(out, xo + t, av)
                t = t + u32(8)
            end
            while t < nt do
                mut sc0 = f32(0.0)
                mut k3 = u32(0)
                while k3 < kk do
                    sc0 = sc0 + w[wo + k3] * xp[pb + t + k3]
                    k3 = k3 + u32(1)
                end
                out[xo + t] = sc0
                t = t + u32(1)
            end
            gi = gi + u32(1)
        end
        bi = bi + u32(1)
    end
end

pub fn depth_space(h: f32[], nb: u32, nf: u32, dm: u32, nc: u32, nt: u32,
                   w: f32[], out: f32[])
    mut ng = nf * dm
    mut ostride = ng * nt
    mut hstride = nf * nc * nt
    mut bi = u32(0)
    while bi < nb do
        mut gi = u32(0)
        while gi < ng do
            mut fi = gi / dm
            mut oo = bi * ng * nt + gi * nt
            mut hb = bi * hstride + fi * nc * nt
            mut wo = gi * nc
            mut t = u32(0)
            while t + u32(32) <= nt do
                mut a0 = simd[f32, 8](f32(0.0))
                mut a1 = simd[f32, 8](f32(0.0))
                mut a2 = simd[f32, 8](f32(0.0))
                mut a3 = simd[f32, 8](f32(0.0))
                mut ci = u32(0)
                while ci < nc do
                    mut wv = simd[f32, 8](w[wo + ci])
                    mut ho = hb + ci * nt + t
                    a0 = fma(wv, simd[f32, 8](h, ho + u32(0)), a0)
                    a1 = fma(wv, simd[f32, 8](h, ho + u32(8)), a1)
                    a2 = fma(wv, simd[f32, 8](h, ho + u32(16)), a2)
                    a3 = fma(wv, simd[f32, 8](h, ho + u32(24)), a3)
                    ci = ci + u32(1)
                end
                store(out, oo + t + u32(0), a0)
                store(out, oo + t + u32(8), a1)
                store(out, oo + t + u32(16), a2)
                store(out, oo + t + u32(24), a3)
                t = t + u32(32)
            end
            while t + u32(8) <= nt do
                mut av = simd[f32, 8](f32(0.0))
                mut c2 = u32(0)
                while c2 < nc do
                    av = fma(simd[f32, 8](w[wo + c2]),
                             simd[f32, 8](h, hb + c2 * nt + t), av)
                    c2 = c2 + u32(1)
                end
                store(out, oo + t, av)
                t = t + u32(8)
            end
            while t < nt do
                mut sc1 = f32(0.0)
                mut c3 = u32(0)
                while c3 < nc do
                    sc1 = sc1 + w[wo + c3] * h[hb + c3 * nt + t]
                    c3 = c3 + u32(1)
                end
                out[oo + t] = sc1
                t = t + u32(1)
            end
            gi = gi + u32(1)
        end
        bi = bi + u32(1)
    end
end

pub fn point_mix(x: f32[], nb: u32, ng: u32, nt: u32,
                 w: f32[], nm: u32, out: f32[])
    mut ostride = nm * nt
    mut xstride = ng * nt
    mut bi = u32(0)
    while bi < nb do
        mut mi = u32(0)
        while mi < nm do
            mut oo = bi * ostride + mi * nt
            mut xb = bi * xstride
            mut wo = mi * ng
            mut t = u32(0)
            while t + u32(32) <= nt do
                mut a0 = simd[f32, 8](f32(0.0))
                mut a1 = simd[f32, 8](f32(0.0))
                mut a2 = simd[f32, 8](f32(0.0))
                mut a3 = simd[f32, 8](f32(0.0))
                mut gi = u32(0)
                while gi < ng do
                    mut wv = simd[f32, 8](w[wo + gi])
                    mut xo = xb + gi * nt + t
                    a0 = fma(wv, simd[f32, 8](x, xo + u32(0)), a0)
                    a1 = fma(wv, simd[f32, 8](x, xo + u32(8)), a1)
                    a2 = fma(wv, simd[f32, 8](x, xo + u32(16)), a2)
                    a3 = fma(wv, simd[f32, 8](x, xo + u32(24)), a3)
                    gi = gi + u32(1)
                end
                store(out, oo + t + u32(0), a0)
                store(out, oo + t + u32(8), a1)
                store(out, oo + t + u32(16), a2)
                store(out, oo + t + u32(24), a3)
                t = t + u32(32)
            end
            while t + u32(8) <= nt do
                mut av = simd[f32, 8](f32(0.0))
                mut g2 = u32(0)
                while g2 < ng do
                    av = fma(simd[f32, 8](w[wo + g2]),
                             simd[f32, 8](x, xb + g2 * nt + t), av)
                    g2 = g2 + u32(1)
                end
                store(out, oo + t, av)
                t = t + u32(8)
            end
            while t < nt do
                mut sc2 = f32(0.0)
                mut g3 = u32(0)
                while g3 < ng do
                    sc2 = sc2 + w[wo + g3] * x[xb + g3 * nt + t]
                    g3 = g3 + u32(1)
                end
                out[oo + t] = sc2
                t = t + u32(1)
            end
            mi = mi + u32(1)
        end
        bi = bi + u32(1)
    end
end

pub fn avgpool(x: f32[], nb: u32, nch: u32, nt: u32, pk: u32, out: f32[])
    mut no = nt / pk
    mut inv = f32(1.0) / f32(i32(pk))
    mut i = u32(0)
    while i < nb * nch do
        mut xo = i * nt
        mut oo = i * no
        mut o = u32(0)
        while o < no do
            mut acc = f32(0.0)
            mut k = u32(0)
            while k < pk do
                acc = acc + x[xo + o * pk + k]
                k = k + u32(1)
            end
            out[oo + o] = acc * inv
            o = o + u32(1)
        end
        i = i + u32(1)
    end
end

pub fn depth_space_back(h: f32[], dout: f32[], nb: u32, nf: u32, dm: u32,
                        nc: u32, nt: u32, w: f32[], dw: f32[], dh: f32[])
    mut ng = nf * dm
    mut bi = u32(0)
    while bi < nb do
        mut fi = u32(0)
        while fi < nf do
            mut ci = u32(0)
            while ci < nc do
                mut ho = bi * nf * nc * nt + fi * nc * nt + ci * nt
                mut t = u32(0)
                while t + u32(8) <= nt do
                    mut acc = simd[f32, 8](f32(0.0))
                    mut di = u32(0)
                    while di < dm do
                        mut gi = fi * dm + di
                        acc = fma(simd[f32, 8](w[gi * nc + ci]),
                                  simd[f32, 8](dout, bi * ng * nt + gi * nt + t),
                                  acc)
                        di = di + u32(1)
                    end
                    store(dh, ho + t, acc)
                    t = t + u32(8)
                end
                while t < nt do
                    mut sc = f32(0.0)
                    mut d2 = u32(0)
                    while d2 < dm do
                        mut g2 = fi * dm + d2
                        sc = sc + w[g2 * nc + ci] * dout[bi * ng * nt + g2 * nt + t]
                        d2 = d2 + u32(1)
                    end
                    dh[ho + t] = sc
                    t = t + u32(1)
                end
                ci = ci + u32(1)
            end
            fi = fi + u32(1)
        end
        bi = bi + u32(1)
    end
    mut gi2 = u32(0)
    while gi2 < ng do
        mut f2 = gi2 / dm
        mut c4 = u32(0)
        while c4 + u32(4) <= nc do
            mut q0 = simd[f32, 8](f32(0.0))
            mut q1 = simd[f32, 8](f32(0.0))
            mut q2 = simd[f32, 8](f32(0.0))
            mut q3 = simd[f32, 8](f32(0.0))
            mut s0 = f32(0.0)
            mut s1 = f32(0.0)
            mut s2 = f32(0.0)
            mut s3 = f32(0.0)
            mut b2 = u32(0)
            while b2 < nb do
                mut go = b2 * ng * nt + gi2 * nt
                mut hb = b2 * nf * nc * nt + f2 * nc * nt
                mut t2 = u32(0)
                while t2 + u32(8) <= nt do
                    mut dv = simd[f32, 8](dout, go + t2)
                    q0 = fma(dv, simd[f32, 8](h, hb + c4 * nt + t2), q0)
                    q1 = fma(dv, simd[f32, 8](h, hb + (c4 + u32(1)) * nt + t2), q1)
                    q2 = fma(dv, simd[f32, 8](h, hb + (c4 + u32(2)) * nt + t2), q2)
                    q3 = fma(dv, simd[f32, 8](h, hb + (c4 + u32(3)) * nt + t2), q3)
                    t2 = t2 + u32(8)
                end
                mut tr = nt / u32(8) * u32(8)
                while tr < nt do
                    mut dv2 = dout[go + tr]
                    s0 = s0 + dv2 * h[hb + c4 * nt + tr]
                    s1 = s1 + dv2 * h[hb + (c4 + u32(1)) * nt + tr]
                    s2 = s2 + dv2 * h[hb + (c4 + u32(2)) * nt + tr]
                    s3 = s3 + dv2 * h[hb + (c4 + u32(3)) * nt + tr]
                    tr = tr + u32(1)
                end
                b2 = b2 + u32(1)
            end
            dw[gi2 * nc + c4] = dw[gi2 * nc + c4] + hsum(q0) + s0
            dw[gi2 * nc + c4 + u32(1)] = dw[gi2 * nc + c4 + u32(1)] + hsum(q1) + s1
            dw[gi2 * nc + c4 + u32(2)] = dw[gi2 * nc + c4 + u32(2)] + hsum(q2) + s2
            dw[gi2 * nc + c4 + u32(3)] = dw[gi2 * nc + c4 + u32(3)] + hsum(q3) + s3
            c4 = c4 + u32(4)
        end
        while c4 < nc do
            mut qv = simd[f32, 8](f32(0.0))
            mut sc2 = f32(0.0)
            mut b3 = u32(0)
            while b3 < nb do
                mut go2 = b3 * ng * nt + gi2 * nt
                mut hb2 = b3 * nf * nc * nt + f2 * nc * nt
                mut t3 = u32(0)
                while t3 + u32(8) <= nt do
                    qv = fma(simd[f32, 8](dout, go2 + t3),
                             simd[f32, 8](h, hb2 + c4 * nt + t3), qv)
                    t3 = t3 + u32(8)
                end
                while t3 < nt do
                    sc2 = sc2 + dout[go2 + t3] * h[hb2 + c4 * nt + t3]
                    t3 = t3 + u32(1)
                end
                b3 = b3 + u32(1)
            end
            dw[gi2 * nc + c4] = dw[gi2 * nc + c4] + hsum(qv) + sc2
            c4 = c4 + u32(1)
        end
        gi2 = gi2 + u32(1)
    end
end

pub fn time_depth_back(x: f32[], dout: f32[], nb: u32, ng: u32, nt: u32,
                       w: f32[], kk: u32, dw: f32[], dx: f32[])
    mut lpad = (kk - u32(1)) / u32(2)
    mut rpad = kk - u32(1) - lpad
    mut np = nt + kk
    mut dp = array[f32](nb * ng * np)
    mut xp = array[f32](nb * ng * np)
    mut i = u32(0)
    while i < nb * ng do
        mut so = i * nt
        mut dq = i * np + rpad
        mut xq = i * np + lpad
        mut t = u32(0)
        while t + u32(8) <= nt do
            store(dp, dq + t, simd[f32, 8](dout, so + t))
            store(xp, xq + t, simd[f32, 8](x, so + t))
            t = t + u32(8)
        end
        while t < nt do
            dp[dq + t] = dout[so + t]
            xp[xq + t] = x[so + t]
            t = t + u32(1)
        end
        i = i + u32(1)
    end
    mut wr = array[f32](ng * kk)
    mut g0 = u32(0)
    while g0 < ng do
        mut j = u32(0)
        while j < kk do
            wr[g0 * kk + j] = w[g0 * kk + kk - u32(1) - j]
            j = j + u32(1)
        end
        g0 = g0 + u32(1)
    end
    mut bi = u32(0)
    while bi < nb do
        mut gi = u32(0)
        while gi < ng do
            mut o = (bi * ng + gi) * nt
            mut po = (bi * ng + gi) * np
            mut wo = gi * kk
            mut s = u32(0)
            while s + u32(16) <= nt do
                mut a0 = simd[f32, 8](f32(0.0))
                mut a1 = simd[f32, 8](f32(0.0))
                mut j2 = u32(0)
                while j2 < kk do
                    mut wv = simd[f32, 8](wr[wo + j2])
                    a0 = fma(wv, simd[f32, 8](dp, po + s + j2), a0)
                    a1 = fma(wv, simd[f32, 8](dp, po + s + j2 + u32(8)), a1)
                    j2 = j2 + u32(1)
                end
                store(dx, o + s, a0)
                store(dx, o + s + u32(8), a1)
                s = s + u32(16)
            end
            while s + u32(8) <= nt do
                mut av = simd[f32, 8](f32(0.0))
                mut j3 = u32(0)
                while j3 < kk do
                    av = fma(simd[f32, 8](wr[wo + j3]),
                             simd[f32, 8](dp, po + s + j3), av)
                    j3 = j3 + u32(1)
                end
                store(dx, o + s, av)
                s = s + u32(8)
            end
            while s < nt do
                mut sc = f32(0.0)
                mut j4 = u32(0)
                while j4 < kk do
                    sc = sc + wr[wo + j4] * dp[po + s + j4]
                    j4 = j4 + u32(1)
                end
                dx[o + s] = sc
                s = s + u32(1)
            end
            gi = gi + u32(1)
        end
        bi = bi + u32(1)
    end
    mut gj = u32(0)
    while gj < ng do
        mut k = u32(0)
        while k + u32(8) <= kk do
            mut c0 = simd[f32, 8](f32(0.0))
            mut c1 = simd[f32, 8](f32(0.0))
            mut c2 = simd[f32, 8](f32(0.0))
            mut c3 = simd[f32, 8](f32(0.0))
            mut c4 = simd[f32, 8](f32(0.0))
            mut c5 = simd[f32, 8](f32(0.0))
            mut c6 = simd[f32, 8](f32(0.0))
            mut c7 = simd[f32, 8](f32(0.0))
            mut b2 = u32(0)
            while b2 < nb do
                mut go = (b2 * ng + gj) * nt
                mut xo = (b2 * ng + gj) * np + k
                mut t2 = u32(0)
                while t2 + u32(8) <= nt do
                    mut dv = simd[f32, 8](dout, go + t2)
                    c0 = fma(dv, simd[f32, 8](xp, xo + t2 + u32(0)), c0)
                    c1 = fma(dv, simd[f32, 8](xp, xo + t2 + u32(1)), c1)
                    c2 = fma(dv, simd[f32, 8](xp, xo + t2 + u32(2)), c2)
                    c3 = fma(dv, simd[f32, 8](xp, xo + t2 + u32(3)), c3)
                    c4 = fma(dv, simd[f32, 8](xp, xo + t2 + u32(4)), c4)
                    c5 = fma(dv, simd[f32, 8](xp, xo + t2 + u32(5)), c5)
                    c6 = fma(dv, simd[f32, 8](xp, xo + t2 + u32(6)), c6)
                    c7 = fma(dv, simd[f32, 8](xp, xo + t2 + u32(7)), c7)
                    t2 = t2 + u32(8)
                end
                while t2 < nt do
                    mut dv2 = dout[go + t2]
                    dw[gj * kk + k + u32(0)] = dw[gj * kk + k + u32(0)] + dv2 * xp[xo + t2 + u32(0)]
                    dw[gj * kk + k + u32(1)] = dw[gj * kk + k + u32(1)] + dv2 * xp[xo + t2 + u32(1)]
                    dw[gj * kk + k + u32(2)] = dw[gj * kk + k + u32(2)] + dv2 * xp[xo + t2 + u32(2)]
                    dw[gj * kk + k + u32(3)] = dw[gj * kk + k + u32(3)] + dv2 * xp[xo + t2 + u32(3)]
                    dw[gj * kk + k + u32(4)] = dw[gj * kk + k + u32(4)] + dv2 * xp[xo + t2 + u32(4)]
                    dw[gj * kk + k + u32(5)] = dw[gj * kk + k + u32(5)] + dv2 * xp[xo + t2 + u32(5)]
                    dw[gj * kk + k + u32(6)] = dw[gj * kk + k + u32(6)] + dv2 * xp[xo + t2 + u32(6)]
                    dw[gj * kk + k + u32(7)] = dw[gj * kk + k + u32(7)] + dv2 * xp[xo + t2 + u32(7)]
                    t2 = t2 + u32(1)
                end
                b2 = b2 + u32(1)
            end
            dw[gj * kk + k + u32(0)] = dw[gj * kk + k + u32(0)] + hsum(c0)
            dw[gj * kk + k + u32(1)] = dw[gj * kk + k + u32(1)] + hsum(c1)
            dw[gj * kk + k + u32(2)] = dw[gj * kk + k + u32(2)] + hsum(c2)
            dw[gj * kk + k + u32(3)] = dw[gj * kk + k + u32(3)] + hsum(c3)
            dw[gj * kk + k + u32(4)] = dw[gj * kk + k + u32(4)] + hsum(c4)
            dw[gj * kk + k + u32(5)] = dw[gj * kk + k + u32(5)] + hsum(c5)
            dw[gj * kk + k + u32(6)] = dw[gj * kk + k + u32(6)] + hsum(c6)
            dw[gj * kk + k + u32(7)] = dw[gj * kk + k + u32(7)] + hsum(c7)
            k = k + u32(8)
        end
        while k < kk do
            mut cv = simd[f32, 8](f32(0.0))
            mut sc2 = f32(0.0)
            mut b3 = u32(0)
            while b3 < nb do
                mut go2 = (b3 * ng + gj) * nt
                mut xo2 = (b3 * ng + gj) * np + k
                mut t3 = u32(0)
                while t3 + u32(8) <= nt do
                    cv = fma(simd[f32, 8](dout, go2 + t3),
                             simd[f32, 8](xp, xo2 + t3), cv)
                    t3 = t3 + u32(8)
                end
                while t3 < nt do
                    sc2 = sc2 + dout[go2 + t3] * xp[xo2 + t3]
                    t3 = t3 + u32(1)
                end
                b3 = b3 + u32(1)
            end
            dw[gj * kk + k] = dw[gj * kk + k] + hsum(cv) + sc2
            k = k + u32(1)
        end
        gj = gj + u32(1)
    end
end

pub fn point_mix_back(x: f32[], dout: f32[], nb: u32, ng: u32, nt: u32,
                      w: f32[], nm: u32, dw: f32[], dx: f32[])
    mut bi = u32(0)
    while bi < nb do
        mut gi = u32(0)
        while gi < ng do
            mut xo = bi * ng * nt + gi * nt
            mut go0 = bi * nm * nt
            mut t = u32(0)
            while t + u32(8) <= nt do
                mut acc = simd[f32, 8](f32(0.0))
                mut mi = u32(0)
                while mi < nm do
                    acc = fma(simd[f32, 8](w[mi * ng + gi]),
                              simd[f32, 8](dout, go0 + mi * nt + t), acc)
                    mi = mi + u32(1)
                end
                store(dx, xo + t, acc)
                t = t + u32(8)
            end
            while t < nt do
                mut sc = f32(0.0)
                mut m2 = u32(0)
                while m2 < nm do
                    sc = sc + w[m2 * ng + gi] * dout[go0 + m2 * nt + t]
                    m2 = m2 + u32(1)
                end
                dx[xo + t] = sc
                t = t + u32(1)
            end
            gi = gi + u32(1)
        end
        bi = bi + u32(1)
    end
    mut mi2 = u32(0)
    while mi2 < nm do
        mut g2 = u32(0)
        while g2 < ng do
            mut av = simd[f32, 8](f32(0.0))
            mut acc2 = f32(0.0)
            mut b2 = u32(0)
            while b2 < nb do
                mut go = b2 * nm * nt + mi2 * nt
                mut xo2 = b2 * ng * nt + g2 * nt
                mut t2 = u32(0)
                while t2 + u32(8) <= nt do
                    av = fma(simd[f32, 8](dout, go + t2),
                             simd[f32, 8](x, xo2 + t2), av)
                    t2 = t2 + u32(8)
                end
                while t2 < nt do
                    acc2 = acc2 + dout[go + t2] * x[xo2 + t2]
                    t2 = t2 + u32(1)
                end
                b2 = b2 + u32(1)
            end
            dw[mi2 * ng + g2] = dw[mi2 * ng + g2] + hsum(av) + acc2
            g2 = g2 + u32(1)
        end
        mi2 = mi2 + u32(1)
    end
end

pub fn avgpool_back(dout: f32[], nb: u32, nch: u32, nt: u32, pk: u32, dx: f32[])
    mut no = nt / pk
    mut inv = f32(1.0) / f32(i32(pk))
    mut i = u32(0)
    while i < nb * nch do
        mut oo = i * no
        mut xo = i * nt
        mut o = u32(0)
        while o < no do
            mut g = dout[oo + o] * inv
            mut k = u32(0)
            while k < pk do
                dx[xo + o * pk + k] = g
                k = k + u32(1)
            end
            o = o + u32(1)
        end
        i = i + u32(1)
    end
end
