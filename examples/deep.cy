mut dn = require("../lib/nn/dense.cy")

N = u32(64)
L = u32(24)

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

pub fn run(p: u32) -> f64
    mut reps = p / u32(2)
    mut doit = p % u32(2)
    mut x = array[f32](N)
    mut w = array[f32](L * N * N)
    mut b = array[f32](L * N)
    mut a0 = array[f32](N)
    mut a1 = array[f32](N)
    mut s0 = fill(x, N, u32(999))
    mut s1 = fill(w, L * N * N, s0)
    mut s2 = fill(b, L * N, s1)
    mut r = u32(0)
    while r < reps do
        if doit == u32(1) then
            mut i = u32(0)
            while i < N do
                a0[i] = x[i]
                i = i + u32(1)
            end
            mut l = u32(0)
            while l < L do
                dn.forward(a0, w, b, a1, u32(1), N, N)
                dn.relu(a1, N)
                mut k = u32(0)
                while k < N do
                    a0[k] = a1[k]
                    k = k + u32(1)
                end
                l = l + u32(1)
            end
        end
        r = r + u32(1)
    end
    mut acc = 0.0
    mut q = u32(0)
    while q < N do
        acc = acc + f64(a0[q])
        q = q + u32(1)
    end
    return acc
end
