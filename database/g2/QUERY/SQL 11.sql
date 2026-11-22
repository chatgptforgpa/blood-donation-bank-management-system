-- 11. Which blood group / Rh / component combinations are still requested by hospitals
--     (request not yet Fulfilled) but have no usable unit in stock in any bank?
--     Set operation: EXCEPT (set difference). Requires MySQL 8.0.31 or later.
--     The old Q11 (units issued with the wrong group, Rh or component) is an integrity
--     check that must always return nothing; it now lives in test_business_rules.sql.
USE blood_bank_group2_d3;

SELECT r.blood_group, r.rh_factor, r.component_type
FROM REQUEST AS r
WHERE r.status <> 'Fulfilled'
EXCEPT
SELECT d.blood_group, d.rh_factor, u.component_type
FROM BLOOD_UNIT AS u
JOIN DONATION_EVENT AS e ON e.event_id = u.event_id
JOIN DONOR AS d ON d.donor_id = e.donor_id
WHERE u.status = 'Available'
  AND u.collection_date <= CURRENT_DATE
  AND u.expiry_date >= CURRENT_DATE
ORDER BY blood_group, rh_factor, component_type;
