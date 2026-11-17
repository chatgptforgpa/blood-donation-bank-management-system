package bb.service;

import bb.core.AppException;
import bb.core.Biz;
import bb.core.Check;
import bb.core.Ids;
import bb.core.Rows;
import bb.core.Sql;
import java.sql.CallableStatement;
import java.time.LocalDate;

public final class InventoryService {
    public static final String[] COMPONENTS = {"Whole Blood", "Plasma", "Platelets"};
    public static final String[] STATUSES = {"Available", "Reserved", "Issued", "Expired", "Discarded"};

    public Rows units(String bankId, String status, String group, String rh, String component) {
        return Sql.query("SELECT u.bank_id, u.unit_id, d.blood_group, d.rh_factor, u.component_type, u.collection_date, u.expiry_date, u.status, u.event_id "
                + "FROM BLOOD_UNIT u JOIN DONATION_EVENT e ON e.event_id = u.event_id JOIN DONOR d ON d.donor_id = e.donor_id "
                + "WHERE (? IS NULL OR u.bank_id = ?) AND (? IS NULL OR u.status = ?) AND (? IS NULL OR d.blood_group = ?) "
                + "AND (? IS NULL OR d.rh_factor = ?) AND (? IS NULL OR u.component_type = ?) "
                + "ORDER BY u.expiry_date, u.bank_id, u.unit_id LIMIT 1000",
                bankId, bankId, status, status, group, group, rh, rh, component, component);
    }

    public String register(String bankId, String eventId, String component, LocalDate collectionDate,
            LocalDate expiryDate) {
        Check.text(bankId, "Ngân hàng lưu trữ", 20);
        Check.text(eventId, "Đợt hiến máu", 20);
        Check.oneOf(component, "Thành phần máu", COMPONENTS);
        validateDates(collectionDate, expiryDate);
        String unitId = Ids.next("U");
        Sql.run(c -> Sql.update(c, "INSERT INTO BLOOD_UNIT (bank_id, unit_id, event_id, component_type, collection_date, expiry_date, status) "
                + "VALUES (?, ?, ?, ?, ?, ?, 'Available')", bankId, unitId, eventId, component, collectionDate, expiryDate));
        return unitId;
    }

    static void validateDates(LocalDate collectionDate, LocalDate expiryDate) {
        Check.notFuture(collectionDate, "Ngày thu thập");
        if (expiryDate == null) {
            throw new AppException("Ngày hết hạn không được để trống.");
        }
        if (!expiryDate.isAfter(collectionDate)) {
            throw new AppException("Ngày hết hạn phải sau ngày thu thập.");
        }
    }

    public void discard(String bankId, String unitId, String staffId) {
        Check.text(bankId, "Ngân hàng", 20);
        Check.text(unitId, "Đơn vị máu", 20);
        Check.text(staffId, "Nhân viên", 20);
        Sql.run(c -> {
            try (CallableStatement call = c.prepareCall("{CALL d309_discard_unit(?, ?, ?)}")) {
                call.setString(1, bankId);
                call.setString(2, unitId);
                call.setString(3, staffId);
                call.execute();
            }
        });
    }

    public long expireNow() {
        return Sql.tx(c -> {
            Rows due = Sql.select(c, "SELECT COUNT(*) AS n FROM BLOOD_UNIT WHERE status = 'Available' AND expiry_date < " + Biz.SQL_TODAY);
            long count = due.num(0, "n");
            if (count > 0) {
                try (CallableStatement call = c.prepareCall("{CALL d309_expire_units()}")) {
                    call.execute();
                }
            }
            return count;
        });
    }

    public static AppException notFound(String what) {
        return new AppException("Không tìm thấy " + what + ".");
    }
}
