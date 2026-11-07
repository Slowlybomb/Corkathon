package ie.corkathon.phone;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.Inet4Address;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.NetworkInterface;
import java.net.ServerSocket;
import java.net.Socket;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.zip.GZIPOutputStream;

final class ResultServer {
    static final int PORT = 8080;
    static final String[] DEPTHS = {"0-5cm", "5-15cm", "15-30cm", "30-60cm", "60-100cm", "100-200cm"};
    static final int[][] DEPTH_CM = {{0, 5}, {5, 15}, {15, 30}, {30, 60}, {60, 100}, {100, 200}};
    static final String[] SOIL = {"ph", "soc_gkg", "clay_pct", "sand_pct"};
    static final String[] SOIL_UNITS = {"pH", "g/kg", "%", "%"};

    interface Listener {
        void log(String line);
    }

    static final class Survey {
        final float[][] layers;
        final int width;
        final double originX;
        final double originY;
        final String device;
        final double seconds;
        final int cores;
        final long at;

        Survey(float[][] layers, int width, double originX, double originY, String device, double seconds, int cores) {
            this.layers = layers;
            this.width = width;
            this.originX = originX;
            this.originY = originY;
            this.device = device;
            this.seconds = seconds;
            this.cores = cores;
            this.at = System.currentTimeMillis();
        }
    }

    static volatile Survey latest;

    private final Map<String, byte[]> files = new ConcurrentHashMap<>();
    private final Listener listener;
    private volatile boolean running;
    private ServerSocket server;

    ResultServer(Listener listener) {
        this.listener = listener;
    }

    static int[] channels() {
        int[] c = new int[1 + 24];
        c[0] = AgriModel.BOUNDARY;
        for (int t = 0; t < 24; t++) {
            c[1 + t] = AgriModel.PH + t;
        }
        return c;
    }

    static String layerName(int index) {
        return index == 0 ? "field_boundary_score" : SOIL[(index - 1) / 6] + "_" + DEPTHS[(index - 1) % 6];
    }

    static JSONObject manifest(Survey s) throws Exception {
        JSONArray list = new JSONArray();
        for (int i = 0; i < s.layers.length; i++) {
            float[] v = s.layers[i];
            double min = Double.POSITIVE_INFINITY, max = Double.NEGATIVE_INFINITY, sum = 0;
            for (float x : v) {
                min = Math.min(min, x);
                max = Math.max(max, x);
                sum += x;
            }
            String name = layerName(i);
            JSONObject l = new JSONObject().put("name", name).put("file", "layers/" + name + ".f32").put("type", "float32")
                    .put("min", round(min)).put("max", round(max)).put("mean", round(sum / v.length));
            if (i == 0) {
                l.put("units", "score").put("group", "fields");
            } else {
                int[] d = DEPTH_CM[(i - 1) % 6];
                l.put("units", SOIL_UNITS[(i - 1) / 6]).put("group", "soil").put("depth_cm", new JSONArray().put(d[0]).put(d[1]));
            }
            list.put(l);
        }
        return new JSONObject()
                .put("name", "Cork survey computed on the phone (" + s.device + ")")
                .put("crs", "EPSG:32629").put("width", s.width).put("height", s.width).put("pixel_size_m", 10)
                .put("origin_x", s.originX).put("origin_y", s.originY)
                .put("layout", "row-major from the north-west corner, one value per pixel, little-endian")
                .put("nodata_float32", -9999)
                .put("layers", list)
                .put("computed", new JSONObject().put("device", s.device).put("seconds", round(s.seconds)).put("cores", s.cores).put("at", s.at))
                .put("notes", "Computed on the phone by the Century model compiled to ARM64 from the recorded Sentinel-2 L2A scene of 30 May 2023 stored in the app. "
                        + "Soil layers are model estimates with soil heads recalibrated on Irish SoilGrids (held-out R2 pH 0.19, organic carbon 0.20), not field measurements. "
                        + "The field boundary score is the raw model score. Weather layers are left out: the model's weather heads learnt Bavarian seasons.")
                .put("sources", "Sentinel-2 L2A (Earth Search, AWS); model trained on Munich480 with ISRIC SoilGrids 2.0 labels");
    }

    long publish(Survey s) throws Exception {
        long total = 0;
        files.clear();
        for (int i = 0; i < s.layers.length; i++) {
            float[] v = s.layers[i];
            ByteBuffer b = ByteBuffer.allocate(v.length * 4).order(ByteOrder.LITTLE_ENDIAN);
            for (float x : v) {
                b.putFloat(x);
            }
            byte[] gz = gzip(b.array());
            files.put("/layers/" + layerName(i) + ".f32", gz);
            total += gz.length;
        }
        byte[] manifest = gzip(manifest(s).toString(2).getBytes(StandardCharsets.UTF_8));
        files.put("/manifest.json", manifest);
        return total + manifest.length;
    }

    static int stride(int width, int height) {
        int s = Math.max(1, (int) Math.ceil(Math.sqrt(width * (double) height / 1000)));
        while (((width + s - 1) / s) * ((height + s - 1) / s) > 1000) {
            s++;
        }
        return s;
    }

    static JSONObject header(Survey s, String id) throws Exception {
        int step = stride(s.width, s.width);
        return manifest(s).put("v", 1).put("type", "results").put("id", id).put("sentAt", System.currentTimeMillis())
                .put("stride", step).put("grid", (s.width + step - 1) / step).put("encoding", "f32le+deflate+base64");
    }

    static JSONObject layerPacket(Survey s, String id, String name) throws Exception {
        int index = -1;
        for (int i = 0; i < s.layers.length; i++) {
            if (layerName(i).equals(name)) {
                index = i;
            }
        }
        if (index < 0) {
            throw new IllegalArgumentException("unknown layer " + name);
        }
        int step = stride(s.width, s.width);
        int grid = (s.width + step - 1) / step;
        ByteBuffer b = ByteBuffer.allocate(grid * grid * 4).order(ByteOrder.LITTLE_ENDIAN);
        for (int r = 0; r < grid; r++) {
            for (int c = 0; c < grid; c++) {
                b.putFloat(s.layers[index][(r * step) * s.width + c * step]);
            }
        }
        java.util.zip.Deflater d = new java.util.zip.Deflater(9);
        d.setInput(b.array());
        d.finish();
        ByteArrayOutputStream z = new ByteArrayOutputStream();
        byte[] buf = new byte[8192];
        while (!d.finished()) {
            z.write(buf, 0, d.deflate(buf));
        }
        d.end();
        return new JSONObject().put("v", 1).put("type", "results_layer").put("id", id).put("sentAt", System.currentTimeMillis())
                .put("name", name).put("grid", grid).put("stride", step)
                .put("data", android.util.Base64.encodeToString(z.toByteArray(), android.util.Base64.NO_WRAP));
    }

    boolean hasResults() {
        return files.containsKey("/manifest.json");
    }

    void start() throws IOException {
        server = new ServerSocket();
        server.setReuseAddress(true);
        server.bind(new InetSocketAddress(PORT));
        running = true;
        new Thread(this::acceptLoop, "agri-http").start();
    }

    void stop() {
        running = false;
        try {
            if (server != null) {
                server.close();
            }
        } catch (IOException ignored) {
        }
    }

    boolean running() {
        return running;
    }

    static List<String> urls() {
        List<String> out = new ArrayList<>();
        try {
            for (NetworkInterface n : Collections.list(NetworkInterface.getNetworkInterfaces())) {
                if (!n.isUp() || n.isLoopback()) {
                    continue;
                }
                for (InetAddress a : Collections.list(n.getInetAddresses())) {
                    if (a instanceof Inet4Address) {
                        out.add("http://" + a.getHostAddress() + ":" + PORT + "/manifest.json");
                    }
                }
            }
        } catch (Exception ignored) {
        }
        return out;
    }

    private void acceptLoop() {
        while (running) {
            try {
                Socket s = server.accept();
                new Thread(() -> serve(s), "agri-http-client").start();
            } catch (IOException e) {
                if (running) {
                    listener.log("result server error: " + e.getMessage());
                }
            }
        }
    }

    private void serve(Socket s) {
        try (Socket socket = s) {
            socket.setSoTimeout(15000);
            InputStream in = new BufferedInputStream(socket.getInputStream());
            String request = line(in);
            String header;
            while ((header = line(in)) != null && !header.isEmpty()) {
                if (header.length() > 8192) {
                    return;
                }
            }
            if (request == null) {
                return;
            }
            String[] parts = request.split(" ");
            String method = parts.length > 0 ? parts[0] : "";
            String path = parts.length > 1 ? parts[1] : "/";
            int q = path.indexOf('?');
            if (q >= 0) {
                path = path.substring(0, q);
            }
            OutputStream out = new BufferedOutputStream(socket.getOutputStream());
            String cors = "Access-Control-Allow-Origin: *\r\nAccess-Control-Allow-Methods: GET, OPTIONS\r\nAccess-Control-Allow-Headers: *\r\n";
            if (method.equals("OPTIONS")) {
                out.write(("HTTP/1.1 204 No Content\r\n" + cors + "Content-Length: 0\r\nConnection: close\r\n\r\n").getBytes(StandardCharsets.US_ASCII));
                out.flush();
                return;
            }
            byte[] body = files.get(path);
            if (!method.equals("GET") || body == null) {
                byte[] msg = "not found".getBytes(StandardCharsets.US_ASCII);
                out.write(("HTTP/1.1 404 Not Found\r\n" + cors + "Content-Type: text/plain\r\nContent-Length: " + msg.length
                        + "\r\nConnection: close\r\n\r\n").getBytes(StandardCharsets.US_ASCII));
                out.write(msg);
                out.flush();
                return;
            }
            String type = path.endsWith(".json") ? "application/json" : "application/octet-stream";
            out.write(("HTTP/1.1 200 OK\r\n" + cors + "Content-Type: " + type + "\r\nContent-Encoding: gzip\r\nCache-Control: no-store\r\nContent-Length: "
                    + body.length + "\r\nConnection: close\r\n\r\n").getBytes(StandardCharsets.US_ASCII));
            out.write(body);
            out.flush();
            listener.log(String.format(Locale.US, "sent %s (%.0f KB compressed) to %s", path, body.length / 1024.0,
                    socket.getInetAddress().getHostAddress()));
        } catch (IOException e) {
            if (running) {
                listener.log("result request failed: " + e.getMessage());
            }
        }
    }

    private static String line(InputStream in) throws IOException {
        StringBuilder s = new StringBuilder();
        while (true) {
            int c = in.read();
            if (c < 0) {
                return s.length() == 0 ? null : s.toString();
            }
            if (c == '\n') {
                int n = s.length();
                return n > 0 && s.charAt(n - 1) == '\r' ? s.substring(0, n - 1) : s.toString();
            }
            if (s.length() > 8192) {
                return s.toString();
            }
            s.append((char) c);
        }
    }

    private static byte[] gzip(byte[] raw) throws IOException {
        ByteArrayOutputStream b = new ByteArrayOutputStream(raw.length / 2);
        try (GZIPOutputStream z = new GZIPOutputStream(b, 1 << 16)) {
            z.write(raw);
        }
        return b.toByteArray();
    }

    private static double round(double v) {
        return Math.round(v * 10000.0) / 10000.0;
    }
}
