-- 1.Units of group O − that expire within seven days. 
USE blood_bank_group2_d3;
SELECT
    u.unit_id,
    u.bank_id,
    d.blood_group,
    d.rh_factor,
    u.component_type,
    u.expiry_date,
    u.collection_date,
    u.status
FROM BLOOD_UNIT AS u
JOIN DONATION_EVENT AS e
    ON u.event_id = e.event_id
JOIN DONOR AS d
    ON d.donor_id = e.donor_id
WHERE d.blood_group = 'O' AND d.rh_factor = '-' AND u.status = 'Available' AND u.collection_date <= CURRENT_DATE() AND u.expiry_date BETWEEN CURRENT_DATE() AND DATE_ADD(CURRENT_DATE(), INTERVAL 7 DAY);
