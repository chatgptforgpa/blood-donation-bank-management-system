-- 12.Find blood groups and components with unfulfilled demand 
USE blood_bank_group2_d3;

CREATE OR REPLACE VIEW v_request_outstanding AS
SELECT r.request_id, r.blood_group, r.rh_factor,
       r.component_type, r.quantity_needed,
       COUNT(ir.issue_id) AS quantity_filled,
       r.quantity_needed - COUNT(ir.issue_id) AS outstanding_units
FROM REQUEST AS r
LEFT JOIN ISSUE_RECORD AS ir ON ir.request_id = r.request_id
GROUP BY r.request_id, r.blood_group, r.rh_factor,
         r.component_type, r.quantity_needed;

SELECT
    x.blood_group,
    x.rh_factor,
    x.component_type,
    SUM(x.quantity_needed) AS total_requested,
    SUM(x.quantity_filled) AS total_filled,
    SUM(x.outstanding_units) AS units_still_needed
FROM v_request_outstanding AS x
GROUP BY x.blood_group, x.rh_factor, x.component_type
HAVING SUM(x.outstanding_units) > 0
ORDER BY units_still_needed DESC;
