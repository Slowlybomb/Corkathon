package ie.corkathon.phone;

import android.content.res.AssetManager;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.ArrayBlockingQueue;

public final class AgriModel {
    public static final int MARGIN = 24;
    public static final int OUTPUTS = 31;
    public static final int BANDS = 10;
    public static final int BOUNDARY = 0, CROP = 1, WRB = 2, PH = 3, CARBON = 9, CLAY = 15, SAND = 21;
    public static final int TEMPERATURE = 27, HUMIDITY = 28, SOIL_MOISTURE = 29, WATER_BALANCE = 30;

    private static final String LIBRARY_ERROR;
    private static AgriModel shared;

    static {
        String error = null;
        try {
            System.loadLibrary("agri");
        } catch (Throwable t) {
            error = t.toString();
        }
        LIBRARY_ERROR = error;
    }

    private static native int nativeLoad(ByteBuffer image, int length, long bss);

    private static native long nativeRun(int slot, ByteBuffer model, int modelLength, ByteBuffer heads, int headsLength,
                                         ByteBuffer refl, ByteBuffer out, int size, int doy);

    private final ByteBuffer model;
    private final ByteBuffer heads;
    private final ArrayBlockingQueue<Integer> free;
    public final int instances;
    public final int imageBytes;
    public final long heapBytes;

    private AgriModel(ByteBuffer model, ByteBuffer heads, ArrayBlockingQueue<Integer> free, int instances, int imageBytes, long heapBytes) {
        this.model = model;
        this.heads = heads;
        this.free = free;
        this.instances = instances;
        this.imageBytes = imageBytes;
        this.heapBytes = heapBytes;
    }

    public static synchronized AgriModel get(AssetManager assets, int instances) throws IOException {
        if (shared != null) {
            return shared;
        }
        if (LIBRARY_ERROR != null) {
            throw new IOException("native loader missing: " + LIBRARY_ERROR);
        }
        ByteBuffer image = asset(assets, "agri/agri_arm64.bin");
        String info = new String(bytes(assets, "agri/agri_arm64.txt"), StandardCharsets.US_ASCII).trim();
        long bss = Long.parseLong(info.substring(info.lastIndexOf(' ') + 1));
        ArrayBlockingQueue<Integer> free = new ArrayBlockingQueue<>(Math.max(1, instances));
        for (int k = 0; k < Math.max(1, instances); k++) {
            int rc = nativeLoad(image, image.capacity(), bss);
            if (rc < 0) {
                if (k > 0) {
                    break;
                }
                if (rc <= -2000) {
                    throw new IOException("this phone refused executable memory (errno " + (-2000 - rc) + ")");
                }
                if (rc <= -1000) {
                    throw new IOException("could not reserve memory for the model (errno " + (-1000 - rc) + ")");
                }
                throw new IOException("could not load the model image (" + rc + ")");
            }
            free.add(rc);
        }
        shared = new AgriModel(asset(assets, "agri/agri.bin"), asset(assets, "agri/cork_soil_heads.bin"), free, free.size(),
                image.capacity(), bss);
        return shared;
    }

    public Result run(ByteBuffer refl, int size, int doy, boolean irishSoilHeads) throws InterruptedException {
        if (refl.capacity() != BANDS * size * size * 4) {
            throw new IllegalArgumentException("refl must hold 10 bands of " + size + " x " + size + " float32 values");
        }
        ByteBuffer out = ByteBuffer.allocateDirect(OUTPUTS * size * size * 4).order(ByteOrder.LITTLE_ENDIAN);
        int slot = free.take();
        long t0 = System.nanoTime();
        long ns;
        try {
            ns = nativeRun(slot, model, model.capacity(), irishSoilHeads ? heads : null, irishSoilHeads ? heads.capacity() : 0,
                    refl, out, size, doy);
        } finally {
            free.add(slot);
        }
        long total = System.nanoTime() - t0;
        if (ns < 0) {
            throw new IllegalStateException("model call failed (" + ns + ")");
        }
        return new Result(size, out, ns, total, slot);
    }

    public static ByteBuffer asset(AssetManager assets, String name) throws IOException {
        byte[] b = bytes(assets, name);
        ByteBuffer d = ByteBuffer.allocateDirect(b.length).order(ByteOrder.LITTLE_ENDIAN);
        d.put(b);
        d.rewind();
        return d;
    }

    public static String text(AssetManager assets, String name) throws IOException {
        return new String(bytes(assets, name), StandardCharsets.UTF_8);
    }

    private static byte[] bytes(AssetManager assets, String name) throws IOException {
        try (InputStream in = assets.open(name)) {
            ByteArrayOutputStream all = new ByteArrayOutputStream(Math.max(in.available(), 1 << 16));
            byte[] buf = new byte[1 << 16];
            int n;
            while ((n = in.read(buf)) > 0) {
                all.write(buf, 0, n);
            }
            return all.toByteArray();
        }
    }

    public static final class Result {
        public final int size;
        public final int interior;
        public final ByteBuffer out;
        public final long computeNanos;
        public final long totalNanos;
        public final int slot;

        Result(int size, ByteBuffer out, long computeNanos, long totalNanos, int slot) {
            this.size = size;
            this.interior = size - 2 * MARGIN;
            this.out = out;
            this.computeNanos = computeNanos;
            this.totalNanos = totalNanos;
            this.slot = slot;
        }

        public float raw(int channel, int row, int col) {
            return out.getFloat(((channel * size + row) * size + col) * 4);
        }

        public float value(int channel, int row, int col) {
            return raw(channel, row + MARGIN, col + MARGIN);
        }

        public float[] layer(int channel) {
            float[] v = new float[interior * interior];
            for (int r = 0; r < interior; r++) {
                for (int c = 0; c < interior; c++) {
                    v[r * interior + c] = value(channel, r, c);
                }
            }
            return v;
        }

        public void writeInterior(ByteBuffer dst) {
            for (int k = 0; k < OUTPUTS; k++) {
                for (int r = 0; r < interior; r++) {
                    int at = ((k * size + r + MARGIN) * size + MARGIN) * 4;
                    for (int c = 0; c < interior; c++) {
                        dst.putFloat(out.getFloat(at + c * 4));
                    }
                }
            }
        }
    }
}
