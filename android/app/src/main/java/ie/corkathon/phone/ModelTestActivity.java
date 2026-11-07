package ie.corkathon.phone;

import android.app.Activity;
import android.content.res.ColorStateList;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.graphics.Typeface;
import android.os.Build;
import android.os.Bundle;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import org.json.JSONObject;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

public final class ModelTestActivity extends Activity {
    private static final int CREAM = Color.rgb(254, 254, 227), MUTED = Color.rgb(184, 202, 181), INK = Color.rgb(16, 44, 32);
    private static final int DOY = 150;
    private static final int TILE = 144;
    private static final int[] PREVIEW = {AgriModel.PH, AgriModel.CARBON, AgriModel.SAND, AgriModel.BOUNDARY, AgriModel.SOIL_MOISTURE};
    private static final String[] PREVIEW_NAMES = {"pH 0-5 cm", "organic carbon 0-5 cm (g/kg)", "sand 0-5 cm (%)", "field boundary score", "soil moisture (m3/m3)"};

    private TextView log;
    private ScrollView logScroll;
    private ImageView preview;
    private TextView legend;
    private AgriModel model;
    private AgriModel.Result last;
    private float[][] mosaic;
    private boolean[] tileDone;
    private int mosaicSize;
    private boolean showMosaic;
    private int previewIndex;
    private volatile boolean busy;

    @Override
    public void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().setStatusBarColor(INK);
        getWindow().setNavigationBarColor(INK);
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(20), dp(20), dp(20), dp(12));
        root.setBackgroundColor(INK);
        setContentView(root);
        text(root, "Ithir Model", 24, CREAM).setTypeface(null, Typeface.BOLD);
        text(root, "Century model compiled to ARM64, running on this phone. Input: recorded Sentinel-2 scene of the Cork demo area (30 May 2023), stored in the app.", 13, MUTED);
        LinearLayout row0 = new LinearLayout(this);
        root.addView(row0);
        button(row0, "Survey Cork area", () -> start(5));
        button(row0, "Camera module", this::finish);
        LinearLayout row1 = new LinearLayout(this);
        root.addView(row1);
        button(row1, "Check 32 px", () -> start(0));
        button(row1, "Check 128 px", () -> start(1));
        button(row1, "Next layer", this::nextLayer);
        preview = new ImageView(this);
        preview.setScaleType(ImageView.ScaleType.FIT_CENTER);
        preview.setAdjustViewBounds(true);
        root.addView(preview, new LinearLayout.LayoutParams(-1, dp(240)));
        legend = text(root, "", 12, MUTED);
        logScroll = new ScrollView(this);
        root.addView(logScroll, new LinearLayout.LayoutParams(-1, 0, 1));
        log = new TextView(this);
        log.setTextColor(MUTED);
        log.setTextSize(12);
        log.setTypeface(Typeface.MONOSPACE);
        log.setTextIsSelectable(true);
        logScroll.addView(log);
        say("device " + Build.MANUFACTURER + " " + Build.MODEL + ", Android " + Build.VERSION.RELEASE + ", ABI " + Build.SUPPORTED_ABIS[0]);
        if (getIntent().getBooleanExtra("autorun", false)) {
            start(3);
        }
    }

    private void start(int which) {
        if (busy) {
            say("busy: wait for the current run");
            return;
        }
        busy = true;
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        new Thread(null, () -> {
            try {
                ensureModel();
                if (which == 0 || which == 3) {
                    test("check 32 px, both stages, against the laptop", "golden32", 80, false);
                }
                if (which == 1 || which == 3) {
                    test("check 128 px, Irish soil heads, against the laptop", "cork128", 176, true);
                }
                if (which == 5 || which == 3) {
                    survey();
                }
            } catch (Throwable t) {
                say("error: " + t);
            } finally {
                busy = false;
                runOnUiThread(() -> getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON));
            }
        }, "agri-model", 64L << 20).start();
    }

    private synchronized void ensureModel() throws Exception {
        if (model != null) {
            return;
        }
        long t0 = System.nanoTime();
        model = AgriModel.get(getAssets(), Math.min(4, Runtime.getRuntime().availableProcessors()));
        say(String.format(Locale.US, "loaded ARM64 image (%d bytes) on %d cores and the model in %.0f ms",
                model.imageBytes, model.instances, (System.nanoTime() - t0) / 1e6));
    }

    private void test(String title, String name, int size, boolean irish) throws Exception {
        say("");
        say(title);
        ByteBuffer refl = AgriModel.asset(getAssets(), "agri/" + name + "_in.f32");
        AgriModel.Result r = model.run(refl, size, DOY, irish);
        int n = size - 2 * AgriModel.MARGIN;
        say(String.format(Locale.US, "  %d x %d px chunk: %.2f s on one core", n, n, r.computeNanos / 1e9));
        compare(r, AgriModel.asset(getAssets(), "agri/" + name + "_expected.f32"));
        last = r;
        showMosaic = false;
        runOnUiThread(this::showPreview);
    }

    private void survey() throws Exception {
        say("");
        JSONObject info = new JSONObject(AgriModel.text(getAssets(), "agri/cork_cube.json"));
        int a = info.getInt("width");
        int w = info.getInt("window_px");
        int doy = info.getInt("doy");
        int tiles = w / TILE;
        int size = TILE + 2 * AgriModel.MARGIN;
        ByteBuffer cube = AgriModel.asset(getAssets(), "agri/cork_cube.u16");
        say(String.format(Locale.US, "survey: %.2f x %.2f km in %d tiles of %d x %d px on %d cores",
                w * 0.01, w * 0.01, tiles * tiles, TILE, TILE, model.instances));
        mosaicSize = w;
        mosaic = new float[PREVIEW.length][w * w];
        tileDone = new boolean[tiles * tiles];
        showMosaic = true;
        runOnUiThread(this::showPreview);
        ExecutorService pool = Executors.newFixedThreadPool(model.instances, r -> new Thread(null, r, "agri-tile", 64L << 20));
        long t0 = System.nanoTime();
        List<Future<Double>> jobs = new ArrayList<>();
        int[] done = {0};
        try {
            for (int ti = 0; ti < tiles; ti++) {
                for (int k = 0; k < tiles; k++) {
                    int tj = ti % 2 == 0 ? k : tiles - 1 - k;
                    int row = ti;
                    jobs.add(pool.submit(() -> {
                        ByteBuffer refl = cut(cube, a, row * TILE, tj * TILE, size);
                        AgriModel.Result r = model.run(refl, size, doy, true);
                        for (int p = 0; p < PREVIEW.length; p++) {
                            for (int y = 0; y < TILE; y++) {
                                for (int x = 0; x < TILE; x++) {
                                    mosaic[p][(row * TILE + y) * w + tj * TILE + x] = r.value(PREVIEW[p], y, x);
                                }
                            }
                        }
                        int count;
                        synchronized (done) {
                            tileDone[row * tiles + tj] = true;
                            count = ++done[0];
                        }
                        say(String.format(Locale.US, "  tile %2d/%d (row %d, col %d): %.2f s on core %d, %.1f s since start",
                                count, tiles * tiles, row, tj, r.computeNanos / 1e9, r.slot, (System.nanoTime() - t0) / 1e9));
                        runOnUiThread(this::showPreview);
                        return r.computeNanos / 1e9;
                    }));
                }
            }
            double sum = 0;
            for (Future<Double> f : jobs) {
                sum += f.get();
            }
            double wall = (System.nanoTime() - t0) / 1e9;
            say(String.format(Locale.US, "survey done: %.1f s for %.1f km2 (%d pixels of 10 m), %.2f s per tile on one core, %.0f pixels/s with all cores",
                    wall, w * w * 1e-4, w * w, sum / jobs.size(), w * (double) w / wall));
        } finally {
            pool.shutdown();
        }
    }

    private static ByteBuffer cut(ByteBuffer cube, int a, int y0, int x0, int size) {
        ByteBuffer refl = ByteBuffer.allocateDirect(AgriModel.BANDS * size * size * 4).order(ByteOrder.LITTLE_ENDIAN);
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

    private void compare(AgriModel.Result r, ByteBuffer expected) {
        int s = r.size;
        double boundary = 0, soil = 0, weather = 0;
        int classes = 0, pixels = 0;
        for (int row = AgriModel.MARGIN; row < s - AgriModel.MARGIN; row++) {
            for (int col = AgriModel.MARGIN; col < s - AgriModel.MARGIN; col++) {
                pixels++;
                for (int k = 0; k < AgriModel.OUTPUTS; k++) {
                    float a = r.raw(k, row, col);
                    float b = expected.getFloat(((k * s + row) * s + col) * 4);
                    double e = Math.abs(a - b) / Math.max(1.0, Math.abs(b));
                    if (k == AgriModel.CROP || k == AgriModel.WRB) {
                        if (a != b) {
                            classes++;
                        }
                    } else if (k == AgriModel.BOUNDARY) {
                        boundary = Math.max(boundary, e);
                    } else if (k < AgriModel.TEMPERATURE) {
                        soil = Math.max(soil, e);
                    } else {
                        weather = Math.max(weather, e);
                    }
                }
            }
        }
        boolean pass = boundary < 1e-3 && soil < 1e-3 && weather < 1e-3 && classes <= pixels / 100;
        say(String.format(Locale.US, "  against the laptop: boundary %.1e, soil %.1e, weather %.1e, class differences %d of %d",
                boundary, soil, weather, classes, 2 * pixels));
        say(pass ? "  PASS: the phone gives the laptop's results" : "  FAIL: results differ from the laptop");
    }

    private void nextLayer() {
        previewIndex = (previewIndex + 1) % PREVIEW.length;
        showPreview();
    }

    private void showPreview() {
        float[] v;
        int n;
        boolean[] valid = null;
        if (showMosaic && mosaic != null) {
            n = mosaicSize;
            v = mosaic[previewIndex];
            int tiles = n / TILE;
            valid = new boolean[n * n];
            for (int i = 0; i < n * n; i++) {
                valid[i] = tileDone[(i / n / TILE) * tiles + (i % n) / TILE];
            }
        } else if (last != null) {
            n = last.interior;
            v = last.layer(PREVIEW[previewIndex]);
        } else {
            return;
        }
        float[] sorted = new float[v.length];
        int m = 0;
        for (int i = 0; i < v.length; i++) {
            if (valid == null || valid[i]) {
                sorted[m++] = v[i];
            }
        }
        if (m == 0) {
            preview.setImageBitmap(Bitmap.createBitmap(n, n, Bitmap.Config.ARGB_8888));
            legend.setText("survey running: tiles appear as the phone finishes them");
            return;
        }
        Arrays.sort(sorted, 0, m);
        float lo = sorted[(int) (m * 0.02)];
        float hi = sorted[Math.min(m - 1, (int) (m * 0.98))];
        if (hi <= lo) {
            hi = lo + 1e-6f;
        }
        int[] px = new int[n * n];
        for (int i = 0; i < px.length; i++) {
            px[i] = valid == null || valid[i] ? ramp((v[i] - lo) / (hi - lo)) : INK;
        }
        preview.setImageBitmap(Bitmap.createBitmap(px, n, n, Bitmap.Config.ARGB_8888));
        legend.setText(String.format(Locale.US, "%s: %.3g (red) to %.3g (green), %d x %d pixels of 10 m. Model estimate, not a field measurement.",
                PREVIEW_NAMES[previewIndex], lo, hi, n, n));
    }

    private static int ramp(float t) {
        t = Math.max(0f, Math.min(1f, t));
        int[][] stops = {{215, 48, 39}, {254, 224, 139}, {26, 152, 80}};
        float x = t * 2f;
        int i = Math.min(1, (int) x);
        float f = x - i;
        int r = (int) (stops[i][0] + f * (stops[i + 1][0] - stops[i][0]));
        int g = (int) (stops[i][1] + f * (stops[i + 1][1] - stops[i][1]));
        int b = (int) (stops[i][2] + f * (stops[i + 1][2] - stops[i][2]));
        return Color.rgb(r, g, b);
    }

    private void say(String line) {
        android.util.Log.i("AgriModel", line);
        runOnUiThread(() -> {
            log.append(line + "\n");
            logScroll.post(() -> logScroll.fullScroll(ScrollView.FOCUS_DOWN));
        });
    }

    private TextView text(LinearLayout parent, String value, int size, int color) {
        TextView view = new TextView(this);
        view.setText(value);
        view.setTextSize(size);
        view.setTextColor(color);
        view.setPadding(0, dp(5), 0, dp(5));
        parent.addView(view);
        return view;
    }

    private Button button(LinearLayout parent, String label, Runnable action) {
        Button button = new Button(this);
        button.setText(label);
        button.setAllCaps(false);
        button.setTextColor(INK);
        button.setBackgroundTintList(ColorStateList.valueOf(CREAM));
        button.setMinHeight(dp(48));
        button.setOnClickListener(view -> action.run());
        parent.addView(button, new LinearLayout.LayoutParams(0, -2, 1));
        return button;
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }
}
