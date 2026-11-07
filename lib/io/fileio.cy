extern "kernel32.dll" fn CreateFileA(name: u8[], access: u32, share: u32, sec: u64, disp: u32, flags: u32, tmpl: u64) -> u64
extern "kernel32.dll" fn ReadFile(h: u64, buf: u8[], n: u32, got: u32[], ov: u64) -> i32
extern "kernel32.dll" fn WriteFile(h: u64, buf: u8[], n: u32, put: u32[], ov: u64) -> i32
extern "kernel32.dll" fn SetFilePointerEx(h: u64, dist: i64, newpos: u64, method: u32) -> i32
extern "kernel32.dll" fn GetFileSizeEx(h: u64, size: u64[]) -> i32
extern "kernel32.dll" fn CloseHandle(h: u64) -> i32

pub BAD = u64(18446744073709551615)

fn cpath(p: u8[]) -> u8[]
    mut c = array[u8](0)
    for b in p do
        push(c, b)
    end
    push(c, u8(0))
    return c
end

pub fn open_read(p: u8[]) -> u64
    return CreateFileA(cpath(p), u32(2147483648), u32(1), u64(0), u32(3), u32(128), u64(0))
end

pub fn open_write(p: u8[]) -> u64
    return CreateFileA(cpath(p), u32(1073741824), u32(0), u64(0), u32(2), u32(128), u64(0))
end

pub fn size(h: u64) -> u64
    mut s = array[u64](1)
    ok = GetFileSizeEx(h, s)
    if ok == i32(0) then
        return u64(0)
    end
    return s[0]
end

pub fn read_at(h: u64, off: u64, buf: u8[], n: u32) -> u32
    ok = SetFilePointerEx(h, i64(off), u64(0), u32(0))
    if ok == i32(0) then
        return u32(0)
    end
    mut got = array[u32](1)
    mut total = u32(0)
    mut more = true
    while more and total < n do
        if total == u32(0) then
            r = ReadFile(h, buf, n, got, u64(0))
            if r == i32(0) or got[0] == u32(0) then
                more = false
            else
                total = got[0]
            end
        else
            mut tmp = array[u8](n - total)
            r2 = ReadFile(h, tmp, n - total, got, u64(0))
            if r2 == i32(0) or got[0] == u32(0) then
                more = false
            else
                mut k = u32(0)
                while k < got[0] do
                    buf[total + k] = tmp[k]
                    k = k + u32(1)
                end
                total = total + got[0]
            end
        end
    end
    return total
end

pub fn write_all(h: u64, buf: u8[], n: u32) -> u32
    mut put = array[u32](1)
    if n == len(buf) then
        r = WriteFile(h, buf, n, put, u64(0))
        if r == i32(0) then
            return u32(0)
        end
        return put[0]
    end
    mut tmp = array[u8](n)
    mut k = u32(0)
    while k < n do
        tmp[k] = buf[k]
        k = k + u32(1)
    end
    r2 = WriteFile(h, tmp, n, put, u64(0))
    if r2 == i32(0) then
        return u32(0)
    end
    return put[0]
end

pub fn shut(h: u64)
    r = CloseHandle(h)
end
