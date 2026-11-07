mut m = require("../math/scalar.cy")

pub fn setup(n: u32, lo: u32, count: u32, coef: f32[])
    mut upto = (count + u32(7)) / u32(8) * u32(8)
    mut z = count
    while z < upto do
        coef[z] = f32(0.0)
        z = z + u32(1)
    end
    mut i = u32(0)
    while i < count do
        mut th = f32(6.2831853) * f32(i32(lo + i)) / f32(i32(n))
        coef[i] = f32(2.0) * m.cos(th)
        i = i + u32(1)
    end
end

pub fn powers(x: f32[], xo: u32, n: u32, win: f32[], coef: f32[],
              count: u32, out: f32[], oo: u32)
    mut j = u32(0)
    while j < count do
        mut c = coef[j]
        mut s1 = f32(0.0)
        mut s2 = f32(0.0)
        mut t = u32(0)
        while t < n do
            mut s = x[xo + t] * win[t] + c * s1 - s2
            s2 = s1
            s1 = s
            t = t + u32(1)
        end
        out[oo + j] = s1 * s1 + s2 * s2 - c * s1 * s2
        j = j + u32(1)
    end
end

pub fn band5(x: f32[], xo: u32, n: u32, win: f32[], coef: f32[], kb: u32[])
          -> (f32, f32, f32, f32, f32, f32)
    mut lo = kb[u32(0)]
    mut nbin = kb[u32(5)] - lo
    mut acc0 = f32(0.0)
    mut acc1 = f32(0.0)
    mut acc2 = f32(0.0)
    mut acc3 = f32(0.0)
    mut acc4 = f32(0.0)
    mut nproc = (nbin + u32(7)) / u32(8) * u32(8)
    mut gi = u32(0)
    while gi + u32(24) <= nproc do
        mut c0 = simd[f32, 8](coef, gi + u32(0))
        mut p0 = simd[f32, 8](f32(0.0))
        mut q0 = simd[f32, 8](f32(0.0))
        mut c1 = simd[f32, 8](coef, gi + u32(8))
        mut p1 = simd[f32, 8](f32(0.0))
        mut q1 = simd[f32, 8](f32(0.0))
        mut c2 = simd[f32, 8](coef, gi + u32(16))
        mut p2 = simd[f32, 8](f32(0.0))
        mut q2 = simd[f32, 8](f32(0.0))
        mut t = u32(0)
        while t < n do
            mut xw = simd[f32, 8](x[xo + t] * win[t])
            mut s0 = fma(c0, p0, xw - q0)
            mut s1 = fma(c1, p1, xw - q1)
            mut s2 = fma(c2, p2, xw - q2)
            q0 = p0
            p0 = s0
            q1 = p1
            p1 = s1
            q2 = p2
            p2 = s2
            t = t + u32(1)
        end
        mut w0 = p0 * p0 + q0 * q0 - c0 * p0 * q0
        mut w1 = p1 * p1 + q1 * q1 - c1 * p1 * q1
        mut w2 = p2 * p2 + q2 * q2 - c2 * p2 * q2
        mut k0_0 = lo + gi + u32(0)
        mut v0_0 = w0[0]
        if k0_0 < kb[u32(5)] then
        if k0_0 < kb[u32(1)] then
            acc0 = acc0 + v0_0
        else
            if k0_0 < kb[u32(2)] then
                acc1 = acc1 + v0_0
            else
                if k0_0 < kb[u32(3)] then
                    acc2 = acc2 + v0_0
                else
                    if k0_0 < kb[u32(4)] then
                        acc3 = acc3 + v0_0
                    else
                        acc4 = acc4 + v0_0
                    end
                end
            end
        end
        end
        mut k0_1 = lo + gi + u32(1)
        mut v0_1 = w0[1]
        if k0_1 < kb[u32(5)] then
        if k0_1 < kb[u32(1)] then
            acc0 = acc0 + v0_1
        else
            if k0_1 < kb[u32(2)] then
                acc1 = acc1 + v0_1
            else
                if k0_1 < kb[u32(3)] then
                    acc2 = acc2 + v0_1
                else
                    if k0_1 < kb[u32(4)] then
                        acc3 = acc3 + v0_1
                    else
                        acc4 = acc4 + v0_1
                    end
                end
            end
        end
        end
        mut k0_2 = lo + gi + u32(2)
        mut v0_2 = w0[2]
        if k0_2 < kb[u32(5)] then
        if k0_2 < kb[u32(1)] then
            acc0 = acc0 + v0_2
        else
            if k0_2 < kb[u32(2)] then
                acc1 = acc1 + v0_2
            else
                if k0_2 < kb[u32(3)] then
                    acc2 = acc2 + v0_2
                else
                    if k0_2 < kb[u32(4)] then
                        acc3 = acc3 + v0_2
                    else
                        acc4 = acc4 + v0_2
                    end
                end
            end
        end
        end
        mut k0_3 = lo + gi + u32(3)
        mut v0_3 = w0[3]
        if k0_3 < kb[u32(5)] then
        if k0_3 < kb[u32(1)] then
            acc0 = acc0 + v0_3
        else
            if k0_3 < kb[u32(2)] then
                acc1 = acc1 + v0_3
            else
                if k0_3 < kb[u32(3)] then
                    acc2 = acc2 + v0_3
                else
                    if k0_3 < kb[u32(4)] then
                        acc3 = acc3 + v0_3
                    else
                        acc4 = acc4 + v0_3
                    end
                end
            end
        end
        end
        mut k0_4 = lo + gi + u32(4)
        mut v0_4 = w0[4]
        if k0_4 < kb[u32(5)] then
        if k0_4 < kb[u32(1)] then
            acc0 = acc0 + v0_4
        else
            if k0_4 < kb[u32(2)] then
                acc1 = acc1 + v0_4
            else
                if k0_4 < kb[u32(3)] then
                    acc2 = acc2 + v0_4
                else
                    if k0_4 < kb[u32(4)] then
                        acc3 = acc3 + v0_4
                    else
                        acc4 = acc4 + v0_4
                    end
                end
            end
        end
        end
        mut k0_5 = lo + gi + u32(5)
        mut v0_5 = w0[5]
        if k0_5 < kb[u32(5)] then
        if k0_5 < kb[u32(1)] then
            acc0 = acc0 + v0_5
        else
            if k0_5 < kb[u32(2)] then
                acc1 = acc1 + v0_5
            else
                if k0_5 < kb[u32(3)] then
                    acc2 = acc2 + v0_5
                else
                    if k0_5 < kb[u32(4)] then
                        acc3 = acc3 + v0_5
                    else
                        acc4 = acc4 + v0_5
                    end
                end
            end
        end
        end
        mut k0_6 = lo + gi + u32(6)
        mut v0_6 = w0[6]
        if k0_6 < kb[u32(5)] then
        if k0_6 < kb[u32(1)] then
            acc0 = acc0 + v0_6
        else
            if k0_6 < kb[u32(2)] then
                acc1 = acc1 + v0_6
            else
                if k0_6 < kb[u32(3)] then
                    acc2 = acc2 + v0_6
                else
                    if k0_6 < kb[u32(4)] then
                        acc3 = acc3 + v0_6
                    else
                        acc4 = acc4 + v0_6
                    end
                end
            end
        end
        end
        mut k0_7 = lo + gi + u32(7)
        mut v0_7 = w0[7]
        if k0_7 < kb[u32(5)] then
        if k0_7 < kb[u32(1)] then
            acc0 = acc0 + v0_7
        else
            if k0_7 < kb[u32(2)] then
                acc1 = acc1 + v0_7
            else
                if k0_7 < kb[u32(3)] then
                    acc2 = acc2 + v0_7
                else
                    if k0_7 < kb[u32(4)] then
                        acc3 = acc3 + v0_7
                    else
                        acc4 = acc4 + v0_7
                    end
                end
            end
        end
        end
        mut k1_0 = lo + gi + u32(8)
        mut v1_0 = w1[0]
        if k1_0 < kb[u32(5)] then
        if k1_0 < kb[u32(1)] then
            acc0 = acc0 + v1_0
        else
            if k1_0 < kb[u32(2)] then
                acc1 = acc1 + v1_0
            else
                if k1_0 < kb[u32(3)] then
                    acc2 = acc2 + v1_0
                else
                    if k1_0 < kb[u32(4)] then
                        acc3 = acc3 + v1_0
                    else
                        acc4 = acc4 + v1_0
                    end
                end
            end
        end
        end
        mut k1_1 = lo + gi + u32(9)
        mut v1_1 = w1[1]
        if k1_1 < kb[u32(5)] then
        if k1_1 < kb[u32(1)] then
            acc0 = acc0 + v1_1
        else
            if k1_1 < kb[u32(2)] then
                acc1 = acc1 + v1_1
            else
                if k1_1 < kb[u32(3)] then
                    acc2 = acc2 + v1_1
                else
                    if k1_1 < kb[u32(4)] then
                        acc3 = acc3 + v1_1
                    else
                        acc4 = acc4 + v1_1
                    end
                end
            end
        end
        end
        mut k1_2 = lo + gi + u32(10)
        mut v1_2 = w1[2]
        if k1_2 < kb[u32(5)] then
        if k1_2 < kb[u32(1)] then
            acc0 = acc0 + v1_2
        else
            if k1_2 < kb[u32(2)] then
                acc1 = acc1 + v1_2
            else
                if k1_2 < kb[u32(3)] then
                    acc2 = acc2 + v1_2
                else
                    if k1_2 < kb[u32(4)] then
                        acc3 = acc3 + v1_2
                    else
                        acc4 = acc4 + v1_2
                    end
                end
            end
        end
        end
        mut k1_3 = lo + gi + u32(11)
        mut v1_3 = w1[3]
        if k1_3 < kb[u32(5)] then
        if k1_3 < kb[u32(1)] then
            acc0 = acc0 + v1_3
        else
            if k1_3 < kb[u32(2)] then
                acc1 = acc1 + v1_3
            else
                if k1_3 < kb[u32(3)] then
                    acc2 = acc2 + v1_3
                else
                    if k1_3 < kb[u32(4)] then
                        acc3 = acc3 + v1_3
                    else
                        acc4 = acc4 + v1_3
                    end
                end
            end
        end
        end
        mut k1_4 = lo + gi + u32(12)
        mut v1_4 = w1[4]
        if k1_4 < kb[u32(5)] then
        if k1_4 < kb[u32(1)] then
            acc0 = acc0 + v1_4
        else
            if k1_4 < kb[u32(2)] then
                acc1 = acc1 + v1_4
            else
                if k1_4 < kb[u32(3)] then
                    acc2 = acc2 + v1_4
                else
                    if k1_4 < kb[u32(4)] then
                        acc3 = acc3 + v1_4
                    else
                        acc4 = acc4 + v1_4
                    end
                end
            end
        end
        end
        mut k1_5 = lo + gi + u32(13)
        mut v1_5 = w1[5]
        if k1_5 < kb[u32(5)] then
        if k1_5 < kb[u32(1)] then
            acc0 = acc0 + v1_5
        else
            if k1_5 < kb[u32(2)] then
                acc1 = acc1 + v1_5
            else
                if k1_5 < kb[u32(3)] then
                    acc2 = acc2 + v1_5
                else
                    if k1_5 < kb[u32(4)] then
                        acc3 = acc3 + v1_5
                    else
                        acc4 = acc4 + v1_5
                    end
                end
            end
        end
        end
        mut k1_6 = lo + gi + u32(14)
        mut v1_6 = w1[6]
        if k1_6 < kb[u32(5)] then
        if k1_6 < kb[u32(1)] then
            acc0 = acc0 + v1_6
        else
            if k1_6 < kb[u32(2)] then
                acc1 = acc1 + v1_6
            else
                if k1_6 < kb[u32(3)] then
                    acc2 = acc2 + v1_6
                else
                    if k1_6 < kb[u32(4)] then
                        acc3 = acc3 + v1_6
                    else
                        acc4 = acc4 + v1_6
                    end
                end
            end
        end
        end
        mut k1_7 = lo + gi + u32(15)
        mut v1_7 = w1[7]
        if k1_7 < kb[u32(5)] then
        if k1_7 < kb[u32(1)] then
            acc0 = acc0 + v1_7
        else
            if k1_7 < kb[u32(2)] then
                acc1 = acc1 + v1_7
            else
                if k1_7 < kb[u32(3)] then
                    acc2 = acc2 + v1_7
                else
                    if k1_7 < kb[u32(4)] then
                        acc3 = acc3 + v1_7
                    else
                        acc4 = acc4 + v1_7
                    end
                end
            end
        end
        end
        mut k2_0 = lo + gi + u32(16)
        mut v2_0 = w2[0]
        if k2_0 < kb[u32(5)] then
        if k2_0 < kb[u32(1)] then
            acc0 = acc0 + v2_0
        else
            if k2_0 < kb[u32(2)] then
                acc1 = acc1 + v2_0
            else
                if k2_0 < kb[u32(3)] then
                    acc2 = acc2 + v2_0
                else
                    if k2_0 < kb[u32(4)] then
                        acc3 = acc3 + v2_0
                    else
                        acc4 = acc4 + v2_0
                    end
                end
            end
        end
        end
        mut k2_1 = lo + gi + u32(17)
        mut v2_1 = w2[1]
        if k2_1 < kb[u32(5)] then
        if k2_1 < kb[u32(1)] then
            acc0 = acc0 + v2_1
        else
            if k2_1 < kb[u32(2)] then
                acc1 = acc1 + v2_1
            else
                if k2_1 < kb[u32(3)] then
                    acc2 = acc2 + v2_1
                else
                    if k2_1 < kb[u32(4)] then
                        acc3 = acc3 + v2_1
                    else
                        acc4 = acc4 + v2_1
                    end
                end
            end
        end
        end
        mut k2_2 = lo + gi + u32(18)
        mut v2_2 = w2[2]
        if k2_2 < kb[u32(5)] then
        if k2_2 < kb[u32(1)] then
            acc0 = acc0 + v2_2
        else
            if k2_2 < kb[u32(2)] then
                acc1 = acc1 + v2_2
            else
                if k2_2 < kb[u32(3)] then
                    acc2 = acc2 + v2_2
                else
                    if k2_2 < kb[u32(4)] then
                        acc3 = acc3 + v2_2
                    else
                        acc4 = acc4 + v2_2
                    end
                end
            end
        end
        end
        mut k2_3 = lo + gi + u32(19)
        mut v2_3 = w2[3]
        if k2_3 < kb[u32(5)] then
        if k2_3 < kb[u32(1)] then
            acc0 = acc0 + v2_3
        else
            if k2_3 < kb[u32(2)] then
                acc1 = acc1 + v2_3
            else
                if k2_3 < kb[u32(3)] then
                    acc2 = acc2 + v2_3
                else
                    if k2_3 < kb[u32(4)] then
                        acc3 = acc3 + v2_3
                    else
                        acc4 = acc4 + v2_3
                    end
                end
            end
        end
        end
        mut k2_4 = lo + gi + u32(20)
        mut v2_4 = w2[4]
        if k2_4 < kb[u32(5)] then
        if k2_4 < kb[u32(1)] then
            acc0 = acc0 + v2_4
        else
            if k2_4 < kb[u32(2)] then
                acc1 = acc1 + v2_4
            else
                if k2_4 < kb[u32(3)] then
                    acc2 = acc2 + v2_4
                else
                    if k2_4 < kb[u32(4)] then
                        acc3 = acc3 + v2_4
                    else
                        acc4 = acc4 + v2_4
                    end
                end
            end
        end
        end
        mut k2_5 = lo + gi + u32(21)
        mut v2_5 = w2[5]
        if k2_5 < kb[u32(5)] then
        if k2_5 < kb[u32(1)] then
            acc0 = acc0 + v2_5
        else
            if k2_5 < kb[u32(2)] then
                acc1 = acc1 + v2_5
            else
                if k2_5 < kb[u32(3)] then
                    acc2 = acc2 + v2_5
                else
                    if k2_5 < kb[u32(4)] then
                        acc3 = acc3 + v2_5
                    else
                        acc4 = acc4 + v2_5
                    end
                end
            end
        end
        end
        mut k2_6 = lo + gi + u32(22)
        mut v2_6 = w2[6]
        if k2_6 < kb[u32(5)] then
        if k2_6 < kb[u32(1)] then
            acc0 = acc0 + v2_6
        else
            if k2_6 < kb[u32(2)] then
                acc1 = acc1 + v2_6
            else
                if k2_6 < kb[u32(3)] then
                    acc2 = acc2 + v2_6
                else
                    if k2_6 < kb[u32(4)] then
                        acc3 = acc3 + v2_6
                    else
                        acc4 = acc4 + v2_6
                    end
                end
            end
        end
        end
        mut k2_7 = lo + gi + u32(23)
        mut v2_7 = w2[7]
        if k2_7 < kb[u32(5)] then
        if k2_7 < kb[u32(1)] then
            acc0 = acc0 + v2_7
        else
            if k2_7 < kb[u32(2)] then
                acc1 = acc1 + v2_7
            else
                if k2_7 < kb[u32(3)] then
                    acc2 = acc2 + v2_7
                else
                    if k2_7 < kb[u32(4)] then
                        acc3 = acc3 + v2_7
                    else
                        acc4 = acc4 + v2_7
                    end
                end
            end
        end
        end
        gi = gi + u32(24)
    end
    while gi + u32(8) <= nproc do
        mut cz = simd[f32, 8](coef, gi)
        mut pz = simd[f32, 8](f32(0.0))
        mut qz = simd[f32, 8](f32(0.0))
        mut tz = u32(0)
        while tz < n do
            mut xz = simd[f32, 8](x[xo + tz] * win[tz])
            mut sz = fma(cz, pz, xz - qz)
            qz = pz
            pz = sz
            tz = tz + u32(1)
        end
        mut wz = pz * pz + qz * qz - cz * pz * qz
        mut kz0 = lo + gi + u32(0)
        mut vz0 = wz[0]
        if kz0 < kb[u32(5)] then
        if kz0 < kb[u32(1)] then
            acc0 = acc0 + vz0
        else
            if kz0 < kb[u32(2)] then
                acc1 = acc1 + vz0
            else
                if kz0 < kb[u32(3)] then
                    acc2 = acc2 + vz0
                else
                    if kz0 < kb[u32(4)] then
                        acc3 = acc3 + vz0
                    else
                        acc4 = acc4 + vz0
                    end
                end
            end
        end
        end
        mut kz1 = lo + gi + u32(1)
        mut vz1 = wz[1]
        if kz1 < kb[u32(5)] then
        if kz1 < kb[u32(1)] then
            acc0 = acc0 + vz1
        else
            if kz1 < kb[u32(2)] then
                acc1 = acc1 + vz1
            else
                if kz1 < kb[u32(3)] then
                    acc2 = acc2 + vz1
                else
                    if kz1 < kb[u32(4)] then
                        acc3 = acc3 + vz1
                    else
                        acc4 = acc4 + vz1
                    end
                end
            end
        end
        end
        mut kz2 = lo + gi + u32(2)
        mut vz2 = wz[2]
        if kz2 < kb[u32(5)] then
        if kz2 < kb[u32(1)] then
            acc0 = acc0 + vz2
        else
            if kz2 < kb[u32(2)] then
                acc1 = acc1 + vz2
            else
                if kz2 < kb[u32(3)] then
                    acc2 = acc2 + vz2
                else
                    if kz2 < kb[u32(4)] then
                        acc3 = acc3 + vz2
                    else
                        acc4 = acc4 + vz2
                    end
                end
            end
        end
        end
        mut kz3 = lo + gi + u32(3)
        mut vz3 = wz[3]
        if kz3 < kb[u32(5)] then
        if kz3 < kb[u32(1)] then
            acc0 = acc0 + vz3
        else
            if kz3 < kb[u32(2)] then
                acc1 = acc1 + vz3
            else
                if kz3 < kb[u32(3)] then
                    acc2 = acc2 + vz3
                else
                    if kz3 < kb[u32(4)] then
                        acc3 = acc3 + vz3
                    else
                        acc4 = acc4 + vz3
                    end
                end
            end
        end
        end
        mut kz4 = lo + gi + u32(4)
        mut vz4 = wz[4]
        if kz4 < kb[u32(5)] then
        if kz4 < kb[u32(1)] then
            acc0 = acc0 + vz4
        else
            if kz4 < kb[u32(2)] then
                acc1 = acc1 + vz4
            else
                if kz4 < kb[u32(3)] then
                    acc2 = acc2 + vz4
                else
                    if kz4 < kb[u32(4)] then
                        acc3 = acc3 + vz4
                    else
                        acc4 = acc4 + vz4
                    end
                end
            end
        end
        end
        mut kz5 = lo + gi + u32(5)
        mut vz5 = wz[5]
        if kz5 < kb[u32(5)] then
        if kz5 < kb[u32(1)] then
            acc0 = acc0 + vz5
        else
            if kz5 < kb[u32(2)] then
                acc1 = acc1 + vz5
            else
                if kz5 < kb[u32(3)] then
                    acc2 = acc2 + vz5
                else
                    if kz5 < kb[u32(4)] then
                        acc3 = acc3 + vz5
                    else
                        acc4 = acc4 + vz5
                    end
                end
            end
        end
        end
        mut kz6 = lo + gi + u32(6)
        mut vz6 = wz[6]
        if kz6 < kb[u32(5)] then
        if kz6 < kb[u32(1)] then
            acc0 = acc0 + vz6
        else
            if kz6 < kb[u32(2)] then
                acc1 = acc1 + vz6
            else
                if kz6 < kb[u32(3)] then
                    acc2 = acc2 + vz6
                else
                    if kz6 < kb[u32(4)] then
                        acc3 = acc3 + vz6
                    else
                        acc4 = acc4 + vz6
                    end
                end
            end
        end
        end
        mut kz7 = lo + gi + u32(7)
        mut vz7 = wz[7]
        if kz7 < kb[u32(5)] then
        if kz7 < kb[u32(1)] then
            acc0 = acc0 + vz7
        else
            if kz7 < kb[u32(2)] then
                acc1 = acc1 + vz7
            else
                if kz7 < kb[u32(3)] then
                    acc2 = acc2 + vz7
                else
                    if kz7 < kb[u32(4)] then
                        acc3 = acc3 + vz7
                    else
                        acc4 = acc4 + vz7
                    end
                end
            end
        end
        end
        gi = gi + u32(8)
    end
    mut tot = f32(1.0e-20) + acc0 + acc1 + acc2 + acc3 + acc4
    return (acc0, acc1, acc2, acc3, acc4, tot)
end
