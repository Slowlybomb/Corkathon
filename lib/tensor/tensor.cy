mut io = require("../io/bytes.cy")

pub type Tensor
    data: u8[]
    shape: u32[]
    off: u32
    dtype: u32
end

pub DT_UNKNOWN = u32(0)
pub DT_F32 = u32(1)
pub DT_F16 = u32(2)
pub DT_BF16 = u32(3)
pub DT_I8 = u32(4)
pub DT_U8 = u32(5)
pub DT_I32 = u32(6)
pub DT_I64 = u32(7)
pub DT_F64 = u32(8)

pub fn dtype_bytes(dt: u32) -> u32
    if dt == DT_I8 or dt == DT_U8 then
        return u32(1)
    end
    if dt == DT_F16 or dt == DT_BF16 then
        return u32(2)
    end
    if dt == DT_F32 or dt == DT_I32 then
        return u32(4)
    end
    if dt == DT_F64 or dt == DT_I64 then
        return u32(8)
    end
    return u32(0)
end

pub fn rank(t: Tensor) -> u32
    return len(t.shape)
end

pub fn dim(t: Tensor, k: u32) -> u32
    if k >= len(t.shape) then
        return u32(0)
    end
    return t.shape[k]
end

pub fn count(t: Tensor) -> u64
    mut n = u64(1)
    mut k = u32(0)
    while k < len(t.shape) do
        n = n * u64(t.shape[k])
        k = k + u32(1)
    end
    return n
end

pub fn nbytes(t: Tensor) -> u64
    return count(t) * u64(dtype_bytes(t.dtype))
end

pub fn stride(t: Tensor, k: u32) -> u64
    mut s = u64(1)
    mut j = k + u32(1)
    while j < len(t.shape) do
        s = s * u64(t.shape[j])
        j = j + u32(1)
    end
    return s
end

pub fn valid(t: Tensor) -> bool
    if dtype_bytes(t.dtype) == u32(0) then
        return false
    end
    if len(t.shape) == u32(0) then
        return false
    end
    mut end_at = u64(t.off) + nbytes(t)
    return end_at <= u64(len(t.data))
end

pub fn make(data: u8[], shape: u32[], off: u32, dtype: u32) -> Tensor
    return Tensor(data: data, shape: shape, off: off, dtype: dtype)
end

pub fn vector(data: u8[], n: u32, off: u32, dtype: u32) -> Tensor
    mut s = array[u32](u32(1))
    s[u32(0)] = n
    return Tensor(data: data, shape: s, off: off, dtype: dtype)
end

pub fn matrix(data: u8[], rows: u32, cols: u32, off: u32, dtype: u32) -> Tensor
    mut s = array[u32](u32(2))
    s[u32(0)] = rows
    s[u32(1)] = cols
    return Tensor(data: data, shape: s, off: off, dtype: dtype)
end

pub fn at(t: Tensor, i: u64) -> u32
    return t.off + u32(i * u64(dtype_bytes(t.dtype)))
end

pub fn at2(t: Tensor, i: u32, j: u32) -> u32
    return at(t, u64(i) * stride(t, u32(0)) + u64(j))
end

pub fn bf16_to_f32(h: u32) -> f32
    return frombits(h << u32(16))
end

pub fn f32_to_bf16(v: f32) -> u32
    mut b = tobits(v)
    mut r = (b >> u32(16)) & u32(1)
    return (b + u32(32767) + r) >> u32(16)
end

pub fn f16_to_f32(h: u32) -> f32
    mut sign = (h & u32(32768)) << u32(16)
    mut exp = (h >> u32(10)) & u32(31)
    mut man = h & u32(1023)
    if exp == u32(0) then
        if man == u32(0) then
            return frombits(sign)
        end
        mut e = u32(127) - u32(15) + u32(1)
        while (man & u32(1024)) == u32(0) do
            man = man << u32(1)
            e = e - u32(1)
        end
        man = man & u32(1023)
        return frombits(sign | (e << u32(23)) | (man << u32(13)))
    end
    if exp == u32(31) then
        return frombits(sign | u32(2139095040) | (man << u32(13)))
    end
    return frombits(sign | ((exp + u32(112)) << u32(23)) | (man << u32(13)))
end

pub fn get(t: Tensor, i: u64) -> f32
    mut p = at(t, i)
    if t.dtype == DT_F32 then
        return io.f32le(t.data, p)
    end
    if t.dtype == DT_BF16 then
        return bf16_to_f32(io.u16le(t.data, p))
    end
    if t.dtype == DT_F16 then
        return f16_to_f32(io.u16le(t.data, p))
    end
    if t.dtype == DT_U8 then
        return f32(u32(t.data[p]))
    end
    if t.dtype == DT_I8 then
        mut b = u32(t.data[p])
        if b >= u32(128) then
            return f32(0) - f32(u32(256) - b)
        end
        return f32(b)
    end
    if t.dtype == DT_I32 then
        return f32(io.i32le(t.data, p))
    end
    if t.dtype == DT_F64 then
        return f32(io.f64le(t.data, p))
    end
    return f32(0)
end

pub fn get2(t: Tensor, i: u32, j: u32) -> f32
    return get(t, u64(i) * stride(t, u32(0)) + u64(j))
end

pub fn to_f32(t: Tensor) -> f32[]
    mut n = u32(count(t))
    mut out = array[f32](n)
    mut i = u32(0)
    while i < n do
        out[i] = get(t, u64(i))
        i = i + u32(1)
    end
    return out
end

pub fn row(t: Tensor, r: u32) -> Tensor
    mut cols = u32(stride(t, u32(0)))
    mut s = array[u32](u32(1))
    s[u32(0)] = cols
    return Tensor(data: t.data, shape: s, off: at(t, u64(r) * u64(cols)), dtype: t.dtype)
end
