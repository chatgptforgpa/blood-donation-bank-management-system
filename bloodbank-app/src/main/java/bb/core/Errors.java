package bb.core;

import java.sql.SQLException;
import java.util.Locale;
import java.util.Map;

public final class Errors {
    /** Plain-language explanation for each named constraint, keyed by constraint name. */
    private static final Map<String, String> CONSTRAINTS = Map.ofEntries(
            Map.entry("fk_donation_donor", "This donor has donation history and cannot be deleted. Donation history must be kept."),
            Map.entry("fk_donation_bank", "This blood bank has donation events and cannot be deleted."),
            Map.entry("fk_issue_request", "This request already has issue records and cannot be deleted."),
            Map.entry("fk_request_hospital", "The hospital does not exist, or it has blood requests and cannot be deleted."),
            Map.entry("fk_issue_unit", "This blood unit has been issued and cannot be deleted."),
            Map.entry("fk_blood_unit_event", "This donation event has produced blood units and cannot be deleted."),
            Map.entry("fk_screening_test_event", "This donation event has screening results and cannot be deleted."),
            Map.entry("fk_issue_staff_bank", "The issuing staff member must work at the bank that holds the unit."),
            Map.entry("chk_donor_blood_group", "Blood group must be A, B, AB or O."),
            Map.entry("chk_request_quantity", "Requested quantity must be greater than 0."),
            Map.entry("chk_donation_volume", "Donation volume must be greater than 0 ml."),
            Map.entry("chk_blood_unit_expiry", "Expiry date must be after the collection date."),
            Map.entry("chk_bank_hours", "Closing time must be after opening time."),
            Map.entry("uq_donation_donor_date", "This donor already has a donation on the same day."));

    private Errors() {
    }

    public static AppException of(SQLException e) {
        if ("45000".equals(e.getSQLState())) {
            return new AppException(e.getMessage());
        }
        String known = byConstraint(e.getMessage());
        if (known != null) {
            return new AppException(known);
        }
        return switch (e.getErrorCode()) {
            case 1062 -> new AppException("Duplicate key: the value breaks a PRIMARY KEY or UNIQUE constraint.");
            case 1451 -> new AppException("Cannot delete or change this row: other records still refer to it.");
            case 1452 -> new AppException("The referenced row does not exist, or the bank/staff/unit does not match.");
            case 3819 -> new AppException("A value breaks a CHECK constraint of the table.");
            case 1048 -> new AppException("A required value is missing.");
            case 1213, 1205 -> new AppException("The database is busy with another change. Please try again.");
            default -> new AppException("Database error (" + e.getSQLState() + "/" + e.getErrorCode() + "): " + e.getMessage());
        };
    }

    static String byConstraint(String message) {
        if (message == null) {
            return null;
        }
        String lower = message.toLowerCase(Locale.ROOT);
        for (Map.Entry<String, String> entry : CONSTRAINTS.entrySet()) {
            if (lower.contains("`" + entry.getKey() + "`") || lower.contains("'" + entry.getKey() + "'")) {
                return entry.getValue();
            }
        }
        return null;
    }
}
