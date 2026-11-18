package bb.service;

import bb.core.Option;
import bb.core.Rows;
import bb.core.Sql;
import java.util.ArrayList;
import java.util.List;

public final class LookupService {
    private List<Option> options(Rows rows) {
        List<Option> list = new ArrayList<>();
        for (int i = 0; i < rows.size(); i++) {
            list.add(new Option(rows.str(i, "id"), rows.str(i, "label")));
        }
        return list;
    }

    public List<Option> banks() {
        return options(Sql.query("SELECT bank_id AS id, CONCAT(bank_id, ': ', bank_name) AS label FROM BLOOD_BANK ORDER BY bank_id"));
    }

    public List<Option> hospitals() {
        return options(Sql.query("SELECT hospital_id AS id, CONCAT(hospital_id, ': ', hospital_name) AS label FROM HOSPITAL ORDER BY hospital_id"));
    }

    public List<Option> staff() {
        return options(Sql.query("SELECT staff_id AS id, CONCAT(staff_id, ': ', full_name, ' (', role, ', ', bank_id, ')') AS label FROM STAFF ORDER BY bank_id, staff_id"));
    }

    public List<Option> passedEvents() {
        return options(Sql.query("SELECT e.event_id AS id, CONCAT(e.event_id, ': ', d.full_name, ' (', d.blood_group, d.rh_factor, ', ', e.donation_date, ')') AS label "
                + "FROM DONATION_EVENT e JOIN DONOR d ON d.donor_id = e.donor_id WHERE e.screening_result = 'Passed' "
                + "ORDER BY e.donation_date DESC, e.event_id DESC LIMIT 500"));
    }
}
