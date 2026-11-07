mut gm = require("../lib/nn/gemm.cy")
mut at = require("../lib/nn/attention.cy")
mut op = require("../lib/nn/ops.cy")

SEQ = u32(128)
DIM = u32(256)
FF = u32(1024)

fn fill(a: f32[], n: u32, seed: u32) -> u32
    mut s = seed
    mut i = u32(0)
    while i < n do
        s = s * u32(1664525) + u32(1013904223)
        a[i] = f32(i32((s >> u32(8)) % u32(2001)) - i32(1000)) / 5000.0
        i = i + u32(1)
    end
    return s
end

fn proj(pa: f32[], pw: f32[], bias: f32[], y: f32[], nin: u32, nout: u32)
    gm.gemm(pa, pw, bias, y, SEQ, nin, nout)
end

fn norm_rows(x: f32[], g: f32[], b: f32[], out: f32[], seq: u32, dim: u32)
    mut t = u32(0)
    while t < seq do
        mut o = t * dim
        mut sum = 0.0
        mut i = u32(0)
        while i < dim do
            sum = sum + f64(x[o + i])
            i = i + u32(1)
        end
        mut mu = sum / f64(dim)
        mut var = 0.0
        i = u32(0)
        while i < dim do
            mut d = f64(x[o + i]) - mu
            var = var + d * d
            i = i + u32(1)
        end
        mut inv = 1.0 / sqrt(var / f64(dim) + 0.00001)
        i = u32(0)
        while i < dim do
            out[o + i] = f32((f64(x[o + i]) - mu) * inv) * g[i] + b[i]
            i = i + u32(1)
        end
        t = t + u32(1)
    end
end

pub fn run(p: u32) -> f64
    mut reps = p / u32(2)
    mut doit = p % u32(2)
    mut x = array[f32](SEQ * DIM)
    mut h = array[f32](SEQ * DIM)
    mut nn = array[f32](SEQ * DIM)
    mut q = array[f32](SEQ * DIM)
    mut k = array[f32](SEQ * DIM)
    mut v = array[f32](SEQ * DIM)
    mut ao = array[f32](SEQ * DIM)
    mut po = array[f32](SEQ * DIM)
    mut f1 = array[f32](SEQ * FF)
    mut f2 = array[f32](SEQ * DIM)
    mut wq = array[f32](DIM * DIM)
    mut wk = array[f32](DIM * DIM)
    mut wv = array[f32](DIM * DIM)
    mut wo = array[f32](DIM * DIM)
    mut w1 = array[f32](DIM * FF)
    mut w2 = array[f32](FF * DIM)
    mut pq = array[f32](DIM * DIM)
    mut pk = array[f32](DIM * DIM)
    mut pv = array[f32](DIM * DIM)
    mut pwo = array[f32](DIM * DIM)
    mut pw1 = array[f32](DIM * FF)
    mut pw2 = array[f32](FF * DIM)
    mut pa = array[f32](SEQ * FF)
    mut bz = array[f32](FF)
    mut g1 = array[f32](DIM)
    mut b1 = array[f32](DIM)
    mut g2 = array[f32](DIM)
    mut b2 = array[f32](DIM)

    mut s = fill(x, SEQ * DIM, u32(12345))
    s = fill(wq, DIM * DIM, s)
    s = fill(wk, DIM * DIM, s)
    s = fill(wv, DIM * DIM, s)
    s = fill(wo, DIM * DIM, s)
    s = fill(w1, DIM * FF, s)
    s = fill(w2, FF * DIM, s)
    mut i = u32(0)
    while i < DIM do
        g1[i] = f32(1.0)
        b1[i] = f32(0.0)
        g2[i] = f32(1.0)
        b2[i] = f32(0.0)
        i = i + u32(1)
    end
    i = u32(0)
    while i < FF do
        bz[i] = f32(0.0)
        i = i + u32(1)
    end
    gm.pack_b(wq, pq, DIM, DIM)
    gm.pack_b(wk, pk, DIM, DIM)
    gm.pack_b(wv, pv, DIM, DIM)
    gm.pack_b(wo, pwo, DIM, DIM)
    gm.pack_b(w1, pw1, DIM, FF)
    gm.pack_b(w2, pw2, FF, DIM)

    mut r = u32(0)
    while r < reps do
        if doit == u32(1) then
            norm_rows(x, g1, b1, nn, SEQ, DIM)
            gm.pack_a(nn, pa, SEQ, DIM)
            proj(pa, pq, bz, q, DIM, DIM)
            proj(pa, pk, bz, k, DIM, DIM)
            proj(pa, pv, bz, v, DIM, DIM)
            at.sdpa(q, k, v, ao, SEQ, DIM, true)
            gm.pack_a(ao, pa, SEQ, DIM)
            proj(pa, pwo, bz, po, DIM, DIM)
            mut j = u32(0)
            while j < SEQ * DIM do
                h[j] = x[j] + po[j]
                j = j + u32(1)
            end
            norm_rows(h, g2, b2, nn, SEQ, DIM)
            gm.pack_a(nn, pa, SEQ, DIM)
            proj(pa, pw1, bz, f1, DIM, FF)
            op.gelu_inplace(f1, SEQ * FF)
            gm.pack_a(f1, pa, SEQ, FF)
            proj(pa, pw2, bz, f2, FF, DIM)
            j = u32(0)
            while j < SEQ * DIM do
                h[j] = h[j] + f2[j]
                j = j + u32(1)
            end
        end
        r = r + u32(1)
    end
    mut acc = 0.0
    mut z = u32(0)
    while z < SEQ * DIM do
        acc = acc + f64(h[z])
        z = z + u32(1)
    end
    return acc
end
