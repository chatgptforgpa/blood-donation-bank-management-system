package bb.service;

import bb.core.AppException;
import bb.core.Check;
import bb.core.Ids;
import bb.core.Rows;
import bb.core.Sql;
import java.time.LocalDate;

public final class RequestService {
    public static final String[] URGENCIES = {"Low", "Medium", "High", "Critical"};
    public static final String[] STATUSES = {"Pending", "Partially Filled", "Fulfilled"};

    private static final String BASE = "SELECT r.request_id, h.hospital_name, r.blood_group, r.rh_factor, r.component_type, r.quantity_needed, "
            + "COUNT(i.issue_id) AS issued, r.quantity_needed - COUNT(i.issue_id) AS remaining, r.urgency_level, r.request_date, r.status "
            + "FROM REQUEST r JOIN HOSPITAL h ON h.hospital_id = r.hospital_id LEFT JOIN ISSUE_RECORD i ON i.request_id = r.request_id "
            + "WHERE (? IS NULL OR r.status = ?) AND (? IS NULL OR r.urgency_level = ?) "
            + "GROUP BY r.request_id, h.hospital_name, r.blood_group, r.rh_factor, r.component_type, r.quantity_needed, r.urgency_level, r.request_date, r.status ";

    public Rows list(String status, String urgency) {
        return Sql.query(BASE + "ORDER BY r.request_date DESC, r.request_id DESC LIMIT 500", status, status, urgency, urgency);
    }

    public Rows open() {
        return Sql.query(BASE + "HAVING remaining > 0 ORDER BY FIELD(r.urgency_level, 'Critical', 'High', 'Medium', 'Low'), r.request_date, r.request_id LIMIT 500",
                null, null, null, null);
    }

    public Rows issues(String requestId) {
        return Sql.query("SELECT issue_id, bank_id, unit_id, issue_date, staff_id FROM ISSUE_RECORD WHERE request_id = ? ORDER BY issue_id", requestId);
    }

    public String create(String hospitalId, String group, String rh, String component, int quantity, String urgency, LocalDate date) {
        Check.text(hospitalId, "Hospital", 20);
        Check.oneOf(group, "Blood group", "A", "B", "AB", "O");
        Check.oneOf(rh, "Rh", "+", "-");
        Check.oneOf(component, "Component", InventoryService.COMPONENTS);
        Check.positive(quantity, "Quantity");
        Check.oneOf(urgency, "Urgency", URGENCIES);
        Check.notFuture(date, "Request date");
        String id = Ids.next("R");
        Sql.run(c -> Sql.update(c, "INSERT INTO REQUEST (request_id, hospital_id, blood_group, rh_factor, component_type, quantity_needed, urgency_level, request_date, status) "
                + "VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'Pending')", id, hospitalId, group, rh, component, quantity, urgency, date));
        return id;
    }

    /**
     * Changes urgency and quantity. Once a unit has been issued, trigger d309_request_bu
     * rejects any quantity change ("Request details are locked after the first issue").
     */
    public void update(String requestId, String urgency, int quantity) {
        Check.text(requestId, "Request", 20);
        Check.oneOf(urgency, "Urgency", URGENCIES);
        Check.positive(quantity, "Quantity");
        Sql.run(c -> {
            int changed = Sql.update(c, "UPDATE REQUEST SET urgency_level = ?, quantity_needed = ? WHERE request_id = ?",
                    urgency, quantity, requestId);
            if (changed != 1) {
                throw new AppException("Request not found: " + requestId + ".");
            }
        });
    }

    /** Deletes a request; fk_issue_request (RESTRICT) blocks requests that already have issue records. */
    public void delete(String requestId) {
        Check.text(requestId, "Request", 20);
        Sql.run(c -> {
            int changed = Sql.update(c, "DELETE FROM REQUEST WHERE request_id = ?", requestId);
            if (changed != 1) {
                throw new AppException("Request not found: " + requestId + ".");
            }
        });
    }
}
