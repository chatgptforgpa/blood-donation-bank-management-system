package bb.service;

import bb.core.AppException;
import bb.core.Biz;
import bb.core.Check;
import bb.core.Ids;
import bb.core.Rows;
import bb.core.Sql;
import java.time.LocalDate;
import java.util.List;

public final class DonorService {
    public Rows search(String keyword) {
        String like = "%" + (keyword == null ? "" : keyword.trim()) + "%";
        return Sql.query("SELECT d.donor_id, d.full_name, d.blood_group, d.rh_factor, d.date_of_birth, d.address, "
                + "(SELECT GROUP_CONCAT(p.phone ORDER BY p.phone SEPARATOR ', ') FROM DONOR_PHONE p WHERE p.donor_id = d.donor_id) AS phones, "
                + "(SELECT MAX(e.donation_date) FROM DONATION_EVENT e WHERE e.donor_id = d.donor_id) AS last_donation "
                + "FROM DONOR d WHERE d.donor_id LIKE ? OR d.full_name LIKE ? ORDER BY d.donor_id LIMIT 500", like, like);
    }

    public String register(String name, String group, String rh, String address, LocalDate dob, List<String> phones) {
        String fullName = Check.text(name, "Full name", 150);
        String addr = Check.text(address, "Address", 255);
        Check.oneOf(group, "Blood group", "A", "B", "AB", "O");
        Check.oneOf(rh, "Rh", "+", "-");
        if (dob == null || !dob.isBefore(Biz.today())) {
            throw new AppException("Date of birth is not valid.");
        }
        List<String> phoneList = Check.phones(phones);
        String id = Ids.next("D");
        Sql.run(c -> {
            Sql.update(c, "INSERT INTO DONOR (donor_id, full_name, blood_group, rh_factor, address, date_of_birth) VALUES (?, ?, ?, ?, ?, ?)",
                    id, fullName, group, rh, addr, dob);
            for (String phone : phoneList) {
                Sql.update(c, "INSERT INTO DONOR_PHONE (donor_id, phone) VALUES (?, ?)", id, phone);
            }
        });
        return id;
    }

    public void update(String donorId, String name, String address, LocalDate dob, List<String> phones) {
        Check.text(donorId, "Donor ID", 20);
        String fullName = Check.text(name, "Full name", 150);
        String addr = Check.text(address, "Address", 255);
        if (dob == null || !dob.isBefore(Biz.today())) {
            throw new AppException("Date of birth is not valid.");
        }
        List<String> phoneList = Check.phones(phones);
        Sql.run(c -> {
            int changed = Sql.update(c, "UPDATE DONOR SET full_name = ?, address = ?, date_of_birth = ? WHERE donor_id = ?",
                    fullName, addr, dob, donorId);
            if (changed != 1) {
                throw new AppException("Donor not found: " + donorId + ".");
            }
            Sql.update(c, "DELETE FROM DONOR_PHONE WHERE donor_id = ?", donorId);
            for (String phone : phoneList) {
                Sql.update(c, "INSERT INTO DONOR_PHONE (donor_id, phone) VALUES (?, ?)", donorId, phone);
            }
        });
    }

    /**
     * Deletes a donor. Phone rows go with it (ON DELETE CASCADE); a donor with donation
     * history is protected by fk_donation_donor (RESTRICT) and the error is explained by Errors.
     */
    public void delete(String donorId) {
        Check.text(donorId, "Donor ID", 20);
        Sql.run(c -> {
            int changed = Sql.update(c, "DELETE FROM DONOR WHERE donor_id = ?", donorId);
            if (changed != 1) {
                throw new AppException("Donor not found: " + donorId + ".");
            }
        });
    }
}
