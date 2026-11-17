-- 10. Find hospitals with increasing blood demand 

USE blood_bank_group2_d3;

SELECT
    h.hospital_id,
    h.hospital_name,
    SUM(CASE WHEN r.request_date >= DATE_FORMAT(CURRENT_DATE - INTERVAL 1 MONTH, '%Y-%m-01')
        AND r.request_date < DATE_FORMAT(CURRENT_DATE, '%Y-%m-01')
        THEN r.quantity_needed ELSE 0 END) AS last_month_demand,

    SUM(CASE WHEN r.request_date >= DATE_FORMAT(CURRENT_DATE - INTERVAL 2 MONTH, '%Y-%m-01')
        AND r.request_date < DATE_FORMAT(CURRENT_DATE - INTERVAL 1 MONTH, '%Y-%m-01')
        THEN r.quantity_needed ELSE 0 END) AS previous_month_demand

FROM HOSPITAL AS h
INNER JOIN REQUEST AS r
ON h.hospital_id = r.hospital_id

WHERE r.request_date >= DATE_FORMAT(CURRENT_DATE - INTERVAL 2 MONTH, '%Y-%m-01')
  AND r.request_date < DATE_FORMAT(CURRENT_DATE, '%Y-%m-01')

GROUP BY h.hospital_id, h.hospital_name
HAVING last_month_demand > previous_month_demand
ORDER BY last_month_demand - previous_month_demand DESC;
