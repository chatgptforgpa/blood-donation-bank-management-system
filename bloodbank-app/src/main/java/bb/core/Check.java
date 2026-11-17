package bb.core;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.regex.Pattern;

public final class Check {
    private static final Pattern PHONE = Pattern.compile("[0-9+() .-]{6,25}");

    private Check() {
    }

    public static String text(String value, String field, int max) {
        if (value == null || value.isBlank()) {
            throw new AppException(field + " không được để trống.");
        }
        String trimmed = value.trim();
        if (trimmed.length() > max) {
            throw new AppException(field + " tối đa " + max + " ký tự.");
        }
        return trimmed;
    }

    public static String oneOf(String value, String field, String... allowed) {
        for (String option : allowed) {
            if (option.equals(value)) {
                return value;
            }
        }
        throw new AppException(field + " không hợp lệ: " + value);
    }

    public static LocalDate notFuture(LocalDate date, String field) {
        if (date == null) {
            throw new AppException(field + " không được để trống.");
        }
        if (date.isAfter(Biz.today())) {
            throw new AppException(field + " không được sau ngày hiện tại.");
        }
        return date;
    }

    public static int positive(int value, String field) {
        if (value <= 0) {
            throw new AppException(field + " phải lớn hơn 0.");
        }
        return value;
    }

    public static List<String> phones(List<String> raw) {
        Set<String> unique = new LinkedHashSet<>();
        if (raw != null) {
            for (String phone : raw) {
                if (phone == null || phone.isBlank()) {
                    continue;
                }
                String trimmed = phone.trim();
                if (!PHONE.matcher(trimmed).matches()) {
                    throw new AppException("Số điện thoại không hợp lệ: " + trimmed);
                }
                unique.add(trimmed);
            }
        }
        return new ArrayList<>(unique);
    }
}
