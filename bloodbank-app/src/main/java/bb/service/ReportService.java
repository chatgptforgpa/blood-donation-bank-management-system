package bb.service;

import bb.core.AppException;
import bb.core.Biz;
import bb.core.Rows;
import bb.core.Sql;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public final class ReportService {
    private static final String TODAY = Biz.SQL_TODAY;
    private static final Map<String, String> REPORTS = new LinkedHashMap<>();

    static {
        add("Q1 — Đơn vị O− sắp hết hạn trong 7 ngày", """
                SELECT u.unit_id, u.bank_id, d.blood_group, d.rh_factor,
                       u.component_type, u.expiry_date, u.collection_date, u.status
                FROM BLOOD_UNIT u
                JOIN DONATION_EVENT e ON u.event_id = e.event_id
                JOIN DONOR d ON d.donor_id = e.donor_id
                WHERE d.blood_group = 'O' AND d.rh_factor = '-'
                  AND u.status = 'Available' AND u.collection_date <= $TODAY
                  AND u.expiry_date BETWEEN $TODAY AND DATE_ADD($TODAY, INTERVAL 7 DAY)
                ORDER BY u.expiry_date, u.bank_id, u.unit_id
                """);
        add("Q2 — Donor đủ điều kiện hiến lại hôm nay", """
                SELECT d.donor_id, d.full_name, d.blood_group, d.rh_factor,
                       MAX(e.donation_date) AS last_donation_date
                FROM DONOR d
                JOIN DONATION_EVENT e ON d.donor_id = e.donor_id
                WHERE d.donor_id IN (
                    SELECT eligible.donor_id
                    FROM DONATION_EVENT eligible
                    GROUP BY eligible.donor_id
                    HAVING DATEDIFF($TODAY, MAX(eligible.donation_date)) >= $GAP_DAYS
                )
                GROUP BY d.donor_id, d.full_name, d.blood_group, d.rh_factor
                ORDER BY d.donor_id
                """);
        add("Q3 — Yêu cầu tạo tháng trước hiện còn thiếu một phần", """
                SELECT r.request_id, r.quantity_needed,
                       COUNT(ir.unit_id) AS fulfilled_quantity,
                       r.quantity_needed - COUNT(ir.unit_id) AS shortage_quantity
                FROM REQUEST r
                JOIN ISSUE_RECORD ir ON r.request_id = ir.request_id
                WHERE r.status = 'Partially Filled'
                  AND r.request_date < DATE_SUB($TODAY, INTERVAL DAY($TODAY) - 1 DAY)
                  AND r.request_date >= DATE_SUB(
                      DATE_SUB($TODAY, INTERVAL DAY($TODAY) - 1 DAY), INTERVAL 1 MONTH)
                GROUP BY r.request_id, r.quantity_needed
                HAVING r.quantity_needed - COUNT(ir.unit_id) > 0 AND COUNT(ir.unit_id) > 0
                ORDER BY r.request_id
                """);
        add("Q4 — Ngân hàng có đủ bốn nhóm ABO khả dụng", """
                SELECT b.bank_id, b.bank_name
                FROM BLOOD_BANK b
                WHERE NOT EXISTS (
                    SELECT 1
                    FROM (
                        SELECT 'A' AS blood_group
                        UNION ALL SELECT 'B'
                        UNION ALL SELECT 'AB'
                        UNION ALL SELECT 'O'
                    ) required_groups
                    WHERE NOT EXISTS (
                        SELECT 1
                        FROM BLOOD_UNIT u
                        JOIN DONATION_EVENT e ON e.event_id = u.event_id
                        JOIN DONOR d ON d.donor_id = e.donor_id
                        WHERE u.bank_id = b.bank_id
                          AND d.blood_group = required_groups.blood_group
                          AND u.status = 'Available' AND u.collection_date <= $TODAY
                          AND u.expiry_date >= $TODAY
                    )
                )
                ORDER BY b.bank_id
                """);
        add("Q5 — Số ngày trung bình từ collection đến issue", """
                SELECT u.component_type,
                       AVG(DATEDIFF(ir.issue_date, u.collection_date)) AS avg_day
                FROM ISSUE_RECORD ir
                JOIN BLOOD_UNIT u ON ir.bank_id = u.bank_id AND ir.unit_id = u.unit_id
                GROUP BY u.component_type
                ORDER BY u.component_type
                """);
        add("Q6 — Đơn vị AB+ Platelets phù hợp cho yêu cầu Critical, kèm tổng tồn", """
                WITH matching_units AS (
                    SELECT b.bank_id, b.bank_name, u.unit_id, u.expiry_date
                    FROM BLOOD_BANK b
                    JOIN BLOOD_UNIT u ON u.bank_id = b.bank_id
                    JOIN DONATION_EVENT e ON e.event_id = u.event_id
                    JOIN DONOR d ON d.donor_id = e.donor_id
                    WHERE d.blood_group = 'AB' AND d.rh_factor = '+'
                      AND u.component_type = 'Platelets' AND u.status = 'Available'
                      AND u.collection_date <= $TODAY AND u.expiry_date >= $TODAY
                ), bank_totals AS (
                    SELECT bank_id, COUNT(*) AS available_unit
                    FROM matching_units
                    GROUP BY bank_id
                )
                SELECT m.bank_id, m.bank_name, m.unit_id, m.expiry_date, t.available_unit
                FROM matching_units m
                JOIN bank_totals t ON t.bank_id = m.bank_id
                ORDER BY m.expiry_date, m.bank_id, m.unit_id
                """);
        add("Q7 — Tỷ lệ hao hụt theo ngân hàng và thành phần kèm manager", """
                WITH wastage AS (
                    SELECT bank_id, component_type, COUNT(*) AS total_units,
                           SUM(CASE WHEN status = 'Expired' THEN 1 ELSE 0 END) AS expired_units
                    FROM BLOOD_UNIT
                    GROUP BY bank_id, component_type
                )
                SELECT b.bank_id, b.bank_name, w.component_type,
                       w.expired_units, w.total_units,
                       ROUND(100.0 * w.expired_units / NULLIF(w.total_units, 0), 2)
                           AS wastage_rate_percent,
                       s.staff_id AS manager_id, s.full_name AS manager_name
                FROM wastage w
                JOIN BLOOD_BANK b ON b.bank_id = w.bank_id
                JOIN STAFF s ON s.bank_id = b.bank_id AND s.role = 'Manager'
                ORDER BY b.bank_id, w.component_type, s.staff_id
                """);
        add("Q8 — Yêu cầu Critical chưa có phiếu cấp", """
                SELECT r.request_id, h.hospital_name, r.request_date,
                       r.blood_group, r.rh_factor, r.component_type, r.quantity_needed
                FROM REQUEST r JOIN HOSPITAL h ON h.hospital_id = r.hospital_id
                WHERE r.urgency_level = 'Critical'
                  AND NOT EXISTS (SELECT 1 FROM ISSUE_RECORD i WHERE i.request_id = r.request_id)
                ORDER BY r.request_date, r.request_id
                """);
        add("Q9 — Túi máu đã cấp cho yêu cầu Critical kèm ngày cấp", """
                SELECT ir.issue_id, ir.issue_date, b.bank_id, b.bank_name,
                       h.hospital_id, h.hospital_name, u.unit_id, d.blood_group, d.rh_factor,
                       u.component_type, s.full_name AS staff_name
                FROM ISSUE_RECORD ir
                JOIN REQUEST r ON ir.request_id = r.request_id
                JOIN HOSPITAL h ON h.hospital_id = r.hospital_id
                JOIN BLOOD_UNIT u ON u.unit_id = ir.unit_id AND u.bank_id = ir.bank_id
                JOIN BLOOD_BANK b ON b.bank_id = u.bank_id
                JOIN STAFF s ON s.staff_id = ir.staff_id AND s.bank_id = ir.bank_id
                JOIN DONATION_EVENT e ON e.event_id = u.event_id
                JOIN DONOR d ON d.donor_id = e.donor_id
                WHERE r.urgency_level = 'Critical'
                ORDER BY ir.issue_date, ir.issue_id
                """);
        add("Q10 — Bệnh viện có nhu cầu máu tăng", """
                SELECT h.hospital_id, h.hospital_name,
                       SUM(CASE WHEN r.request_date >= DATE_FORMAT($TODAY - INTERVAL 1 MONTH, '%Y-%m-01')
                                 AND r.request_date < DATE_FORMAT($TODAY, '%Y-%m-01')
                                THEN r.quantity_needed ELSE 0 END) AS last_month_demand,
                       SUM(CASE WHEN r.request_date >= DATE_FORMAT($TODAY - INTERVAL 2 MONTH, '%Y-%m-01')
                                 AND r.request_date < DATE_FORMAT($TODAY - INTERVAL 1 MONTH, '%Y-%m-01')
                                THEN r.quantity_needed ELSE 0 END) AS previous_month_demand
                FROM HOSPITAL h
                JOIN REQUEST r ON h.hospital_id = r.hospital_id
                WHERE r.request_date >= DATE_FORMAT($TODAY - INTERVAL 2 MONTH, '%Y-%m-01')
                  AND r.request_date < DATE_FORMAT($TODAY, '%Y-%m-01')
                GROUP BY h.hospital_id, h.hospital_name
                HAVING last_month_demand > previous_month_demand
                ORDER BY last_month_demand - previous_month_demand DESC, h.hospital_id
                """);
        add("Q11 — Unit cấp sai nhóm máu, Rh hoặc thành phần so với yêu cầu", """
                SELECT ir.issue_id, ir.request_id, u.bank_id, u.unit_id,
                       d.blood_group AS unit_blood_group, d.rh_factor AS unit_rh_factor,
                       u.component_type AS unit_component,
                       r.blood_group AS requested_blood_group, r.rh_factor AS requested_rh_factor,
                       r.component_type AS requested_component
                FROM ISSUE_RECORD ir
                JOIN BLOOD_UNIT u ON ir.bank_id = u.bank_id AND ir.unit_id = u.unit_id
                JOIN DONATION_EVENT e ON e.event_id = u.event_id
                JOIN DONOR d ON d.donor_id = e.donor_id
                JOIN REQUEST r ON r.request_id = ir.request_id
                WHERE d.blood_group <> r.blood_group OR d.rh_factor <> r.rh_factor
                UNION
                SELECT ir.issue_id, ir.request_id, u.bank_id, u.unit_id,
                       d.blood_group, d.rh_factor, u.component_type,
                       r.blood_group, r.rh_factor, r.component_type
                FROM ISSUE_RECORD ir
                JOIN BLOOD_UNIT u ON ir.bank_id = u.bank_id AND ir.unit_id = u.unit_id
                JOIN DONATION_EVENT e ON e.event_id = u.event_id
                JOIN DONOR d ON d.donor_id = e.donor_id
                JOIN REQUEST r ON r.request_id = ir.request_id
                WHERE u.component_type <> r.component_type
                ORDER BY issue_id
                """);
        add("Q12 — Nhu cầu còn thiếu theo nhóm máu và thành phần", """
                SELECT r.blood_group, r.rh_factor, r.component_type,
                       SUM(r.quantity_needed) AS total_requested,
                       SUM(COALESCE(i.cnt, 0)) AS total_filled,
                       SUM(r.quantity_needed - COALESCE(i.cnt, 0)) AS units_still_needed
                FROM REQUEST r
                LEFT JOIN (SELECT request_id, COUNT(*) AS cnt FROM ISSUE_RECORD GROUP BY request_id) i
                    ON i.request_id = r.request_id
                GROUP BY r.blood_group, r.rh_factor, r.component_type
                HAVING units_still_needed > 0
                ORDER BY units_still_needed DESC
                """);
        add("Tồn kho khả dụng theo ngân hàng, nhóm máu, thành phần", """
                SELECT b.bank_name, d.blood_group, d.rh_factor, u.component_type,
                       COUNT(*) AS available_units, MIN(u.expiry_date) AS earliest_expiry
                FROM BLOOD_UNIT u
                JOIN BLOOD_BANK b ON b.bank_id = u.bank_id
                JOIN DONATION_EVENT e ON e.event_id = u.event_id
                JOIN DONOR d ON d.donor_id = e.donor_id
                WHERE u.status = 'Available' AND u.expiry_date >= $TODAY
                GROUP BY b.bank_id, b.bank_name, d.blood_group, d.rh_factor, u.component_type
                ORDER BY b.bank_id, d.blood_group, d.rh_factor, u.component_type
                """);
    }

    public List<String> names() {
        return List.copyOf(REPORTS.keySet());
    }

    public Rows run(String name) {
        String sql = REPORTS.get(name);
        if (sql == null) {
            throw new AppException("Báo cáo không tồn tại: " + name);
        }
        return Sql.query(sql);
    }

    private static void add(String name, String sql) {
        REPORTS.put(name, sql.replace("$TODAY", TODAY)
                .replace("$GAP_DAYS", Integer.toString(Biz.DONATION_GAP_DAYS)));
    }
}
