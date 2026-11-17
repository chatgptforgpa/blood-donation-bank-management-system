package bb.core;

import java.time.LocalDate;
import java.time.ZoneId;

public final class Biz {
    public static final ZoneId ZONE = ZoneId.of("Asia/Ho_Chi_Minh");
    public static final String SQL_TODAY = "DATE(UTC_TIMESTAMP() + INTERVAL 7 HOUR)";
    public static final int DONATION_GAP_DAYS = 56;

    private Biz() {
    }

    public static LocalDate today() {
        return LocalDate.now(ZONE);
    }

}
