-- 6. For an urgent Critical hospital request for AB+ Platelets, 
-- list suitable available units with bank details, expiry dates and stock totals, ordered by expiry date.

USE blood_bank_group2_d3;

WITH matching_units AS (
    SELECT b.bank_id, b.bank_name, u.unit_id, u.expiry_date
    FROM BLOOD_BANK AS b
    JOIN BLOOD_UNIT AS u ON u.bank_id = b.bank_id
    JOIN DONATION_EVENT AS e ON e.event_id = u.event_id
    JOIN DONOR AS d ON d.donor_id = e.donor_id
    WHERE d.blood_group = 'AB'
      AND d.rh_factor = '+'
      AND u.component_type = 'Platelets'
      AND u.status = 'Available'
      AND u.collection_date <= CURRENT_DATE
      AND u.expiry_date >= CURRENT_DATE
), bank_totals AS (
    SELECT bank_id, COUNT(*) AS available_unit
    FROM matching_units
    GROUP BY bank_id
)
SELECT m.bank_id, m.bank_name, m.unit_id, m.expiry_date,t.available_unit
FROM matching_units AS m
JOIN bank_totals AS t ON t.bank_id = m.bank_id
ORDER BY m.expiry_date, m.bank_id, m.unit_id;

