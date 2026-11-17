-- 11.Find blood units issued to requests where the blood group, Rh factor, or component type does not match the request.  

USE blood_bank_group2_d3;

SELECT
    ir.issue_id, ir.request_id, u.bank_id, u.unit_id,
    d.blood_group AS unit_blood_group,
    d.rh_factor AS unit_rh_factor,
    u.component_type AS unit_component,
    r.blood_group AS requested_blood_group,
    r.rh_factor AS requested_rh_factor,
    r.component_type AS requested_component
FROM ISSUE_RECORD AS ir
JOIN BLOOD_UNIT AS u ON ir.bank_id = u.bank_id AND ir.unit_id = u.unit_id
JOIN DONATION_EVENT AS e ON e.event_id = u.event_id
JOIN DONOR AS d ON d.donor_id = e.donor_id
JOIN REQUEST AS r ON r.request_id = ir.request_id
WHERE d.blood_group <> r.blood_group OR d.rh_factor <> r.rh_factor

UNION

SELECT
    ir.issue_id, ir.request_id, u.bank_id, u.unit_id,
    d.blood_group AS unit_blood_group,
    d.rh_factor AS unit_rh_factor,
    u.component_type AS unit_component,
    r.blood_group AS requested_blood_group,
    r.rh_factor AS requested_rh_factor,
    r.component_type AS requested_component
FROM ISSUE_RECORD AS ir
JOIN BLOOD_UNIT AS u ON ir.bank_id = u.bank_id AND ir.unit_id = u.unit_id
JOIN DONATION_EVENT AS e ON e.event_id = u.event_id
JOIN DONOR AS d ON d.donor_id = e.donor_id
JOIN REQUEST AS r ON r.request_id = ir.request_id
WHERE u.component_type <> r.component_type;
