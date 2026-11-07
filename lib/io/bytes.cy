pub fn u16le(d: u8[], at: u32) -> u32
    return u32(d[at]) | (u32(d[at + u32(1)]) << u32(8))
end

pub fn u32le(d: u8[], at: u32) -> u32
    return u32(d[at])
         | (u32(d[at + u32(1)]) << u32(8))
         | (u32(d[at + u32(2)]) << u32(16))
         | (u32(d[at + u32(3)]) << u32(24))
end

pub fn u64le(d: u8[], at: u32) -> u64
    return u64(u32le(d, at)) | (u64(u32le(d, at + u32(4))) << u64(32))
end

pub fn i32le(d: u8[], at: u32) -> i32
    return i32(u32le(d, at))
end

pub fn f32le(d: u8[], at: u32) -> f32
    return frombits(u32le(d, at))
end

pub fn f64le(d: u8[], at: u32) -> f64
    return frombits(u64le(d, at))
end

pub fn putu32le(d: u8[], at: u32, v: u32)
    d[at] = u8(v & u32(255))
    d[at + u32(1)] = u8((v >> u32(8)) & u32(255))
    d[at + u32(2)] = u8((v >> u32(16)) & u32(255))
    d[at + u32(3)] = u8((v >> u32(24)) & u32(255))
end

pub fn putu64le(d: u8[], at: u32, v: u64)
    putu32le(d, at, u32(v & u64(4294967295)))
    putu32le(d, at + u32(4), u32(v >> u64(32)))
end

pub fn putf32le(d: u8[], at: u32, v: f32)
    putu32le(d, at, tobits(v))
end

pub fn putf64le(d: u8[], at: u32, v: f64)
    putu64le(d, at, tobits(v))
end

pub fn matches(d: u8[], at: u32, s: u8[]) -> bool
    if at + len(s) > len(d) then
        return false
    end
    mut i = u32(0)
    while i < len(s) do
        if d[at + i] != s[i] then
            return false
        end
        i = i + u32(1)
    end
    return true
end
