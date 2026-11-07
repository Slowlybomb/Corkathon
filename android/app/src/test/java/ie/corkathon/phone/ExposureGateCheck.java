package ie.corkathon.phone;

/** Checks capture timing without camera hardware or Android framework stubs. */
public final class ExposureGateCheck {
    public static void main(String[] args) {
        ExposureGate gate = new ExposureGate();
        if (gate.claim(0, false)) throw new AssertionError("Captured the first unmetered frame");
        if (gate.claim(100, true)) throw new AssertionError("Skipped minimum camera warmup");
        if (gate.claim(500, false)) throw new AssertionError("Captured while exposure was searching");
        if (!gate.claim(700, true)) throw new AssertionError("Did not capture after exposure settled");
        if (gate.claim(800, true)) throw new AssertionError("Captured twice from repeated callbacks");
        if (gate.claim(2500, false)) throw new AssertionError("Timeout duplicated the capture");

        ExposureGate unsupportedState = new ExposureGate();
        if (unsupportedState.claim(2499, false)) throw new AssertionError("Fallback fired too early");
        if (!unsupportedState.claim(2500, false)) throw new AssertionError("Missing AE state blocked capture indefinitely");
        if (unsupportedState.claim(2600, true)) throw new AssertionError("Late AE result duplicated fallback capture");
        System.out.println("ExposureGate checks passed");
    }
}
