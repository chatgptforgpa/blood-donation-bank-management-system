
USE blood_bank_group2_d3;

SELECT
    urgency_level,
    COUNT(*) AS total_requests
FROM REQUEST
GROUP BY urgency_level;

