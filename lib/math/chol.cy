pub fn factor_unblocked(a: f64[], o: u32, n: u32, ld: u32) -> u32
    mut j = u32(0)
    while j < n do
        mut s = a[o + j * ld + j]
        mut t = u32(0)
        while t < j do
            mut v = a[o + j * ld + t]
            s = s - v * v
            t = t + u32(1)
        end
        if s <= f64(0.0) then
            return j + u32(1)
        end
        mut piv = sqrt(s)
        a[o + j * ld + j] = piv
        mut r = j + u32(1)
        while r < n do
            mut acc = a[o + r * ld + j]
            mut q = u32(0)
            while q < j do
                acc = acc - a[o + r * ld + q] * a[o + j * ld + q]
                q = q + u32(1)
            end
            a[o + r * ld + j] = acc / piv
            r = r + u32(1)
        end
        j = j + u32(1)
    end
    return u32(0)
end

pub fn pack_diag(a: f64[], k: u32, b: u32, n: u32, dg: f64[])
    mut j = u32(0)
    while j < b do
        mut src = (k + j) * n + k
        mut q = u32(0)
        while q < j do
            dg[q * b + j] = f64(0.0) - a[src + q]
            q = q + u32(1)
        end
        dg[j * b + j] = a[src + j]
        j = j + u32(1)
    end
end

pub fn solve_panel(a: f64[], k: u32, b: u32, n: u32, dg: f64[])
    mut r = k + b
    while r + u32(4) <= n do
        mut j = u32(0)
        while j < b do
            mut c0 = a[r * n + k + j]
            mut c1 = a[(r + u32(1)) * n + k + j]
            mut c2 = a[(r + u32(2)) * n + k + j]
            mut c3 = a[(r + u32(3)) * n + k + j]
            mut q = u32(0)
            while q < j do
                mut d = dg[q * b + j]
                c0 = fma(a[r * n + k + q], d, c0)
                c1 = fma(a[(r + u32(1)) * n + k + q], d, c1)
                c2 = fma(a[(r + u32(2)) * n + k + q], d, c2)
                c3 = fma(a[(r + u32(3)) * n + k + q], d, c3)
                q = q + u32(1)
            end
            mut piv = dg[j * b + j]
            a[r * n + k + j] = c0 / piv
            a[(r + u32(1)) * n + k + j] = c1 / piv
            a[(r + u32(2)) * n + k + j] = c2 / piv
            a[(r + u32(3)) * n + k + j] = c3 / piv
            j = j + u32(1)
        end
        r = r + u32(4)
    end
    while r < n do
        mut j2 = u32(0)
        while j2 < b do
            mut acc = a[r * n + k + j2]
            mut q2 = u32(0)
            while q2 < j2 do
                acc = fma(a[r * n + k + q2], dg[q2 * b + j2], acc)
                q2 = q2 + u32(1)
            end
            a[r * n + k + j2] = acc / dg[j2 * b + j2]
            j2 = j2 + u32(1)
        end
        r = r + u32(1)
    end
end

fn trailing(a: f64[], k: u32, b: u32, n: u32)
    mut bv = b / u32(4) * u32(4)
    mut i = k + b
    while i < n do
        mut j = k + b
        while j + u32(3) <= i do
            mut c0 = simd[f64, 4](f64(0.0))
            mut c1 = simd[f64, 4](f64(0.0))
            mut c2 = simd[f64, 4](f64(0.0))
            mut c3 = simd[f64, 4](f64(0.0))
            mut t = u32(0)
            while t < bv do
                mut v = simd[f64, 4](a, i * n + k + t)
                c0 = c0 + v * simd[f64, 4](a, j * n + k + t)
                c1 = c1 + v * simd[f64, 4](a, (j + u32(1)) * n + k + t)
                c2 = c2 + v * simd[f64, 4](a, (j + u32(2)) * n + k + t)
                c3 = c3 + v * simd[f64, 4](a, (j + u32(3)) * n + k + t)
                t = t + u32(4)
            end
            mut s0 = hsum(c0)
            mut s1 = hsum(c1)
            mut s2 = hsum(c2)
            mut s3 = hsum(c3)
            while t < b do
                mut w = a[i * n + k + t]
                s0 = s0 + w * a[j * n + k + t]
                s1 = s1 + w * a[(j + u32(1)) * n + k + t]
                s2 = s2 + w * a[(j + u32(2)) * n + k + t]
                s3 = s3 + w * a[(j + u32(3)) * n + k + t]
                t = t + u32(1)
            end
            a[i * n + j] = a[i * n + j] - s0
            a[i * n + j + u32(1)] = a[i * n + j + u32(1)] - s1
            a[i * n + j + u32(2)] = a[i * n + j + u32(2)] - s2
            a[i * n + j + u32(3)] = a[i * n + j + u32(3)] - s3
            j = j + u32(4)
        end
        while j <= i do
            mut acc = f64(0.0)
            mut q = u32(0)
            while q < b do
                acc = acc + a[i * n + k + q] * a[j * n + k + q]
                q = q + u32(1)
            end
            a[i * n + j] = a[i * n + j] - acc
            j = j + u32(1)
        end
        i = i + u32(1)
    end
end

pub fn pack_panel(a: f64[], k: u32, b: u32, n: u32, pk: f64[], nc: u32)
    mut base = k + b
    mut cfull = (n - base) / u32(4)
    mut c = u32(0)
    while c < cfull do
        mut top = base + c * u32(4)
        mut dst = c * b * u32(4)
        mut r = u32(0)
        while r < u32(4) do
            mut src = (top + r) * n + k
            mut t = u32(0)
            while t < b do
                pk[dst + t * u32(4) + r] = a[src + t]
                t = t + u32(1)
            end
            r = r + u32(1)
        end
        c = c + u32(1)
    end
    while c < nc do
        mut top2 = base + c * u32(4)
        mut have = u32(4)
        if top2 + u32(4) > n then
            have = n - top2
        end
        mut dst2 = c * b * u32(4)
        mut r2 = u32(0)
        while r2 < have do
            mut src2 = (top2 + r2) * n + k
            mut t2 = u32(0)
            while t2 < b do
                pk[dst2 + t2 * u32(4) + r2] = a[src2 + t2]
                t2 = t2 + u32(1)
            end
            r2 = r2 + u32(1)
        end
        while r2 < u32(4) do
            mut t3 = u32(0)
            while t3 < b do
                pk[dst2 + t3 * u32(4) + r2] = f64(0.0)
                t3 = t3 + u32(1)
            end
            r2 = r2 + u32(1)
        end
        c = c + u32(1)
    end
end

pub fn solve_packed(pk: f64[], dg: f64[], nc: u32, b: u32)
    mut c = u32(0)
    while c < nc do
        mut base = c * b * u32(4)
        mut jb = u32(0)
        while jb + u32(8) <= b do
            mut a0 = simd[f64, 4](pk, base + (jb + u32(0)) * u32(4))
            mut a1 = simd[f64, 4](pk, base + (jb + u32(1)) * u32(4))
            mut a2 = simd[f64, 4](pk, base + (jb + u32(2)) * u32(4))
            mut a3 = simd[f64, 4](pk, base + (jb + u32(3)) * u32(4))
            mut a4 = simd[f64, 4](pk, base + (jb + u32(4)) * u32(4))
            mut a5 = simd[f64, 4](pk, base + (jb + u32(5)) * u32(4))
            mut a6 = simd[f64, 4](pk, base + (jb + u32(6)) * u32(4))
            mut a7 = simd[f64, 4](pk, base + (jb + u32(7)) * u32(4))
            mut q = u32(0)
            while q < jb do
                mut vq = simd[f64, 4](pk, base + q * u32(4))
                a0 = fma(simd[f64, 4](dg[q * b + jb + u32(0)]), vq, a0)
                a1 = fma(simd[f64, 4](dg[q * b + jb + u32(1)]), vq, a1)
                a2 = fma(simd[f64, 4](dg[q * b + jb + u32(2)]), vq, a2)
                a3 = fma(simd[f64, 4](dg[q * b + jb + u32(3)]), vq, a3)
                a4 = fma(simd[f64, 4](dg[q * b + jb + u32(4)]), vq, a4)
                a5 = fma(simd[f64, 4](dg[q * b + jb + u32(5)]), vq, a5)
                a6 = fma(simd[f64, 4](dg[q * b + jb + u32(6)]), vq, a6)
                a7 = fma(simd[f64, 4](dg[q * b + jb + u32(7)]), vq, a7)
                q = q + u32(1)
            end
            store(pk, base + (jb + u32(0)) * u32(4), a0)
            store(pk, base + (jb + u32(1)) * u32(4), a1)
            store(pk, base + (jb + u32(2)) * u32(4), a2)
            store(pk, base + (jb + u32(3)) * u32(4), a3)
            store(pk, base + (jb + u32(4)) * u32(4), a4)
            store(pk, base + (jb + u32(5)) * u32(4), a5)
            store(pk, base + (jb + u32(6)) * u32(4), a6)
            store(pk, base + (jb + u32(7)) * u32(4), a7)
            mut j2 = jb
            while j2 < jb + u32(8) do
                mut v = simd[f64, 4](pk, base + j2 * u32(4))
                mut q2 = jb
                while q2 < j2 do
                    v = fma(simd[f64, 4](dg[q2 * b + j2]),
                            simd[f64, 4](pk, base + q2 * u32(4)), v)
                    q2 = q2 + u32(1)
                end
                store(pk, base + j2 * u32(4),
                      v * simd[f64, 4](1.0 / dg[j2 * b + j2]))
                j2 = j2 + u32(1)
            end
            jb = jb + u32(8)
        end
        mut j = jb
        while j < b do
            mut v3 = simd[f64, 4](pk, base + j * u32(4))
            mut q3 = u32(0)
            while q3 < j do
                v3 = fma(simd[f64, 4](dg[q3 * b + j]),
                         simd[f64, 4](pk, base + q3 * u32(4)), v3)
                q3 = q3 + u32(1)
            end
            store(pk, base + j * u32(4),
                  v3 * simd[f64, 4](1.0 / dg[j * b + j]))
            j = j + u32(1)
        end
        c = c + u32(1)
    end
end

pub fn unpack_panel(pk: f64[], a: f64[], k: u32, b: u32, n: u32, nc: u32)
    mut base = k + b
    mut cfull = (n - base) / u32(4)
    mut c = u32(0)
    while c < cfull do
        mut top = base + c * u32(4)
        mut src = c * b * u32(4)
        mut r = u32(0)
        while r < u32(4) do
            mut dst = (top + r) * n + k
            mut t = u32(0)
            while t < b do
                a[dst + t] = pk[src + t * u32(4) + r]
                t = t + u32(1)
            end
            r = r + u32(1)
        end
        c = c + u32(1)
    end
    while c < nc do
        mut top2 = base + c * u32(4)
        mut have = u32(4)
        if top2 + u32(4) > n then
            have = n - top2
        end
        mut src2 = c * b * u32(4)
        mut r2 = u32(0)
        while r2 < have do
            mut dst2 = (top2 + r2) * n + k
            mut t2 = u32(0)
            while t2 < b do
                a[dst2 + t2] = pk[src2 + t2 * u32(4) + r2]
                t2 = t2 + u32(1)
            end
            r2 = r2 + u32(1)
        end
        c = c + u32(1)
    end
end

pub fn trailing_packed(a: f64[], k: u32, b: u32, n: u32, pk: f64[], nc: u32)
    mut base = k + b
    mut nlim = n / u32(8) * u32(8)
    mut ncfull = (n - base) / u32(4)
    mut ci = u32(0)
    while ci < ncfull do
        mut i0 = base + ci * u32(4)
        mut j0 = u32(0)
        while j0 < nlim do
            if j0 >= base then
                if j0 <= i0 then
                    mut cj = (j0 - base) / u32(4)
                    mut d00 = simd[f64, 4](f64(0.0))
                    mut d01 = simd[f64, 4](f64(0.0))
                    mut d10 = simd[f64, 4](f64(0.0))
                    mut d11 = simd[f64, 4](f64(0.0))
                    mut d20 = simd[f64, 4](f64(0.0))
                    mut d21 = simd[f64, 4](f64(0.0))
                    mut d30 = simd[f64, 4](f64(0.0))
                    mut d31 = simd[f64, 4](f64(0.0))
                    mut db = b * u32(4)
                    mut dpa = (ci - cj) * db
                    mut p0 = cj * db
                    mut pend = p0 + db
                    while p0 < pend do
                        mut pa = p0 + dpa
                        mut v0 = simd[f64, 4](pk, p0)
                        mut v1 = simd[f64, 4](pk, p0 + db)
                        mut av = simd[f64, 4](pk[pa])
                        d00 = fma(av, v0, d00)
                        d01 = fma(av, v1, d01)
                        av = simd[f64, 4](pk[pa + u32(1)])
                        d10 = fma(av, v0, d10)
                        d11 = fma(av, v1, d11)
                        av = simd[f64, 4](pk[pa + u32(2)])
                        d20 = fma(av, v0, d20)
                        d21 = fma(av, v1, d21)
                        av = simd[f64, 4](pk[pa + u32(3)])
                        d30 = fma(av, v0, d30)
                        d31 = fma(av, v1, d31)
                        p0 = p0 + u32(4)
                    end
                    mut w0 = (base + ci * u32(4)) * n + j0
                    store(a, w0, simd[f64, 4](a, w0) - d00)
                    store(a, w0 + u32(4), simd[f64, 4](a, w0 + u32(4)) - d01)
                    mut w1 = (base + ci * u32(4) + u32(1)) * n + j0
                    store(a, w1, simd[f64, 4](a, w1) - d10)
                    store(a, w1 + u32(4), simd[f64, 4](a, w1 + u32(4)) - d11)
                    mut w2 = (base + ci * u32(4) + u32(2)) * n + j0
                    store(a, w2, simd[f64, 4](a, w2) - d20)
                    store(a, w2 + u32(4), simd[f64, 4](a, w2 + u32(4)) - d21)
                    mut w3 = (base + ci * u32(4) + u32(3)) * n + j0
                    store(a, w3, simd[f64, 4](a, w3) - d30)
                    store(a, w3 + u32(4), simd[f64, 4](a, w3 + u32(4)) - d31)
                end
            end
            j0 = j0 + u32(8)
        end
        ci = ci + u32(1)
    end
    mut i = base
    while i < n do
        mut c2 = (i - base) / u32(4)
        mut done = base
        if c2 < ncfull then
            mut i0c = base + c2 * u32(4)
            while done + u32(8) <= i0c do
                done = done + u32(8)
            end
            if done + u32(8) <= nlim then
                done = done + u32(8)
            end
        end
        mut jj = done
        while jj <= i do
            mut v0 = simd[f64, 4](f64(0.0))
            mut v1 = simd[f64, 4](f64(0.0))
            mut q = u32(0)
            while q + u32(8) <= b do
                v0 = fma(simd[f64, 4](a, i * n + k + q),
                         simd[f64, 4](a, jj * n + k + q), v0)
                v1 = fma(simd[f64, 4](a, i * n + k + q + u32(4)),
                         simd[f64, 4](a, jj * n + k + q + u32(4)), v1)
                q = q + u32(8)
            end
            mut acc = hsum(v0) + hsum(v1)
            while q < b do
                acc = acc + a[i * n + k + q] * a[jj * n + k + q]
                q = q + u32(1)
            end
            a[i * n + jj] = a[i * n + jj] - acc
            jj = jj + u32(1)
        end
        i = i + u32(1)
    end
end

fn sub8(a: f64[], i: u32, j0: u32, n: u32, lo: simd[f64, 4], hi: simd[f64, 4])
    if i >= n then
        return
    end
    mut row = i * n + j0
    store(a, row, simd[f64, 4](a, row) - lo)
    store(a, row + u32(4), simd[f64, 4](a, row + u32(4)) - hi)
end

pub fn factor_blocked(a: f64[], n: u32, nb: u32) -> u32
    mut b0 = (nb + u32(7)) / u32(8) * u32(8)
    if b0 == u32(0) then
        b0 = u32(8)
    end
    mut pk = array[f64](n * b0 + b0 * u32(8) + u32(8))
    mut dg = array[f64](b0 * b0)
    mut k = u32(0)
    while k < n do
        mut b = b0
        if k + b > n then
            b = n - k
        end
        mut bad = factor_unblocked(a, k * n + k, b, n)
        if bad != u32(0) then
            return k + bad
        end
        pack_diag(a, k, b, n, dg)
        mut m = n - (k + b)
        if m > u32(0) then
            mut nc = (m + u32(3)) / u32(4)
            pack_panel(a, k, b, n, pk, nc)
            solve_packed(pk, dg, nc, b)
            unpack_panel(pk, a, k, b, n, nc)
            trailing_packed(a, k, b, n, pk, nc)
        end
        if m == u32(0) then
            solve_panel(a, k, b, n, dg)
        end
        k = k + b0
    end
    return u32(0)
end

pub fn factor(a: f64[], n: u32) -> u32
    return factor_blocked(a, n, u32(64))
end
