package bb.service;

import bb.core.AppException;
import bb.core.Biz;
import bb.core.Check;
import bb.core.Ids;
import bb.core.Rows;
import bb.core.Sql;
import java.sql.CallableStatement;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

public final class IssuanceService {
    public Rows candidateUnits(String requestId, String staffId) {
        Check.text(requestId, "Yêu cầu", 20);
        Check.text(staffId, "Nhân viên", 20);
        return Sql.query("SELECT u.bank_id, u.unit_id, d.blood_group, d.rh_factor, u.component_type, u.collection_date, u.expiry_date "
                + "FROM REQUEST r JOIN STAFF s ON s.staff_id = ? JOIN BLOOD_UNIT u ON u.bank_id = s.bank_id "
                + "JOIN DONATION_EVENT e ON e.event_id = u.event_id JOIN DONOR d ON d.donor_id = e.donor_id "
                + "WHERE r.request_id = ? AND u.status = 'Available' AND d.blood_group = r.blood_group AND d.rh_factor = r.rh_factor "
                + "AND u.component_type = r.component_type AND u.collection_date <= " + Biz.SQL_TODAY + " AND u.expiry_date >= " + Biz.SQL_TODAY + " "
                + "ORDER BY u.expiry_date, u.unit_id LIMIT 300", staffId, requestId);
    }

    public List<String> issue(String requestId, String staffId, List<String> unitIds) {
        Check.text(requestId, "Yêu cầu", 20);
        Check.text(staffId, "Nhân viên", 20);
        if (unitIds == null || unitIds.isEmpty()) {
            throw new AppException("Chưa chọn đơn vị máu để cấp.");
        }
        Set<String> distinct = new HashSet<>(unitIds);
        if (distinct.size() != unitIds.size()) {
            throw new AppException("Danh sách đơn vị máu có mã trùng.");
        }
        return Sql.tx(c -> {
            Rows request = Sql.select(c, "SELECT quantity_needed FROM REQUEST WHERE request_id = ? FOR UPDATE", requestId);
            if (request.size() == 0) {
                throw new AppException("Không tìm thấy yêu cầu " + requestId + ".");
            }
            long needed = request.num(0, "quantity_needed");
            long issued = Sql.select(c, "SELECT COUNT(*) AS n FROM ISSUE_RECORD WHERE request_id = ?", requestId).num(0, "n");
            long remaining = needed - issued;
            if (remaining <= 0) {
                throw new AppException("Yêu cầu đã được cấp đủ.");
            }
            if (unitIds.size() > remaining) {
                throw new AppException("Chỉ còn thiếu " + remaining + " đơn vị, không thể cấp " + unitIds.size() + ".");
            }
            Rows staff = Sql.select(c, "SELECT bank_id FROM STAFF WHERE staff_id = ?", staffId);
            if (staff.size() == 0) {
                throw new AppException("Không tìm thấy nhân viên " + staffId + ".");
            }
            String bankId = staff.str(0, "bank_id");
            List<String> issueIds = new ArrayList<>();
            try (CallableStatement call = c.prepareCall("{CALL d309_issue_unit(?, ?, ?, ?, ?)}")) {
                for (String unitId : unitIds) {
                    String issueId = Ids.next("I");
                    call.setString(1, issueId);
                    call.setString(2, requestId);
                    call.setString(3, bankId);
                    call.setString(4, unitId);
                    call.setString(5, staffId);
                    call.execute();
                    issueIds.add(issueId);
                }
            }
            return issueIds;
        });
    }
}
