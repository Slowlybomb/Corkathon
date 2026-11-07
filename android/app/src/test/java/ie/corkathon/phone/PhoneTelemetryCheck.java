package ie.corkathon.phone;

public final class PhoneTelemetryCheck {
    public static void main(String[] args) {
        if (PhoneTelemetry.freshAgeMs(20_000_000_000L, 0, 15000) != -1)
            throw new AssertionError("Missing sensor reading became fresh");
        if (PhoneTelemetry.freshAgeMs(20_000_000_000L, 21_000_000_000L, 15000) != -1)
            throw new AssertionError("Future sensor reading accepted");
        if (PhoneTelemetry.freshAgeMs(20_000_000_000L, 5_000_000_000L, 15000) != 15000)
            throw new AssertionError("Fresh GPS boundary rejected");
        if (PhoneTelemetry.freshAgeMs(20_001_000_000L, 5_000_000_000L, 15000) != -1)
            throw new AssertionError("Old GPS fix remained live");
        if (PhoneTelemetry.freshAgeMs(20_000_000_000L, 19_800_000_000L, 3000) != 200)
            throw new AssertionError("Sensor age was not measured monotonically");
        System.out.println("PhoneTelemetry checks passed");
    }
}
