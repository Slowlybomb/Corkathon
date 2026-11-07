pub fn expv(x: simd[f32, 8]) -> simd[f32, 8]
    mut xc = min(max(x, simd[f32, 8](-87.0)), simd[f32, 8](88.0))
    mut t = xc * simd[f32, 8](1.4426950408889634)
    mut magic = simd[f32, 8](12582912.0)
    mut tz = t + magic
    mut kb = tobits(tz) - simd[u32, 8](u32(1262485377))
    mut f = t - (tz - magic)
    mut two = frombits(kb << simd[u32, 8](u32(23)))
    mut p = simd[f32, 8](0.0001546532)
    p = fma(p, f, simd[f32, 8](0.0013395285))
    p = fma(p, f, simd[f32, 8](0.0096180399))
    p = fma(p, f, simd[f32, 8](0.0555034067))
    p = fma(p, f, simd[f32, 8](0.2402265110))
    p = fma(p, f, simd[f32, 8](0.6931472001))
    p = fma(p, f, simd[f32, 8](1.0))
    return p * two
end

pub fn logv(x: simd[f32, 8]) -> simd[f32, 8]
    mut b = tobits(x) + simd[u32, 8](u32(4913421))
    mut ei = b >> simd[u32, 8](u32(23))
    mut ez = frombits(ei | simd[u32, 8](u32(1262485504)))
    mut ef = ez - simd[f32, 8](12582912.0)
    ef = ef - simd[f32, 8](127.0)
    mut m = frombits((b & simd[u32, 8](u32(8388607))) + simd[u32, 8](u32(1060439795)))
    mut f = m - simd[f32, 8](1.0)
    mut p = simd[f32, 8](-0.1443696729)
    p = fma(p, f, simd[f32, 8](0.2313164749))
    p = fma(p, f, simd[f32, 8](-0.2482656744))
    p = fma(p, f, simd[f32, 8](0.2873953514))
    p = fma(p, f, simd[f32, 8](-0.3603087982))
    p = fma(p, f, simd[f32, 8](0.4809150294))
    p = fma(p, f, simd[f32, 8](-0.7213514876))
    p = fma(p, f, simd[f32, 8](1.4426949978))
    return (fma(p, f, ef)) * simd[f32, 8](0.6931471805599453)
end

pub fn sigmoidv(x: simd[f32, 8]) -> simd[f32, 8]
    mut e = expv(simd[f32, 8](0.0) - x)
    return simd[f32, 8](1.0) / (simd[f32, 8](1.0) + e)
end

pub fn tanhv(x: simd[f32, 8]) -> simd[f32, 8]
    mut e = expv(x + x)
    return (e - simd[f32, 8](1.0)) / (e + simd[f32, 8](1.0))
end

pub fn siluv(x: simd[f32, 8]) -> simd[f32, 8]
    return x * sigmoidv(x)
end

pub fn geluv(x: simd[f32, 8]) -> simd[f32, 8]
    mut x3 = x * x * x
    mut inner = fma(simd[f32, 8](0.044715), x3, x) * simd[f32, 8](0.7978845608028654)
    return simd[f32, 8](0.5) * x * (simd[f32, 8](1.0) + tanhv(inner))
end

pub fn reluv(x: simd[f32, 8]) -> simd[f32, 8]
    return max(x, simd[f32, 8](0.0))
end

pub fn rsqrtv(x: simd[f32, 8]) -> simd[f32, 8]
    return simd[f32, 8](1.0) / sqrt(x)
end

pub fn expv2(x: simd[f32, 8]) -> simd[f32, 8]
    return expv(x * simd[f32, 8](0.6931471805599453))
end

fn quad(x: simd[f32, 8]) -> simd[u32, 8]
    mut tz = fma(x, simd[f32, 8](0.63661977236758134), simd[f32, 8](12582912.0))
    return tobits(tz) & simd[u32, 8](u32(3))
end

fn redu(x: simd[f32, 8]) -> simd[f32, 8]
    mut magic = simd[f32, 8](12582912.0)
    mut tz = fma(x, simd[f32, 8](0.63661977236758134), magic)
    mut qf = tz - magic
    mut r = fma(qf, simd[f32, 8](-1.57079625129699707031), x)
    r = fma(qf, simd[f32, 8](-7.54978941586159635335e-8), r)
    return fma(qf, simd[f32, 8](-5.39030252995776476554e-15), r)
end

fn spoly(r: simd[f32, 8], r2: simd[f32, 8]) -> simd[f32, 8]
    mut p = simd[f32, 8](-1.9515295891e-4)
    p = fma(p, r2, simd[f32, 8](8.3321608736e-3))
    p = fma(p, r2, simd[f32, 8](-1.6666654611e-1))
    return fma(p * r2, r, r)
end

fn cpoly(r2: simd[f32, 8]) -> simd[f32, 8]
    mut p = simd[f32, 8](2.443315711809948e-5)
    p = fma(p, r2, simd[f32, 8](-1.388731625493765e-3))
    p = fma(p, r2, simd[f32, 8](4.166664568298827e-2))
    return fma(p * r2, r2, fma(r2, simd[f32, 8](-0.5), simd[f32, 8](1.0)))
end

pub fn sinv(x: simd[f32, 8]) -> simd[f32, 8]
    mut q = quad(x)
    mut r = redu(x)
    mut r2 = r * r
    mut v = select(q & simd[u32, 8](u32(1)) > simd[u32, 8](u32(0)),
                   cpoly(r2), spoly(r, r2))
    return frombits(tobits(v) ^ ((q & simd[u32, 8](u32(2))) << simd[u32, 8](u32(30))))
end

pub fn cosv(x: simd[f32, 8]) -> simd[f32, 8]
    mut q = quad(x)
    mut r = redu(x)
    mut r2 = r * r
    mut v = select(q & simd[u32, 8](u32(1)) > simd[u32, 8](u32(0)),
                   spoly(r, r2), cpoly(r2))
    return frombits(tobits(v) ^
                    (((q + simd[u32, 8](u32(1))) & simd[u32, 8](u32(2))) << simd[u32, 8](u32(30))))
end
