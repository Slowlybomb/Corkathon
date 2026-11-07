mut io = require("../io/bytes.cy")

QUOTE = u8(34)
BACKSLASH = u8(92)
LBRACE = u8(123)
RBRACE = u8(125)
LBRACKET = u8(91)
RBRACKET = u8(93)
COLON = u8(58)
COMMA = u8(44)
DIGIT0 = u8(48)
DIGIT9 = u8(57)

pub DT_UNKNOWN = u32(0)
pub DT_F32 = u32(1)
pub DT_F16 = u32(2)
pub DT_BF16 = u32(3)
pub DT_I8 = u32(4)
pub DT_U8 = u32(5)
pub DT_I32 = u32(6)
pub DT_I64 = u32(7)
pub DT_F64 = u32(8)
pub DT_BOOL = u32(9)
pub DT_U16 = u32(10)
pub DT_I16 = u32(11)
pub DT_U32 = u32(12)
pub DT_U64 = u32(13)

pub fn dtype_bytes(dt: u32) -> u32
    if dt == DT_I8 or dt == DT_U8 or dt == DT_BOOL then
        return u32(1)
    end
    if dt == DT_F16 or dt == DT_BF16 or dt == DT_I16 or dt == DT_U16 then
        return u32(2)
    end
    if dt == DT_F32 or dt == DT_I32 or dt == DT_U32 then
        return u32(4)
    end
    if dt == DT_F64 or dt == DT_I64 or dt == DT_U64 then
        return u32(8)
    end
    return u32(0)
end

pub fn header_len(d: u8[]) -> u32
    if len(d) < u32(8) then
        return u32(0)
    end
    if io.u32le(d, u32(4)) != u32(0) then
        return u32(0)
    end
    mut hl = io.u32le(d, u32(0))
    if hl > len(d) - u32(8) then
        return u32(0)
    end
    return hl
end

pub fn data_start(d: u8[]) -> u32
    mut e = u32(8) + header_len(d)
    if e > len(d) then
        return len(d)
    end
    return e
end

fn header_end(d: u8[]) -> u32
    return data_start(d)
end

pub fn skip_string(d: u8[], at: u32) -> u32
    mut i = at + u32(1)
    while i < len(d) do
        if d[i] == BACKSLASH then
            i = i + u32(2)
        else
            if d[i] == QUOTE then
                return i + u32(1)
            end
            i = i + u32(1)
        end
    end
    return len(d)
end

fn skip_nest(d: u8[], at: u32) -> u32
    mut depth = u32(0)
    mut i = at
    while i < len(d) do
        mut c = d[i]
        if c == QUOTE then
            i = skip_string(d, i)
        else
            if c == LBRACE or c == LBRACKET then
                depth = depth + u32(1)
            end
            if c == RBRACE or c == RBRACKET then
                depth = depth - u32(1)
            end
            i = i + u32(1)
            if depth == u32(0) then
                return i
            end
        end
    end
    return len(d)
end

pub fn skip_value(d: u8[], at: u32) -> u32
    if at >= len(d) then
        return len(d)
    end
    mut c = d[at]
    if c == QUOTE then
        return skip_string(d, at)
    end
    if c == LBRACE or c == LBRACKET then
        return skip_nest(d, at)
    end
    mut i = at
    while i < len(d) do
        mut k = d[i]
        if k == COMMA or k == RBRACE or k == RBRACKET then
            return i
        end
        i = i + u32(1)
    end
    return len(d)
end

fn next_name(d: u8[], from: u32, stop: u32) -> u32
    mut i = from
    while i < stop do
        if d[i] == QUOTE then
            return i
        end
        if d[i] == RBRACE then
            return stop
        end
        i = i + u32(1)
    end
    return stop
end

fn raw_first(d: u8[]) -> u32
    mut stop = header_end(d)
    if header_len(d) == u32(0) then
        return stop
    end
    mut i = u32(8)
    while i < stop do
        if d[i] == LBRACE then
            return next_name(d, i + u32(1), stop)
        end
        i = i + u32(1)
    end
    return stop
end

fn raw_next(d: u8[], at: u32) -> u32
    mut stop = header_end(d)
    if at >= stop then
        return stop
    end
    mut i = skip_string(d, at)
    while i < stop do
        if d[i] == COLON then
            return next_name(d, skip_value(d, i + u32(1)), stop)
        end
        i = i + u32(1)
    end
    return stop
end

pub fn name_at(d: u8[], at: u32) -> u32
    return at + u32(1)
end

pub fn name_len(d: u8[], at: u32) -> u32
    mut e = skip_string(d, at)
    if e < at + u32(2) then
        return u32(0)
    end
    return e - at - u32(2)
end

pub fn name_is(d: u8[], at: u32, key: u8[]) -> bool
    if name_len(d, at) != len(key) then
        return false
    end
    return io.matches(d, at + u32(1), key)
end

pub fn is_metadata(d: u8[], at: u32) -> bool
    if at >= header_end(d) then
        return false
    end
    return name_is(d, at, bytes("__metadata__"))
end

pub fn metadata(d: u8[]) -> u32
    mut stop = header_end(d)
    mut at = raw_first(d)
    while at < stop do
        if is_metadata(d, at) then
            return at
        end
        at = raw_next(d, at)
    end
    return stop
end

pub fn first(d: u8[]) -> u32
    mut stop = header_end(d)
    mut at = raw_first(d)
    while at < stop do
        if is_metadata(d, at) == false then
            return at
        end
        at = raw_next(d, at)
    end
    return stop
end

pub fn next(d: u8[], at: u32) -> u32
    mut stop = header_end(d)
    mut i = raw_next(d, at)
    while i < stop do
        if is_metadata(d, i) == false then
            return i
        end
        i = raw_next(d, i)
    end
    return stop
end

pub fn done(d: u8[], at: u32) -> bool
    return at >= header_end(d)
end

pub fn find_name(d: u8[], key: u8[]) -> u32
    mut at = first(d)
    while done(d, at) == false do
        if name_is(d, at, key) then
            return at
        end
        at = next(d, at)
    end
    return at
end

fn entry_end(d: u8[], at: u32) -> u32
    mut stop = header_end(d)
    mut i = skip_string(d, at)
    while i < stop do
        if d[i] == COLON then
            return skip_value(d, i + u32(1))
        end
        i = i + u32(1)
    end
    return stop
end

fn in_entry(d: u8[], at: u32, key: u8[]) -> u32
    mut fin = entry_end(d, at)
    mut j = skip_string(d, at)
    while j + len(key) <= fin do
        if io.matches(d, j, key) then
            return j + len(key)
        end
        j = j + u32(1)
    end
    return fin
end

pub fn dtype_at(d: u8[], at: u32) -> u32
    mut q = in_entry(d, at, bytes("\"dtype\":\""))
    mut fin = entry_end(d, at)
    if q >= fin then
        return DT_UNKNOWN
    end
    mut n = u32(0)
    mut i = q
    while i < fin do
        if d[i] == QUOTE then
            i = fin
        else
            n = n + u32(1)
            i = i + u32(1)
        end
    end
    if n < u32(2) then
        return DT_UNKNOWN
    end
    mut c0 = d[q]
    mut c1 = d[q + u32(1)]
    if n == u32(2) then
        if c0 == u8(73) then
            return DT_I8
        end
        if c0 == u8(85) then
            return DT_U8
        end
        return DT_UNKNOWN
    end
    if n == u32(3) then
        if c0 == u8(70) then
            if c1 == u8(51) then
                return DT_F32
            end
            if c1 == u8(54) then
                return DT_F64
            end
            if c1 == u8(49) then
                return DT_F16
            end
            return DT_UNKNOWN
        end
        if c0 == u8(73) then
            if c1 == u8(49) then
                return DT_I16
            end
            if c1 == u8(51) then
                return DT_I32
            end
            if c1 == u8(54) then
                return DT_I64
            end
            return DT_UNKNOWN
        end
        if c0 == u8(85) then
            if c1 == u8(49) then
                return DT_U16
            end
            if c1 == u8(51) then
                return DT_U32
            end
            if c1 == u8(54) then
                return DT_U64
            end
            return DT_UNKNOWN
        end
        return DT_UNKNOWN
    end
    if n == u32(4) then
        if c1 == u8(70) then
            return DT_BF16
        end
        if c1 == u8(79) then
            return DT_BOOL
        end
    end
    return DT_UNKNOWN
end

pub fn read_uint(d: u8[], at: u32) -> u64
    mut i = at
    mut v = u64(0)
    while i < len(d) do
        mut c = d[i]
        if c < DIGIT0 or c > DIGIT9 then
            return v
        end
        v = v * u64(10) + u64(u32(c) - u32(48))
        i = i + u32(1)
    end
    return v
end

pub fn skip_uint(d: u8[], at: u32) -> u32
    mut i = at
    while i < len(d) do
        mut c = d[i]
        if c < DIGIT0 or c > DIGIT9 then
            return i
        end
        i = i + u32(1)
    end
    return i
end

pub fn rank_at(d: u8[], at: u32) -> u32
    mut i = in_entry(d, at, bytes("\"shape\":["))
    mut fin = entry_end(d, at)
    if i >= fin then
        return u32(0)
    end
    mut n = u32(0)
    while i < fin do
        mut c = d[i]
        if c == RBRACKET then
            return n
        end
        if c >= DIGIT0 and c <= DIGIT9 then
            n = n + u32(1)
            i = skip_uint(d, i)
        else
            i = i + u32(1)
        end
    end
    return n
end

pub fn dim_at(d: u8[], at: u32, k: u32) -> u64
    mut i = in_entry(d, at, bytes("\"shape\":["))
    mut fin = entry_end(d, at)
    mut n = u32(0)
    while i < fin do
        mut c = d[i]
        if c == RBRACKET then
            return u64(0)
        end
        if c >= DIGIT0 and c <= DIGIT9 then
            if n == k then
                return read_uint(d, i)
            end
            n = n + u32(1)
            i = skip_uint(d, i)
        else
            i = i + u32(1)
        end
    end
    return u64(0)
end

pub fn begin_at(d: u8[], at: u32) -> u64
    mut i = in_entry(d, at, bytes("\"data_offsets\":["))
    if i >= entry_end(d, at) then
        return u64(0)
    end
    return read_uint(d, i)
end

pub fn end_at(d: u8[], at: u32) -> u64
    mut i = in_entry(d, at, bytes("\"data_offsets\":["))
    mut fin = entry_end(d, at)
    if i >= fin then
        return u64(0)
    end
    mut j = skip_uint(d, i)
    while j < fin do
        mut c = d[j]
        if c == RBRACKET then
            return u64(0)
        end
        if c >= DIGIT0 and c <= DIGIT9 then
            return read_uint(d, j)
        end
        j = j + u32(1)
    end
    return u64(0)
end

pub fn count_at(d: u8[], at: u32) -> u64
    mut r = rank_at(d, at)
    if r == u32(0) then
        return u64(0)
    end
    mut n = u64(1)
    mut k = u32(0)
    while k < r do
        n = n * dim_at(d, at, k)
        k = k + u32(1)
    end
    return n
end

pub fn count(d: u8[]) -> u32
    mut n = u32(0)
    mut at = first(d)
    while done(d, at) == false do
        n = n + u32(1)
        at = next(d, at)
    end
    return n
end
