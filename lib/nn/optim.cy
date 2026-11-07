mut m = require("../math/scalar.cy")

pub fn sgd(w: f32[], g: f32[], v: f32[], n: u32, lr: f32, mom: f32, wd: f32)
    mut i = u32(0)
    while i + u32(8) <= n do
        mut gg = simd[f32, 8](g, i)
        mut ww = simd[f32, 8](w, i)
        gg = fma(simd[f32, 8](wd), ww, gg)
        mut vv = fma(simd[f32, 8](mom), simd[f32, 8](v, i), gg)
        store(v, i, vv)
        store(w, i, ww - simd[f32, 8](lr) * vv)
        i = i + u32(8)
    end
    while i < n do
        mut gs = g[i] + wd * w[i]
        v[i] = mom * v[i] + gs
        w[i] = w[i] - lr * v[i]
        i = i + u32(1)
    end
end

pub fn adamw(w: f32[], g: f32[], mt: f32[], vt: f32[], n: u32, t: u32,
             lr: f32, b1: f32, b2: f32, eps: f32, wd: f32)
    mut c1 = f32(1.0) - m.pow(b1, f32(i32(t)))
    mut c2 = f32(1.0) - m.pow(b2, f32(i32(t)))
    mut step = lr * sqrt(c2) / c1
    mut i = u32(0)
    while i + u32(8) <= n do
        mut gg = simd[f32, 8](g, i)
        mut mm = fma(simd[f32, 8](b1), simd[f32, 8](mt, i), simd[f32, 8](f32(1.0) - b1) * gg)
        mut vv = fma(simd[f32, 8](b2), simd[f32, 8](vt, i), simd[f32, 8](f32(1.0) - b2) * gg * gg)
        store(mt, i, mm)
        store(vt, i, vv)
        mut ww = simd[f32, 8](w, i) * simd[f32, 8](f32(1.0) - lr * wd)
        store(w, i, ww - simd[f32, 8](step) * mm / (sqrt(vv) + simd[f32, 8](eps * sqrt(c2))))
        i = i + u32(8)
    end
    mut es = eps * sqrt(c2)
    while i < n do
        mt[i] = b1 * mt[i] + (f32(1.0) - b1) * g[i]
        vt[i] = b2 * vt[i] + (f32(1.0) - b2) * g[i] * g[i]
        w[i] = w[i] * (f32(1.0) - lr * wd) - step * mt[i] / (sqrt(vt[i]) + es)
        i = i + u32(1)
    end
end

pub fn zero(g: f32[], n: u32)
    mut i = u32(0)
    while i + u32(8) <= n do
        store(g, i, simd[f32, 8](f32(0.0)))
        i = i + u32(8)
    end
    while i < n do
        g[i] = f32(0.0)
        i = i + u32(1)
    end
end
