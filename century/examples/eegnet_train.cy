mut net = require("../../lib/models/eegnet.cy")
mut data = require("../../lib/data/eeg.cy")
mut rng = require("../../lib/rng/random.cy")

WIN = u32(128)
STRIDE = u32(8)
NCH = u32(14)
BATCH = u32(64)
KEEP = f32(0.75)
LR = f32(0.002)

fn build(d: u8[], x: f32[], y: u32[], nw: u32, n: u32, ch: u32)
    mut w = u32(0)
    while w < nw do
        mut c = u32(0)
        while c < ch do
            mut o = w * ch * WIN + c * WIN
            mut t = u32(0)
            while t < WIN do
                x[o + t] = data.sample(d, n, ch, w * STRIDE + t, c)
                t = t + u32(1)
            end
            c = c + u32(1)
        end
        y[w] = data.label(d, n, ch, w * STRIDE + WIN - u32(1))
        w = w + u32(1)
    end
end

fn standardise_idx(x: f32[], nw: u32, ch: u32, idx: u32[], ntr: u32)
    mut c = u32(0)
    while c < ch do
        mut s = f64(0.0)
        mut w = u32(0)
        while w < ntr do
            mut o = idx[w] * ch * WIN + c * WIN
            mut t = u32(0)
            while t < WIN do
                s = s + f64(x[o + t])
                t = t + u32(1)
            end
            w = w + u32(1)
        end
        mut mu = f32(s / f64(i32(ntr * WIN)))
        mut v = f64(0.0)
        mut w2 = u32(0)
        while w2 < ntr do
            mut o2 = idx[w2] * ch * WIN + c * WIN
            mut t2 = u32(0)
            while t2 < WIN do
                mut dd = f64(x[o2 + t2] - mu)
                v = v + dd * dd
                t2 = t2 + u32(1)
            end
            w2 = w2 + u32(1)
        end
        mut sd = f32(sqrt(v / f64(i32(ntr * WIN)))) + f32(0.000001)
        mut iv = f32(1.0) / sd
        mut w3 = u32(0)
        while w3 < nw do
            mut o3 = w3 * ch * WIN + c * WIN
            mut t3 = u32(0)
            while t3 < WIN do
                x[o3 + t3] = (x[o3 + t3] - mu) * iv
                t3 = t3 + u32(1)
            end
            w3 = w3 + u32(1)
        end
        c = c + u32(1)
    end
end

fn gather(x: f32[], perm: u32[], at: u32, nb: u32, ch: u32, xb: f32[], y: u32[],
          yb: u32[])
    mut i = u32(0)
    while i < nb do
        mut src = perm[at + i] * ch * WIN
        mut dst = i * ch * WIN
        mut k = u32(0)
        while k + u32(8) <= ch * WIN do
            store(xb, dst + k, simd[f32, 8](x, src + k))
            k = k + u32(8)
        end
        while k < ch * WIN do
            xb[dst + k] = x[src + k]
            k = k + u32(1)
        end
        yb[i] = y[perm[at + i]]
        i = i + u32(1)
    end
end

pub fn run(a: u32) -> u32
    mut mode = a % u32(2)
    mut epochs = a / u32(2)
    if epochs == u32(0) then
        epochs = u32(1)
    end
    mut d = readfile("century/examples/data/eeg_eye.bin")
    mut n = data.n_samples(d)
    mut ch = data.n_channels(d)
    mut ntr_s = data.n_train(d)
    mut nw = data.n_windows(n, WIN, STRIDE)
    mut nspan = data.n_windows(ntr_s, WIN, STRIDE)
    if nspan > nw then
        nspan = nw
    end
    mut x = array[f32](nw * ch * WIN)
    mut y = array[u32](nw)
    build(d, x, y, nw, n, ch)

    mut idtr0 = array[u32](nw)
    mut idte0 = array[u32](nw)
    mut ntr = u32(0)
    mut nte = u32(0)
    if mode == u32(0) then
        mut w0 = u32(0)
        while w0 < nw do
            if w0 < nspan then
                idtr0[ntr] = w0
                ntr = ntr + u32(1)
            else
                idte0[nte] = w0
                nte = nte + u32(1)
            end
            w0 = w0 + u32(1)
        end
    else
        mut blk = u32(200)
        mut gap = WIN / STRIDE
        mut w1 = u32(0)
        while w1 < nw do
            mut inblk = w1 % blk
            mut far = inblk
            if blk - u32(1) - inblk < far then
                far = blk - u32(1) - inblk
            end
            if far >= gap then
                if (w1 / blk) % u32(5) == u32(4) then
                    idte0[nte] = w1
                    nte = nte + u32(1)
                else
                    idtr0[ntr] = w1
                    ntr = ntr + u32(1)
                end
            end
            w1 = w1 + u32(1)
        end
    end
    standardise_idx(x, nw, ch, idtr0, ntr)
    mut na = net.init_a(u64(20260918))
    mut nb2 = net.init_b(u64(20260918))
    mut ns = net.init_s()
    mut ga = net.zeros_a()
    mut gb = net.zeros_b()
    mut ma = net.zeros_a()
    mut mb = net.zeros_b()
    mut va = net.zeros_a()
    mut vb = net.zeros_b()
    mut bf = net.buf_f(BATCH)
    mut bg = net.buf_g(BATCH)
    mut bb = net.buf_b(BATCH)
    mut bc = net.buf_c(BATCH)
    mut bd = net.buf_d(BATCH)
    mut be = net.buf_e()
    mut xb = array[f32](BATCH * ch * WIN)
    mut yb = array[u32](BATCH)
    mut perm = array[u32](ntr)
    mut ord = array[u32](ntr)
    mut st = rng.stream(u64(777))
    mut t = u32(0)
    mut e = u32(0)
    while e < epochs do
        rng.shuffle(st, perm, ntr, e)
        mut pj = u32(0)
        while pj < ntr do
            ord[pj] = idtr0[perm[pj]]
            pj = pj + u32(1)
        end
        mut lr = LR
        if e * u32(2) >= epochs then
            lr = LR * f32(0.25)
        end
        mut at = u32(0)
        while at + BATCH <= ntr do
            gather(x, ord, at, BATCH, ch, xb, y, yb)
            net.zero_grad(ga, gb)
            net.forward(na, nb2, ns, bf, bg, bb, bc, bd, be, xb, u32(0), BATCH,
                        u32(1), u32(4242), t, KEEP)
            mut loss = net.backward(na, nb2, ga, gb, bf, bg, bb, bc, bd, be,
                                    xb, u32(0), BATCH, yb, KEEP)
            t = t + u32(1)
            net.step(na, nb2, ga, gb, ma, mb, va, vb, t, lr)
            at = at + BATCH
        end
        e = e + u32(1)
    end

    mut oktr = u32(0)
    mut ntrb = u32(0)
    mut a1 = u32(0)
    while a1 + BATCH <= ntr do
        gather(x, idtr0, a1, BATCH, ch, xb, y, yb)
        oktr = oktr + net.correct(na, nb2, ns, bf, bg, bb, bc, bd, be,
                                  xb, u32(0), BATCH, yb)
        ntrb = ntrb + BATCH
        a1 = a1 + BATCH
    end
    mut okte = u32(0)
    mut nteb = u32(0)
    mut a2 = u32(0)
    while a2 + BATCH <= nte do
        gather(x, idte0, a2, BATCH, ch, xb, y, yb)
        okte = okte + net.correct(na, nb2, ns, bf, bg, bb, bc, bd, be,
                                  xb, u32(0), BATCH, yb)
        nteb = nteb + BATCH
        a2 = a2 + BATCH
    end
    mut ptr = u32(0)
    if ntrb > u32(0) then
        ptr = oktr * u32(1000) / ntrb
    end
    mut pte = u32(0)
    if nteb > u32(0) then
        pte = okte * u32(1000) / nteb
    end
    return ptr * u32(1000000) + pte * u32(1000) + nteb / u32(10)
end

pub fn stage(a: u32) -> u32
    mut reps = a / u32(8)
    mut upto = a % u32(8)
    if reps == u32(0) then
        reps = u32(1)
    end
    mut d = readfile("century/examples/data/eeg_eye.bin")
    mut n = data.n_samples(d)
    mut ch = data.n_channels(d)
    mut nw = data.n_windows(n, WIN, STRIDE)
    mut x = array[f32](nw * ch * WIN)
    mut y = array[u32](nw)
    build(d, x, y, nw, n, ch)
    mut na = net.init_a(u64(20260918))
    mut nb2 = net.init_b(u64(20260918))
    mut ns = net.init_s()
    mut ga = net.zeros_a()
    mut gb = net.zeros_b()
    mut ma = net.zeros_a()
    mut mb = net.zeros_b()
    mut va = net.zeros_a()
    mut vb = net.zeros_b()
    mut bf = net.buf_f(BATCH)
    mut bg = net.buf_g(BATCH)
    mut bb = net.buf_b(BATCH)
    mut bc = net.buf_c(BATCH)
    mut bd = net.buf_d(BATCH)
    mut be = net.buf_e()
    mut xb = array[f32](BATCH * ch * WIN)
    mut yb = array[u32](BATCH)
    mut ord = array[u32](nw)
    mut i0 = u32(0)
    while i0 < nw do
        ord[i0] = i0
        i0 = i0 + u32(1)
    end
    mut acc = f32(0.0)
    mut t = u32(0)
    while t < reps do
        mut at = (t * BATCH) % (nw - BATCH)
        gather(x, ord, at, BATCH, ch, xb, y, yb)
        if upto >= u32(2) then
            net.forward(na, nb2, ns, bf, bg, bb, bc, bd, be, xb, u32(0), BATCH,
                        u32(1), u32(4242), t, KEEP)
        end
        if upto >= u32(3) then
            net.zero_grad(ga, gb)
            mut loss = net.backward(na, nb2, ga, gb, bf, bg, bb, bc, bd, be,
                                    xb, u32(0), BATCH, yb, KEEP)
            acc = acc + loss
        end
        if upto >= u32(4) then
            net.step(na, nb2, ga, gb, ma, mb, va, vb, t + u32(1), f32(0.002))
        end
        t = t + u32(1)
    end
    return u32(i32(abs(acc))) + u32(i32(abs(bd.z[u32(0)])))
end
