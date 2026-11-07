mut io = require("../io/bytes.cy")

T_UINT8 = u32(0)
T_INT8 = u32(1)
T_UINT16 = u32(2)
T_INT16 = u32(3)
T_UINT32 = u32(4)
T_INT32 = u32(5)
T_FLOAT32 = u32(6)
T_BOOL = u32(7)
T_STRING = u32(8)
T_ARRAY = u32(9)
T_UINT64 = u32(10)
T_INT64 = u32(11)
T_FLOAT64 = u32(12)

pub GT_F32 = u32(0)
pub GT_F16 = u32(1)
pub GT_Q4_0 = u32(2)
pub GT_Q4_1 = u32(3)
pub GT_Q5_0 = u32(6)
pub GT_Q5_1 = u32(7)
pub GT_Q8_0 = u32(8)
pub GT_Q8_1 = u32(9)
pub GT_Q2_K = u32(10)
pub GT_Q3_K = u32(11)
pub GT_Q4_K = u32(12)
pub GT_Q5_K = u32(13)
pub GT_Q6_K = u32(14)
pub GT_Q8_K = u32(15)
pub GT_BF16 = u32(30)

pub fn block_elems(t: u32) -> u32
    if t == GT_F32 or t == GT_F16 or t == GT_BF16 then
        return u32(1)
    end
    if t >= GT_Q2_K and t <= GT_Q8_K then
        return u32(256)
    end
    if t == GT_Q4_0 or t == GT_Q4_1 or t == GT_Q5_0 or t == GT_Q5_1
       or t == GT_Q8_0 or t == GT_Q8_1 then
        return u32(32)
    end
    return u32(0)
end

pub fn block_bytes(t: u32) -> u32
    if t == GT_F32 then
        return u32(4)
    end
    if t == GT_F16 then
        return u32(2)
    end
    if t == GT_BF16 then
        return u32(2)
    end
    if t == GT_Q4_0 then
        return u32(18)
    end
    if t == GT_Q4_1 then
        return u32(20)
    end
    if t == GT_Q5_0 then
        return u32(22)
    end
    if t == GT_Q5_1 then
        return u32(24)
    end
    if t == GT_Q8_0 then
        return u32(34)
    end
    if t == GT_Q8_1 then
        return u32(40)
    end
    if t == GT_Q2_K then
        return u32(84)
    end
    if t == GT_Q3_K then
        return u32(110)
    end
    if t == GT_Q4_K then
        return u32(144)
    end
    if t == GT_Q5_K then
        return u32(176)
    end
    if t == GT_Q6_K then
        return u32(210)
    end
    if t == GT_Q8_K then
        return u32(292)
    end
    return u32(0)
end

pub fn is_gguf(d: u8[]) -> bool
    if len(d) < u32(24) then
        return false
    end
    if io.matches(d, u32(0), bytes("GGUF")) == false then
        return false
    end
    mut v = io.u32le(d, u32(4))
    if v < u32(2) then
        return false
    end
    return v <= u32(3)
end

pub fn version(d: u8[]) -> u32
    if is_gguf(d) == false then
        return u32(0)
    end
    return io.u32le(d, u32(4))
end

pub fn tensor_count(d: u8[]) -> u64
    if is_gguf(d) == false then
        return u64(0)
    end
    return io.u64le(d, u32(8))
end

pub fn kv_count(d: u8[]) -> u64
    if is_gguf(d) == false then
        return u64(0)
    end
    return io.u64le(d, u32(16))
end

pub fn str_at(d: u8[], at: u32) -> u32
    return at + u32(8)
end

pub fn str_len(d: u8[], at: u32) -> u32
    if at + u32(8) > len(d) then
        return u32(0)
    end
    mut n = io.u64le(d, at)
    if n > u64(len(d) - at - u32(8)) then
        return u32(0)
    end
    return u32(n)
end

pub fn skip_string(d: u8[], at: u32) -> u32
    if at + u32(8) > len(d) then
        return len(d)
    end
    return at + u32(8) + str_len(d, at)
end

pub fn str_is(d: u8[], at: u32, key: u8[]) -> bool
    if str_len(d, at) != len(key) then
        return false
    end
    return io.matches(d, str_at(d, at), key)
end

pub fn value_bytes(d: u8[], at: u32, t: u32) -> u32
    if t == T_UINT8 then
        return u32(1)
    end
    if t == T_INT8 then
        return u32(1)
    end
    if t == T_BOOL then
        return u32(1)
    end
    if t == T_UINT16 then
        return u32(2)
    end
    if t == T_INT16 then
        return u32(2)
    end
    if t == T_UINT32 then
        return u32(4)
    end
    if t == T_INT32 then
        return u32(4)
    end
    if t == T_FLOAT32 then
        return u32(4)
    end
    if t == T_UINT64 then
        return u32(8)
    end
    if t == T_INT64 then
        return u32(8)
    end
    if t == T_FLOAT64 then
        return u32(8)
    end
    if t == T_STRING then
        return u32(8) + str_len(d, at)
    end
    if t == T_ARRAY then
        if at + u32(12) > len(d) then
            return u32(0)
        end
        mut et = io.u32le(d, at)
        mut cnt = io.u64le(d, at + u32(4))
        mut i = at + u32(12)
        if et == T_STRING then
            mut k = u64(0)
            while k < cnt do
                if i >= len(d) then
                    return len(d) - at
                end
                i = skip_string(d, i)
                k = k + u64(1)
            end
            return i - at
        end
        mut w = value_bytes(d, i, et)
        if w == u32(0) then
            return u32(0)
        end
        return u32(12) + u32(cnt) * w
    end
    return u32(0)
end

pub fn kv_first(d: u8[]) -> u32
    if is_gguf(d) == false then
        return len(d)
    end
    return u32(24)
end

pub fn kv_type(d: u8[], at: u32) -> u32
    mut p = skip_string(d, at)
    if p + u32(4) > len(d) then
        return u32(0)
    end
    return io.u32le(d, p)
end

pub fn kv_value_at(d: u8[], at: u32) -> u32
    return skip_string(d, at) + u32(4)
end

pub fn kv_next(d: u8[], at: u32) -> u32
    mut v = kv_value_at(d, at)
    mut n = value_bytes(d, v, kv_type(d, at))
    if n == u32(0) then
        return len(d)
    end
    if v + n > len(d) then
        return len(d)
    end
    return v + n
end

pub fn kv_key_is(d: u8[], at: u32, key: u8[]) -> bool
    return str_is(d, at, key)
end

pub fn find_kv(d: u8[], key: u8[]) -> u32
    mut at = kv_first(d)
    mut n = kv_count(d)
    mut i = u64(0)
    while i < n do
        if at >= len(d) then
            return len(d)
        end
        if kv_key_is(d, at, key) then
            return at
        end
        at = kv_next(d, at)
        i = i + u64(1)
    end
    return at
end

pub fn kv_uint(d: u8[], at: u32) -> u64
    mut t = kv_type(d, at)
    mut v = kv_value_at(d, at)
    if v >= len(d) then
        return u64(0)
    end
    if t == T_UINT8 then
        return u64(u32(d[v]))
    end
    if t == T_INT8 then
        return u64(u32(d[v]))
    end
    if t == T_BOOL then
        return u64(u32(d[v]))
    end
    if t == T_UINT16 then
        return u64(io.u16le(d, v))
    end
    if t == T_INT16 then
        return u64(io.u16le(d, v))
    end
    if t == T_UINT32 then
        return u64(io.u32le(d, v))
    end
    if t == T_INT32 then
        return u64(io.u32le(d, v))
    end
    if t == T_UINT64 then
        return io.u64le(d, v)
    end
    if t == T_INT64 then
        return io.u64le(d, v)
    end
    return u64(0)
end

pub fn kv_f32(d: u8[], at: u32) -> f32
    if kv_type(d, at) != T_FLOAT32 then
        return f32(0)
    end
    return io.f32le(d, kv_value_at(d, at))
end

pub fn tensors_first(d: u8[]) -> u32
    mut at = kv_first(d)
    mut n = kv_count(d)
    mut i = u64(0)
    while i < n do
        if at >= len(d) then
            return len(d)
        end
        at = kv_next(d, at)
        i = i + u64(1)
    end
    return at
end

pub fn t_name_at(d: u8[], at: u32) -> u32
    return str_at(d, at)
end

pub fn t_name_len(d: u8[], at: u32) -> u32
    return str_len(d, at)
end

pub fn t_name_is(d: u8[], at: u32, key: u8[]) -> bool
    return str_is(d, at, key)
end

pub fn t_rank(d: u8[], at: u32) -> u32
    mut p = skip_string(d, at)
    if p + u32(4) > len(d) then
        return u32(0)
    end
    mut r = io.u32le(d, p)
    if r > u32(4) then
        return u32(0)
    end
    return r
end

pub fn t_dim(d: u8[], at: u32, k: u32) -> u64
    mut r = t_rank(d, at)
    if k >= r then
        return u64(0)
    end
    mut p = skip_string(d, at) + u32(4) + k * u32(8)
    if p + u32(8) > len(d) then
        return u64(0)
    end
    return io.u64le(d, p)
end

pub fn t_type(d: u8[], at: u32) -> u32
    mut p = skip_string(d, at) + u32(4) + t_rank(d, at) * u32(8)
    if p + u32(4) > len(d) then
        return u32(0)
    end
    return io.u32le(d, p)
end

pub fn t_offset(d: u8[], at: u32) -> u64
    mut p = skip_string(d, at) + u32(4) + t_rank(d, at) * u32(8) + u32(4)
    if p + u32(8) > len(d) then
        return u64(0)
    end
    return io.u64le(d, p)
end

pub fn t_next(d: u8[], at: u32) -> u32
    mut p = skip_string(d, at) + u32(4) + t_rank(d, at) * u32(8) + u32(12)
    if p > len(d) then
        return len(d)
    end
    return p
end

pub fn t_count(d: u8[], at: u32) -> u64
    mut r = t_rank(d, at)
    if r == u32(0) then
        return u64(0)
    end
    mut n = u64(1)
    mut k = u32(0)
    while k < r do
        n = n * t_dim(d, at, k)
        k = k + u32(1)
    end
    return n
end

pub fn t_nbytes(d: u8[], at: u32) -> u64
    mut ty = t_type(d, at)
    mut be = block_elems(ty)
    if be == u32(0) then
        return u64(0)
    end
    mut n = t_count(d, at)
    return (n / u64(be)) * u64(block_bytes(ty))
end

pub fn alignment(d: u8[]) -> u32
    mut at = find_kv(d, bytes("general.alignment"))
    if at >= len(d) then
        return u32(32)
    end
    mut a = u32(kv_uint(d, at))
    if a == u32(0) then
        return u32(32)
    end
    return a
end

pub fn data_start(d: u8[]) -> u32
    mut at = tensors_first(d)
    mut n = tensor_count(d)
    mut i = u64(0)
    while i < n do
        if at >= len(d) then
            return len(d)
        end
        at = t_next(d, at)
        i = i + u64(1)
    end
    mut a = alignment(d)
    mut r = at % a
    if r != u32(0) then
        at = at + a - r
    end
    if at > len(d) then
        return len(d)
    end
    return at
end
