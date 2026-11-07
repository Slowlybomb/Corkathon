mut RNG = require("../../lib/rng/random.cy")

pub NL = u32(7)

pub type Net
    nb: u32
    n: u32
    cin: u32
    width: u32
    cout: u32
    mut ci: u32[]
    mut co: u32[]
    mut k: u32[]
    mut dil: u32[]
    mut wo: u32[]
    mut bo: u32[]
    mut np: u32
    mut p: f32[]
    mut g: f32[]
    mut m1: f32[]
    mut m2: f32[]
    mut x: f32[]
    mut a1: f32[]
    mut a2: f32[]
    mut a3: f32[]
    mut a4: f32[]
    mut a5: f32[]
    mut a6: f32[]
    mut z: f32[]
    mut ga: f32[]
    mut gb: f32[]
    mut gz: f32[]
end

pub fn conv_fwd(x: f32[], p: f32[], y: f32[], nb: u32, ci: u32, co: u32, n: u32, k: u32, dil: u32, wo: u32, bo: u32, relu: u32)
    total = nb * co * n * n
    half = i32(k / u32(2)) * i32(dil)
    gpu do
        mut e = u32(0)
        while e < total do
            j = e % n
            i = (e / n) % n
            o = (e / (n * n)) % co
            b = e / (n * n * co)
            mut acc = p[bo + o]
            mut c = u32(0)
            while c < ci do
                mut ky = u32(0)
                while ky < k do
                    ii = i32(i) + i32(ky) * i32(dil) - half
                    if ii >= 0 and ii < i32(n) then
                        mut kx = u32(0)
                        while kx < k do
                            jj = i32(j) + i32(kx) * i32(dil) - half
                            if jj >= 0 and jj < i32(n) then
                                acc = acc + p[wo + ((o * ci + c) * k + ky) * k + kx] * x[((b * ci + c) * n + u32(ii)) * n + u32(jj)]
                            end
                            kx = kx + u32(1)
                        end
                    end
                    ky = ky + u32(1)
                end
                c = c + u32(1)
            end
            if relu == u32(1) then
                acc = max(acc, f32(0.0))
            end
            y[e] = acc
            e = e + u32(1)
        end
    end
end

pub fn conv_bwd_x(g: f32[], p: f32[], mask: f32[], dx: f32[], nb: u32, ci: u32, co: u32, n: u32, k: u32, dil: u32, wo: u32)
    total = nb * ci * n * n
    half = i32(k / u32(2)) * i32(dil)
    gpu do
        mut e = u32(0)
        while e < total do
            j = e % n
            i = (e / n) % n
            c = (e / (n * n)) % ci
            b = e / (n * n * ci)
            mut acc = f32(0.0)
            if mask[e] > f32(0.0) then
                mut o = u32(0)
                while o < co do
                    mut ky = u32(0)
                    while ky < k do
                        ii = i32(i) + half - i32(ky) * i32(dil)
                        if ii >= 0 and ii < i32(n) then
                            mut kx = u32(0)
                            while kx < k do
                                jj = i32(j) + half - i32(kx) * i32(dil)
                                if jj >= 0 and jj < i32(n) then
                                    acc = acc + p[wo + ((o * ci + c) * k + ky) * k + kx] * g[((b * co + o) * n + u32(ii)) * n + u32(jj)]
                                end
                                kx = kx + u32(1)
                            end
                        end
                        ky = ky + u32(1)
                    end
                    o = o + u32(1)
                end
            end
            dx[e] = acc
            e = e + u32(1)
        end
    end
end

pub fn conv_bwd_w(g: f32[], x: f32[], gr: f32[], nb: u32, ci: u32, co: u32, n: u32, k: u32, dil: u32, wo: u32)
    total = co * ci * k * k
    half = i32(k / u32(2)) * i32(dil)
    gpu do
        mut e = u32(0)
        while e < total do
            kx = e % k
            ky = (e / k) % k
            c = (e / (k * k)) % ci
            o = e / (k * k * ci)
            dy = i32(ky) * i32(dil) - half
            dxo = i32(kx) * i32(dil) - half
            ilo = u32(max(i32(0), -dy))
            ihi = u32(min(i32(n), i32(n) - dy))
            jlo = u32(max(i32(0), -dxo))
            jhi = u32(min(i32(n), i32(n) - dxo))
            mut acc = f32(0.0)
            mut b = u32(0)
            while b < nb do
                mut i = ilo
                while i < ihi do
                    gro = ((b * co + o) * n + i) * n
                    xro = ((b * ci + c) * n + u32(i32(i) + dy)) * n
                    mut j = jlo
                    while j < jhi do
                        acc = acc + g[gro + j] * x[xro + u32(i32(j) + dxo)]
                        j = j + u32(1)
                    end
                    i = i + u32(1)
                end
                b = b + u32(1)
            end
            gr[wo + e] = acc
            e = e + u32(1)
        end
    end
end

pub fn bias_bwd(g: f32[], gr: f32[], nb: u32, co: u32, n: u32, bo: u32)
    gpu do
        mut o = u32(0)
        while o < co do
            mut acc = f32(0.0)
            mut b = u32(0)
            while b < nb do
                base = (b * co + o) * n * n
                mut q = u32(0)
                while q < n * n do
                    acc = acc + g[base + q]
                    q = q + u32(1)
                end
                b = b + u32(1)
            end
            gr[bo + o] = acc
            o = o + u32(1)
        end
    end
end

pub fn create(nb: u32, n: u32, cin: u32, width: u32, cout: u32, seed: u64) -> Net
    mut ci = array[u32](NL)
    mut co = array[u32](NL)
    mut k = array[u32](NL)
    mut dil = array[u32](NL)
    mut wo = array[u32](NL)
    mut bo = array[u32](NL)
    mut l = u32(0)
    mut off = u32(0)
    while l < NL do
        ci[l] = width
        co[l] = width
        k[l] = u32(3)
        dil[l] = u32(1)
        l = l + u32(1)
    end
    ci[0] = cin
    dil[2] = u32(2)
    dil[3] = u32(4)
    dil[4] = u32(8)
    co[6] = cout
    k[6] = u32(1)
    l = u32(0)
    while l < NL do
        wo[l] = off
        off = off + co[l] * ci[l] * k[l] * k[l]
        bo[l] = off
        off = off + co[l]
        l = l + u32(1)
    end
    mut p = array[f32](off)
    st = RNG.stream(seed)
    l = u32(0)
    mut r = u32(0)
    while l < NL do
        fan = f32(ci[l] * k[l] * k[l])
        mut sd = sqrt(f32(2.0) / fan)
        if l == NL - u32(1) then
            sd = sqrt(f32(1.0) / fan)
        end
        mut q = u32(0)
        while q < co[l] * ci[l] * k[l] * k[l] do
            p[wo[l] + q] = RNG.normal(st, r) * sd
            r = r + u32(1)
            q = q + u32(1)
        end
        l = l + u32(1)
    end
    act = nb * width * n * n
    return Net(nb: nb, n: n, cin: cin, width: width, cout: cout, ci: ci, co: co, k: k, dil: dil, wo: wo, bo: bo, np: off,
               p: p, g: array[f32](off), m1: array[f32](off), m2: array[f32](off),
               x: array[f32](nb * cin * n * n), a1: array[f32](act), a2: array[f32](act), a3: array[f32](act),
               a4: array[f32](act), a5: array[f32](act), a6: array[f32](act), z: array[f32](nb * cout * n * n),
               ga: array[f32](act), gb: array[f32](act), gz: array[f32](nb * cout * n * n))
end

pub fn forward(t: Net)
    nb = t.nb
    n = t.n
    mut x = t.x
    mut p = t.p
    mut a1 = t.a1
    mut a2 = t.a2
    mut a3 = t.a3
    mut a4 = t.a4
    mut a5 = t.a5
    mut a6 = t.a6
    mut z = t.z
    conv_fwd(x, p, a1, nb, t.ci[0], t.co[0], n, t.k[0], t.dil[0], t.wo[0], t.bo[0], u32(1))
    conv_fwd(a1, p, a2, nb, t.ci[1], t.co[1], n, t.k[1], t.dil[1], t.wo[1], t.bo[1], u32(1))
    conv_fwd(a2, p, a3, nb, t.ci[2], t.co[2], n, t.k[2], t.dil[2], t.wo[2], t.bo[2], u32(1))
    conv_fwd(a3, p, a4, nb, t.ci[3], t.co[3], n, t.k[3], t.dil[3], t.wo[3], t.bo[3], u32(1))
    conv_fwd(a4, p, a5, nb, t.ci[4], t.co[4], n, t.k[4], t.dil[4], t.wo[4], t.bo[4], u32(1))
    conv_fwd(a5, p, a6, nb, t.ci[5], t.co[5], n, t.k[5], t.dil[5], t.wo[5], t.bo[5], u32(1))
    conv_fwd(a6, p, z, nb, t.ci[6], t.co[6], n, t.k[6], t.dil[6], t.wo[6], t.bo[6], u32(0))
end

pub fn backward(t: Net)
    nb = t.nb
    n = t.n
    mut x = t.x
    mut p = t.p
    mut g = t.g
    mut a1 = t.a1
    mut a2 = t.a2
    mut a3 = t.a3
    mut a4 = t.a4
    mut a5 = t.a5
    mut a6 = t.a6
    mut ga = t.ga
    mut gb = t.gb
    mut gz = t.gz
    conv_bwd_w(gz, a6, g, nb, t.ci[6], t.co[6], n, t.k[6], t.dil[6], t.wo[6])
    bias_bwd(gz, g, nb, t.co[6], n, t.bo[6])
    conv_bwd_x(gz, p, a6, ga, nb, t.ci[6], t.co[6], n, t.k[6], t.dil[6], t.wo[6])
    conv_bwd_w(ga, a5, g, nb, t.ci[5], t.co[5], n, t.k[5], t.dil[5], t.wo[5])
    bias_bwd(ga, g, nb, t.co[5], n, t.bo[5])
    conv_bwd_x(ga, p, a5, gb, nb, t.ci[5], t.co[5], n, t.k[5], t.dil[5], t.wo[5])
    conv_bwd_w(gb, a4, g, nb, t.ci[4], t.co[4], n, t.k[4], t.dil[4], t.wo[4])
    bias_bwd(gb, g, nb, t.co[4], n, t.bo[4])
    conv_bwd_x(gb, p, a4, ga, nb, t.ci[4], t.co[4], n, t.k[4], t.dil[4], t.wo[4])
    conv_bwd_w(ga, a3, g, nb, t.ci[3], t.co[3], n, t.k[3], t.dil[3], t.wo[3])
    bias_bwd(ga, g, nb, t.co[3], n, t.bo[3])
    conv_bwd_x(ga, p, a3, gb, nb, t.ci[3], t.co[3], n, t.k[3], t.dil[3], t.wo[3])
    conv_bwd_w(gb, a2, g, nb, t.ci[2], t.co[2], n, t.k[2], t.dil[2], t.wo[2])
    bias_bwd(gb, g, nb, t.co[2], n, t.bo[2])
    conv_bwd_x(gb, p, a2, ga, nb, t.ci[2], t.co[2], n, t.k[2], t.dil[2], t.wo[2])
    conv_bwd_w(ga, a1, g, nb, t.ci[1], t.co[1], n, t.k[1], t.dil[1], t.wo[1])
    bias_bwd(ga, g, nb, t.co[1], n, t.bo[1])
    conv_bwd_x(ga, p, a1, gb, nb, t.ci[1], t.co[1], n, t.k[1], t.dil[1], t.wo[1])
    conv_bwd_w(gb, x, g, nb, t.ci[0], t.co[0], n, t.k[0], t.dil[0], t.wo[0])
    bias_bwd(gb, g, nb, t.co[0], n, t.bo[0])
end
