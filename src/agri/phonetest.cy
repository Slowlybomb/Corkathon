mut PC = require("phone_core.cy")
mut TR = require("train.cy")
mut TX = require("../../lib/io/text.cy")
mut BY = require("../../lib/io/bytes.cy")

fn put_f32s(path: u8[], a: f32[], n: u32) -> u32
    mut b = array[u8](n * u32(4))
    mut i = u32(0)
    while i < n do
        BY.putu32le(b, i * u32(4), tobits(a[i]))
        i = i + u32(1)
    end
    return writefile(path, b)
end

pub fn main(S: u32, heads: u32, doy: u32) -> f64
    mut d = readfile(bytes("out/model.bin"))
    if len(d) == u32(0) then
        d = readfile(bytes("models/agri.bin"))
    end
    mut ov = array[u8](0)
    if heads == u32(1) then
        ov = readfile(bytes("out/cork_soil_heads.bin"))
        if len(ov) == u32(0) then
            ov = readfile(bytes("models/cork_soil_heads.bin"))
        end
    end
    P = S * S
    ri = readfile(bytes("out/golden/input_refl.f32"))
    if len(ri) != u32(40) * P then
        TR.say(bytes("input size does not match S\n"))
        return -1.0
    end
    mut refl = array[f32](u32(10) * P)
    mut i = u32(0)
    while i < u32(10) * P do
        refl[i] = BY.f32le(ri, i * u32(4))
        i = i + u32(1)
    end
    mut out = array[f32](PC.NO * P)
    dt = PC.infer(d, ov, refl, S, doy, out)
    w = put_f32s(bytes("out/golden/phone_out.f32"), out, PC.NO * P)
    mut lg = array[u8](0)
    TX.putstr(lg, bytes("phone core: S "))
    TX.putint(lg, u64(S))
    TX.putstr(lg, bytes(", regional heads "))
    TX.putint(lg, u64(heads))
    TX.putstr(lg, bytes(", chunk ms "))
    TX.putfix(lg, dt * 1000.0, u32(1))
    ex = readfile(bytes("out/golden/expected_out.f32"))
    if heads == u32(0) and len(ex) == PC.NO * P * u32(4) then
        mut dsoil = 0.0
        mut dwx = 0.0
        mut dbd = 0.0
        mut ncls = u32(0)
        mut r = u32(24)
        while r < S - u32(24) do
            mut c = u32(24)
            while c < S - u32(24) do
                sp = r * S + c
                mut k = u32(0)
                while k < PC.NO do
                    a = f64(out[k * P + sp])
                    b = f64(BY.f32le(ex, (k * P + sp) * u32(4)))
                    e = max(a - b, b - a)
                    if k == u32(0) then
                        dbd = max(dbd, e)
                    end
                    if k == u32(1) or k == u32(2) then
                        if e > 0.5 then
                            ncls = ncls + u32(1)
                        end
                    end
                    if k >= u32(3) and k < u32(27) then
                        dsoil = max(dsoil, e)
                    end
                    if k >= u32(27) then
                        dwx = max(dwx, e)
                    end
                    k = k + u32(1)
                end
                c = c + u32(1)
            end
            r = r + u32(1)
        end
        TX.putstr(lg, bytes("; against fastrun: boundary max diff "))
        TX.putsci(lg, dbd, u32(2))
        TX.putstr(lg, bytes(", soil "))
        TX.putsci(lg, dsoil, u32(2))
        TX.putstr(lg, bytes(", weather "))
        TX.putsci(lg, dwx, u32(2))
        TX.putstr(lg, bytes(", class mismatches "))
        TX.putint(lg, u64(ncls))
    end
    TX.putch(lg, u32(10))
    TR.say(lg)
    return dt * 1000.0
end
