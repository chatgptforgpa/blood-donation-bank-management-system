-- 4.Blood banks that hold at least one unit of every group
USE blood_bank_group2_d3;

SELECT b.bank_id, b.bank_name
FROM BLOOD_BANK AS b
WHERE NOT EXISTS (
    SELECT 1
    FROM (
        SELECT 'A' AS blood_group
        UNION ALL SELECT 'B'
        UNION ALL SELECT 'AB'
        UNION ALL SELECT 'O'
    ) AS required_groups
    WHERE NOT EXISTS (
        SELECT 1
        FROM BLOOD_UNIT AS u
        JOIN DONATION_EVENT AS e
            ON e.event_id = u.event_id
        JOIN DONOR AS d
            ON d.donor_id = e.donor_id
        WHERE u.bank_id = b.bank_id
          AND d.blood_group = required_groups.blood_group
          AND u.status = 'Available'
          AND u.collection_date <= CURRENT_DATE
          AND u.expiry_date >= CURRENT_DATE
    )
);
