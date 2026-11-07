mut cv = require("../nn/conv.cy")
mut fu = require("../nn/fused.cy")
mut ch = require("../nn/chain.cy")
mut fb = require("../nn/fusedback.cy")
mut bn = require("../nn/bnorm.cy")
mut dn = require("../nn/dense.cy")
mut dp = require("../nn/dropout.cy")
mut ls = require("../nn/loss.cy")
mut op = require("../nn/optim.cy")
mut rng = require("../rng/random.cy")

NC = u32(14)
NT = u32(128)
F1 = u32(8)
DM = u32(2)
NG = u32(16)
K1 = u32(64)
K2 = u32(16)
F2 = u32(16)
NP1 = u32(32)
NP2 = u32(4)
NFLAT = u32(64)
NCLS = u32(2)

pub type NetA
    w1: f32[]
    g1: f32[]
    b1: f32[]
    w2: f32[]
    g2: f32[]
    b2: f32[]
end

pub type NetB
    w3: f32[]
    w4: f32[]
    g3: f32[]
    b3: f32[]
    wf: f32[]
    bf: f32[]
end

pub type NetS
    rm1: f32[]
    rv1: f32[]
    rm2: f32[]
    rv2: f32[]
    rm3: f32[]
    rv3: f32[]
end

pub type BufB
    h2: f32[]
    xh2: f32[]
    n2: f32[]
    e2: f32[]
    d3: f32[]
    d4: f32[]
end

pub type BufC
    p1: f32[]
    m1: f32[]
    h3: f32[]
    h4: f32[]
    xh3: f32[]
    n3: f32[]
    e3: f32[]
end

pub type BufD
    p2: f32[]
    m2: f32[]
    z: f32[]
    d5: f32[]
    d6: f32[]
end

pub type BufF
    z: f32[]
    xe: f32[]
    pr: f32[]
    sm: f32[]
    r: f32[]
    mk: f32[]
    q: f32[]
end

pub type BufG
    av: f32[]
    bv: f32[]
    s2: f32[]
    dp: f32[]
    wr: f32[]
    pwo: f32[]
end

pub type BufE
    mu1: f32[]
    iv1: f32[]
    mu2: f32[]
    iv2: f32[]
    mu3: f32[]
    iv3: f32[]
end

fn glorot(a: f32[], n: u32, fan_in: u32, fan_out: u32, seed: u64)
    mut st = rng.stream(seed)
    mut lim = sqrt(f32(6.0) / f32(i32(fan_in + fan_out)))
    mut i = u32(0)
    while i < n do
        a[i] = (rng.uniform(st, i) * f32(2.0) - f32(1.0)) * lim
        i = i + u32(1)
    end
end

fn ones(a: f32[], n: u32)
    mut i = u32(0)
    while i < n do
        a[i] = f32(1.0)
        i = i + u32(1)
    end
end

pub fn init_a(seed: u64) -> NetA
    mut w1 = array[f32](F1 * K1)
    mut w2 = array[f32](NG * NC)
    glorot(w1, F1 * K1, K1, F1 * K1, seed + u64(104729))
    glorot(w2, NG * NC, NC, NC * DM, seed + u64(209458))
    mut g1 = array[f32](F1)
    mut g2 = array[f32](NG)
    ones(g1, F1)
    ones(g2, NG)
    return NetA(w1: w1, g1: g1, b1: array[f32](F1),
                w2: w2, g2: g2, b2: array[f32](NG))
end

pub fn init_b(seed: u64) -> NetB
    mut w3 = array[f32](NG * K2)
    mut w4 = array[f32](F2 * NG)
    mut wf = array[f32](NFLAT * NCLS)
    glorot(w3, NG * K2, K2, K2, seed + u64(314187))
    glorot(w4, F2 * NG, NG, F2, seed + u64(418916))
    glorot(wf, NFLAT * NCLS, NFLAT, NCLS, seed + u64(523645))
    mut g3 = array[f32](F2)
    ones(g3, F2)
    return NetB(w3: w3, w4: w4, g3: g3, b3: array[f32](F2),
                wf: wf, bf: array[f32](NCLS))
end

pub fn init_s() -> NetS
    mut rv1 = array[f32](F1)
    mut rv2 = array[f32](NG)
    mut rv3 = array[f32](F2)
    ones(rv1, F1)
    ones(rv2, NG)
    ones(rv3, F2)
    return NetS(rm1: array[f32](F1), rv1: rv1,
                rm2: array[f32](NG), rv2: rv2,
                rm3: array[f32](F2), rv3: rv3)
end

pub fn zeros_a() -> NetA
    return NetA(w1: array[f32](F1 * K1), g1: array[f32](F1), b1: array[f32](F1),
                w2: array[f32](NG * NC), g2: array[f32](NG), b2: array[f32](NG))
end

pub fn zeros_b() -> NetB
    return NetB(w3: array[f32](NG * K2), w4: array[f32](F2 * NG),
                g3: array[f32](F2), b3: array[f32](F2),
                wf: array[f32](NFLAT * NCLS), bf: array[f32](NCLS))
end

pub fn buf_b(nb: u32) -> BufB
    mut s2 = nb * NG * NT
    return BufB(h2: array[f32](s2), xh2: array[f32](s2), n2: array[f32](s2),
                e2: array[f32](s2), d3: array[f32](s2), d4: array[f32](s2))
end

pub fn buf_c(nb: u32) -> BufC
    mut s3 = nb * NG * NP1
    return BufC(p1: array[f32](s3), m1: array[f32](s3), h3: array[f32](s3),
                h4: array[f32](s3), xh3: array[f32](s3), n3: array[f32](s3),
                e3: array[f32](s3))
end

pub fn buf_d(nb: u32) -> BufD
    mut s3 = nb * NG * NP1
    return BufD(p2: array[f32](nb * F2 * NP2), m2: array[f32](nb * F2 * NP2),
                z: array[f32](nb * NCLS), d5: array[f32](s3),
                d6: array[f32](s3))
end

pub fn buf_f(nb: u32) -> BufF
    return BufF(z: array[f32](nb * NG * (NT + K1)),
                xe: array[f32](nb * NC * (NT + K1)),
                pr: array[f32](K1 * NT), sm: array[f32](NT),
                r: array[f32](K1 * K1), mk: array[f32](K1),
                q: array[f32](F1 * K1))
end

pub fn buf_g(nb: u32) -> BufG
    return BufG(av: array[f32](F1), bv: array[f32](F1), s2: array[f32](NG),
                dp: array[f32](nb * NG * (NT + u32(2) * K1)),
                wr: array[f32](F1 * K1),
                pwo: array[f32](nb * NG * NT))
end

pub fn buf_e() -> BufE
    return BufE(mu1: array[f32](F1), iv1: array[f32](F1),
                mu2: array[f32](NG), iv2: array[f32](NG),
                mu3: array[f32](F2), iv3: array[f32](F2))
end

pub fn forward(na: NetA, nb2: NetB, ns: NetS,
               bf: BufF, bg: BufG, bb: BufB, bc: BufC, bd: BufD, be: BufE,
               x: f32[], b0: u32, nb: u32,
               train: u32, dseed: u32, dstep: u32, keep: f32)
    fu.mix_pad(x, b0, nb, NC, NT, na.w2, F1, DM, K1, bf.z)
    fu.group_sums(na.w2, NG, NC, bg.s2)
    if train == u32(1) then
        fu.pad_tail(x, b0, nb, NC, NT, K1, bf.xe)
        fu.corr_lags(bf.xe, nb * NC, NT, K1, bf.pr)
        fu.col_sums(bf.xe, nb * NC, NT, K1, bf.sm)
        fu.bn_from_moments(bf.pr, bf.sm, nb, NC, NT, na.w1, F1, K1, na.g1,
                           na.b1, be.mu1, be.iv1, ns.rm1, ns.rv1, f32(0.1),
                           bg.av, bg.bv, bf.r, bf.mk)
    else
        fu.infer_scale(ns.rm1, ns.rv1, na.g1, na.b1, F1, bg.av, bg.bv,
                       be.mu1, be.iv1)
    end
    fu.fused_conv(bf.z, nb, F1, DM, NT, K1, na.w1, bg.av, bg.bv, bg.s2, bb.h2)
    if train == u32(1) then
        bn.bn_train(bb.h2, nb, NG, NT, na.g2, na.b2, be.mu2, be.iv2,
                    ns.rm2, ns.rv2, f32(0.1), bb.xh2, bb.n2)
    else
        bn.bn_infer(bb.h2, nb, NG, NT, na.g2, na.b2, ns.rm2, ns.rv2, bb.n2)
    end
    if train == u32(1) then
        dp.mask(dseed, dstep, bc.m1, nb * NG * NP1, keep)
    else
        ch.ones(bc.m1, nb * NG * NP1)
    end
    ch.elu_pool_drop(bb.n2, nb, NG, NT, u32(4), bc.m1, bb.e2, bc.p1)
    cv.time_depth(bc.p1, nb, NG, NP1, nb2.w3, K2, bc.h3)
    cv.point_mix(bc.h3, nb, NG, NP1, nb2.w4, F2, bc.h4)
    if train == u32(1) then
        bn.bn_train(bc.h4, nb, F2, NP1, nb2.g3, nb2.b3, be.mu3, be.iv3,
                    ns.rm3, ns.rv3, f32(0.1), bc.xh3, bc.n3)
    else
        bn.bn_infer(bc.h4, nb, F2, NP1, nb2.g3, nb2.b3, ns.rm3, ns.rv3, bc.n3)
    end
    if train == u32(1) then
        dp.mask(dseed + u32(7919), dstep, bd.m2, nb * F2 * NP2, keep)
    else
        ch.ones(bd.m2, nb * F2 * NP2)
    end
    ch.elu_pool_drop(bc.n3, nb, F2, NP1, u32(8), bd.m2, bc.e3, bd.p2)
    dn.forward(bd.p2, nb2.wf, nb2.bf, bd.z, nb, NFLAT, NCLS)
end

pub fn backward(na: NetA, nb2: NetB, ga: NetA, gb: NetB,
                bf: BufF, bg: BufG, bb: BufB, bc: BufC, bd: BufD, be: BufE,
                x: f32[], b0: u32, nb: u32, y: u32[], keep: f32) -> f32
    mut dz = array[f32](nb * NCLS)
    mut loss = ls.softmax_cross_entropy(bd.z, y, dz, nb, NCLS)
    dn.backward_weights(bd.p2, dz, gb.wf, gb.bf, nb, NFLAT, NCLS)
    dn.input_gradient(dz, nb2.wf, bd.p2, nb, NFLAT, NCLS)
    ch.elu_pool_drop_back(bd.p2, bd.m2, bc.e3, nb, F2, NP1, u32(8), bd.d6)
    bn.bn_backward(bd.d6, bc.xh3, nb, F2, NP1, nb2.g3, be.iv3, gb.g3, gb.b3, bd.d5)
    cv.point_mix_back(bc.h3, bd.d5, nb, NG, NP1, nb2.w4, F2, gb.w4, bd.d6)
    cv.time_depth_back(bc.p1, bd.d6, nb, NG, NP1, nb2.w3, K2, gb.w3, bd.d5)
    ch.elu_pool_drop_back(bd.d5, bc.m1, bb.e2, nb, NG, NT, u32(4), bb.d4)
    bn.bn_backward(bb.d4, bb.xh2, nb, NG, NT, na.g2, be.iv2, ga.g2, ga.b2, bb.d3)
    fb.corr_q(bb.d3, bf.z, nb, F1, DM, NT, K1, bf.q)
    fb.corr_pw(bb.d3, nb, F1, DM, NT, K1, na.w1, bg.dp, bg.wr, bg.pwo)
    fb.dw2_from_pw(bg.pwo, bb.d3, x, b0, nb, NC, NT, F1, DM, bg.av, bg.bv, ga.w2)
    fb.dw1_and_scale(bf.q, bf.mk, bf.r, na.w1, bg.s2, bb.d3, nb, NC, NT, F1, DM,
                     K1, na.g1, be.mu1, be.iv1, ga.w1, ga.g1, ga.b1)
    return loss
end

fn zero(a: f32[], n: u32)
    mut i = u32(0)
    while i < n do
        a[i] = f32(0.0)
        i = i + u32(1)
    end
end

pub fn zero_grad(ga: NetA, gb: NetB)
    zero(ga.w1, F1 * K1)
    zero(ga.g1, F1)
    zero(ga.b1, F1)
    zero(ga.w2, NG * NC)
    zero(ga.g2, NG)
    zero(ga.b2, NG)
    zero(gb.w3, NG * K2)
    zero(gb.w4, F2 * NG)
    zero(gb.g3, F2)
    zero(gb.b3, F2)
    zero(gb.wf, NFLAT * NCLS)
    zero(gb.bf, NCLS)
end

pub fn step(na: NetA, nb2: NetB, ga: NetA, gb: NetB,
            ma: NetA, mb: NetB, va: NetA, vb: NetB, t: u32, lr: f32)
    op.adamw(na.w1, ga.w1, ma.w1, va.w1, F1 * K1, t, lr, f32(0.9), f32(0.999), f32(0.00000001), f32(0.0))
    op.adamw(na.g1, ga.g1, ma.g1, va.g1, F1, t, lr, f32(0.9), f32(0.999), f32(0.00000001), f32(0.0))
    op.adamw(na.b1, ga.b1, ma.b1, va.b1, F1, t, lr, f32(0.9), f32(0.999), f32(0.00000001), f32(0.0))
    op.adamw(na.w2, ga.w2, ma.w2, va.w2, NG * NC, t, lr, f32(0.9), f32(0.999), f32(0.00000001), f32(0.0))
    op.adamw(na.g2, ga.g2, ma.g2, va.g2, NG, t, lr, f32(0.9), f32(0.999), f32(0.00000001), f32(0.0))
    op.adamw(na.b2, ga.b2, ma.b2, va.b2, NG, t, lr, f32(0.9), f32(0.999), f32(0.00000001), f32(0.0))
    op.adamw(nb2.w3, gb.w3, mb.w3, vb.w3, NG * K2, t, lr, f32(0.9), f32(0.999), f32(0.00000001), f32(0.0))
    op.adamw(nb2.w4, gb.w4, mb.w4, vb.w4, F2 * NG, t, lr, f32(0.9), f32(0.999), f32(0.00000001), f32(0.0))
    op.adamw(nb2.g3, gb.g3, mb.g3, vb.g3, F2, t, lr, f32(0.9), f32(0.999), f32(0.00000001), f32(0.0))
    op.adamw(nb2.b3, gb.b3, mb.b3, vb.b3, F2, t, lr, f32(0.9), f32(0.999), f32(0.00000001), f32(0.0))
    op.adamw(nb2.wf, gb.wf, mb.wf, vb.wf, NFLAT * NCLS, t, lr, f32(0.9), f32(0.999), f32(0.00000001), f32(0.0))
    op.adamw(nb2.bf, gb.bf, mb.bf, vb.bf, NCLS, t, lr, f32(0.9), f32(0.999), f32(0.00000001), f32(0.0))
end

pub fn correct(na: NetA, nb2: NetB, ns: NetS,
               bf: BufF, bg: BufG, bb: BufB, bc: BufC, bd: BufD, be: BufE,
               x: f32[], b0: u32, nb: u32, y: u32[]) -> u32
    forward(na, nb2, ns, bf, bg, bb, bc, bd, be, x, b0, nb,
            u32(0), u32(0), u32(0), f32(1.0))
    mut ok = u32(0)
    mut i = u32(0)
    while i < nb do
        mut best = u32(0)
        if bd.z[i * NCLS + u32(1)] > bd.z[i * NCLS] then
            best = u32(1)
        end
        if best == y[i] then
            ok = ok + u32(1)
        end
        i = i + u32(1)
    end
    return ok
end
