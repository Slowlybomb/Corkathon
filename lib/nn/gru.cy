mut dn = require("dense.cy")
mut gm = require("gemm.cy")
mut v = require("../math/vector.cy")
mut sc = require("../math/scalar.cy")

pub fn sequence(x: f32[], wi: f32[], bi: f32[], wh: f32[], bh: f32[],
                h: f32[], xh: f32[], hh: f32[], out: f32[],
                pwi: f32[], pwh: f32[], pa: f32[],
                seq: u32, batch: u32, nin: u32, hid: u32)
    mut g3 = hid * u32(3)
    mut fast = gm.fits(seq * batch, g3) and gm.fits(batch, g3)
    if fast then
        gm.pack_b(wi, pwi, nin, g3)
        gm.pack_b(wh, pwh, hid, g3)
        gm.pack_a(x, pa, seq * batch, nin)
        gm.gemm(pa, pwi, bi, xh, seq * batch, nin, g3)
    else
        dn.forward(x, wi, bi, xh, seq * batch, nin, g3)
    end
    mut t = u32(0)
    while t < seq do
        if fast then
            gm.pack_a(h, pa, batch, hid)
            gm.gemm(pa, pwh, bh, hh, batch, hid, g3)
        else
            dn.forward(h, wh, bh, hh, batch, hid, g3)
        end
        mut b = u32(0)
        while b < batch do
            mut xb = (t * batch + b) * g3
            mut hb = b * g3
            mut ob = (t * batch + b) * hid
            mut sb = b * hid
            mut j = u32(0)
            while j + u32(8) <= hid do
                mut rr = v.sigmoidv(simd[f32, 8](xh, xb + j) +
                                    simd[f32, 8](hh, hb + j))
                mut zz = v.sigmoidv(simd[f32, 8](xh, xb + hid + j) +
                                    simd[f32, 8](hh, hb + hid + j))
                mut nn = v.tanhv(simd[f32, 8](xh, xb + hid + hid + j) +
                                 rr * simd[f32, 8](hh, hb + hid + hid + j))
                mut hp = simd[f32, 8](h, sb + j)
                mut hn = (simd[f32, 8](f32(1.0)) - zz) * nn + zz * hp
                store(h, sb + j, hn)
                store(out, ob + j, hn)
                j = j + u32(8)
            end
            while j < hid do
                mut r1 = sc.sigmoid(xh[xb + j] + hh[hb + j])
                mut z1 = sc.sigmoid(xh[xb + hid + j] + hh[hb + hid + j])
                mut n1 = sc.tanh(xh[xb + hid + hid + j] +
                              r1 * hh[hb + hid + hid + j])
                mut h1 = (f32(1.0) - z1) * n1 + z1 * h[sb + j]
                h[sb + j] = h1
                out[ob + j] = h1
                j = j + u32(1)
            end
            b = b + u32(1)
        end
        t = t + u32(1)
    end
end
