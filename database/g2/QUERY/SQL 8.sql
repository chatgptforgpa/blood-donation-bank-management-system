-- 8.List blood donation requests (request_id, hospital_Name, request_date, blood_group, quantity_needed)
-- with urgency_level = 'Critical' but for which no issuance records (Issue_Records) have been created for processing
USE blood_bank_group2_d3;

SELECT r.request_id,h.hospital_Name,r.request_date,r.blood_group,r.quantity_needed
FROM REQUEST AS r
INNER JOIN HOSPITAL AS h
ON r.hospital_id = h.hospital_id
LEFT JOIN ISSUE_RECORD AS ir
ON r.request_id=ir.request_id
WHERE r.urgency_level='Critical'
AND ir.issue_id IS NULL;
