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
