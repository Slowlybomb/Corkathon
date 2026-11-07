mut PC = require("phone_core.cy")

fn copy_from_memory(address: u64, count: u32) -> u8[]
    mut data = array[u8](count)
    mut i = u32(0)
    while i < count do
        data[i] = peek[u8](address + u64(i))
        i = i + u32(1)
    end
    return data
end

pub fn agri_run(model_address: u64, model_length: u64, heads_address: u64, heads_length: u64, refl_address: u64, out_address: u64, size: u64, doy: u64) -> u64
    model = copy_from_memory(model_address, u32(model_length))
    mut regional_soil_heads = array[u8](0)
    if heads_length > u64(0) then
        regional_soil_heads = copy_from_memory(heads_address, u32(heads_length))
    end
    chunk = u32(size)
    pixels = chunk * chunk
    band_values = u32(10) * pixels
    mut refl = array[f32](band_values)
    mut i = u32(0)
    while i < band_values do
        refl[i] = frombits(peek[u32](refl_address + u64(i) * u64(4)))
        i = i + u32(1)
    end
    output_values = PC.OUTPUTS * pixels
    mut out = array[f32](output_values)
    seconds = PC.infer(model, regional_soil_heads, refl, chunk, u32(doy), out)
    i = u32(0)
    while i < output_values do
        poke(out_address + u64(i) * u64(4), tobits(out[i]))
        i = i + u32(1)
    end
    return u64(seconds * 1000000000.0)
end
