package ie.corkathon.phone;

import android.content.res.AssetManager;

import org.json.JSONObject;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

final class SurveyRunner {
    static final int TILE = 144;
    static final String[] DEPTHS = {
        "0-5cm", "5-15cm", "15-30cm", "30-60cm", "60-100cm", "100-200cm"
    };
    static final int[][] DEPTH_CM = {{0, 5}, {5, 15}, {15, 30}, {30, 60}, {60, 100}, {100, 200}};
    static final String[] SOIL = {"ph", "soc_gkg", "clay_pct", "sand_pct"};
    static final String[] SOIL_UNITS = {"pH", "g/kg", "%", "%"};
    static final String[][] WEATHER = {
        {"temperature_c", "C"},
        {"humidity_pct", "%"},
        {"soil_moisture_m3m3", "m3/m3"},
        {"water_balance_30d_mm", "mm"}
    };

    interface Progress {
        default void started(List<ResultServer.Layer> layers, int tiles, boolean[] done) {}

        void tile(int done, int total, int row, int col, double seconds, int core, double elapsed);
    }

    static String check(AssetManager assets, AgriModel model) throws Exception {
        int size = 80;
        AgriModel.Result r =
                model.run(AgriModel.asset(assets, "agri/golden32_in.f32"), size, 150, false);
        ByteBuffer expected = AgriModel.asset(assets, "agri/golden32_expected.f32");
        double worst = 0;
        int classes = 0;
        for (int k = 0; k < AgriModel.OUTPUTS; k++) {
            for (int y = AgriModel.MARGIN; y < size - AgriModel.MARGIN; y++) {
                for (int x = AgriModel.MARGIN; x < size - AgriModel.MARGIN; x++) {
                    float a = r.raw(k, y, x);
                    float b = expected.getFloat(((k * size + y) * size + x) * 4);
                    if (k == AgriModel.CROP || k == AgriModel.WRB) {
                        classes += a != b ? 1 : 0;
                    } else {
                        worst = Math.max(worst, Math.abs(a - b) / Math.max(1.0, Math.abs(b)));
                    }
                }
            }
        }
        boolean pass = worst < 1e-3 && classes == 0;
        return String.format(
                Locale.UK,
                "%s (largest difference from the laptop %.1e, %.1f s)",
                pass ? "PASS" : "FAIL",
                worst,
                r.computeNanos / 1e9);
    }

    static ResultServer.Survey run(
            AssetManager assets, AgriModel model, String device, Progress progress)
            throws Exception {
        JSONObject info = new JSONObject(AgriModel.text(assets, "agri/cork_cube.json"));
        int a = info.getInt("width");
        int w = info.getInt("window_px");
        int margin = info.getInt("margin");
        int doy = info.getInt("doy");
        int tiles = w / TILE;
        int size = TILE + 2 * AgriModel.MARGIN;
        ByteBuffer cube = AgriModel.asset(assets, "agri/cork_cube.u16");
        List<ResultServer.Layer> layers = new ArrayList<>();
        int[] channels = new int[25];
        float[][] modelData = new float[25][];
        channels[0] = AgriModel.BOUNDARY;
        modelData[0] = new float[w * w];
        layers.add(
                new ResultServer.Layer(
                        "field_boundary_score", "score", "fields", null, modelData[0]));
        for (int t = 0; t < 24; t++) {
            channels[1 + t] = AgriModel.PH + t;
            modelData[1 + t] = new float[w * w];
            layers.add(
                    new ResultServer.Layer(
                            SOIL[t / 6] + "_" + DEPTHS[t % 6],
                            SOIL_UNITS[t / 6],
                            "soil",
                            DEPTH_CM[t % 6],
                            modelData[1 + t]));
        }
        boolean[] done = new boolean[tiles * tiles];
        progress.started(layers, tiles, done);
        ExecutorService pool =
                Executors.newFixedThreadPool(
                        model.instances, r -> new Thread(null, r, "agri-tile", 64L << 20));
        long t0 = System.nanoTime();
        int[] count = {0};
        List<Future<?>> jobs = new ArrayList<>();
        try {
            for (int row = 0; row < tiles; row++) {
                for (int k = 0; k < tiles; k++) {
                    int ti = row;
                    int tj = row % 2 == 0 ? k : tiles - 1 - k;
                    jobs.add(
                            pool.submit(
                                    () -> {
                                        AgriModel.Result r =
                                                model.run(
                                                        cut(cube, a, ti * TILE, tj * TILE, size),
                                                        size,
                                                        doy,
                                                        true);
                                        for (int p = 0; p < channels.length; p++) {
                                            for (int y = 0; y < TILE; y++) {
                                                for (int x = 0; x < TILE; x++) {
                                                    modelData[p][
                                                                    (ti * TILE + y) * w
                                                                            + tj * TILE
                                                                            + x] =
                                                            r.value(channels[p], y, x);
                                                }
                                            }
                                        }
                                        int n;
                                        synchronized (count) {
                                            done[ti * tiles + tj] = true;
                                            n = ++count[0];
                                        }
                                        progress.tile(
                                                n,
                                                tiles * tiles,
                                                ti,
                                                tj,
                                                r.computeNanos / 1e9,
                                                r.slot,
                                                (System.nanoTime() - t0) / 1e9);
                                        return null;
                                    }));
                }
            }
            for (Future<?> f : jobs) {
                f.get();
            }
        } finally {
            pool.shutdown();
        }
        double seconds = (System.nanoTime() - t0) / 1e9;
        float[] ndvi = new float[w * w], ndmi = new float[w * w], ndwi = new float[w * w];
        for (int y = 0; y < w; y++) {
            for (int x = 0; x < w; x++) {
                int q = y * w + x;
                ndvi[q] =
                        ratio(
                                band(cube, a, 3, y + margin, x + margin),
                                band(cube, a, 2, y + margin, x + margin));
                ndmi[q] =
                        ratio(
                                band(cube, a, 7, y + margin, x + margin),
                                band(cube, a, 8, y + margin, x + margin));
                ndwi[q] =
                        ratio(
                                band(cube, a, 1, y + margin, x + margin),
                                band(cube, a, 3, y + margin, x + margin));
            }
        }
        layers.add(new ResultServer.Layer("ndvi", "index", "surface", null, ndvi));
        layers.add(new ResultServer.Layer("ndmi", "index", "surface", null, ndmi));
        layers.add(new ResultServer.Layer("ndwi", "index", "surface", null, ndwi));
        for (String[] item : WEATHER) {
            ByteBuffer b = AgriModel.asset(assets, "agri/weather/" + item[0] + ".f32");
            float[] v = new float[w * w];
            for (int i = 0; i < v.length; i++) {
                v[i] = b.getFloat(i * 4);
            }
            layers.add(new ResultServer.Layer(item[0], item[1], "weather", null, v));
        }
        return new ResultServer.Survey(
                layers,
                w,
                info.getDouble("window_e"),
                info.getDouble("window_n"),
                device,
                seconds,
                model.instances);
    }

    private static float band(ByteBuffer cube, int a, int b, int y, int x) {
        return (cube.getShort(((b * a + y) * a + x) * 2) & 0xFFFF) / 10000f;
    }

    private static float ratio(float a, float b) {
        return (a - b) / (a + b + 0.000001f);
    }

    static ByteBuffer cut(ByteBuffer cube, int a, int y0, int x0, int size) {
        ByteBuffer refl =
                ByteBuffer.allocateDirect(AgriModel.BANDS * size * size * 4)
                        .order(ByteOrder.LITTLE_ENDIAN);
        for (int b = 0; b < AgriModel.BANDS; b++) {
            for (int r = 0; r < size; r++) {
                int at = ((b * a + y0 + r) * a + x0) * 2;
                for (int c = 0; c < size; c++) {
                    refl.putFloat((cube.getShort(at + c * 2) & 0xFFFF) / 10000f);
                }
            }
        }
        refl.rewind();
        return refl;
    }
}
