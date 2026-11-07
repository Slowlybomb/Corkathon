mut io = require("../io/bytes.cy")

pub fn n_samples(d: u8[]) -> u32
    return u32(io.i32le(d, u32(0)))
end

pub fn n_channels(d: u8[]) -> u32
    return u32(io.i32le(d, u32(4)))
end

pub fn n_train(d: u8[]) -> u32
    return u32(io.i32le(d, u32(8)))
end

pub fn sample(d: u8[], n: u32, ch: u32, i: u32, c: u32) -> f32
    return io.f32le(d, u32(12) + (i * ch + c) * u32(4))
end

pub fn label(d: u8[], n: u32, ch: u32, i: u32) -> u32
    return u32(io.i32le(d, u32(12) + n * ch * u32(4) + i * u32(4)))
end

pub fn n_windows(n: u32, len: u32, stride: u32) -> u32
    if n < len then
        return u32(0)
    end
    return (n - len) / stride + u32(1)
end

pub fn decode(d: u8[], out: f32[])
    mut n = n_samples(d)
    mut ch = n_channels(d)
    mut c = u32(0)
    while c < ch do
        mut i = u32(0)
        while i < n do
            out[c * n + i] = io.f32le(d, u32(12) + (i * ch + c) * u32(4))
            i = i + u32(1)
        end
        c = c + u32(1)
    end
end

pub fn window_at(n: u32, c: u32, w: u32, stride: u32) -> u32
    return c * n + w * stride
end
