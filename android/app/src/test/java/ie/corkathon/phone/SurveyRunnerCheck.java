package ie.corkathon.phone;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;

public final class SurveyRunnerCheck {
    public static void main(String[] args) {
        cutReadsChannelMajorReflectance();
        System.out.println("SurveyRunnerCheck passed");
    }

    private static void cutReadsChannelMajorReflectance() {
        int width = 60;
        int size = 50;
        ByteBuffer cube =
                ByteBuffer.allocate(AgriModel.BANDS * width * width * 2)
                        .order(ByteOrder.LITTLE_ENDIAN);
        for (int band = 0; band < AgriModel.BANDS; band++) {
            for (int y = 0; y < width; y++) {
                for (int x = 0; x < width; x++) {
                    cube.putShort(
                            ((band * width + y) * width + x) * 2,
                            (short) (band * 1000 + y * 10 + x));
                }
            }
        }
        ByteBuffer chunk = SurveyRunner.cut(cube, width, 4, 6, size);
        check(chunk.capacity() == AgriModel.BANDS * size * size * 4, "chunk holds every band");
        for (int band = 0; band < AgriModel.BANDS; band++) {
            float expected = (band * 1000 + (4 + 7) * 10 + (6 + 9)) / 10000f;
            float actual = chunk.getFloat(((band * size + 7) * size + 9) * 4);
            check(actual == expected, "band " + band + " is the scaled digital number");
        }
    }

    private static void check(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message);
        }
    }
}
