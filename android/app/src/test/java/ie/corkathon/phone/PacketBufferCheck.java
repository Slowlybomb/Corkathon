package ie.corkathon.phone;

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

public final class PacketBufferCheck {
    public static void main(String[] args) {
        PacketBuffer buffer = new PacketBuffer(64);
        List<String> messages = new ArrayList<>();
        byte[] wire =
                "{\"label\":\"Cork 🌱\"}\n{\"command\":\"ping\"}\n"
                        .getBytes(StandardCharsets.UTF_8);
        for (byte value : wire) buffer.accept(new byte[] {value}, messages::add);
        if (!messages.equals(List.of("{\"label\":\"Cork 🌱\"}", "{\"command\":\"ping\"}")))
            throw new AssertionError(messages);
        boolean rejected = false;
        try {
            buffer.accept(new byte[65], messages::add);
        } catch (IllegalArgumentException expected) {
            rejected = true;
        }
        if (!rejected) throw new AssertionError("Oversized command accepted");
        buffer.reset();
        buffer.accept("ok\n".getBytes(StandardCharsets.UTF_8), messages::add);
        if (!messages.get(2).equals("ok")) throw new AssertionError("Reset failed");
        System.out.println("PacketBuffer checks passed");
    }
}
