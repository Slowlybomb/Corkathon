pub fn update(factor: f64[], vec: f64[], dim: u32)
    mut col = 0
    while col < dim do
        mut base = col * dim
        mut diag = factor[base + col]
        mut head = vec[col]
        mut new_diag = sqrt(diag * diag + head * head)
        mut cosine = new_diag / diag
        mut sine = head / diag
        mut inv_cos = 1.0 / cosine
        factor[base + col] = new_diag
        mut row = col + 1
        while row < dim do
            mut old = factor[base + row]
            mut tail = vec[row]
            mut rotated = (old + sine * tail) * inv_cos
            factor[base + row] = rotated
            vec[row] = cosine * tail - sine * rotated
            row = row + 1
        end
        col = col + 1
    end
end

pub fn downdate(factor: f64[], vec: f64[], dim: u32) -> u32
    mut col = 0
    while col < dim do
        mut base = col * dim
        mut diag = factor[base + col]
        mut head = vec[col]
        mut remaining = diag * diag - head * head
        if remaining <= 0.0 then
            return col + 1
        end
        mut new_diag = sqrt(remaining)
        mut cosine = new_diag / diag
        mut sine = head / diag
        mut inv_cos = 1.0 / cosine
        factor[base + col] = new_diag
        mut row = col + 1
        while row < dim do
            mut old = factor[base + row]
            mut tail = vec[row]
            mut rotated = (old - sine * tail) * inv_cos
            factor[base + row] = rotated
            vec[row] = cosine * tail - sine * rotated
            row = row + 1
        end
        col = col + 1
    end
    return 0
end

pub fn syr(target: f64[], vec: f64[], alpha: f64, dim: u32)
    mut col = 0
    while col < dim do
        mut scaled = alpha * vec[col]
        mut base = col * dim
        mut row = col
        while row < dim do
            target[base + row] = target[base + row] + scaled * vec[row]
            row = row + 1
        end
        col = col + 1
    end
end

pub fn solve_lower(factor: f64[], rhs: f64[], dim: u32)
    mut col = 0
    while col < dim do
        mut base = col * dim
        mut known = rhs[col] / factor[base + col]
        rhs[col] = known
        mut row = col + 1
        while row < dim do
            rhs[row] = rhs[row] - known * factor[base + row]
            row = row + 1
        end
        col = col + 1
    end
end

pub fn solve_upper(factor: f64[], rhs: f64[], dim: u32)
    mut left = dim
    while left > 0 do
        mut row = left - 1
        mut base = row * dim
        mut wide = simd[f64, 4](0.0)
        mut total = 0.0
        mut col = row + 1
        while col + 4 <= dim do
            wide = fma(simd[f64, 4](factor, base + col),
                       simd[f64, 4](rhs, col), wide)
            col = col + 4
        end
        while col < dim do
            total = total + factor[base + col] * rhs[col]
            col = col + 1
        end
        rhs[row] = (rhs[row] - (hsum(wide) + total)) / factor[base + row]
        left = left - 1
    end
end

pub fn factor(mat: f64[], out: f64[], dim: u32) -> u32
    mut i = 0
    while i < dim * dim do
        out[i] = 0.0
        i = i + 1
    end
    mut col = 0
    while col < dim do
        mut base = col * dim
        mut diag = mat[base + col]
        mut k = 0
        while k < col do
            mut above = out[k * dim + col]
            diag = diag - above * above
            k = k + 1
        end
        if diag <= 0.0 then
            return col + 1
        end
        mut root = sqrt(diag)
        out[base + col] = root
        mut inv_root = 1.0 / root
        mut row = col + 1
        while row < dim do
            out[base + row] = mat[base + row]
            row = row + 1
        end
        mut prev = 0
        while prev < col do
            mut prev_base = prev * dim
            mut coeff = out[prev_base + col]
            mut r2 = col + 1
            while r2 < dim do
                out[base + r2] = out[base + r2] - coeff * out[prev_base + r2]
                r2 = r2 + 1
            end
            prev = prev + 1
        end
        mut r3 = col + 1
        while r3 < dim do
            out[base + r3] = out[base + r3] * inv_root
            r3 = r3 + 1
        end
        col = col + 1
    end
    return 0
end

pub fn roll2(factor: f64[], vec_a: f64[], vec_b: f64[],
             sign_a: f64, sign_b: f64, dim: u32) -> u32
    mut col = 0
    while col < dim do
        mut base = col * dim
        mut diag = factor[base + col]
        mut head_a = vec_a[col]
        mut remaining_a = diag * diag + sign_a * head_a * head_a
        if remaining_a <= 0.0 then
            return col + 1
        end
        mut mid_diag = sqrt(remaining_a)
        mut cos_a = mid_diag / diag
        mut sin_a = head_a / diag
        mut signed_a = sign_a * sin_a
        mut inv_cos_a = 1.0 / cos_a
        mut head_b = vec_b[col]
        mut remaining_b = mid_diag * mid_diag + sign_b * head_b * head_b
        if remaining_b <= 0.0 then
            return col + 1
        end
        mut new_diag = sqrt(remaining_b)
        mut cos_b = new_diag / mid_diag
        mut sin_b = head_b / mid_diag
        mut signed_b = sign_b * sin_b
        mut inv_cos_b = 1.0 / cos_b
        factor[base + col] = new_diag
        mut wide_signed_a = simd[f64, 4](signed_a)
        mut wide_neg_sin_a = simd[f64, 4](0.0 - sin_a)
        mut wide_cos_a = simd[f64, 4](cos_a)
        mut wide_inv_a = simd[f64, 4](inv_cos_a)
        mut wide_signed_b = simd[f64, 4](signed_b)
        mut wide_neg_sin_b = simd[f64, 4](0.0 - sin_b)
        mut wide_cos_b = simd[f64, 4](cos_b)
        mut wide_inv_b = simd[f64, 4](inv_cos_b)
        mut row = col + 1
        while row + 4 <= dim do
            mut old = simd[f64, 4](factor, base + row)
            mut tail_a = simd[f64, 4](vec_a, row)
            mut mid = fma(wide_signed_a, tail_a, old) * wide_inv_a
            store(vec_a, row, fma(wide_neg_sin_a, mid, wide_cos_a * tail_a))
            mut tail_b = simd[f64, 4](vec_b, row)
            mut rotated = fma(wide_signed_b, tail_b, mid) * wide_inv_b
            store(vec_b, row, fma(wide_neg_sin_b, rotated, wide_cos_b * tail_b))
            store(factor, base + row, rotated)
            row = row + 4
        end
        while row < dim do
            mut old = factor[base + row]
            mut tail_a = vec_a[row]
            mut mid = (old + signed_a * tail_a) * inv_cos_a
            vec_a[row] = cos_a * tail_a - sin_a * mid
            mut tail_b = vec_b[row]
            mut rotated = (mid + signed_b * tail_b) * inv_cos_b
            vec_b[row] = cos_b * tail_b - sin_b * rotated
            factor[base + row] = rotated
            row = row + 1
        end
        col = col + 1
    end
    return 0
end

pub fn roll4(factor: f64[], vec_a: f64[], vec_b: f64[], vec_c: f64[],
             vec_d: f64[], sign_a: f64, sign_b: f64, sign_c: f64,
             sign_d: f64, dim: u32) -> u32
    mut first = roll2(factor, vec_a, vec_b, sign_a, sign_b, dim)
    if first != 0 then
        return first
    end
    return roll2(factor, vec_c, vec_d, sign_c, sign_d, dim)
end

pub fn solve3_lower(factor: f64[], rhs_a: f64[], rhs_b: f64[], rhs_c: f64[],
                    dim: u32)
    mut col = 0
    while col < dim do
        mut base = col * dim
        mut diag = factor[base + col]
        mut known_a = rhs_a[col] / diag
        mut known_b = rhs_b[col] / diag
        mut known_c = rhs_c[col] / diag
        rhs_a[col] = known_a
        rhs_b[col] = known_b
        rhs_c[col] = known_c
        mut row = col + 1
        while row < dim do
            mut coeff = factor[base + row]
            rhs_a[row] = rhs_a[row] - known_a * coeff
            rhs_b[row] = rhs_b[row] - known_b * coeff
            rhs_c[row] = rhs_c[row] - known_c * coeff
            row = row + 1
        end
        col = col + 1
    end
end

pub fn solve3_upper(factor: f64[], rhs_a: f64[], rhs_b: f64[], rhs_c: f64[],
                    dim: u32)
    mut left = dim
    while left > 0 do
        mut row = left - 1
        mut base = row * dim
        mut diag = factor[base + row]
        mut wide_a = simd[f64, 4](0.0)
        mut wide_b = simd[f64, 4](0.0)
        mut wide_c = simd[f64, 4](0.0)
        mut total_a = 0.0
        mut total_b = 0.0
        mut total_c = 0.0
        mut col = row + 1
        while col + 4 <= dim do
            mut wide_coeff = simd[f64, 4](factor, base + col)
            wide_a = fma(wide_coeff, simd[f64, 4](rhs_a, col), wide_a)
            wide_b = fma(wide_coeff, simd[f64, 4](rhs_b, col), wide_b)
            wide_c = fma(wide_coeff, simd[f64, 4](rhs_c, col), wide_c)
            col = col + 4
        end
        while col < dim do
            mut coeff = factor[base + col]
            total_a = total_a + coeff * rhs_a[col]
            total_b = total_b + coeff * rhs_b[col]
            total_c = total_c + coeff * rhs_c[col]
            col = col + 1
        end
        rhs_a[row] = (rhs_a[row] - (hsum(wide_a) + total_a)) / diag
        rhs_b[row] = (rhs_b[row] - (hsum(wide_b) + total_b)) / diag
        rhs_c[row] = (rhs_c[row] - (hsum(wide_c) + total_c)) / diag
        left = left - 1
    end
end
