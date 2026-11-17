package bb.service;

import bb.core.AppException;
import bb.core.Biz;
import bb.core.Check;
import bb.core.Ids;
import bb.core.Rows;
import bb.core.Sql;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;

public final class DonationService {
    public static final List<String> TEST_TYPES = List.of("HIV", "HBsAg", "HCV", "Syphilis", "Malaria");

    public Rows list(String donorFilter) {
        String like = "%" + (donorFilter == null ? "" : donorFilter.trim()) + "%";
        return Sql.query("SELECT e.event_id, e.donor_id, d.full_name, e.bank_id, e.donation_date, e.volume_ml, e.screening_result, "
                + "(SELECT COUNT(*) FROM SCREENING_TEST t WHERE t.event_id = e.event_id) AS tests, "
                + "(SELECT COUNT(*) FROM BLOOD_UNIT u WHERE u.event_id = e.event_id) AS units "
                + "FROM DONATION_EVENT e JOIN DONOR d ON d.donor_id = e.donor_id "
                + "WHERE e.donor_id LIKE ? OR d.full_name LIKE ? ORDER BY e.donation_date DESC, e.event_id DESC LIMIT 500", like, like);
    }

    public LocalDate nextEligibleDate(String donorId) {
        Check.text(donorId, "Mã donor", 20);
        Rows donor = Sql.query("SELECT COUNT(*) AS n FROM DONOR WHERE donor_id = ?", donorId);
        if (donor.num(0, "n") == 0) {
            throw new AppException("Không tìm thấy donor " + donorId + ".");
        }
        Rows last = Sql.query("SELECT MAX(donation_date) AS last_date FROM DONATION_EVENT WHERE donor_id = ?", donorId);
        String value = last.str(0, "last_date");
        return value == null ? null : LocalDate.parse(value).plusDays(Biz.DONATION_GAP_DAYS);
    }

    public String record(String donorId, String bankId, LocalDate date, int volumeMl) {
        Check.text(donorId, "Mã donor", 20);
        Check.text(bankId, "Ngân hàng", 20);
        Check.notFuture(date, "Ngày hiến");
        Check.positive(volumeMl, "Thể tích");
        String id = Ids.next("E");
        Sql.run(c -> Sql.update(c, "INSERT INTO DONATION_EVENT (event_id, donor_id, bank_id, donation_date, volume_ml, screening_result) "
                + "VALUES (?, ?, ?, ?, ?, 'Pending')", id, donorId, bankId, date, volumeMl));
        return id;
    }

    public Rows tests(String eventId) {
        return Sql.query("SELECT test_type, result, test_date FROM SCREENING_TEST WHERE event_id = ? ORDER BY test_type", eventId);
    }

    public void saveTests(String eventId, LocalDate testDate, Map<String, String> results) {
        Check.text(eventId, "Mã đợt hiến", 20);
        Check.notFuture(testDate, "Ngày xét nghiệm");
        if (results == null || results.isEmpty()) {
            throw new AppException("Chưa chọn kết quả xét nghiệm nào.");
        }
        for (Map.Entry<String, String> entry : results.entrySet()) {
            Check.oneOf(entry.getKey(), "Loại xét nghiệm", TEST_TYPES.toArray(new String[0]));
            Check.oneOf(entry.getValue(), "Kết quả", "Positive", "Negative");
        }
        Sql.run(c -> {
            for (Map.Entry<String, String> entry : results.entrySet()) {
                Sql.update(c, "INSERT INTO SCREENING_TEST (event_id, test_type, result, test_date) VALUES (?, ?, ?, ?)",
                        eventId, entry.getKey(), entry.getValue(), testDate);
            }
        });
    }

    public void deleteTest(String eventId, String testType) {
        Check.text(eventId, "Mã đợt hiến", 20);
        Check.oneOf(testType, "Loại xét nghiệm", TEST_TYPES.toArray(new String[0]));
        Sql.run(c -> {
            int changed = Sql.update(c, "DELETE FROM SCREENING_TEST WHERE event_id = ? AND test_type = ?", eventId, testType);
            if (changed != 1) {
                throw new AppException("Không tìm thấy xét nghiệm cần xóa.");
            }
        });
    }
}
