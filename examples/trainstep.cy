mut dense = require("../lib/nn/dense.cy")
mut loss = require("../lib/nn/loss.cy")
mut optim = require("../lib/nn/optim.cy")
mut drop = require("../lib/nn/dropout.cy")

NFEAT = u32(140)
NH1 = u32(128)
NH2 = u32(64)
NCLS = u32(2)
BATCH = u32(64)
STEPS = u32(800)

fn fill(a: f32[], n: u32, seed: u32)
    mut i = u32(0)
    while i < n do
        a[i] = f32(i32((i * u32(2654435761) + seed) % u32(2000))) * f32(0.001)
              - f32(1.0)
        i = i + u32(1)
    end
end

pub fn fwd(n: u32) -> u32
    mut x = array[f32](BATCH * NFEAT)
    mut w1 = array[f32](NFEAT * NH1)
    mut w2 = array[f32](NH1 * NH2)
    mut w3 = array[f32](NH2 * NCLS)
    mut b1 = array[f32](NH1)
    mut b2 = array[f32](NH2)
    mut b3 = array[f32](NCLS)
    mut h1 = array[f32](BATCH * NH1)
    mut h2 = array[f32](BATCH * NH2)
    mut z = array[f32](BATCH * NCLS)
    fill(x, BATCH * NFEAT, u32(1))
    fill(w1, NFEAT * NH1, u32(2))
    fill(w2, NH1 * NH2, u32(3))
    fill(w3, NH2 * NCLS, u32(4))
    mut r = u32(0)
    while r < n * STEPS do
        dense.forward(x, w1, b1, h1, BATCH, NFEAT, NH1)
        dense.relu(h1, BATCH * NH1)
        dense.forward(h1, w2, b2, h2, BATCH, NH1, NH2)
        dense.relu(h2, BATCH * NH2)
        dense.forward(h2, w3, b3, z, BATCH, NH2, NCLS)
        r = r + u32(1)
    end
    return u32(i32(abs(z[u32(0)])))
end

pub fn bwd(n: u32) -> u32
    mut x = array[f32](BATCH * NFEAT)
    mut w1 = array[f32](NFEAT * NH1)
    mut w2 = array[f32](NH1 * NH2)
    mut w3 = array[f32](NH2 * NCLS)
    mut h1 = array[f32](BATCH * NH1)
    mut h2 = array[f32](BATCH * NH2)
    mut dz = array[f32](BATCH * NCLS)
    mut dh2 = array[f32](BATCH * NH2)
    mut dh1 = array[f32](BATCH * NH1)
    mut dx = array[f32](BATCH * NFEAT)
    mut g1 = array[f32](NFEAT * NH1)
    mut g2 = array[f32](NH1 * NH2)
    mut g3 = array[f32](NH2 * NCLS)
    mut gb1 = array[f32](NH1)
    mut gb2 = array[f32](NH2)
    mut gb3 = array[f32](NCLS)
    fill(x, BATCH * NFEAT, u32(1))
    fill(h1, BATCH * NH1, u32(5))
    fill(h2, BATCH * NH2, u32(6))
    fill(dz, BATCH * NCLS, u32(7))
    mut r = u32(0)
    while r < n * STEPS do
        dense.backward(h2, w3, dz, dh2, g3, gb3, BATCH, NH2, NCLS)
        dense.backward(h1, w2, dh2, dh1, g2, gb2, BATCH, NH1, NH2)
        dense.backward(x, w1, dh1, dx, g1, gb1, BATCH, NFEAT, NH1)
        r = r + u32(1)
    end
    return u32(i32(abs(dx[u32(0)])))
end

pub fn opt(n: u32) -> u32
    mut w1 = array[f32](NFEAT * NH1)
    mut g1 = array[f32](NFEAT * NH1)
    mut m1 = array[f32](NFEAT * NH1)
    mut v1 = array[f32](NFEAT * NH1)
    mut w2 = array[f32](NH1 * NH2)
    mut g2 = array[f32](NH1 * NH2)
    mut m2 = array[f32](NH1 * NH2)
    mut v2 = array[f32](NH1 * NH2)
    fill(g1, NFEAT * NH1, u32(8))
    fill(g2, NH1 * NH2, u32(9))
    mut r = u32(0)
    while r < n * STEPS do
        optim.zero(g1, NFEAT * NH1)
        optim.zero(g2, NH1 * NH2)
        optim.adamw(w1, g1, m1, v1, NFEAT * NH1, r + u32(1), f32(0.002),
                    f32(0.9), f32(0.999), f32(1.0e-8), f32(0.01))
        optim.adamw(w2, g2, m2, v2, NH1 * NH2, r + u32(1), f32(0.002),
                    f32(0.9), f32(0.999), f32(1.0e-8), f32(0.01))
        r = r + u32(1)
    end
    return u32(i32(abs(w1[u32(0)])))
end

pub fn mask(n: u32) -> u32
    mut m1 = array[f32](BATCH * NH1)
    mut m2 = array[f32](BATCH * NH2)
    mut r = u32(0)
    while r < n * STEPS do
        drop.mask(u32(7), r, m1, BATCH * NH1, f32(0.9))
        drop.mask(u32(7), r + u32(2048), m2, BATCH * NH2, f32(0.9))
        r = r + u32(1)
    end
    return u32(i32(abs(m1[u32(0)])))
end

pub fn glue(n: u32) -> u32
    mut nall = u32(1300)
    mut xall = array[f32](nall * NFEAT)
    mut idx = array[u32](nall)
    mut xb = array[f32](BATCH * NFEAT)
    mut yb = array[u32](BATCH)
    mut h1 = array[f32](BATCH * NH1)
    mut h2 = array[f32](BATCH * NH2)
    mut z = array[f32](BATCH * NCLS)
    mut dz = array[f32](BATCH * NCLS)
    mut dh1 = array[f32](BATCH * NH1)
    mut dh2 = array[f32](BATCH * NH2)
    mut m1 = array[f32](BATCH * NH1)
    mut m2 = array[f32](BATCH * NH2)
    fill(xall, nall * NFEAT, u32(1))
    fill(h1, BATCH * NH1, u32(5))
    fill(h2, BATCH * NH2, u32(6))
    fill(z, BATCH * NCLS, u32(7))
    fill(dh1, BATCH * NH1, u32(11))
    fill(dh2, BATCH * NH2, u32(12))
    drop.mask(u32(7), u32(0), m1, BATCH * NH1, f32(0.9))
    drop.mask(u32(7), u32(1), m2, BATCH * NH2, f32(0.9))
    mut q = u32(0)
    while q < nall do
        idx[q] = (q * u32(2654435761)) % nall
        q = q + u32(1)
    end
    mut acc = f32(0.0)
    mut r = u32(0)
    while r < n * STEPS do
        mut i = u32(0)
        while i < BATCH do
            mut src = idx[(r * BATCH + i) % nall]
            mut f = u32(0)
            while f < NFEAT do
                xb[i * NFEAT + f] = xall[src * NFEAT + f]
                f = f + u32(1)
            end
            yb[i] = src % NCLS
            i = i + u32(1)
        end
        dense.relu(h1, BATCH * NH1)
        drop.apply(h1, m1, BATCH * NH1)
        dense.relu(h2, BATCH * NH2)
        drop.apply(h2, m2, BATCH * NH2)
        acc = acc + loss.softmax_cross_entropy(z, yb, dz, BATCH, NCLS)
        drop.backward(dh2, m2, BATCH * NH2)
        dense.relu_backward(h2, dh2, BATCH * NH2)
        drop.backward(dh1, m1, BATCH * NH1)
        dense.relu_backward(h1, dh1, BATCH * NH1)
        r = r + u32(1)
    end
    return u32(i32(abs(acc))) + u32(i32(abs(xb[u32(0)])))
end

pub fn gather(n: u32) -> u32
    mut nall = u32(1300)
    mut xall = array[f32](nall * NFEAT)
    mut idx = array[u32](nall)
    mut xb = array[f32](BATCH * NFEAT)
    fill(xall, nall * NFEAT, u32(1))
    mut q = u32(0)
    while q < nall do
        idx[q] = (q * u32(2654435761)) % nall
        q = q + u32(1)
    end
    mut r = u32(0)
    while r < n * STEPS do
        mut i = u32(0)
        while i < BATCH do
            mut src = idx[(r * BATCH + i) % nall]
            mut f = u32(0)
            while f < NFEAT do
                xb[i * NFEAT + f] = xall[src * NFEAT + f]
                f = f + u32(1)
            end
            i = i + u32(1)
        end
        r = r + u32(1)
    end
    return u32(i32(abs(xb[u32(0)])))
end

pub fn relubw(n: u32) -> u32
    mut h1 = array[f32](BATCH * NH1)
    mut h2 = array[f32](BATCH * NH2)
    mut dh1 = array[f32](BATCH * NH1)
    mut dh2 = array[f32](BATCH * NH2)
    fill(h1, BATCH * NH1, u32(5))
    fill(h2, BATCH * NH2, u32(6))
    fill(dh1, BATCH * NH1, u32(11))
    fill(dh2, BATCH * NH2, u32(12))
    mut r = u32(0)
    while r < n * STEPS do
        dense.relu_backward(h2, dh2, BATCH * NH2)
        dense.relu_backward(h1, dh1, BATCH * NH1)
        r = r + u32(1)
    end
    return u32(i32(abs(dh1[u32(0)])))
end

mut rng = require("../lib/rng/random.cy")

pub fn shuf(n: u32) -> u32
    mut ntr = u32(1300)
    mut perm = array[u32](ntr)
    mut st = rng.stream(u64(555))
    mut e = u32(0)
    while e < n * u32(40) do
        rng.shuffle(st, perm, ntr, e)
        e = e + u32(1)
    end
    return perm[u32(0)]
end

pub fn step_all(n: u32) -> u32
    mut nall = u32(1857)
    mut xall = array[f32](nall * NFEAT)
    mut idx = array[u32](nall)
    mut xb = array[f32](BATCH * NFEAT)
    mut yb = array[u32](BATCH)
    mut w1 = array[f32](NFEAT * NH1)
    mut w2 = array[f32](NH1 * NH2)
    mut w3 = array[f32](NH2 * NCLS)
    mut b1 = array[f32](NH1)
    mut b2 = array[f32](NH2)
    mut b3 = array[f32](NCLS)
    mut g1 = array[f32](NFEAT * NH1)
    mut g2 = array[f32](NH1 * NH2)
    mut g3 = array[f32](NH2 * NCLS)
    mut gb1 = array[f32](NH1)
    mut gb2 = array[f32](NH2)
    mut gb3 = array[f32](NCLS)
    mut m1a = array[f32](NFEAT * NH1)
    mut v1a = array[f32](NFEAT * NH1)
    mut m2a = array[f32](NH1 * NH2)
    mut v2a = array[f32](NH1 * NH2)
    mut h1 = array[f32](BATCH * NH1)
    mut h2 = array[f32](BATCH * NH2)
    mut z = array[f32](BATCH * NCLS)
    mut dz = array[f32](BATCH * NCLS)
    mut dh1 = array[f32](BATCH * NH1)
    mut dh2 = array[f32](BATCH * NH2)
    mut mk1 = array[f32](BATCH * NH1)
    mut mk2 = array[f32](BATCH * NH2)
    fill(xall, nall * NFEAT, u32(1))
    fill(w1, NFEAT * NH1, u32(2))
    fill(w2, NH1 * NH2, u32(3))
    fill(w3, NH2 * NCLS, u32(4))
    mut q = u32(0)
    while q < nall do
        idx[q] = (q * u32(2654435761)) % nall
        q = q + u32(1)
    end
    mut r = u32(0)
    while r < n * STEPS do
        mut i = u32(0)
        while i < BATCH do
            mut src = idx[(r * BATCH + i) % nall]
            mut f = u32(0)
            while f < NFEAT do
                xb[i * NFEAT + f] = xall[src * NFEAT + f]
                f = f + u32(1)
            end
            yb[i] = src % NCLS
            i = i + u32(1)
        end
        dense.forward(xb, w1, b1, h1, BATCH, NFEAT, NH1)
        dense.relu(h1, BATCH * NH1)
        drop.mask(u32(7), r, mk1, BATCH * NH1, f32(0.9))
        drop.apply(h1, mk1, BATCH * NH1)
        dense.forward(h1, w2, b2, h2, BATCH, NH1, NH2)
        dense.relu(h2, BATCH * NH2)
        drop.mask(u32(7), r + u32(2048), mk2, BATCH * NH2, f32(0.9))
        drop.apply(h2, mk2, BATCH * NH2)
        dense.forward(h2, w3, b3, z, BATCH, NH2, NCLS)
        loss.softmax_cross_entropy(z, yb, dz, BATCH, NCLS)
        optim.zero(g1, NFEAT * NH1)
        optim.zero(g2, NH1 * NH2)
        optim.zero(g3, NH2 * NCLS)
        dense.backward(h2, w3, dz, dh2, g3, gb3, BATCH, NH2, NCLS)
        drop.backward(dh2, mk2, BATCH * NH2)
        dense.relu_backward(h2, dh2, BATCH * NH2)
        dense.backward(h1, w2, dh2, dh1, g2, gb2, BATCH, NH1, NH2)
        drop.backward(dh1, mk1, BATCH * NH1)
        dense.relu_backward(h1, dh1, BATCH * NH1)
        dense.backward_weights(xb, dh1, g1, gb1, BATCH, NFEAT, NH1)
        optim.adamw(w1, g1, m1a, v1a, NFEAT * NH1, r + u32(1), f32(0.002),
                    f32(0.9), f32(0.999), f32(1.0e-8), f32(0.01))
        optim.adamw(w2, g2, m2a, v2a, NH1 * NH2, r + u32(1), f32(0.002),
                    f32(0.9), f32(0.999), f32(1.0e-8), f32(0.01))
        r = r + u32(1)
    end
    return u32(i32(abs(w1[u32(0)]))) + u32(i32(abs(h1[u32(0)])))
end
