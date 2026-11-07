mut m = require("../math/scalar.cy")

pub fn forward(x: f32[], w: f32[], bias: f32[], y: f32[],
               batch: u32, nin: u32, nout: u32)
    mut b = u32(0)
    while b < batch do
        mut o = u32(0)
        while o + u32(8) <= nout do
            mut a0 = simd[f32, 8](f32(0.0))
            mut a1 = simd[f32, 8](f32(0.0))
            mut a2 = simd[f32, 8](f32(0.0))
            mut a3 = simd[f32, 8](f32(0.0))
            mut a4 = simd[f32, 8](f32(0.0))
            mut a5 = simd[f32, 8](f32(0.0))
            mut a6 = simd[f32, 8](f32(0.0))
            mut a7 = simd[f32, 8](f32(0.0))
            mut r0 = o * nin
            mut k = u32(0)
            while k + u32(8) <= nin do
                mut xv = simd[f32, 8](x, b * nin + k)
                a0 = fma(xv, simd[f32, 8](w, r0 + k), a0)
                a1 = fma(xv, simd[f32, 8](w, r0 + nin + k), a1)
                a2 = fma(xv, simd[f32, 8](w, r0 + nin * u32(2) + k), a2)
                a3 = fma(xv, simd[f32, 8](w, r0 + nin * u32(3) + k), a3)
                a4 = fma(xv, simd[f32, 8](w, r0 + nin * u32(4) + k), a4)
                a5 = fma(xv, simd[f32, 8](w, r0 + nin * u32(5) + k), a5)
                a6 = fma(xv, simd[f32, 8](w, r0 + nin * u32(6) + k), a6)
                a7 = fma(xv, simd[f32, 8](w, r0 + nin * u32(7) + k), a7)
                k = k + u32(8)
            end
            mut s0 = hsum(a0)
            mut s1 = hsum(a1)
            mut s2 = hsum(a2)
            mut s3 = hsum(a3)
            mut s4 = hsum(a4)
            mut s5 = hsum(a5)
            mut s6 = hsum(a6)
            mut s7 = hsum(a7)
            mut t = k
            while t < nin do
                mut xt = x[b * nin + t]
                s0 = s0 + xt * w[r0 + t]
                s1 = s1 + xt * w[r0 + nin + t]
                s2 = s2 + xt * w[r0 + nin * u32(2) + t]
                s3 = s3 + xt * w[r0 + nin * u32(3) + t]
                s4 = s4 + xt * w[r0 + nin * u32(4) + t]
                s5 = s5 + xt * w[r0 + nin * u32(5) + t]
                s6 = s6 + xt * w[r0 + nin * u32(6) + t]
                s7 = s7 + xt * w[r0 + nin * u32(7) + t]
                t = t + u32(1)
            end
            mut yo = b * nout + o
            y[yo] = s0 + bias[o]
            y[yo + u32(1)] = s1 + bias[o + u32(1)]
            y[yo + u32(2)] = s2 + bias[o + u32(2)]
            y[yo + u32(3)] = s3 + bias[o + u32(3)]
            y[yo + u32(4)] = s4 + bias[o + u32(4)]
            y[yo + u32(5)] = s5 + bias[o + u32(5)]
            y[yo + u32(6)] = s6 + bias[o + u32(6)]
            y[yo + u32(7)] = s7 + bias[o + u32(7)]
            o = o + u32(8)
        end
        while o < nout do
            mut acc = simd[f32, 8](f32(0.0))
            mut k2 = u32(0)
            while k2 + u32(8) <= nin do
                acc = fma(simd[f32, 8](x, b * nin + k2),
                          simd[f32, 8](w, o * nin + k2), acc)
                k2 = k2 + u32(8)
            end
            mut s = hsum(acc)
            while k2 < nin do
                s = s + x[b * nin + k2] * w[o * nin + k2]
                k2 = k2 + u32(1)
            end
            y[b * nout + o] = s + bias[o]
            o = o + u32(1)
        end
        b = b + u32(1)
    end
end

pub fn backward(x: f32[], w: f32[], dy: f32[], dx: f32[], dw: f32[],
                db: f32[], batch: u32, nin: u32, nout: u32)
    input_gradient(w, dy, dx, batch, nin, nout)
    backward_weights(x, dy, dw, db, batch, nin, nout)
end

pub fn backward_weights(x: f32[], dy: f32[], dw: f32[], db: f32[],
                        batch: u32, nin: u32, nout: u32)
    mut o = u32(0)
    while o < nout do
        mut acc = f32(0.0)
        mut b = u32(0)
        while b < batch do
            acc = acc + dy[b * nout + o]
            b = b + u32(1)
        end
        db[o] = db[o] + acc
        o = o + u32(1)
    end
    mut n8 = nin / u32(8) * u32(8)
    mut nob = nout / u32(8)
    mut ob = u32(0)
    while ob < nob do
        mut k2 = u32(0)
        while k2 < n8 do
            mut c0 = simd[f32, 8](dw, (ob * u32(8)) * nin + k2)
            mut c1 = simd[f32, 8](dw, (ob * u32(8) + u32(1)) * nin + k2)
            mut c2 = simd[f32, 8](dw, (ob * u32(8) + u32(2)) * nin + k2)
            mut c3 = simd[f32, 8](dw, (ob * u32(8) + u32(3)) * nin + k2)
            mut c4 = simd[f32, 8](dw, (ob * u32(8) + u32(4)) * nin + k2)
            mut c5 = simd[f32, 8](dw, (ob * u32(8) + u32(5)) * nin + k2)
            mut c6 = simd[f32, 8](dw, (ob * u32(8) + u32(6)) * nin + k2)
            mut c7 = simd[f32, 8](dw, (ob * u32(8) + u32(7)) * nin + k2)
            mut b3 = u32(0)
            while b3 < batch do
                mut xv = simd[f32, 8](x, b3 * nin + k2)
                c0 = fma(simd[f32, 8](dy[b3 * nout + ob * u32(8)]), xv, c0)
                c1 = fma(simd[f32, 8](dy[b3 * nout + ob * u32(8) + u32(1)]), xv, c1)
                c2 = fma(simd[f32, 8](dy[b3 * nout + ob * u32(8) + u32(2)]), xv, c2)
                c3 = fma(simd[f32, 8](dy[b3 * nout + ob * u32(8) + u32(3)]), xv, c3)
                c4 = fma(simd[f32, 8](dy[b3 * nout + ob * u32(8) + u32(4)]), xv, c4)
                c5 = fma(simd[f32, 8](dy[b3 * nout + ob * u32(8) + u32(5)]), xv, c5)
                c6 = fma(simd[f32, 8](dy[b3 * nout + ob * u32(8) + u32(6)]), xv, c6)
                c7 = fma(simd[f32, 8](dy[b3 * nout + ob * u32(8) + u32(7)]), xv, c7)
                b3 = b3 + u32(1)
            end
            store(dw, (ob * u32(8)) * nin + k2, c0)
            store(dw, (ob * u32(8) + u32(1)) * nin + k2, c1)
            store(dw, (ob * u32(8) + u32(2)) * nin + k2, c2)
            store(dw, (ob * u32(8) + u32(3)) * nin + k2, c3)
            store(dw, (ob * u32(8) + u32(4)) * nin + k2, c4)
            store(dw, (ob * u32(8) + u32(5)) * nin + k2, c5)
            store(dw, (ob * u32(8) + u32(6)) * nin + k2, c6)
            store(dw, (ob * u32(8) + u32(7)) * nin + k2, c7)
            k2 = k2 + u32(8)
        end
        ob = ob + u32(1)
    end
    mut ot = u32(0)
    while ot < nob * u32(8) do
        mut kt = n8
        while kt < nin do
            mut t0 = dw[ot * nin + kt]
            mut b4 = u32(0)
            while b4 < batch do
                t0 = t0 + dy[b4 * nout + ot] * x[b4 * nin + kt]
                b4 = b4 + u32(1)
            end
            dw[ot * nin + kt] = t0
            kt = kt + u32(1)
        end
        ot = ot + u32(1)
    end
    mut o4 = nob * u32(8)
    while o4 < nout do
        mut k3 = u32(0)
        while k3 + u32(8) <= nin do
            mut cr = simd[f32, 8](dw, o4 * nin + k3)
            mut b5 = u32(0)
            while b5 < batch do
                cr = fma(simd[f32, 8](dy[b5 * nout + o4]),
                         simd[f32, 8](x, b5 * nin + k3), cr)
                b5 = b5 + u32(1)
            end
            store(dw, o4 * nin + k3, cr)
            k3 = k3 + u32(8)
        end
        while k3 < nin do
            mut tr = dw[o4 * nin + k3]
            mut b6 = u32(0)
            while b6 < batch do
                tr = tr + dy[b6 * nout + o4] * x[b6 * nin + k3]
                b6 = b6 + u32(1)
            end
            dw[o4 * nin + k3] = tr
            k3 = k3 + u32(1)
        end
        o4 = o4 + u32(1)
    end
end

pub fn input_gradient(w: f32[], dy: f32[], dx: f32[],
                      batch: u32, nin: u32, nout: u32)
    mut m8 = nin / u32(8) * u32(8)
    mut nbb = batch / u32(8)
    mut bb = u32(0)
    while bb < nbb do
        mut k = u32(0)
        while k < m8 do
            mut a0 = simd[f32, 8](f32(0.0))
            mut a1 = simd[f32, 8](f32(0.0))
            mut a2 = simd[f32, 8](f32(0.0))
            mut a3 = simd[f32, 8](f32(0.0))
            mut a4 = simd[f32, 8](f32(0.0))
            mut a5 = simd[f32, 8](f32(0.0))
            mut a6 = simd[f32, 8](f32(0.0))
            mut a7 = simd[f32, 8](f32(0.0))
            mut o2 = u32(0)
            while o2 < nout do
                mut wv = simd[f32, 8](w, o2 * nin + k)
                a0 = fma(simd[f32, 8](dy[(bb * u32(8)) * nout + o2]), wv, a0)
                a1 = fma(simd[f32, 8](dy[(bb * u32(8) + u32(1)) * nout + o2]), wv, a1)
                a2 = fma(simd[f32, 8](dy[(bb * u32(8) + u32(2)) * nout + o2]), wv, a2)
                a3 = fma(simd[f32, 8](dy[(bb * u32(8) + u32(3)) * nout + o2]), wv, a3)
                a4 = fma(simd[f32, 8](dy[(bb * u32(8) + u32(4)) * nout + o2]), wv, a4)
                a5 = fma(simd[f32, 8](dy[(bb * u32(8) + u32(5)) * nout + o2]), wv, a5)
                a6 = fma(simd[f32, 8](dy[(bb * u32(8) + u32(6)) * nout + o2]), wv, a6)
                a7 = fma(simd[f32, 8](dy[(bb * u32(8) + u32(7)) * nout + o2]), wv, a7)
                o2 = o2 + u32(1)
            end
            store(dx, (bb * u32(8)) * nin + k, a0)
            store(dx, (bb * u32(8) + u32(1)) * nin + k, a1)
            store(dx, (bb * u32(8) + u32(2)) * nin + k, a2)
            store(dx, (bb * u32(8) + u32(3)) * nin + k, a3)
            store(dx, (bb * u32(8) + u32(4)) * nin + k, a4)
            store(dx, (bb * u32(8) + u32(5)) * nin + k, a5)
            store(dx, (bb * u32(8) + u32(6)) * nin + k, a6)
            store(dx, (bb * u32(8) + u32(7)) * nin + k, a7)
            k = k + u32(8)
        end
        bb = bb + u32(1)
    end
    mut bt = u32(0)
    while bt < nbb * u32(8) do
        mut kt2 = m8
        while kt2 < nin do
            mut s0 = f32(0.0)
            mut o3 = u32(0)
            while o3 < nout do
                s0 = s0 + dy[bt * nout + o3] * w[o3 * nin + kt2]
                o3 = o3 + u32(1)
            end
            dx[bt * nin + kt2] = s0
            kt2 = kt2 + u32(1)
        end
        bt = bt + u32(1)
    end
    mut b2 = nbb * u32(8)
    while b2 < batch do
        mut kr = u32(0)
        while kr + u32(8) <= nin do
            mut ar = simd[f32, 8](f32(0.0))
            mut o5 = u32(0)
            while o5 < nout do
                ar = fma(simd[f32, 8](dy[b2 * nout + o5]),
                         simd[f32, 8](w, o5 * nin + kr), ar)
                o5 = o5 + u32(1)
            end
            store(dx, b2 * nin + kr, ar)
            kr = kr + u32(8)
        end
        while kr < nin do
            mut sr = f32(0.0)
            mut o6 = u32(0)
            while o6 < nout do
                sr = sr + dy[b2 * nout + o6] * w[o6 * nin + kr]
                o6 = o6 + u32(1)
            end
            dx[b2 * nin + kr] = sr
            kr = kr + u32(1)
        end
        b2 = b2 + u32(1)
    end
end

pub fn relu(y: f32[], n: u32)
    mut i = u32(0)
    while i + u32(8) <= n do
        store(y, i, max(simd[f32, 8](y, i), simd[f32, 8](f32(0.0))))
        i = i + u32(8)
    end
    while i < n do
        if y[i] < f32(0.0) then
            y[i] = f32(0.0)
        end
        i = i + u32(1)
    end
end

pub fn relu_backward(y: f32[], dy: f32[], n: u32)
    mut i = u32(0)
    while i + u32(8) <= n do
        store(dy, i, select(simd[f32, 8](y, i) <= simd[f32, 8](f32(0.0)),
                            simd[f32, 8](f32(0.0)), simd[f32, 8](dy, i)))
        i = i + u32(8)
    end
    while i < n do
        if y[i] <= f32(0.0) then
            dy[i] = f32(0.0)
        end
        i = i + u32(1)
    end
end

pub fn init_he(w: f32[], nin: u32, nout: u32, draw: f32[], scale_off: u32)
    mut s = sqrt(f32(2.0) / f32(i32(nin)))
    mut i = u32(0)
    while i < nin * nout do
        w[i] = draw[scale_off + i] * s
        i = i + u32(1)
    end
end
