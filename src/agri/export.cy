mut D = require("data.cy")
mut PR = require("predict.cy")
mut U = require("../../lib/geo/utm.cy")
mut TN = require("../../lib/geo/terrain.cy")
mut TX = require("../../lib/io/text.cy")
mut BY = require("../../lib/io/bytes.cy")

extern "kernel32.dll" fn CreateDirectoryA(path: u8[], attrs: u64) -> i32

pub fn mkdir(path: u8[])
    mut p = array[u8](0)
    for c in path do
        push(p, c)
    end
    push(p, u8(0))
    mut r = CreateDirectoryA(p, u64(0))
end

fn cat3(a: u8[], b: u8[], c: u8[]) -> u8[]
    mut p = array[u8](0)
    D.cat(p, a)
    D.cat(p, b)
    D.cat(p, c)
    return p
end

fn stats(v: f32[], valid: f32[], n: u32, out: f64[])
    mut lo = 1e30
    mut hi = -1e30
    mut s = 0.0
    mut k = 0.0
    mut q = u32(0)
    while q < n do
        if valid[q] > f32(0.5) then
            x = f64(v[q])
            lo = min(lo, x)
            hi = max(hi, x)
            s = s + x
            k = k + 1.0
        end
        q = q + u32(1)
    end
    out[0] = lo
    out[1] = hi
    out[2] = s / max(k, 1.0)
end

fn json_layer(j: u8[], first: bool, name: u8[], file: u8[], typ: u8[], units: u8[], group: u8[], st: f64[], d0: u32, d1: u32)
    if not first then
        TX.putstr(j, bytes(","))
    end
    TX.putstr(j, bytes("\n    {\"name\": \""))
    TX.putstr(j, name)
    TX.putstr(j, bytes("\", \"file\": \"layers/"))
    TX.putstr(j, file)
    TX.putstr(j, bytes("\", \"type\": \""))
    TX.putstr(j, typ)
    TX.putstr(j, bytes("\", \"units\": \""))
    TX.putstr(j, units)
    TX.putstr(j, bytes("\", \"group\": \""))
    TX.putstr(j, group)
    TX.putstr(j, bytes("\""))
    if d1 > u32(0) then
        TX.putstr(j, bytes(", \"depth_cm\": ["))
        TX.putint(j, u64(d0))
        TX.putstr(j, bytes(", "))
        TX.putint(j, u64(d1))
        TX.putstr(j, bytes("]"))
    end
    if len(st) == u32(3) then
        TX.putstr(j, bytes(", \"min\": "))
        TX.putfix(j, st[0], u32(4))
        TX.putstr(j, bytes(", \"max\": "))
        TX.putfix(j, st[1], u32(4))
        TX.putstr(j, bytes(", \"mean\": "))
        TX.putfix(j, st[2], u32(4))
    end
    TX.putstr(j, bytes("}"))
end

fn depth_top(k: u32) -> u32
    if k == u32(0) then
        return u32(0)
    end
    if k == u32(1) then
        return u32(5)
    end
    if k == u32(2) then
        return u32(15)
    end
    if k == u32(3) then
        return u32(30)
    end
    if k == u32(4) then
        return u32(60)
    end
    if k == u32(5) then
        return u32(100)
    end
    return u32(200)
end

fn name_at(list: u8[], k: u32) -> u8[]
    mut out = array[u8](0)
    mut idx = u32(0)
    for c in list do
        if c == u8(44) then
            idx = idx + u32(1)
        else
            if idx == k then
                push(out, c)
            end
        end
    end
    return out
end

pub fn package(dir: u8[], label: u8[], cv: f32[], w: u32, h: u32, x0: f64, y0: f64, px: f64, epsg: u32, demdir: u8[], notes: u8[]) -> u32
    n = w * h
    mkdir(dir)
    mkdir(cat3(dir, bytes("layers"), bytes("")))
    mut valid = array[f32](n)
    mut q = u32(0)
    while q < n do
        valid[q] = cv[q * PR.NCH + u32(43)]
        q = q + u32(1)
    end
    mut j = array[u8](0)
    zone = epsg % u32(100)
    south = epsg > u32(32700)
    tl = U.to_latlon(x0, y0, zone, south)
    tr = U.to_latlon(x0 + f64(w) * px, y0, zone, south)
    bl = U.to_latlon(x0, y0 - f64(h) * px, zone, south)
    br = U.to_latlon(x0 + f64(w) * px, y0 - f64(h) * px, zone, south)
    TX.putstr(j, bytes("{\n  \"name\": \""))
    TX.putstr(j, label)
    TX.putstr(j, bytes("\",\n  \"crs\": \"EPSG:"))
    TX.putint(j, u64(epsg))
    TX.putstr(j, bytes("\",\n  \"width\": "))
    TX.putint(j, u64(w))
    TX.putstr(j, bytes(",\n  \"height\": "))
    TX.putint(j, u64(h))
    TX.putstr(j, bytes(",\n  \"pixel_size_m\": "))
    TX.putfix(j, px, u32(2))
    TX.putstr(j, bytes(",\n  \"origin_x\": "))
    TX.putfix(j, x0, u32(2))
    TX.putstr(j, bytes(",\n  \"origin_y\": "))
    TX.putfix(j, y0, u32(2))
    TX.putstr(j, bytes(",\n  \"layout\": \"row-major from the north-west corner, one value per pixel, little-endian\",\n  \"nodata_float32\": -9999,\n  \"nodata_uint8\": 255,\n  \"corners_lat_lon\": {"))
    TX.putstr(j, bytes("\"top_left\": ["))
    TX.putfix(j, tl.0, u32(6))
    TX.putstr(j, bytes(", "))
    TX.putfix(j, tl.1, u32(6))
    TX.putstr(j, bytes("], \"top_right\": ["))
    TX.putfix(j, tr.0, u32(6))
    TX.putstr(j, bytes(", "))
    TX.putfix(j, tr.1, u32(6))
    TX.putstr(j, bytes("], \"bottom_left\": ["))
    TX.putfix(j, bl.0, u32(6))
    TX.putstr(j, bytes(", "))
    TX.putfix(j, bl.1, u32(6))
    TX.putstr(j, bytes("], \"bottom_right\": ["))
    TX.putfix(j, br.0, u32(6))
    TX.putstr(j, bytes(", "))
    TX.putfix(j, br.1, u32(6))
    TX.putstr(j, bytes("]},\n  \"layers\": ["))
    mut wrote = u32(0)
    mut buf = array[f32](n)
    mut st = array[f64](3)
    mut first = true
    mut ch = u32(3)
    while ch < u32(43) do
        mut name = array[u8](0)
        mut units = array[u8](0)
        mut group = array[u8](0)
        mut isu8 = false
        mut d0 = u32(0)
        mut d1 = u32(0)
        mut use = true
        if ch == u32(3) then
            name = bytes("ndvi")
            units = bytes("index")
            group = bytes("surface")
        end
        if ch == u32(4) then
            name = bytes("ndmi")
            units = bytes("index")
            group = bytes("surface")
        end
        if ch == u32(5) then
            name = bytes("field_boundary_score")
            units = bytes("score")
            group = bytes("fields")
        end
        if ch == u32(6) then
            name = bytes("crop_class")
            units = bytes("class")
            group = bytes("fields")
            isu8 = true
        end
        if ch == u32(7) then
            name = bytes("wrb_code")
            units = bytes("SoilGrids WRB code")
            group = bytes("soil")
            isu8 = true
        end
        if ch >= u32(8) and ch < u32(32) then
            name = name_at(PR.soil_names(), ch - u32(8))
            pr = (ch - u32(8)) / u32(6)
            units = bytes("pH")
            if pr == u32(1) then
                units = bytes("g/kg")
            end
            if pr >= u32(2) then
                units = bytes("%")
            end
            group = bytes("soil")
            d0 = depth_top((ch - u32(8)) % u32(6))
            d1 = depth_top((ch - u32(8)) % u32(6) + u32(1))
        end
        if ch >= u32(32) and ch < u32(36) then
            name = name_at(PR.weather_names(), ch - u32(32))
            units = bytes("C")
            if ch == u32(33) then
                units = bytes("%")
            end
            if ch == u32(34) then
                units = bytes("m3/m3")
            end
            if ch == u32(35) then
                units = bytes("mm")
            end
            group = bytes("weather")
        end
        if ch >= u32(36) and ch < u32(40) then
            name = name_at(bytes("fraction_bare_soil,fraction_green_vegetation,fraction_dry_vegetation,fraction_water"), ch - u32(36))
            units = bytes("fraction")
            group = bytes("unmixing")
        end
        if ch == u32(40) then
            name = bytes("texture_class")
            units = bytes("USDA class")
            group = bytes("soil")
            isu8 = true
        end
        if ch == u32(41) then
            name = bytes("field_zones")
            units = bytes("zone")
            group = bytes("fields")
            isu8 = true
        end
        if ch == u32(42) then
            use = false
        end
        if use then
            if isu8 then
                mut b = array[u8](n)
                q = u32(0)
                while q < n do
                    mut v = u8(255)
                    if valid[q] > f32(0.5) then
                        v = u8(u32(max(f32(0.0), min(f32(254.0), cv[q * PR.NCH + ch]))))
                    end
                    b[q] = v
                    q = q + u32(1)
                end
                wrote = wrote + writefile(cat3(dir, bytes("layers/"), cat3(name, bytes(".u8"), bytes(""))), b)
                json_layer(j, first, name, cat3(name, bytes(".u8"), bytes("")), bytes("uint8"), units, group, array[f64](0), d0, d1)
            else
                mut b = array[u8](n * u32(4))
                q = u32(0)
                while q < n do
                    mut v = f32(-9999.0)
                    if valid[q] > f32(0.5) then
                        v = cv[q * PR.NCH + ch]
                    end
                    buf[q] = v
                    BY.putu32le(b, q * u32(4), tobits(v))
                    q = q + u32(1)
                end
                stats(buf, valid, n, st)
                wrote = wrote + writefile(cat3(dir, bytes("layers/"), cat3(name, bytes(".f32"), bytes(""))), b)
                json_layer(j, first, name, cat3(name, bytes(".f32"), bytes("")), bytes("float32"), units, group, st, d0, d1)
            end
            first = false
        end
        ch = ch + u32(1)
    end
    mut rgb = array[u8](n * u32(3))
    q = u32(0)
    while q < n do
        mut c = u32(0)
        while c < u32(3) do
            rgb[q * u32(3) + c] = u8(min(f32(255.0), max(f32(0.0), sqrt(min(cv[q * PR.NCH + c] * f32(3.2), f32(1.0))) * f32(255.0))))
            c = c + u32(1)
        end
        q = q + u32(1)
    end
    wrote = wrote + writefile(cat3(dir, bytes("layers/true_color.rgb8"), bytes("")), rgb)
    mut all = array[f32](n)
    q = u32(0)
    while q < n do
        all[q] = f32(1.0)
        q = q + u32(1)
    end
    TX.putstr(j, bytes(",\n    {\"name\": \"true_color\", \"file\": \"layers/true_color.rgb8\", \"type\": \"uint8 x3 (RGB)\", \"units\": \"display\", \"group\": \"surface\"}"))
    t = TN.load(demdir)
    if t.ok then
        mut el = array[u8](n * u32(4))
        q = u32(0)
        while q < n do
            ll = U.to_latlon(x0 + (f64(q % w) + 0.5) * px, y0 - (f64(q / w) + 0.5) * px, zone, south)
            e = TN.elevation_at(t, ll.0, ll.1)
            buf[q] = e
            BY.putu32le(el, q * u32(4), tobits(e))
            q = q + u32(1)
        end
        stats(buf, all, n, st)
        wrote = wrote + writefile(cat3(dir, bytes("layers/elevation.f32"), bytes("")), el)
        json_layer(j, false, bytes("elevation"), bytes("elevation.f32"), bytes("float32"), bytes("m above sea level"), bytes("terrain"), st, u32(0), u32(0))
    end
    TX.putstr(j, bytes("\n  ],\n  \"soil_volume\": {\"properties\": [\"ph\", \"soc_gkg\", \"clay_pct\", \"sand_pct\"], \"depths_cm\": [0, 5, 15, 30, 60, 100, 200], \"layer_name\": \"<property>_<top>-<bottom>cm\"},"))
    TX.putstr(j, bytes("\n  \"legends\": {\n    \"field_zones\": [\"not a field\", \"low\", \"medium\", \"high\"],"))
    TX.putstr(j, bytes("\n    \"texture_class\": [\"sand\", \"loamy sand\", \"sandy loam\", \"loam\", \"silt loam\", \"silt\", \"sandy clay loam\", \"clay loam\", \"silty clay loam\", \"sandy clay\", \"silty clay\", \"clay\"],"))
    TX.putstr(j, bytes("\n    \"crop_class\": [\"unknown\", \"sugar beet\", \"summer oat\", \"meadow\", \"rape\", \"hop\", \"winter spelt\", \"winter triticale\", \"beans\", \"peas\", \"potato\", \"soybeans\", \"asparagus\", \"winter wheat\", \"winter barley\", \"winter rye\", \"summer barley\", \"maize\"],"))
    TX.putstr(j, bytes("\n    \"wrb_code\": \"SoilGrids 2.0 WRB most-probable-group code (see the ISRIC WRB legend)\"\n  },"))
    TX.putstr(j, bytes("\n  \"notes\": \""))
    TX.putstr(j, notes)
    TX.putstr(j, bytes("\","))
    TX.putstr(j, bytes("\n  \"sources\": \"Sentinel-2 L2A (Earth Search, AWS), ISRIC SoilGrids 2.0, ERA5-Land via Open-Meteo, AWS Terrain Tiles; model trained on Munich480\"\n}\n"))
    wrote = wrote + writefile(cat3(dir, bytes("manifest.json"), bytes("")), j)
    return wrote
end
