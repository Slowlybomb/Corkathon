mut sc = require("../math/scalar.cy")
mut vc = require("../math/vector.cy")

pub fn bn_train(x: f32[], nb: u32, nch: u32, nt: u32,
                gamma: f32[], beta: f32[], mean: f32[], ivar: f32[],
                rmean: f32[], rvar: f32[], mom: f32, xhat: f32[], out: f32[])
    mut n = nb * nt
    mut inv = f32(1.0) / f32(i32(n))
    mut c = u32(0)
    while c < nch do
        mut nv = nt / u32(32) * u32(32)
        mut s0 = simd[f32, 8](f32(0.0))
        mut s1 = simd[f32, 8](f32(0.0))
        mut s2 = simd[f32, 8](f32(0.0))
        mut s3 = simd[f32, 8](f32(0.0))
        mut stail = f32(0.0)
        mut bi = u32(0)
        while bi < nb do
            mut o = bi * nch * nt + c * nt
            mut t = u32(0)
            while t < nv do
                s0 = s0 + simd[f32, 8](x, o + t)
                s1 = s1 + simd[f32, 8](x, o + t + u32(8))
                s2 = s2 + simd[f32, 8](x, o + t + u32(16))
                s3 = s3 + simd[f32, 8](x, o + t + u32(24))
                t = t + u32(32)
            end
            while t < nt do
                stail = stail + x[o + t]
                t = t + u32(1)
            end
            bi = bi + u32(1)
        end
        mut s = hsum((s0 + s1) + (s2 + s3)) + stail
        mut mu = s * inv
        mut muv = simd[f32, 8](mu)
        mut v0 = simd[f32, 8](f32(0.0))
        mut v1 = simd[f32, 8](f32(0.0))
        mut v2 = simd[f32, 8](f32(0.0))
        mut v3 = simd[f32, 8](f32(0.0))
        mut vtail = f32(0.0)
        mut bj = u32(0)
        while bj < nb do
            mut o2 = bj * nch * nt + c * nt
            mut t2 = u32(0)
            while t2 < nv do
                mut d0 = simd[f32, 8](x, o2 + t2) - muv
                mut d1 = simd[f32, 8](x, o2 + t2 + u32(8)) - muv
                mut d2 = simd[f32, 8](x, o2 + t2 + u32(16)) - muv
                mut d3 = simd[f32, 8](x, o2 + t2 + u32(24)) - muv
                v0 = fma(d0, d0, v0)
                v1 = fma(d1, d1, v1)
                v2 = fma(d2, d2, v2)
                v3 = fma(d3, d3, v3)
                t2 = t2 + u32(32)
            end
            while t2 < nt do
                mut dt = x[o2 + t2] - mu
                vtail = vtail + dt * dt
                t2 = t2 + u32(1)
            end
            bj = bj + u32(1)
        end
        mut v = (hsum((v0 + v1) + (v2 + v3)) + vtail) * inv
        mut iv = sc.rsqrt(v + f32(0.00001))
        mean[c] = mu
        ivar[c] = iv
        mut unb = v * f32(i32(n)) / f32(i32(n - u32(1)))
        rmean[c] = rmean[c] * (f32(1.0) - mom) + mu * mom
        rvar[c] = rvar[c] * (f32(1.0) - mom) + unb * mom
        mut g = gamma[c]
        mut bt = beta[c]
        mut ivv = simd[f32, 8](iv)
        mut gv = simd[f32, 8](g)
        mut btv = simd[f32, 8](bt)
        mut bk = u32(0)
        while bk < nb do
            mut o3 = bk * nch * nt + c * nt
            mut t3 = u32(0)
            while t3 + u32(8) <= nt do
                mut h = (simd[f32, 8](x, o3 + t3) - muv) * ivv
                store(xhat, o3 + t3, h)
                store(out, o3 + t3, fma(gv, h, btv))
                t3 = t3 + u32(8)
            end
            while t3 < nt do
                mut hs = (x[o3 + t3] - mu) * iv
                xhat[o3 + t3] = hs
                out[o3 + t3] = g * hs + bt
                t3 = t3 + u32(1)
            end
            bk = bk + u32(1)
        end
        c = c + u32(1)
    end
end

pub fn bn_infer(x: f32[], nb: u32, nch: u32, nt: u32,
                gamma: f32[], beta: f32[], rmean: f32[], rvar: f32[], out: f32[])
    mut c = u32(0)
    while c < nch do
        mut iv = sc.rsqrt(rvar[c] + f32(0.00001))
        mut g = gamma[c] * iv
        mut bt = beta[c] - rmean[c] * g
        mut bi = u32(0)
        while bi < nb do
            mut o = bi * nch * nt + c * nt
            mut t = u32(0)
            while t < nt do
                out[o + t] = g * x[o + t] + bt
                t = t + u32(1)
            end
            bi = bi + u32(1)
        end
        c = c + u32(1)
    end
end

pub fn bn_backward(dy: f32[], xhat: f32[], nb: u32, nch: u32, nt: u32,
                   gamma: f32[], ivar: f32[],
                   dgamma: f32[], dbeta: f32[], dx: f32[])
    mut n = nb * nt
    mut inv = f32(1.0) / f32(i32(n))
    mut c = u32(0)
    while c < nch do
        mut y0 = simd[f32, 8](f32(0.0))
        mut y1 = simd[f32, 8](f32(0.0))
        mut h0 = simd[f32, 8](f32(0.0))
        mut h1 = simd[f32, 8](f32(0.0))
        mut sdy = f32(0.0)
        mut sdh = f32(0.0)
        mut nv = nt / u32(16) * u32(16)
        mut bi = u32(0)
        while bi < nb do
            mut o = bi * nch * nt + c * nt
            mut t = u32(0)
            while t < nv do
                mut d0 = simd[f32, 8](dy, o + t)
                mut d1 = simd[f32, 8](dy, o + t + u32(8))
                y0 = y0 + d0
                y1 = y1 + d1
                h0 = fma(d0, simd[f32, 8](xhat, o + t), h0)
                h1 = fma(d1, simd[f32, 8](xhat, o + t + u32(8)), h1)
                t = t + u32(16)
            end
            while t < nt do
                sdy = sdy + dy[o + t]
                sdh = sdh + dy[o + t] * xhat[o + t]
                t = t + u32(1)
            end
            bi = bi + u32(1)
        end
        sdy = sdy + hsum(y0 + y1)
        sdh = sdh + hsum(h0 + h1)
        dgamma[c] = dgamma[c] + sdh
        dbeta[c] = dbeta[c] + sdy
        mut k = gamma[c] * ivar[c]
        mut mdy = sdy * inv
        mut mdh = sdh * inv
        mut kv = simd[f32, 8](k)
        mut mdyv = simd[f32, 8](mdy)
        mut mdhv = simd[f32, 8](mdh)
        mut bj = u32(0)
        while bj < nb do
            mut o2 = bj * nch * nt + c * nt
            mut t2 = u32(0)
            while t2 + u32(8) <= nt do
                store(dx, o2 + t2,
                      kv * ((simd[f32, 8](dy, o2 + t2) - mdyv)
                            - simd[f32, 8](xhat, o2 + t2) * mdhv))
                t2 = t2 + u32(8)
            end
            while t2 < nt do
                dx[o2 + t2] = k * (dy[o2 + t2] - mdy - xhat[o2 + t2] * mdh)
                t2 = t2 + u32(1)
            end
            bj = bj + u32(1)
        end
        c = c + u32(1)
    end
end

pub fn elu(x: f32[], n: u32, out: f32[])
    mut i = u32(0)
    while i + u32(8) <= n do
        mut v = simd[f32, 8](x, i)
        store(out, i, select(v > simd[f32, 8](f32(0.0)), v,
                             vc.expv(v) - simd[f32, 8](f32(1.0))))
        i = i + u32(8)
    end
    while i < n do
        mut v2 = x[i]
        if v2 > f32(0.0) then
            out[i] = v2
        else
            out[i] = sc.expm1(v2)
        end
        i = i + u32(1)
    end
end

pub fn elu_backward(y: f32[], dy: f32[], n: u32, dx: f32[])
    mut i = u32(0)
    while i + u32(8) <= n do
        mut yv = simd[f32, 8](y, i)
        store(dx, i, simd[f32, 8](dy, i)
                   * min(simd[f32, 8](f32(1.0)), yv + simd[f32, 8](f32(1.0))))
        i = i + u32(8)
    end
    while i < n do
        if y[i] > f32(0.0) then
            dx[i] = dy[i]
        else
            dx[i] = dy[i] * (y[i] + f32(1.0))
        end
        i = i + u32(1)
    end
end
