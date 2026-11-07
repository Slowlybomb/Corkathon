pub fn word(seed: u32, i: u32) -> u32
    mut h = i + seed * u32(2654435761)
    h = h ^ (h >> u32(16))
    h = h * u32(2246822507)
    h = h ^ (h >> u32(13))
    h = h * u32(3266489909)
    h = h ^ (h >> u32(16))
    return h
end

pub fn uniform(seed: u32, i: u32) -> f32
    return f32(word(seed, i) >> u32(8)) * f32(5.9604645e-08)
end

pub fn hash8(v: simd[u32, 8], seed: u32) -> simd[u32, 8]
    mut h = v + simd[u32, 8](seed * u32(2654435761))
    h = h ^ (h >> simd[u32, 8](u32(16)))
    h = h * simd[u32, 8](u32(2246822507))
    h = h ^ (h >> simd[u32, 8](u32(13)))
    h = h * simd[u32, 8](u32(3266489909))
    h = h ^ (h >> simd[u32, 8](u32(16)))
    return h
end

pub fn iota8() -> simd[u32, 8]
    mut t = array[u32](u32(8))
    mut i = u32(0)
    while i < u32(8) do
        t[i] = i
        i = i + u32(1)
    end
    return simd[u32, 8](t, u32(0))
end
