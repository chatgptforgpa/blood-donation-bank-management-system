package bb.core;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.concurrent.ThreadLocalRandom;
import java.util.concurrent.atomic.AtomicInteger;

public final class Ids {
    private static final DateTimeFormatter STAMP = DateTimeFormatter.ofPattern("yyMMddHHmmss");
    private static final AtomicInteger SEQ = new AtomicInteger();

    private Ids() {
    }

    public static String next(String prefix) {
        String stamp = LocalDateTime.now(Biz.ZONE).format(STAMP);
        int seq = Math.floorMod(SEQ.getAndIncrement(), 1000);
        int salt = ThreadLocalRandom.current().nextInt(100);
        return String.format("%s%s%03d%02d", prefix, stamp, seq, salt);
    }
}
