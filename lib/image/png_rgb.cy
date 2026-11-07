mut IN = require("../io/inflate.cy")

fn be32(b: u8[], v: u32)
    push(b, u8((v >> u32(24)) & u32(255)))
    push(b, u8((v >> u32(16)) & u32(255)))
    push(b, u8((v >> u32(8)) & u32(255)))
    push(b, u8(v & u32(255)))
end

fn chunk(out: u8[], typ: u8[], data: u8[], tab: u32[])
    be32(out, len(data))
    mut body = array[u8](0)
    for c in typ do
        push(body, c)
    end
    for c in data do
        push(body, c)
    end
    for c in body do
        push(out, c)
    end
    be32(out, IN.crc32(tab, body, u32(0), len(body)))
end

pub fn encode(px: u8[], w: u32, h: u32) -> u8[]
    tab = IN.crc_table()
    mut out = array[u8](0)
    push(out, u8(137))
    push(out, u8(80))
    push(out, u8(78))
    push(out, u8(71))
    push(out, u8(13))
    push(out, u8(10))
    push(out, u8(26))
    push(out, u8(10))
    mut ihdr = array[u8](0)
    be32(ihdr, w)
    be32(ihdr, h)
    push(ihdr, u8(8))
    push(ihdr, u8(2))
    push(ihdr, u8(0))
    push(ihdr, u8(0))
    push(ihdr, u8(0))
    chunk(out, bytes("IHDR"), ihdr, tab)
    rowlen = w * u32(3) + u32(1)
    n = rowlen * h
    mut raw = array[u8](n)
    mut r = u32(0)
    while r < h do
        mut c = u32(0)
        while c < w * u32(3) do
            raw[r * rowlen + u32(1) + c] = px[r * w * u32(3) + c]
            c = c + u32(1)
        end
        r = r + u32(1)
    end
    mut z = array[u8](0)
    push(z, u8(120))
    push(z, u8(1))
    mut o = u32(0)
    while o < n do
        m = min(u32(65535), n - o)
        mut fin = u32(0)
        if o + m == n then
            fin = u32(1)
        end
        push(z, u8(fin))
        push(z, u8(m & u32(255)))
        push(z, u8(m >> u32(8)))
        push(z, u8((m ^ u32(65535)) & u32(255)))
        push(z, u8((m ^ u32(65535)) >> u32(8)))
        mut k = u32(0)
        while k < m do
            push(z, raw[o + k])
            k = k + u32(1)
        end
        o = o + m
    end
    mut a = u32(1)
    mut b = u32(0)
    mut q = u32(0)
    while q < n do
        a = (a + u32(raw[q])) % u32(65521)
        b = (b + a) % u32(65521)
        q = q + u32(1)
    end
    be32(z, (b << u32(16)) | a)
    chunk(out, bytes("IDAT"), z, tab)
    chunk(out, bytes("IEND"), array[u8](0), tab)
    return out
end
