-- Group 02 | Constraint tests (Section 2.3: "test the constraints before you build the interface").
-- Every statement below MUST fail. Run with:  mysql --force < constraint_tests.sql
-- (in MySQL Workbench, turn on "continue on SQL script error" or run one line at a time).

USE blood_bank_group2_d3;

-- 1. Duplicate primary key -> ERROR 1062
INSERT INTO DONOR (donor_id, full_name, blood_group, rh_factor, address, date_of_birth)
VALUES ('S2KD0001', 'Copy Of Robert', 'A', '+', 'Somewhere', '1990-01-01');

-- 2. Foreign key to a hospital that does not exist -> ERROR 1452
INSERT INTO `REQUEST` (request_id, hospital_id, blood_group, rh_factor, component_type,
                       quantity_needed, urgency_level, request_date)
VALUES ('CT_R1', 'NO_SUCH_HOSPITAL', 'A', '+', 'Plasma', 1, 'Low', '2026-11-14');

-- 3. CHECK violation: blood group outside {A, B, AB, O} -> ERROR 3819
INSERT INTO DONOR (donor_id, full_name, blood_group, rh_factor, address, date_of_birth)
VALUES ('CT_D1', 'Bad Group', 'C', '+', 'Somewhere', '1990-01-01');

-- 4. CHECK violation: expiry date not after collection date -> ERROR 3819
INSERT INTO BLOOD_UNIT (bank_id, unit_id, event_id, component_type, collection_date, expiry_date)
SELECT bank_id, 'CT_U1', event_id, 'Plasma', donation_date + INTERVAL 1 DAY, donation_date
FROM DONATION_EVENT WHERE screening_result = 'Passed' LIMIT 1;

-- 5. CHECK violation: quantity must be positive -> ERROR 3819
UPDATE `REQUEST` SET quantity_needed = 0
WHERE request_id = (SELECT r FROM (SELECT MIN(request_id) AS r FROM `REQUEST` WHERE status = 'Pending') AS x);

-- 6. Delete a parent row that is still referenced (donor with donations) -> ERROR 1451
DELETE FROM DONOR WHERE donor_id = (SELECT donor_id FROM (SELECT donor_id FROM DONATION_EVENT LIMIT 1) AS x);

-- 7. Business rule (trigger): a unit can be issued only once -> ERROR 1062 / 45000
INSERT INTO ISSUE_RECORD (issue_id, request_id, bank_id, unit_id, issue_date, staff_id)
SELECT 'CT_I1', request_id, bank_id, unit_id, issue_date, staff_id FROM ISSUE_RECORD LIMIT 1;

-- 8. Business rule (trigger): donations at least 56 days apart -> ERROR 1644 (SQLSTATE 45000)
INSERT INTO DONATION_EVENT (event_id, donor_id, bank_id, donation_date, volume_ml)
SELECT 'CT_E1', donor_id, bank_id, donation_date + INTERVAL 10 DAY, 350
FROM DONATION_EVENT ORDER BY donation_date DESC LIMIT 1;

-- 9. Self-management on the recursive relationship -> ERROR 1644 (SQLSTATE 45000)
UPDATE STAFF SET manager_id = staff_id WHERE staff_id = (SELECT s FROM (SELECT MIN(staff_id) AS s FROM STAFF) AS x);

-- 10. Audit rule: issue records cannot be deleted -> ERROR 1644 (SQLSTATE 45000)
DELETE FROM ISSUE_RECORD WHERE issue_id = (SELECT i FROM (SELECT MIN(issue_id) AS i FROM ISSUE_RECORD) AS x);

-- None of the rows above may exist:
SELECT (SELECT COUNT(*) FROM DONOR WHERE donor_id LIKE 'CT\_%') +
       (SELECT COUNT(*) FROM `REQUEST` WHERE request_id LIKE 'CT\_%') +
       (SELECT COUNT(*) FROM BLOOD_UNIT WHERE unit_id LIKE 'CT\_%') +
       (SELECT COUNT(*) FROM DONATION_EVENT WHERE event_id LIKE 'CT\_%') +
       (SELECT COUNT(*) FROM ISSUE_RECORD WHERE issue_id LIKE 'CT\_%') AS accepted_bad_rows;
