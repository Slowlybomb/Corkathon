pub fn pack_b(w: f32[], bp: f32[], nin: u32, nout: u32)
    mut ob = u32(0)
    while ob + u32(16) <= nout do
        mut base = ob * nin
        mut k = u32(0)
        while k < nin do
            mut d = base + k * u32(16)
            mut j = u32(0)
            while j < u32(16) do
                bp[d + j] = w[(ob + j) * nin + k]
                j = j + u32(1)
            end
            k = k + u32(1)
        end
        ob = ob + u32(16)
    end
end

pub fn pack_a(x: f32[], ap: f32[], batch: u32, nin: u32)
    mut mb = u32(0)
    while mb + u32(4) <= batch do
        mut base = mb * nin
        mut k = u32(0)
        while k < nin do
            mut d = base + k * u32(4)
            ap[d] = x[(mb) * nin + k]
            ap[d + u32(1)] = x[(mb + u32(1)) * nin + k]
            ap[d + u32(2)] = x[(mb + u32(2)) * nin + k]
            ap[d + u32(3)] = x[(mb + u32(3)) * nin + k]
            k = k + u32(1)
        end
        mb = mb + u32(4)
    end
end

fn gemm_ob(ap: f32[], bp: f32[], bias: f32[], y: f32[],
           batch: u32, nin: u32, nout: u32)
    mut ob = u32(0)
    while ob + u32(16) <= nout do
        mut mb = u32(0)
        while mb + u32(4) <= batch do
            mut bs0 = simd[f32, 8](bias, ob)
            mut bs1 = simd[f32, 8](bias, ob + u32(8))
            mut y0 = mb * nout + ob
            mut y1 = y0 + nout
            mut y2 = y1 + nout
            mut y3 = y2 + nout
            mut c00 = simd[f32, 8](f32(0.0))
            mut c01 = simd[f32, 8](f32(0.0))
            mut c10 = simd[f32, 8](f32(0.0))
            mut c11 = simd[f32, 8](f32(0.0))
            mut c20 = simd[f32, 8](f32(0.0))
            mut c21 = simd[f32, 8](f32(0.0))
            mut c30 = simd[f32, 8](f32(0.0))
            mut c31 = simd[f32, 8](f32(0.0))
            mut pa = mb * nin
            mut pb = ob * nin
            mut k = u32(0)
            while k < nin do
                mut bv0 = simd[f32, 8](bp, pb)
                mut bv1 = simd[f32, 8](bp, pb + u32(8))
                c00 = fma(simd[f32, 8](ap[pa + u32(0)]), bv0, c00)
                c01 = fma(simd[f32, 8](ap[pa + u32(0)]), bv1, c01)
                c10 = fma(simd[f32, 8](ap[pa + u32(1)]), bv0, c10)
                c11 = fma(simd[f32, 8](ap[pa + u32(1)]), bv1, c11)
                c20 = fma(simd[f32, 8](ap[pa + u32(2)]), bv0, c20)
                c21 = fma(simd[f32, 8](ap[pa + u32(2)]), bv1, c21)
                c30 = fma(simd[f32, 8](ap[pa + u32(3)]), bv0, c30)
                c31 = fma(simd[f32, 8](ap[pa + u32(3)]), bv1, c31)
                pa = pa + u32(4)
                pb = pb + u32(16)
                k = k + u32(1)
            end
            store(y, y0, c00 + bs0)
            store(y, y0 + u32(8), c01 + bs1)
            store(y, y1, c10 + bs0)
            store(y, y1 + u32(8), c11 + bs1)
            store(y, y2, c20 + bs0)
            store(y, y2 + u32(8), c21 + bs1)
            store(y, y3, c30 + bs0)
            store(y, y3 + u32(8), c31 + bs1)
            mb = mb + u32(4)
        end
        ob = ob + u32(16)
    end
end

fn gemm_mb(ap: f32[], bp: f32[], bias: f32[], y: f32[],
           batch: u32, nin: u32, nout: u32)
    mut mb = u32(0)
    while mb + u32(4) <= batch do
        mut ob = u32(0)
        while ob + u32(16) <= nout do
            mut bs0 = simd[f32, 8](bias, ob)
            mut bs1 = simd[f32, 8](bias, ob + u32(8))
            mut y0 = mb * nout + ob
            mut y1 = y0 + nout
            mut y2 = y1 + nout
            mut y3 = y2 + nout
            mut c00 = simd[f32, 8](f32(0.0))
            mut c01 = simd[f32, 8](f32(0.0))
            mut c10 = simd[f32, 8](f32(0.0))
            mut c11 = simd[f32, 8](f32(0.0))
            mut c20 = simd[f32, 8](f32(0.0))
            mut c21 = simd[f32, 8](f32(0.0))
            mut c30 = simd[f32, 8](f32(0.0))
            mut c31 = simd[f32, 8](f32(0.0))
            mut pa = mb * nin
            mut pb = ob * nin
            mut k = u32(0)
            while k < nin do
                mut bv0 = simd[f32, 8](bp, pb)
                mut bv1 = simd[f32, 8](bp, pb + u32(8))
                c00 = fma(simd[f32, 8](ap[pa + u32(0)]), bv0, c00)
                c01 = fma(simd[f32, 8](ap[pa + u32(0)]), bv1, c01)
                c10 = fma(simd[f32, 8](ap[pa + u32(1)]), bv0, c10)
                c11 = fma(simd[f32, 8](ap[pa + u32(1)]), bv1, c11)
                c20 = fma(simd[f32, 8](ap[pa + u32(2)]), bv0, c20)
                c21 = fma(simd[f32, 8](ap[pa + u32(2)]), bv1, c21)
                c30 = fma(simd[f32, 8](ap[pa + u32(3)]), bv0, c30)
                c31 = fma(simd[f32, 8](ap[pa + u32(3)]), bv1, c31)
                pa = pa + u32(4)
                pb = pb + u32(16)
                k = k + u32(1)
            end
            store(y, y0, c00 + bs0)
            store(y, y0 + u32(8), c01 + bs1)
            store(y, y1, c10 + bs0)
            store(y, y1 + u32(8), c11 + bs1)
            store(y, y2, c20 + bs0)
            store(y, y2 + u32(8), c21 + bs1)
            store(y, y3, c30 + bs0)
            store(y, y3 + u32(8), c31 + bs1)
            ob = ob + u32(16)
        end
        mb = mb + u32(4)
    end
end

pub fn gemm(ap: f32[], bp: f32[], bias: f32[], y: f32[],
            batch: u32, nin: u32, nout: u32)
    if batch < u32(64) then
        gemm_ob(ap, bp, bias, y, batch, nin, nout)
    else
        gemm_mb(ap, bp, bias, y, batch, nin, nout)
    end
end

pub fn packed_b_size(nin: u32, nout: u32) -> u32
    return (nout / u32(16)) * u32(16) * nin
end

pub fn packed_a_size(batch: u32, nin: u32) -> u32
    return (batch / u32(4)) * u32(4) * nin
end

pub fn fits(batch: u32, nout: u32) -> bool
    return batch % u32(4) == u32(0) and nout % u32(16) == u32(0)
        and batch >= u32(4) and nout >= u32(16)
end
