-- Group 02 | D3-09 | Workbench smoke test
-- Run after business_rules.sql, in a separate tab with no transaction in progress.
-- All fixture rows are rolled back. PASS results are returned in one result grid.

USE blood_bank_group2_d3;
DROP PROCEDURE IF EXISTS d309_smoke_test;
DELIMITER $$

CREATE PROCEDURE d309_smoke_test()
BEGIN
    DECLARE v_tag VARCHAR(14);
    DECLARE v_bank, v_other_bank, v_donor, v_other_donor, v_staff, v_other_staff,
            v_hospital, v_event, v_gap_event, v_fail_event, v_request, v_mismatch,
            v_issue, v_today_unit, v_next_unit, v_old_unit, v_extra_unit VARCHAR(20);
    DECLARE v_today, v_collection DATE;
    DECLARE v_status VARCHAR(20);
    DECLARE v_rejected BOOLEAN DEFAULT FALSE;
    DECLARE v_count INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET v_tag = CONCAT('T309', LEFT(REPLACE(UUID(), '-', ''), 10));
    SET v_bank = CONCAT(v_tag, 'B1'), v_other_bank = CONCAT(v_tag, 'B2'),
        v_donor = CONCAT(v_tag, 'D1'), v_other_donor = CONCAT(v_tag, 'D2'),
        v_staff = CONCAT(v_tag, 'S1'), v_other_staff = CONCAT(v_tag, 'S2'),
        v_hospital = CONCAT(v_tag, 'H'), v_event = CONCAT(v_tag, 'E1'),
        v_gap_event = CONCAT(v_tag, 'E2'), v_fail_event = CONCAT(v_tag, 'E3'),
        v_request = CONCAT(v_tag, 'R1'), v_mismatch = CONCAT(v_tag, 'R2'),
        v_issue = CONCAT(v_tag, 'I1'), v_today_unit = CONCAT(v_tag, 'U1'),
        v_next_unit = CONCAT(v_tag, 'U2'), v_old_unit = CONCAT(v_tag, 'U3'),
        v_extra_unit = CONCAT(v_tag, 'U4');
    SET v_today = DATE(UTC_TIMESTAMP() + INTERVAL 7 HOUR);
    SET v_collection = v_today - INTERVAL 2 DAY;

    START TRANSACTION;

    INSERT INTO DONOR (donor_id, full_name, blood_group, rh_factor, address, date_of_birth)
    VALUES (v_donor, 'Smoke Donor', 'A', '+', 'Smoke Address', '1990-01-01'),
           (v_other_donor, 'Smoke Donor 2', 'O', '-', 'Smoke Address', '1990-01-01');
    INSERT INTO BLOOD_BANK (bank_id, bank_name, location, open_time, close_time)
    VALUES (v_bank, 'Smoke Storage Bank', 'Smoke Address', '08:00:00', '17:00:00'),
           (v_other_bank, 'Smoke Donation Bank', 'Smoke Address', '08:00:00', '17:00:00');
    INSERT INTO STAFF (staff_id, bank_id, full_name, `role`)
    VALUES (v_staff, v_bank, 'Smoke Nurse', 'Nurse'),
           (v_other_staff, v_other_bank, 'Smoke Nurse 2', 'Nurse');
    INSERT INTO HOSPITAL (hospital_id, hospital_name, address)
    VALUES (v_hospital, 'Smoke Hospital', 'Smoke Address');

    INSERT INTO DONATION_EVENT (event_id, donor_id, bank_id, donation_date, volume_ml)
    VALUES (v_event, v_donor, v_other_bank, v_collection, 350),
           (v_fail_event, v_other_donor, v_other_bank, v_collection, 350);
    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLSTATE '45000' SET v_rejected = TRUE;
        INSERT INTO DONATION_EVENT (event_id, donor_id, bank_id, donation_date, volume_ml)
        VALUES (v_gap_event, v_donor, v_other_bank, v_collection - INTERVAL 55 DAY, 350);
    END;
    IF NOT v_rejected THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: the 55-day gap was accepted.';
    END IF;
    INSERT INTO DONATION_EVENT (event_id, donor_id, bank_id, donation_date, volume_ml)
    VALUES (v_gap_event, v_donor, v_other_bank, v_collection - INTERVAL 56 DAY, 350);
    SET v_rejected = FALSE;
    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLSTATE '45000' SET v_rejected = TRUE;
        UPDATE DONATION_EVENT SET donation_date = v_collection - INTERVAL 55 DAY
        WHERE event_id = v_gap_event;
    END;
    IF NOT v_rejected THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: a donation edit broke the 56-day gap.';
    END IF;

    SET v_rejected = FALSE;
    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLSTATE '45000' SET v_rejected = TRUE;
        UPDATE DONATION_EVENT SET screening_result = 'Passed' WHERE event_id = v_event;
    END;
    IF NOT v_rejected THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: a manually forged Passed status was accepted.';
    END IF;

    SET v_rejected = FALSE;
    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLSTATE '45000' SET v_rejected = TRUE;
        INSERT INTO SCREENING_TEST VALUES (v_event, 'HIV', 'Negative', v_collection - INTERVAL 1 DAY);
    END;
    IF NOT v_rejected THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: a test dated before the donation was accepted.';
    END IF;

    INSERT INTO SCREENING_TEST
    VALUES (v_event, 'HIV', 'Negative', v_collection), (v_event, 'HBsAg', 'Negative', v_collection),
           (v_event, 'HCV', 'Negative', v_collection), (v_event, 'Syphilis', 'Negative', v_collection);
    SELECT screening_result INTO v_status FROM DONATION_EVENT WHERE event_id = v_event;
    IF v_status <> 'Pending' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: four negative results must leave a donation Pending.';
    END IF;

    SET v_rejected = FALSE;
    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLSTATE '45000' SET v_rejected = TRUE;
        INSERT INTO BLOOD_UNIT (bank_id, unit_id, event_id, component_type, collection_date, expiry_date)
        VALUES (v_bank, v_today_unit, v_event, 'Plasma', v_collection, v_today);
    END;
    IF NOT v_rejected THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: a unit was accepted from a Pending donation.';
    END IF;

    INSERT INTO SCREENING_TEST VALUES (v_event, 'Malaria', 'Negative', v_collection);
    INSERT INTO SCREENING_TEST VALUES (v_fail_event, 'HIV', 'Negative', v_collection);
    UPDATE SCREENING_TEST SET result = 'Positive' WHERE event_id = v_fail_event AND test_type = 'HIV';
    INSERT INTO SCREENING_TEST VALUES (v_fail_event, 'HBsAg', 'Negative', v_collection);

    SELECT COUNT(*) INTO v_count FROM DONATION_EVENT
    WHERE (event_id = v_event AND screening_result = 'Passed')
       OR (event_id = v_fail_event AND screening_result = 'Failed');
    IF v_count <> 2 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: screening did not derive Passed and Failed.';
    END IF;
    SET v_rejected = FALSE;
    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLSTATE '45000' SET v_rejected = TRUE;
        DELETE FROM SCREENING_TEST WHERE event_id = v_fail_event AND test_type = 'HIV';
    END;
    IF NOT v_rejected THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: a finalized screening test could be deleted.';
    END IF;

    INSERT INTO BLOOD_UNIT (bank_id, unit_id, event_id, component_type, collection_date, expiry_date)
    VALUES (v_bank, v_today_unit, v_event, 'Plasma', v_collection, v_today),
           (v_bank, v_next_unit, v_event, 'Plasma', v_collection, v_today + INTERVAL 1 DAY),
           (v_bank, v_old_unit, v_event, 'Plasma', v_collection, v_today - INTERVAL 1 DAY),
           (v_bank, v_extra_unit, v_event, 'Plasma', v_collection, v_today + INTERVAL 1 DAY);

    INSERT INTO `REQUEST`
        (request_id, hospital_id, blood_group, rh_factor, component_type,
         quantity_needed, urgency_level, request_date)
    VALUES (v_request, v_hospital, 'A', '+', 'Plasma', 2, 'High', v_today),
           (v_mismatch, v_hospital, 'A', '-', 'Plasma', 1, 'High', v_today);

    SET v_rejected = FALSE;
    BEGIN
        DECLARE CONTINUE HANDLER FOR 1452 SET v_rejected = TRUE;
        CALL d309_issue_unit(v_issue, v_request, v_bank, v_today_unit, v_other_staff);
    END;
    IF NOT v_rejected THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: a staff member at another bank could issue the unit.';
    END IF;
    SET v_rejected = FALSE;
    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLSTATE '45000' SET v_rejected = TRUE;
        CALL d309_issue_unit(v_issue, v_request, v_bank, v_old_unit, v_staff);
    END;
    IF NOT v_rejected THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: an expired unit could be issued before the daily job.';
    END IF;
    SET v_rejected = FALSE;
    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLSTATE '45000' SET v_rejected = TRUE;
        CALL d309_issue_unit(v_issue, v_mismatch, v_bank, v_today_unit, v_staff);
    END;
    IF NOT v_rejected THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: a mismatched Rh factor was accepted.';
    END IF;

    SAVEPOINT before_issue;
    CALL d309_issue_unit(v_issue, v_request, v_bank, v_today_unit, v_staff);
    SELECT status INTO v_status FROM `REQUEST` WHERE request_id = v_request;
    IF v_status <> 'Partially Filled' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: first issue did not make the request Partially Filled.';
    END IF;
    SELECT status INTO v_status FROM BLOOD_UNIT WHERE bank_id = v_bank AND unit_id = v_today_unit;
    IF v_status <> 'Issued' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: the issued unit status was not updated.';
    END IF;
    ROLLBACK TO SAVEPOINT before_issue;
    SELECT COUNT(*) INTO v_count FROM ISSUE_RECORD WHERE issue_id = v_issue;
    IF v_count <> 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: rollback left an issue record.';
    END IF;
    SELECT status INTO v_status FROM `REQUEST` WHERE request_id = v_request;
    IF v_status <> 'Pending' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: rollback left the changed request status.';
    END IF;
    SELECT status INTO v_status FROM BLOOD_UNIT WHERE bank_id = v_bank AND unit_id = v_today_unit;
    IF v_status <> 'Available' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: rollback left the changed unit status.';
    END IF;

    CALL d309_expire_units();
    SELECT status INTO v_status FROM BLOOD_UNIT WHERE bank_id = v_bank AND unit_id = v_old_unit;
    IF v_status <> 'Expired' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: expiry job did not expire an overdue unit.';
    END IF;
    CALL d309_discard_unit(v_bank, v_old_unit, v_staff);
    SELECT status INTO v_status FROM BLOOD_UNIT WHERE bank_id = v_bank AND unit_id = v_old_unit;
    IF v_status <> 'Discarded' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: storage-bank staff could not discard the expired unit.';
    END IF;

    CALL d309_issue_unit(v_issue, v_request, v_bank, v_today_unit, v_staff);
    CALL d309_issue_unit(CONCAT(v_tag, 'I2'), v_request, v_bank, v_next_unit, v_staff);
    SELECT status INTO v_status FROM `REQUEST` WHERE request_id = v_request;
    IF v_status <> 'Fulfilled' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: second issue did not make the request Fulfilled.';
    END IF;
    SET v_rejected = FALSE;
    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLSTATE '45000' SET v_rejected = TRUE;
        CALL d309_issue_unit(CONCAT(v_tag, 'I3'), v_request, v_bank, v_extra_unit, v_staff);
    END;
    IF NOT v_rejected THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: a fulfilled request could receive an extra unit.';
    END IF;
    SET v_rejected = FALSE;
    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLSTATE '45000' SET v_rejected = TRUE;
        DELETE FROM ISSUE_RECORD WHERE issue_id = v_issue;
    END;
    IF NOT v_rejected THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'FAIL: an issue record could be deleted.';
    END IF;

    ROLLBACK;
    SELECT 'PASS' AS donation_gap, 'PASS' AS screening, 'PASS' AS issuance_validation,
           'PASS' AS request_status, 'PASS' AS expiry_and_discard, 'PASS' AS rollback;
END$$

DELIMITER ;

CALL d309_smoke_test();
DROP PROCEDURE d309_smoke_test;

-- Integrity check (formerly Q11): units issued with a group, Rh or component that
-- differs from the request. The issue trigger makes this impossible, so the expected
-- result is always 0 rows.
SELECT ir.issue_id, ir.request_id, u.bank_id, u.unit_id
FROM ISSUE_RECORD AS ir
JOIN BLOOD_UNIT AS u ON ir.bank_id = u.bank_id AND ir.unit_id = u.unit_id
JOIN DONATION_EVENT AS e ON e.event_id = u.event_id
JOIN DONOR AS d ON d.donor_id = e.donor_id
JOIN `REQUEST` AS r ON r.request_id = ir.request_id
WHERE d.blood_group <> r.blood_group OR d.rh_factor <> r.rh_factor
   OR u.component_type <> r.component_type;
