-- Group 02 | Update statements used by the application (Section 2.3).
-- INSERT / UPDATE / DELETE for each main table, plus two multi-table transactions:
-- one that COMMITs and one that is ROLLED BACK.
-- Run once on a fresh database, right after rebuild.sql. All demo keys start with 'DML'.
-- ISSUE_RECORD is an audit table: the triggers reject UPDATE and DELETE on it by design.

USE blood_bank_group2_d3;

-- Business date used by the triggers (Vietnam, UTC+07:00).
SET @today = DATE(UTC_TIMESTAMP() + INTERVAL 7 HOUR);

-- ---------------------------------------------------------------------------
-- BLOOD_BANK (+ multivalued phone)
-- ---------------------------------------------------------------------------
INSERT INTO BLOOD_BANK (bank_id, bank_name, location, open_time, close_time)
VALUES ('DMLB01', 'District 10 Blood Centre', '201B Nguyen Chi Thanh, District 10, HCMC', '07:00', '17:00');
INSERT INTO BLOOD_BANK_PHONE (bank_id, phone) VALUES ('DMLB01', '028 3955 1234');
UPDATE BLOOD_BANK SET close_time = '19:00' WHERE bank_id = 'DMLB01';

INSERT INTO BLOOD_BANK (bank_id, bank_name, location, open_time, close_time)
VALUES ('DMLB99', 'Temporary Mobile Unit', 'Thu Duc City, HCMC', '08:00', '12:00');
INSERT INTO BLOOD_BANK_PHONE (bank_id, phone) VALUES ('DMLB99', '0909 000 999');
DELETE FROM BLOOD_BANK WHERE bank_id = 'DMLB99';      -- phone row goes with it (ON DELETE CASCADE)

-- ---------------------------------------------------------------------------
-- STAFF (recursive manager_id)
-- ---------------------------------------------------------------------------
INSERT INTO STAFF (staff_id, bank_id, full_name, role, manager_id)
VALUES ('DMLS01', 'DMLB01', 'Tran Thi Mai', 'Manager', NULL),
       ('DMLS02', 'DMLB01', 'Le Van Hung', 'Technician', 'DMLS01'),
       ('DMLS03', 'DMLB01', 'Pham Ngoc Anh', 'Receptionist', 'DMLS01');
UPDATE STAFF SET role = 'Nurse' WHERE staff_id = 'DMLS03';
DELETE FROM STAFF WHERE staff_id = 'DMLS03';

-- ---------------------------------------------------------------------------
-- HOSPITAL (+ phone)
-- ---------------------------------------------------------------------------
INSERT INTO HOSPITAL (hospital_id, hospital_name, address)
VALUES ('DMLH01', 'Nhan Dan 115 Hospital', '527 Su Van Hanh, District 10, HCMC');
INSERT INTO HOSPITAL_PHONE (hospital_id, phone) VALUES ('DMLH01', '028 3865 4249');
UPDATE HOSPITAL SET hospital_name = 'People''s Hospital 115' WHERE hospital_id = 'DMLH01';

INSERT INTO HOSPITAL (hospital_id, hospital_name, address)
VALUES ('DMLH99', 'Closed Clinic', 'Unknown');
DELETE FROM HOSPITAL WHERE hospital_id = 'DMLH99';

-- ---------------------------------------------------------------------------
-- DONOR (+ phones)
-- ---------------------------------------------------------------------------
INSERT INTO DONOR (donor_id, full_name, blood_group, rh_factor, address, date_of_birth)
VALUES ('DMLD01', 'Nguyen Van An', 'AB', '-', '12 Le Loi, District 1, HCMC', '1998-04-12'),
       ('DMLD99', 'Duplicate Entry', 'O', '+', 'Typo address', '2000-01-01');
INSERT INTO DONOR_PHONE (donor_id, phone) VALUES ('DMLD01', '0903 111 222'), ('DMLD01', '0283 888 777');
UPDATE DONOR SET address = '45 Pasteur, District 3, HCMC' WHERE donor_id = 'DMLD01';
DELETE FROM DONOR WHERE donor_id = 'DMLD99';          -- allowed: no donation history

-- ---------------------------------------------------------------------------
-- DONATION_EVENT and SCREENING_TEST
-- ---------------------------------------------------------------------------
INSERT INTO DONATION_EVENT (event_id, donor_id, bank_id, donation_date, volume_ml)
VALUES ('DMLE01', 'DMLD01', 'DMLB01', @today, 350);   -- screening_result defaults to 'Pending'
UPDATE DONATION_EVENT SET volume_ml = 450 WHERE event_id = 'DMLE01';  -- allowed while Pending

-- Five negative tests; the trigger then derives screening_result = 'Passed'.
INSERT INTO SCREENING_TEST (event_id, test_type, result, test_date) VALUES
    ('DMLE01', 'HIV', 'Negative', @today), ('DMLE01', 'HBsAg', 'Negative', @today),
    ('DMLE01', 'HCV', 'Negative', @today), ('DMLE01', 'Syphilis', 'Negative', @today);
DELETE FROM SCREENING_TEST WHERE event_id = 'DMLE01' AND test_type = 'Syphilis';  -- allowed while Pending
INSERT INTO SCREENING_TEST (event_id, test_type, result, test_date) VALUES
    ('DMLE01', 'Syphilis', 'Negative', @today), ('DMLE01', 'Malaria', 'Negative', @today);
SELECT event_id, screening_result FROM DONATION_EVENT WHERE event_id = 'DMLE01';

-- ---------------------------------------------------------------------------
-- BLOOD_UNIT
-- ---------------------------------------------------------------------------
INSERT INTO BLOOD_UNIT (bank_id, unit_id, event_id, component_type, collection_date, expiry_date)
VALUES ('DMLB01', 'DMLU01', 'DMLE01', 'Whole Blood', @today, @today + INTERVAL 35 DAY),
       ('DMLB01', 'DMLU02', 'DMLE01', 'Whole Blood', @today, @today + INTERVAL 35 DAY),
       ('DMLB01', 'DMLU03', 'DMLE01', 'Plasma',      @today, @today + INTERVAL 365 DAY),
       ('DMLB01', 'DMLU04', 'DMLE01', 'Platelets',   @today, @today + INTERVAL 5 DAY);
-- Status changes go through the procedure, which checks that the staff member works at the bank.
CALL d309_discard_unit('DMLB01', 'DMLU04', 'DMLS02');
DELETE FROM BLOOD_UNIT WHERE bank_id = 'DMLB01' AND unit_id = 'DMLU03';   -- never issued, so no FK blocks it

-- ---------------------------------------------------------------------------
-- REQUEST
-- ---------------------------------------------------------------------------
INSERT INTO `REQUEST` (request_id, hospital_id, blood_group, rh_factor, component_type,
                       quantity_needed, urgency_level, request_date)
VALUES ('DMLR01', 'DMLH01', 'AB', '-', 'Whole Blood', 2, 'High', @today),
       ('DMLR02', 'DMLH01', 'AB', '-', 'Whole Blood', 1, 'Low', @today),
       ('DMLR99', 'DMLH01', 'O', '+', 'Plasma', 1, 'Low', @today);
UPDATE `REQUEST` SET urgency_level = 'Critical' WHERE request_id = 'DMLR01';
DELETE FROM `REQUEST` WHERE request_id = 'DMLR99';    -- allowed: nothing issued yet

-- ---------------------------------------------------------------------------
-- TRANSACTION 1 (COMMIT): issue two units against one request.
-- Touches ISSUE_RECORD (insert), BLOOD_UNIT (status -> Issued) and REQUEST
-- (status -> Fulfilled) as one unit of work.
-- ---------------------------------------------------------------------------
START TRANSACTION;
    CALL d309_issue_unit('DMLI01', 'DMLR01', 'DMLB01', 'DMLU01', 'DMLS02');
    CALL d309_issue_unit('DMLI02', 'DMLR01', 'DMLB01', 'DMLU02', 'DMLS02');
COMMIT;

SELECT r.request_id, r.status, COUNT(i.issue_id) AS issued
FROM `REQUEST` AS r LEFT JOIN ISSUE_RECORD AS i ON i.request_id = r.request_id
WHERE r.request_id = 'DMLR01' GROUP BY r.request_id, r.status;

-- ---------------------------------------------------------------------------
-- TRANSACTION 2 (ROLLBACK): register a donor with two phone numbers, then cancel.
-- In the application the same pattern runs automatically: any error inside the
-- unit of work calls Connection.rollback(), so no half-saved donor remains.
-- ---------------------------------------------------------------------------
START TRANSACTION;
    INSERT INTO DONOR (donor_id, full_name, blood_group, rh_factor, address, date_of_birth)
    VALUES ('DMLD02', 'Le Thi Binh', 'B', '+', '9 Tran Hung Dao, District 5, HCMC', '1995-09-09');
    INSERT INTO DONOR_PHONE (donor_id, phone) VALUES ('DMLD02', '0912 345 678'), ('DMLD02', '0283 222 333');
    SELECT COUNT(*) AS rows_inside_transaction FROM DONOR_PHONE WHERE donor_id = 'DMLD02';
ROLLBACK;

SELECT COUNT(*) AS donor_rows_after_rollback FROM DONOR WHERE donor_id = 'DMLD02';
