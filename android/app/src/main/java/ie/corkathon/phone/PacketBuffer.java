package ie.corkathon.phone;

import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.function.Consumer;

/** Newline-delimited UTF-8 JSON; bounds untrusted commands before parsing. */
final class PacketBuffer {
    private final int limit;
    private final ByteArrayOutputStream bytes = new ByteArrayOutputStream();

    PacketBuffer(int limit) {
        this.limit = limit;
    }

    void reset() {
        bytes.reset();
    }

    void accept(byte[] chunk, Consumer<String> receive) {
        for (byte value : chunk) {
            if (value == '\n') {
                String packet = new String(bytes.toByteArray(), StandardCharsets.UTF_8);
                bytes.reset();
                if (!packet.isEmpty()) receive.accept(packet);
            } else {
                if (bytes.size() >= limit) {
                    reset();
                    throw new IllegalArgumentException("Command too large");
                }
                bytes.write(value);
            }
        }
    }
}
