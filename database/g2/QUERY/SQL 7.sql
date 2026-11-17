-- 7. Report wastage rate by blood component and blood bank, with the bank's manager.
USE blood_bank_group2_d3;

WITH wastage AS (
    SELECT bank_id, component_type,
           COUNT(*) AS total_units,
           SUM(CASE WHEN status = 'Expired' THEN 1 ELSE 0 END)
               AS expired_units
    FROM BLOOD_UNIT
    GROUP BY bank_id, component_type
)
SELECT b.bank_id, b.bank_name, w.component_type,
       w.expired_units, w.total_units,
       ROUND(100.0 * w.expired_units / NULLIF(w.total_units, 0), 2) AS wastage_rate_percent,
       s.staff_id AS manager_id, 
       s.full_name AS manager_name
FROM wastage AS w
JOIN BLOOD_BANK AS b ON b.bank_id = w.bank_id
JOIN STAFF AS s ON s.bank_id = b.bank_id AND s.role = 'Manager'
ORDER BY b.bank_id, w.component_type, s.staff_id;
