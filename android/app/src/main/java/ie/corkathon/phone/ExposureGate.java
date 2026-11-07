package ie.corkathon.phone;

/** Controls when a camera session may issue its single still capture. */
final class ExposureGate {
    static final long MAX_WAIT_MS = 2500;
    private boolean claimed;

    boolean claim(long elapsedMillis, boolean settled) {
        if (claimed || elapsedMillis < 500 || (!settled && elapsedMillis < MAX_WAIT_MS))
            return false;
        claimed = true;
        return true;
    }
}
