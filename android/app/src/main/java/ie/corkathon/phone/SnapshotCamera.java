package ie.corkathon.phone;

import android.Manifest;
import android.app.Activity;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.ImageFormat;
import android.graphics.Matrix;
import android.hardware.camera2.*;
import android.media.Image;
import android.media.ImageReader;
import android.os.Handler;
import android.util.Size;
import android.view.Surface;
import java.io.ByteArrayOutputStream;
import java.nio.ByteBuffer;
import java.util.Arrays;
import java.util.Comparator;
import java.util.Collections;
import java.util.function.Consumer;

/** Opens the rear camera for one image. No preview or repeating capture in idle. */
final class SnapshotCamera {
    private final Activity activity;
    private final Handler handler;
    private CameraDevice camera;
    private CameraCaptureSession session;
    private ImageReader reader;
    private Runnable timeout;
    private int generation;
    boolean active;

    SnapshotCamera(Activity activity, Handler handler) { this.activity = activity; this.handler = handler; }

    void stop() {
        generation++;
        if (timeout != null) handler.removeCallbacks(timeout);
        if (session != null) { session.close(); session = null; }
        if (camera != null) { camera.close(); camera = null; }
        if (reader != null) { reader.close(); reader = null; }
        active = false;
    }

    void capture(Consumer<byte[]> receive, Consumer<String> error) {
        if (active) { error.accept("Camera is busy"); return; }
        if (activity.checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            error.accept("Allow camera access on the camera module first"); return;
        }
        active = true;
        final int current = ++generation;
        Consumer<String> fail = message -> { if (current == generation) { stop(); error.accept(message); } };
        timeout = () -> fail.accept("Camera timed out; resources released");
        handler.postDelayed(timeout, 10000);
        try {
            CameraManager manager = activity.getSystemService(CameraManager.class);
            String rear = null;
            for (String id : manager.getCameraIdList()) {
                if (Integer.valueOf(CameraCharacteristics.LENS_FACING_BACK).equals(manager.getCameraCharacteristics(id).get(CameraCharacteristics.LENS_FACING))) { rear = id; break; }
            }
            if (rear == null) throw new IllegalStateException("No rear camera available");
            CameraCharacteristics info = manager.getCameraCharacteristics(rear);
            Size[] sizes = info.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP).getOutputSizes(ImageFormat.JPEG);
            // ponytail: smallest camera JPEG, capped to 320px after capture; no continuous preview.
            Size size = Arrays.stream(sizes).min(Comparator.comparingLong(s -> (long)s.getWidth() * s.getHeight())).orElseThrow();
            int sensor = info.get(CameraCharacteristics.SENSOR_ORIENTATION);
            int rotation = activity.getWindowManager().getDefaultDisplay().getRotation();
            int degrees = rotation == Surface.ROTATION_90 ? 90 : rotation == Surface.ROTATION_180 ? 180 : rotation == Surface.ROTATION_270 ? 270 : 0;
            int orientation = (sensor - degrees + 360) % 360;
            reader = ImageReader.newInstance(size.getWidth(), size.getHeight(), ImageFormat.JPEG, 1);
            reader.setOnImageAvailableListener(source -> {
                if (current != generation) return;
                try {
                    byte[] jpeg;
                    try (Image image = source.acquireLatestImage()) {
                        if (image == null) return;
                        ByteBuffer bytes = image.getPlanes()[0].getBuffer();
                        jpeg = new byte[bytes.remaining()]; bytes.get(jpeg);
                    }
                    stop(); // Release the sensor before encoding or queuing Bluetooth packets.
                    Bitmap original = BitmapFactory.decodeByteArray(jpeg, 0, jpeg.length);
                    if (original == null) throw new IllegalStateException("Camera image could not be decoded");
                    float scale = Math.min(1f, 320f / Math.max(original.getWidth(), original.getHeight()));
                    Matrix transform = new Matrix(); transform.postScale(scale, scale); transform.postRotate(orientation);
                    Bitmap small = Bitmap.createBitmap(original, 0, 0, original.getWidth(), original.getHeight(), transform, true);
                    ByteArrayOutputStream out = new ByteArrayOutputStream(); small.compress(Bitmap.CompressFormat.JPEG, 45, out);
                    if (small != original) small.recycle(); original.recycle();
                    if (out.size() > 32000) throw new IllegalStateException("Image too large for this demo link");
                    receive.accept(out.toByteArray());
                } catch (Exception exception) { stop(); error.accept("Capture failed: " + exception.getMessage()); }
            }, handler);
            manager.openCamera(rear, new CameraDevice.StateCallback() {
                @Override public void onOpened(CameraDevice opened) {
                    if (current != generation) { opened.close(); return; }
                    camera = opened;
                    try {
                        opened.createCaptureSession(Collections.singletonList(reader.getSurface()), new CameraCaptureSession.StateCallback() {
                            @Override public void onConfigured(CameraCaptureSession configured) {
                                if (current != generation) { configured.close(); return; }
                                session = configured;
                                try {
                                    CaptureRequest.Builder request = opened.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE);
                                    request.addTarget(reader.getSurface());
                                    request.set(CaptureRequest.JPEG_ORIENTATION, 0);
                                    configured.capture(request.build(), new CameraCaptureSession.CaptureCallback() {
                                        @Override public void onCaptureFailed(CameraCaptureSession s, CaptureRequest r, CaptureFailure failure) { fail.accept("Camera capture failed"); }
                                    }, handler);
                                } catch (Exception exception) { fail.accept(exception.getMessage()); }
                            }
                            @Override public void onConfigureFailed(CameraCaptureSession failed) { failed.close(); fail.accept("Camera configuration failed"); }
                        }, handler);
                    } catch (Exception exception) { fail.accept(exception.getMessage()); }
                }
                @Override public void onDisconnected(CameraDevice disconnected) { disconnected.close(); fail.accept("Camera disconnected"); }
                @Override public void onError(CameraDevice failed, int code) { failed.close(); fail.accept("Camera error " + code); }
            }, handler);
        } catch (Exception exception) { fail.accept("Capture failed: " + exception.getMessage()); }
    }
}
