-- Group 02 | Topic 10: Blood Donation and Blood Banks
-- The twelve queries of the project (Section 2.2), one commented script.
-- DBMS: MySQL 8.0.46+ (tested on MySQL Community Server 26.10.0).
-- Run after rebuild.sql. Date-relative queries use CURRENT_DATE, so their rows
-- depend on the day the script is run (sample data snapshot: 2026-11-14).

USE blood_bank_group2_d3;

-- ============================================================================
-- Q1. Which Available units of group O negative expire within the next seven days?
-- Technique: multi-table join (BLOOD_UNIT, DONATION_EVENT, DONOR) + date range | topic query 1 | uses index ix_blood_unit_status_expiry
-- ============================================================================
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
WHERE d.blood_group = 'O'
  AND d.rh_factor = '-'
  AND u.status = 'Available'
  AND u.collection_date <= CURRENT_DATE()
  AND u.expiry_date BETWEEN CURRENT_DATE() AND DATE_ADD(CURRENT_DATE(), INTERVAL 7 DAY);

-- ============================================================================
-- Q2. Which donors are eligible to donate again today (last donation at least 56 days ago)?
-- Technique: nested query with IN + GROUP BY/HAVING | topic query 2
-- ============================================================================
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

-- ============================================================================
-- Q3. Which requests made last month are only partly filled, and how many units are still missing?
-- Technique: join + aggregation with GROUP BY and HAVING | topic query 3 | uses index ix_request_date
-- ============================================================================
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

-- ============================================================================
-- Q4. Which blood banks hold at least one usable unit of every ABO group?
-- Technique: relational division with double NOT EXISTS ("for all") | topic query 4
-- ============================================================================
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

-- ============================================================================
-- Q5. What is the average number of days between collection and issue, per component?
-- Technique: join + aggregation | topic query 5
-- ============================================================================
SELECT
    u.component_type,
    AVG(DATEDIFF(ir.issue_date,u.collection_date)) AS avg_day
FROM ISSUE_RECORD AS ir
JOIN BLOOD_UNIT AS u
ON ir.bank_id=u.bank_id
AND ir.unit_id=u.unit_id
GROUP BY u.component_type;

-- ============================================================================
-- Q6. For a Critical request for AB+ Platelets, which usable units exist in each bank, ordered by expiry, with the bank's stock total?
-- Technique: common table expressions + joins
-- ============================================================================
WITH matching_units AS (
    SELECT b.bank_id, b.bank_name, u.unit_id, u.expiry_date
    FROM BLOOD_BANK AS b
    JOIN BLOOD_UNIT AS u ON u.bank_id = b.bank_id
    JOIN DONATION_EVENT AS e ON e.event_id = u.event_id
    JOIN DONOR AS d ON d.donor_id = e.donor_id
    WHERE d.blood_group = 'AB'
      AND d.rh_factor = '+'
      AND u.component_type = 'Platelets'
      AND u.status = 'Available'
      AND u.collection_date <= CURRENT_DATE
      AND u.expiry_date >= CURRENT_DATE
), bank_totals AS (
    SELECT bank_id, COUNT(*) AS available_unit
    FROM matching_units
    GROUP BY bank_id
)
SELECT m.bank_id, m.bank_name, m.unit_id, m.expiry_date,t.available_unit
FROM matching_units AS m
JOIN bank_totals AS t ON t.bank_id = m.bank_id
ORDER BY m.expiry_date, m.bank_id, m.unit_id;

-- ============================================================================
-- Q7. What share of each bank's units, per component, ended up Expired (wastage rate), and who manages the bank?
-- Technique: aggregation + conditional CASE + join with STAFF
-- ============================================================================
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

-- ============================================================================
-- Q8. Which Critical requests have no issue record yet?
-- Technique: outer join (LEFT JOIN ... IS NULL) | relational algebra: set difference
-- ============================================================================
SELECT r.request_id,h.hospital_Name,r.request_date,r.blood_group,r.quantity_needed
FROM REQUEST AS r
INNER JOIN HOSPITAL AS h
ON r.hospital_id = h.hospital_id
LEFT JOIN ISSUE_RECORD AS ir
ON r.request_id=ir.request_id
WHERE r.urgency_level='Critical'
AND ir.issue_id IS NULL;

-- ============================================================================
-- Q9. Which units were issued against Critical requests, from which bank, to which hospital, by whom and when?
-- Technique: eight-table join (seven INNER JOINs)
-- ============================================================================
SELECT ir.issue_id,
ir.issue_date,
b.bank_id,
b.bank_name,
h.hospital_id,
h.hospital_name,
u.unit_id,
d.blood_group,
u.component_type,
s.full_name AS Staff_Name
FROM ISSUE_RECORD AS ir
INNER JOIN REQUEST AS r
ON ir.request_id=r.request_id
INNER JOIN HOSPITAL AS h
ON h.hospital_id=r.hospital_id
INNER JOIN BLOOD_UNIT AS u
ON u.unit_id=ir.unit_id
AND u.bank_id=ir.bank_id
INNER JOIN BLOOD_BANK AS b
ON b.bank_id=u.bank_id
INNER JOIN STAFF AS s
ON s.staff_id=ir.staff_id AND s.bank_id=ir.bank_id
INNER JOIN DONATION_EVENT AS e
ON e.event_id=u.event_id
INNER JOIN DONOR AS d
ON d.donor_id=e.donor_id
WHERE r.urgency_level='Critical'
ORDER BY ir.issue_Date;

-- ============================================================================
-- Q10. Which hospitals requested more units last month than in the month before?
-- Technique: conditional aggregation + GROUP BY/HAVING | uses index ix_request_date
-- ============================================================================
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

-- ============================================================================
-- Q11. Which group/Rh/component combinations are still requested but have no usable unit in any bank?
-- Technique: set operation EXCEPT
-- ============================================================================
SELECT r.blood_group, r.rh_factor, r.component_type
FROM REQUEST AS r
WHERE r.status <> 'Fulfilled'
EXCEPT
SELECT d.blood_group, d.rh_factor, u.component_type
FROM BLOOD_UNIT AS u
JOIN DONATION_EVENT AS e ON e.event_id = u.event_id
JOIN DONOR AS d ON d.donor_id = e.donor_id
WHERE u.status = 'Available'
  AND u.collection_date <= CURRENT_DATE
  AND u.expiry_date >= CURRENT_DATE
ORDER BY blood_group, rh_factor, component_type;

-- ============================================================================
-- Q12. Through the view v_request_outstanding: which group/Rh/component combinations still have unfilled demand?
-- Technique: VIEW + outer join + GROUP BY/HAVING
-- ============================================================================
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
