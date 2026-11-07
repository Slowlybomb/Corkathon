package ie.corkathon.phone;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;

public final class AgriModelResultCheck {
    private static final int SIZE = 2 * AgriModel.MARGIN + 3;

    public static void main(String[] args) {
        AgriModel.Result result = new AgriModel.Result(SIZE, filledOutput(), 5, 9, 0);
        interiorExcludesTheMargin(result);
        layerAndValueAgree(result);
        writeInteriorIsChannelMajor(result);
        System.out.println("AgriModelResultCheck passed");
    }

    private static float expected(int channel, int row, int col) {
        return channel * 10000 + (row + AgriModel.MARGIN) * 100 + (col + AgriModel.MARGIN);
    }

    private static ByteBuffer filledOutput() {
        ByteBuffer out =
                ByteBuffer.allocate(AgriModel.OUTPUTS * SIZE * SIZE * 4)
                        .order(ByteOrder.LITTLE_ENDIAN);
        for (int k = 0; k < AgriModel.OUTPUTS; k++) {
            for (int r = 0; r < SIZE; r++) {
                for (int c = 0; c < SIZE; c++) {
                    out.putFloat(((k * SIZE + r) * SIZE + c) * 4, k * 10000 + r * 100 + c);
                }
            }
        }
        return out;
    }

    private static void interiorExcludesTheMargin(AgriModel.Result result) {
        check(result.interior == 3, "interior is the chunk without its margin");
    }

    private static void layerAndValueAgree(AgriModel.Result result) {
        check(
                result.value(AgriModel.PH, 1, 2) == expected(AgriModel.PH, 1, 2),
                "value reads the interior");
        float[] boundary = result.layer(AgriModel.BOUNDARY);
        check(boundary.length == 9, "layer has interior x interior values");
        check(boundary[4] == expected(AgriModel.BOUNDARY, 1, 1), "layer is row-major");
    }

    private static void writeInteriorIsChannelMajor(AgriModel.Result result) {
        ByteBuffer interior =
                ByteBuffer.allocate(AgriModel.OUTPUTS * 9 * 4).order(ByteOrder.LITTLE_ENDIAN);
        result.writeInterior(interior);
        check(interior.position() == interior.capacity(), "every interior value is written");
        check(
                interior.getFloat(((2 * 3 + 1) * 3 + 2) * 4) == expected(2, 1, 2),
                "channel-major order");
    }

    private static void check(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message);
        }
    }
}
