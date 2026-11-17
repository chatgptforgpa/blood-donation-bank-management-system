-- 2.The donors are eligible to donate again today. 
USE blood_bank_group2_d3;

SELECT d.donor_id,d.full_name,d.blood_group,d.rh_factor,MAX(e.donation_date) AS
last_donation_date
FROM DONOR AS d
JOIN DONATION_EVENT AS e
ON d.donor_id=e.donor_id
WHERE d.donor_id IN (
    SELECT eligible.donor_id
    FROM DONATION_EVENT AS eligible
    GROUP BY eligible.donor_id
    HAVING DATEDIFF(CURRENT_DATE, MAX(eligible.donation_date)) >= 56
)
GROUP BY d.donor_id,d.full_name, d.blood_group, d.rh_factor;
