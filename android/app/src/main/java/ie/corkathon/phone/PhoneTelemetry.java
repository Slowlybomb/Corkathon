package ie.corkathon.phone;

import android.Manifest;
import android.app.Activity;
import android.content.pm.PackageManager;
import android.hardware.*;
import android.location.*;
import android.os.*;

import org.json.*;

/** Foreground readings from the mounted phone; never uses a simulated route or laptop location. */
final class PhoneTelemetry implements SensorEventListener, LocationListener {
    private final Activity activity;
    private final Handler handler;
    private final SensorManager sensors;
    private final LocationManager locations;
    private Location fix;
    private float[] quaternion, angles;
    private long orientationNanos, orientationTime;
    private int accuracy = SensorManager.SENSOR_STATUS_UNRELIABLE;
    private String gpsState = "off", orientationState = "off";
    private boolean active;

    PhoneTelemetry(Activity activity, Handler handler) {
        this.activity = activity;
        this.handler = handler;
        sensors = activity.getSystemService(SensorManager.class);
        locations = activity.getSystemService(LocationManager.class);
    }

    static long freshAgeMs(long nowNanos, long sampledNanos, long maxAgeMillis) {
        if (sampledNanos <= 0 || nowNanos < sampledNanos) return -1;
        long age = (nowNanos - sampledNanos) / 1_000_000;
        return age <= maxAgeMillis ? age : -1;
    }

    void start() {
        stop();
        active = true;
        Sensor rotation =
                sensors == null ? null : sensors.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR);
        orientationState =
                rotation != null
                                && sensors.registerListener(
                                        this, rotation, SensorManager.SENSOR_DELAY_UI, handler)
                        ? "searching"
                        : "unavailable";
        if (activity.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)
                != PackageManager.PERMISSION_GRANTED) {
            gpsState = "permission_required";
            return;
        }
        try {
            if (locations == null
                    || !locations.getAllProviders().contains(LocationManager.GPS_PROVIDER)) {
                gpsState = "unavailable";
                return;
            }
            gpsState =
                    locations.isProviderEnabled(LocationManager.GPS_PROVIDER)
                            ? "searching"
                            : "disabled";
            // Request new satellite fixes; do not reuse a cached fix from an earlier session.
            locations.requestLocationUpdates(
                    LocationManager.GPS_PROVIDER, 1000, 0, this, handler.getLooper());
        } catch (SecurityException exception) {
            gpsState = "permission_required";
        } catch (IllegalArgumentException exception) {
            gpsState = "unavailable";
        }
    }

    void stop() {
        active = false;
        if (sensors != null) sensors.unregisterListener(this);
        if (locations != null)
            try {
                locations.removeUpdates(this);
            } catch (SecurityException ignored) {
            }
        fix = null;
        quaternion = null;
        angles = null;
        orientationNanos = 0;
        accuracy = SensorManager.SENSOR_STATUS_UNRELIABLE;
        gpsState = "off";
        orientationState = "off";
    }

    @Override
    public void onSensorChanged(SensorEvent event) {
        if (!active || event.sensor.getType() != Sensor.TYPE_ROTATION_VECTOR) return;
        float[] matrix = new float[9], wxyz = new float[4];
        SensorManager.getRotationMatrixFromVector(matrix, event.values);
        angles = SensorManager.getOrientation(matrix, new float[3]);
        SensorManager.getQuaternionFromVector(wxyz, event.values);
        quaternion = new float[] {wxyz[1], wxyz[2], wxyz[3], wxyz[0]};
        orientationNanos = event.timestamp;
        orientationTime =
                System.currentTimeMillis()
                        - Math.max(
                                0,
                                (SystemClock.elapsedRealtimeNanos() - event.timestamp) / 1_000_000);
        accuracy = event.accuracy;
        orientationState =
                accuracy > SensorManager.SENSOR_STATUS_UNRELIABLE ? "live" : "unreliable";
    }

    @Override
    public void onAccuracyChanged(Sensor sensor, int value) {
        if (active) accuracy = value;
    }

    @Override
    public void onLocationChanged(Location location) {
        if (!active || !LocationManager.GPS_PROVIDER.equals(location.getProvider())) return;
        if (location.isFromMockProvider()) {
            fix = null;
            gpsState = "unavailable";
            return;
        }
        if (fix == null || location.getElapsedRealtimeNanos() >= fix.getElapsedRealtimeNanos()) {
            fix = new Location(location);
            gpsState = "live";
        }
    }

    @Override
    public void onProviderDisabled(String provider) {
        if (active && LocationManager.GPS_PROVIDER.equals(provider)) {
            fix = null;
            gpsState = "disabled";
        }
    }

    @Override
    public void onProviderEnabled(String provider) {
        if (active && LocationManager.GPS_PROVIDER.equals(provider)) gpsState = "searching";
    }

    @Override
    public void onStatusChanged(String provider, int status, Bundle extras) {}

    JSONObject snapshot() {
        long now = SystemClock.elapsedRealtimeNanos();
        long gpsAge = fix == null ? -1 : freshAgeMs(now, fix.getElapsedRealtimeNanos(), 15000);
        long attitudeAge = freshAgeMs(now, orientationNanos, 3000);
        if (active
                && activity.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)
                        != PackageManager.PERMISSION_GRANTED) {
            fix = null;
            gpsAge = -1;
            gpsState = "permission_required";
        }
        JSONObject position = null, orientation = null;
        try {
            if (fix != null && gpsAge >= 0 && fix.hasAccuracy()) {
                position =
                        new JSONObject()
                                .put("latitude", fix.getLatitude())
                                .put("longitude", fix.getLongitude())
                                .put("accuracyM", fix.getAccuracy())
                                .put("capturedAt", fix.getTime())
                                .put("ageMs", gpsAge)
                                .put("mock", false)
                                .put(
                                        "altitudeM",
                                        fix.hasAltitude() ? fix.getAltitude() : JSONObject.NULL)
                                .put(
                                        "altitudeAccuracyM",
                                        fix.hasVerticalAccuracy()
                                                ? fix.getVerticalAccuracyMeters()
                                                : JSONObject.NULL)
                                .put("speedMps", fix.hasSpeed() ? fix.getSpeed() : JSONObject.NULL);
            }
            if (quaternion != null
                    && attitudeAge >= 0
                    && accuracy > SensorManager.SENSOR_STATUS_UNRELIABLE) {
                Double declination =
                        position == null
                                ? null
                                : (double)
                                        new GeomagneticField(
                                                        (float) fix.getLatitude(),
                                                        (float) fix.getLongitude(),
                                                        fix.hasAltitude()
                                                                ? (float) fix.getAltitude()
                                                                : 0,
                                                        System.currentTimeMillis())
                                                .getDeclination();
                double heading =
                        (Math.toDegrees(angles[0]) + (declination == null ? 0 : declination) + 360)
                                % 360;
                JSONArray q = new JSONArray();
                for (float component : quaternion) q.put(component);
                orientation =
                        new JSONObject()
                                .put("quaternion", q)
                                .put("headingDeg", heading)
                                .put("pitchDeg", Math.toDegrees(angles[1]))
                                .put("rollDeg", Math.toDegrees(angles[2]))
                                .put("reference", "magnetic")
                                .put(
                                        "declinationDeg",
                                        declination == null ? JSONObject.NULL : declination)
                                .put(
                                        "accuracy",
                                        accuracy == SensorManager.SENSOR_STATUS_ACCURACY_HIGH
                                                ? "high"
                                                : accuracy
                                                                == SensorManager
                                                                        .SENSOR_STATUS_ACCURACY_MEDIUM
                                                        ? "medium"
                                                        : "low")
                                .put("capturedAt", orientationTime)
                                .put("ageMs", attitudeAge);
            }
            return new JSONObject()
                    .put("location", position == null ? JSONObject.NULL : position)
                    .put("orientation", orientation == null ? JSONObject.NULL : orientation)
                    .put("gpsState", position != null ? "live" : fix != null ? "stale" : gpsState)
                    .put(
                            "orientationState",
                            orientation != null
                                    ? "live"
                                    : quaternion != null && attitudeAge < 0
                                            ? "stale"
                                            : accuracy <= SensorManager.SENSOR_STATUS_UNRELIABLE
                                                            && quaternion != null
                                                    ? "unreliable"
                                                    : orientationState);
        } catch (JSONException exception) {
            throw new IllegalStateException("Invalid sensor reading", exception);
        }
    }
}
