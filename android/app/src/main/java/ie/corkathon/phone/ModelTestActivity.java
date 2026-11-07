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

import java.nio.ByteBuffer;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;

public final class ModelTestActivity extends Activity {
    private static final int CREAM = Color.rgb(254, 254, 227),
            MUTED = Color.rgb(184, 202, 181),
            INK = Color.rgb(16, 44, 32);
    private static final String[] PREVIEW = {
        "field_boundary_score",
        "ph_0-5cm",
        "soc_gkg_0-5cm",
        "clay_pct_0-5cm",
        "sand_pct_0-5cm",
        "ndvi"
    };
    private static final int[] PREVIEW_CHANNELS = {
        AgriModel.BOUNDARY, AgriModel.PH, AgriModel.CARBON, AgriModel.CLAY, AgriModel.SAND, -1
    };
    private static final String[] PREVIEW_LABELS = {
        "field boundary score",
        "pH 0-5 cm",
        "organic carbon 0-5 cm (g/kg)",
        "clay 0-5 cm (%)",
        "sand 0-5 cm (%)",
        "NDVI"
    };

    private TextView log;
    private ScrollView logScroll;
    private ImageView preview;
    private TextView legend;
    private AgriModel model;
    private AgriModel.Result last;
    private volatile List<ResultServer.Layer> surveyLayers;
    private volatile boolean[] tileDone;
    private volatile int surveyTiles;
    private volatile boolean showMosaic;
    private int previewIndex;
    private volatile boolean busy;
    private final ResultServer results = new ResultServer(this::say);
    private Button shareButton;
    private TextView shareInfo;
    private boolean shareAfterSurvey;

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
        text(
                root,
                "Century model compiled to ARM64, running on this phone. Input: recorded Sentinel-2"
                    + " scene of the Cork demo area (30 May 2023), stored in the app.",
                13,
                MUTED);
        LinearLayout row0 = new LinearLayout(this);
        root.addView(row0);
        button(row0, "Survey Cork area", () -> start(5));
        shareButton = button(row0, "Share results", this::toggleShare);
        shareButton.setEnabled(ResultServer.latest != null);
        button(row0, "Camera module", this::finish);
        shareInfo = text(root, "Run a survey, then share its results with the website.", 13, MUTED);
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
        say(
                "device "
                        + Build.MANUFACTURER
                        + " "
                        + Build.MODEL
                        + ", Android "
                        + Build.VERSION.RELEASE
                        + ", ABI "
                        + Build.SUPPORTED_ABIS[0]);
        if (ResultServer.latest != null) {
            surveyLayers = ResultServer.latest.layers;
            surveyTiles = ResultServer.latest.width / SurveyRunner.TILE;
            tileDone = new boolean[surveyTiles * surveyTiles];
            Arrays.fill(tileDone, true);
            showMosaic = true;
            showPreview();
            say("survey results already on the phone: " + surveyLayers.size() + " layers");
        }
        shareAfterSurvey = getIntent().getBooleanExtra("share", false);
        if (getIntent().getBooleanExtra("autorun", false)) {
            start(3);
        } else if (getIntent().getBooleanExtra("survey", false)) {
            start(5);
        }
    }

    @Override
    protected void onDestroy() {
        results.stop();
        super.onDestroy();
    }

    private void toggleShare() {
        if (results.running()) {
            results.stop();
            shareButton.setText("Share results");
            shareInfo.setText("Sharing stopped.");
            say("result sharing stopped");
            return;
        }
        try {
            if (ResultServer.latest != null) {
                results.publish(ResultServer.latest);
            }
            results.start();
        } catch (Exception e) {
            say("could not share results: " + e);
            return;
        }
        StringBuilder s =
                new StringBuilder(
                        "Sharing over WiFi or USB. In the website choose Data source > Satellite"
                            + " scene package and enter:\n");
        for (String u : ResultServer.urls()) {
            s.append(u).append('\n');
        }
        s.append("USB: adb forward tcp:")
                .append(ResultServer.PORT)
                .append(" tcp:")
                .append(ResultServer.PORT)
                .append(", then http://localhost:")
                .append(ResultServer.PORT)
                .append("/manifest.json");
        shareButton.setText("Stop sharing");
        shareInfo.setText(s.toString());
        say("sharing results on port " + ResultServer.PORT);
    }

    private void start(int which) {
        if (busy) {
            say("busy: wait for the current run");
            return;
        }
        busy = true;
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        new Thread(
                        null,
                        () -> {
                            try {
                                ensureModel();
                                if (which == 0 || which == 3) {
                                    test(
                                            "check 32 px, both stages, against the laptop",
                                            "golden32",
                                            80,
                                            false);
                                }
                                if (which == 1 || which == 3) {
                                    test(
                                            "check 128 px, Irish soil heads, against the laptop",
                                            "cork128",
                                            176,
                                            true);
                                }
                                if (which == 5 || which == 3) {
                                    survey();
                                }
                            } catch (Throwable t) {
                                say("error: " + t);
                            } finally {
                                busy = false;
                                runOnUiThread(
                                        () ->
                                                getWindow()
                                                        .clearFlags(
                                                                WindowManager.LayoutParams
                                                                        .FLAG_KEEP_SCREEN_ON));
                            }
                        },
                        "agri-model",
                        64L << 20)
                .start();
    }

    private synchronized void ensureModel() throws Exception {
        if (model != null) {
            return;
        }
        long t0 = System.nanoTime();
        model = AgriModel.get(getAssets(), Math.min(4, Runtime.getRuntime().availableProcessors()));
        say(
                String.format(
                        Locale.US,
                        "loaded ARM64 image (%d bytes) on %d cores and the model in %.0f ms",
                        model.imageBytes,
                        model.instances,
                        (System.nanoTime() - t0) / 1e6));
    }

    private void test(String title, String name, int size, boolean irish) throws Exception {
        say("");
        say(title);
        ByteBuffer refl = AgriModel.asset(getAssets(), "agri/" + name + "_in.f32");
        AgriModel.Result r = model.run(refl, size, 150, irish);
        int n = size - 2 * AgriModel.MARGIN;
        say(
                String.format(
                        Locale.US,
                        "  %d x %d px chunk: %.2f s on one core",
                        n,
                        n,
                        r.computeNanos / 1e9));
        compare(r, AgriModel.asset(getAssets(), "agri/" + name + "_expected.f32"));
        last = r;
        showMosaic = false;
        runOnUiThread(this::showPreview);
    }

    private void survey() throws Exception {
        say("");
        say("survey: the whole Cork area on " + model.instances + " cores");
        ResultServer.Survey s =
                SurveyRunner.run(
                        getAssets(),
                        model,
                        Build.MANUFACTURER + " " + Build.MODEL,
                        new SurveyRunner.Progress() {
                            @Override
                            public void started(
                                    List<ResultServer.Layer> layers, int tiles, boolean[] done) {
                                surveyLayers = layers;
                                surveyTiles = tiles;
                                tileDone = done;
                                showMosaic = true;
                                runOnUiThread(ModelTestActivity.this::showPreview);
                            }

                            @Override
                            public void tile(
                                    int done,
                                    int total,
                                    int row,
                                    int col,
                                    double seconds,
                                    int core,
                                    double elapsed) {
                                say(
                                        String.format(
                                                Locale.US,
                                                "  tile %2d/%d (row %d, col %d): %.2f s on core %d,"
                                                    + " %.1f s since start",
                                                done,
                                                total,
                                                row,
                                                col,
                                                seconds,
                                                core,
                                                elapsed));
                                runOnUiThread(ModelTestActivity.this::showPreview);
                            }
                        });
        ResultServer.latest = s;
        surveyLayers = s.layers;
        long bytes = results.publish(s);
        say(
                String.format(
                        Locale.US,
                        "survey done: %.1f s for %.1f km2; %d layers ready (%.1f MB compressed)."
                            + " Bluetooth sends them from the camera module screen.",
                        s.seconds,
                        s.width * s.width * 1e-4,
                        s.layers.size(),
                        bytes / 1048576.0));
        runOnUiThread(
                () -> {
                    shareButton.setEnabled(true);
                    showPreview();
                    if (shareAfterSurvey && !results.running()) {
                        toggleShare();
                    }
                });
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
        say(
                String.format(
                        Locale.US,
                        "  against the laptop: boundary %.1e, soil %.1e, weather %.1e, class"
                            + " differences %d of %d",
                        boundary,
                        soil,
                        weather,
                        classes,
                        2 * pixels));
        say(
                pass
                        ? "  PASS: the phone gives the laptop's results"
                        : "  FAIL: results differ from the laptop");
    }

    private void nextLayer() {
        previewIndex = (previewIndex + 1) % PREVIEW.length;
        if (!showMosaic && PREVIEW_CHANNELS[previewIndex] < 0) {
            previewIndex = (previewIndex + 1) % PREVIEW.length;
        }
        showPreview();
    }

    private void showPreview() {
        float[] v = null;
        int n;
        boolean[] valid = null;
        List<ResultServer.Layer> layers = surveyLayers;
        if (showMosaic && layers != null) {
            n =
                    layers.get(0).data.length == 0
                            ? 0
                            : (int) Math.round(Math.sqrt(layers.get(0).data.length));
            for (ResultServer.Layer l : layers) {
                if (l.name.equals(PREVIEW[previewIndex])) {
                    v = l.data;
                }
            }
            if (v == null) {
                legend.setText(PREVIEW_LABELS[previewIndex] + ": ready when the survey finishes");
                return;
            }
            boolean[] done = tileDone;
            int tiles = surveyTiles;
            valid = new boolean[n * n];
            for (int i = 0; i < n * n; i++) {
                valid[i] =
                        done == null
                                || done[
                                        (i / n / SurveyRunner.TILE) * tiles
                                                + (i % n) / SurveyRunner.TILE];
            }
        } else if (last != null && PREVIEW_CHANNELS[previewIndex] >= 0) {
            n = last.interior;
            v = last.layer(PREVIEW_CHANNELS[previewIndex]);
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
        legend.setText(
                String.format(
                        Locale.US,
                        "%s: %.3g (red) to %.3g (green), %d x %d pixels of 10 m. Model estimate,"
                            + " not a field measurement.",
                        PREVIEW_LABELS[previewIndex],
                        lo,
                        hi,
                        n,
                        n));
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
        runOnUiThread(
                () -> {
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
