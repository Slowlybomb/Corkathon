mut PC = require("phone_core.cy")

fn grab(a: u64, n: u32) -> u8[]
    mut d = array[u8](n)
    mut i = u32(0)
    while i < n do
        d[i] = peek[u8](a + u64(i))
        i = i + u32(1)
    end
    return d
end

pub fn agri_run(mp: u64, ml: u64, hp: u64, hl: u64, rp: u64, op: u64, s: u64, doy: u64) -> u64
    d = grab(mp, u32(ml))
    mut ov = array[u8](0)
    if hl > u64(0) then
        ov = grab(hp, u32(hl))
    end
    S = u32(s)
    P = S * S
    n = u32(10) * P
    mut refl = array[f32](n)
    mut i = u32(0)
    while i < n do
        refl[i] = frombits(peek[u32](rp + u64(i) * u64(4)))
        i = i + u32(1)
    end
    m = PC.NO * P
    mut out = array[f32](m)
    dt = PC.infer(d, ov, refl, S, u32(doy), out)
    i = u32(0)
    while i < m do
        poke(op + u64(i) * u64(4), tobits(out[i]))
        i = i + u32(1)
    end
    return u64(dt * 1000000000.0)
end
