LN2_HI = f32(0.693145751953125)
LN2_LO = f32(0.0000014286067653303)
LOG2E = f32(1.4426950408889634)
LN2 = f32(0.6931471805599453)

PIO2_HI = f32(1.5707962512969971)
PIO2_LO = f32(0.00000007549790940)
TWO_OVER_PI = f32(0.6366197723675814)

SQRT2 = f32(1.4142135623730951)
SQRT1_2 = f32(0.7071067811865476)

INF_BITS = u32(2139095040)
NAN_BITS = u32(2143289344)

pub fn inf() -> f32
    return frombits(INF_BITS)
end

pub fn nan() -> f32
    return frombits(NAN_BITS)
end

pub fn is_nan(x: f32) -> bool
    return x != x
end

fn pow2i(k: i32) -> f32
    return frombits(u32(k + i32(127)) << u32(23))
end

pub fn exp(x: f32) -> f32
    mut xc = min(max(x, f32(-87.33654)), f32(88.72283))
    mut kf = round(xc * LOG2E)
    mut r = (xc - kf * LN2_HI) - kf * LN2_LO
    mut p = 1.0 + r * (1.0 + r * (0.5 + r * (0.16666667 + r * (0.041666668
            + r * (0.008333334 + r * 0.0013888889)))))
    return p * pow2i(i32(kf))
end

pub fn exp2(x: f32) -> f32
    return exp(x * LN2)
end

pub fn expm1(x: f32) -> f32
    mut a = abs(x)
    if a < 0.35 then
        return x * (1.0 + x * (0.5 + x * (0.16666667 + x * (0.041666668
               + x * (0.008333334 + x * 0.0013888889)))))
    end
    return exp(x) - 1.0
end

pub fn log(x: f32) -> f32
    mut b = tobits(x) + u32(4913421)
    mut ei = b >> u32(23)
    mut ef = f32(ei) - 127.0
    mut m = frombits((b & u32(8388607)) + u32(1060439795))
    mut f = m - 1.0
    mut z = f / (2.0 + f)
    mut z2 = z * z
    mut s = z * (2.0 + z2 * (0.6666667 + z2 * (0.4 + z2 * (0.2857143
            + z2 * 0.22222222))))
    return s + ef * LN2
end

pub fn log2(x: f32) -> f32
    return log(x) * LOG2E
end

pub fn pow(x: f32, y: f32) -> f32
    if x == 0.0 then
        return f32(0.0)
    end
    return exp(y * log(x))
end

pub fn rsqrt(x: f32) -> f32
    return 1.0 / sqrt(x)
end

pub fn sigmoid(x: f32) -> f32
    return 1.0 / (1.0 + exp(-x))
end

pub fn copysign(v: f32, s: f32) -> f32
    return frombits((tobits(v) & u32(2147483647)) | (tobits(s) & u32(2147483648)))
end

pub fn tanh(x: f32) -> f32
    mut a = min(abs(x), f32(9.011))
    mut e = exp(a + a)
    return copysign((e - 1.0) / (e + 1.0), x)
end

pub fn erf(x: f32) -> f32
    mut a = min(abs(x), f32(4.0))
    mut t = 1.0 / (1.0 + 0.3275911 * a)
    mut p = t * (0.254829592 + t * (-0.284496736 + t * (1.421413741
            + t * (-1.453152027 + t * 1.061405429))))
    return copysign(1.0 - p * exp(-(a * a)), x)
end

pub fn erfc(x: f32) -> f32
    return 1.0 - erf(x)
end

pub fn gelu(x: f32) -> f32
    return 0.5 * x * (1.0 + erf(x * SQRT1_2))
end

pub fn gelu_tanh(x: f32) -> f32
    mut x3 = x * x * x
    return 0.5 * x * (1.0 + tanh(0.7978845608 * (x + 0.044715 * x3)))
end

pub fn silu(x: f32) -> f32
    return x * sigmoid(x)
end

pub fn relu(x: f32) -> f32
    return max(x, f32(0.0))
end

fn sinpoly(r: f32) -> f32
    mut r2 = r * r
    return r * (1.0 + r2 * (-0.16666667 + r2 * (0.008333333
           + r2 * (-0.00019841270 + r2 * 0.0000027557319))))
end

fn cospoly(r: f32) -> f32
    mut r2 = r * r
    return 1.0 + r2 * (-0.5 + r2 * (0.041666668
           + r2 * (-0.0013888889 + r2 * 0.0000248015873)))
end

fn reduce(x: f32) -> f64
    mut xd = f64(x)
    return xd - round(xd * 0.6366197723675814) * 1.5707963267948966
end

fn quadrant(x: f32) -> u32
    return u32(i32(round(f64(x) * 0.6366197723675814)) & i32(3))
end

pub fn sin(x: f32) -> f32
    mut r = f32(reduce(x))
    mut n = quadrant(x)
    if n == u32(0) then
        return sinpoly(r)
    end
    if n == u32(1) then
        return cospoly(r)
    end
    if n == u32(2) then
        return -sinpoly(r)
    end
    return -cospoly(r)
end

pub fn cos(x: f32) -> f32
    mut r = f32(reduce(x))
    mut n = quadrant(x)
    if n == u32(0) then
        return cospoly(r)
    end
    if n == u32(1) then
        return -sinpoly(r)
    end
    if n == u32(2) then
        return -cospoly(r)
    end
    return sinpoly(r)
end
