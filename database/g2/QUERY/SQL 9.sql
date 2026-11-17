-- 9.Report a list of blood bags dispatched for emergency cases (CRITICAL) including the dispatch date.

USE blood_bank_group2_d3;

SELECT ir.issue_id,
ir.issue_date,
b.bank_id,
b.bank_name,
h.hospital_id,
h.hospital_name,
u.unit_id,
d.blood_group,
u.component_type,
s.full_name AS Staff_Name
FROM ISSUE_RECORD AS ir
INNER JOIN REQUEST AS r
ON ir.request_id=r.request_id
INNER JOIN HOSPITAL AS h
ON h.hospital_id=r.hospital_id
INNER JOIN BLOOD_UNIT AS u
ON u.unit_id=ir.unit_id
AND u.bank_id=ir.bank_id
INNER JOIN BLOOD_BANK AS b
ON b.bank_id=u.bank_id
INNER JOIN STAFF AS s
ON s.staff_id=ir.staff_id AND s.bank_id=ir.bank_id
INNER JOIN DONATION_EVENT AS e
ON e.event_id=u.event_id
INNER JOIN DONOR AS d
ON d.donor_id=e.donor_id
WHERE r.urgency_level='Critical'
ORDER BY ir.issue_Date;
