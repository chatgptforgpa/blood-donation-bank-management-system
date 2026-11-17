-- 5. The average number of days between collection and issue, per component. 
USE blood_bank_group2_d3;

SELECT
    u.component_type,
    AVG(DATEDIFF(ir.issue_date,u.collection_date)) AS avg_day
FROM ISSUE_RECORD AS ir
JOIN BLOOD_UNIT AS u
ON ir.bank_id=u.bank_id
AND ir.unit_id=u.unit_id
GROUP BY u.component_type;
