mut PN = require("../image/png_read.cy")
mut U = require("utm.cy")

pub type Terrain
    mut ok: bool
    mut z: u32
    mut x0: u32
    mut y0: u32
    mut nx: u32
    mut ny: u32
    mut h: f32[]
end

fn putu(a: u8[], v: u32)
    if v >= u32(10) then
        putu(a, v / u32(10))
    end
    push(a, u8(u32(48) + v % u32(10)))
end

fn nums(d: u8[], out: u32[]) -> u32
    mut k = u32(0)
    mut v = u32(0)
    mut have = false
    for c in d do
        if c >= u8(48) and c <= u8(57) then
            v = v * u32(10) + u32(c) - u32(48)
            have = true
        else
            if have and k < len(out) then
                out[k] = v
                k = k + u32(1)
            end
            v = u32(0)
            have = false
        end
    end
    if have and k < len(out) then
        out[k] = v
        k = k + u32(1)
    end
    return k
end

pub fn load(dir: u8[]) -> Terrain
    mut t = Terrain(ok: false, z: u32(0), x0: u32(0), y0: u32(0), nx: u32(0), ny: u32(0), h: array[f32](0))
    mut ip = array[u8](0)
    for c in dir do
        push(ip, c)
    end
    for c in bytes("tiles.txt") do
        push(ip, c)
    end
    mut v = array[u32](5)
    if nums(readfile(ip), v) < u32(5) then
        return t
    end
    t.z = v[0]
    t.x0 = v[1]
    t.y0 = v[2]
    t.nx = v[3]
    t.ny = v[4]
    wd = t.nx * u32(256)
    t.h = array[f32](wd * t.ny * u32(256))
    mut j = u32(0)
    while j < t.ny do
        mut i = u32(0)
        while i < t.nx do
            mut p = array[u8](0)
            for c in dir do
                push(p, c)
            end
            for c in bytes("t_") do
                push(p, c)
            end
            putu(p, i)
            push(p, u8(95))
            putu(p, j)
            for c in bytes(".png") do
                push(p, c)
            end
            d = readfile(p)
            g = PN.decode(d, u32(0), len(d))
            if g.err == u32(0) and g.w == u32(256) and g.nch >= u32(3) then
                mut r = u32(0)
                while r < u32(256) do
                    mut c = u32(0)
                    while c < u32(256) do
                        o = (r * u32(256) + c) * g.nch
                        e = f32(g.s[o]) * f32(256.0) + f32(g.s[o + u32(1)]) + f32(g.s[o + u32(2)]) / f32(256.0) - f32(32768.0)
                        t.h[(j * u32(256) + r) * wd + i * u32(256) + c] = e
                        c = c + u32(1)
                    end
                    r = r + u32(1)
                end
            end
            i = i + u32(1)
        end
        j = j + u32(1)
    end
    t.ok = true
    return t
end

pub fn elevation_at(t: Terrain, lat: f64, lon: f64) -> f32
    mut n = 1.0
    mut k = u32(0)
    while k < t.z do
        n = n * 2.0
        k = k + u32(1)
    end
    r = lat * U.PI / 180.0
    gx = (lon + 180.0) / 360.0 * n * 256.0 - f64(t.x0) * 256.0 - 0.5
    gy = (1.0 - U.log64(U.sin64(r) / U.cos64(r) + 1.0 / U.cos64(r)) / U.PI) / 2.0 * n * 256.0 - f64(t.y0) * 256.0 - 0.5
    wd = t.nx * u32(256)
    ht = t.ny * u32(256)
    cx = max(0.0, min(gx, f64(wd) - 1.001))
    cy = max(0.0, min(gy, f64(ht) - 1.001))
    x0 = u32(cx)
    y0 = u32(cy)
    ax = f32(cx - f64(x0))
    ay = f32(cy - f64(y0))
    a = t.h[y0 * wd + x0] * (f32(1.0) - ax) + t.h[y0 * wd + x0 + u32(1)] * ax
    b = t.h[(y0 + u32(1)) * wd + x0] * (f32(1.0) - ax) + t.h[(y0 + u32(1)) * wd + x0 + u32(1)] * ax
    return a * (f32(1.0) - ay) + b * ay
end
