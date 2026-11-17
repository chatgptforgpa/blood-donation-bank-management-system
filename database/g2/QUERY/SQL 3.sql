-- 3.Requests that were only partly filled last month. 
USE blood_bank_group2_d3;

SELECT
    r.request_id,
    r.quantity_needed,
    COUNT(ir.unit_id) AS fulfilled_quantity,
    r.quantity_needed - COUNT(ir.unit_id) AS shortage_quantity
FROM REQUEST AS r
INNER JOIN ISSUE_RECORD AS ir
    ON r.request_id = ir.request_id
WHERE r.status = 'Partially Filled' AND r.request_date < DATE_SUB(CURRENT_DATE(), INTERVAL DAY(CURRENT_DATE()) - 1 DAY)
  AND r.request_date >= DATE_SUB(
      DATE_SUB(
          CURRENT_DATE(),
          INTERVAL DAY(CURRENT_DATE()) - 1 DAY
      ),
      INTERVAL 1 MONTH
  )
GROUP BY r.request_id, r.quantity_needed
HAVING r.quantity_needed - COUNT(ir.unit_id) > 0 AND COUNT(ir.unit_id) > 0;
