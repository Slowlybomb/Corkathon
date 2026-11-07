mut vc = require("../math/vector.cy")
mut sc = require("../math/scalar.cy")

pub fn elu_pool_drop(x: f32[], nb: u32, nch: u32, nt: u32, pk: u32,
                     m: f32[], e: f32[], out: f32[])
    mut no = nt / pk
    mut rs = no * pk
    mut inv = f32(1.0) / f32(i32(pk))
    if rs == nt then
        mut i = u32(0)
        while i < nb * nch do
            mut xo = i * no * pk
            mut t = u32(0)
            while t + u32(8) <= no * pk do
                mut v = simd[f32, 8](x, xo + t)
                store(e, xo + t, select(v > simd[f32, 8](f32(0.0)), v, vc.expv(v) - simd[f32, 8](f32(1.0))))
                t = t + u32(8)
            end
            while t < no * pk do
                mut v2 = x[xo + t]
                if v2 > f32(0.0) then
                    e[xo + t] = v2
                else
                    e[xo + t] = sc.expm1(v2)
                end
                t = t + u32(1)
            end
            mut o = u32(0)
            while o < no do
                mut acc = f32(0.0)
                mut k = u32(0)
                while k < pk do
                    acc = acc + e[(i * no + o) * pk + k]
                    k = k + u32(1)
                end
                out[i * no + o] = acc * inv * m[i * no + o]
                o = o + u32(1)
            end
            i = i + u32(1)
        end
    else
        mut i2 = u32(0)
        while i2 < nb * nch do
            mut xo2 = i2 * nt
            mut oo2 = i2 * no
            mut t2 = u32(0)
            while t2 < nt do
                mut v3 = x[xo2 + t2]
                if v3 > f32(0.0) then
                    e[xo2 + t2] = v3
                else
                    e[xo2 + t2] = sc.expm1(v3)
                end
                t2 = t2 + u32(1)
            end
            mut o2 = u32(0)
            while o2 < no do
                mut acc2 = f32(0.0)
                mut k2 = u32(0)
                while k2 < pk do
                    acc2 = acc2 + e[xo2 + o2 * pk + k2]
                    k2 = k2 + u32(1)
                end
                out[oo2 + o2] = acc2 * inv * m[oo2 + o2]
                o2 = o2 + u32(1)
            end
            i2 = i2 + u32(1)
        end
    end
end

pub fn elu_pool_drop_back(dout: f32[], m: f32[], e: f32[], nb: u32, nch: u32,
                          nt: u32, pk: u32, dx: f32[])
    mut no = nt / pk
    mut rs = no * pk
    mut inv = f32(1.0) / f32(i32(pk))
    if rs == nt then
        mut i = u32(0)
        while i < nb * nch do
            mut o = u32(0)
            while o < no do
                mut g = dout[i * no + o] * inv * m[i * no + o]
                mut gv = simd[f32, 8](g)
                mut k = u32(0)
                while k + u32(8) <= pk do
                    mut ev = simd[f32, 8](e, (i * no + o) * pk + k)
                    store(dx, (i * no + o) * pk + k, gv * min(simd[f32, 8](f32(1.0)), ev + simd[f32, 8](f32(1.0))))
                    k = k + u32(8)
                end
                while k < pk do
                    mut ez = e[(i * no + o) * pk + k]
                    dx[(i * no + o) * pk + k] = g * min(f32(1.0), ez + f32(1.0))
                    k = k + u32(1)
                end
                o = o + u32(1)
            end
            i = i + u32(1)
        end
    else
        mut i2 = u32(0)
        while i2 < nb * nch do
            mut xo2 = i2 * nt
            mut oo2 = i2 * no
            mut o2 = u32(0)
            while o2 < no do
                mut g2 = dout[oo2 + o2] * inv * m[oo2 + o2]
                mut k2 = u32(0)
                while k2 < pk do
                    mut ez2 = e[xo2 + o2 * pk + k2]
                    dx[xo2 + o2 * pk + k2] = g2 * min(f32(1.0), ez2 + f32(1.0))
                    k2 = k2 + u32(1)
                end
                o2 = o2 + u32(1)
            end
            i2 = i2 + u32(1)
        end
    end
end

pub fn ones(m: f32[], n: u32)
    mut i = u32(0)
    while i + u32(8) <= n do
        store(m, i, simd[f32, 8](f32(1.0)))
        i = i + u32(8)
    end
    while i < n do
        m[i] = f32(1.0)
        i = i + u32(1)
    end
end
