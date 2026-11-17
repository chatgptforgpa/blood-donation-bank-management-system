-- Group 02 | D3-09 | Business rules for MySQL 8.0.46
-- Fresh setup order: setup.sql, seed_2000.sql, business_rules.sql.
-- Run installation while application writes are paused. This file can be re-run.
-- Application entry points: CALL d309_issue_unit(...) and CALL d309_discard_unit(...).
-- These procedures participate in the caller's transaction. Autocommit is also supported.
-- For application users grant EXECUTE on the entry points and only necessary column
-- privileges. Keep BLOOD_UNIT.status out of direct application UPDATE grants so
-- discards go through the storage-bank staff check.
-- If the global Event Scheduler is OFF, an administrator may run
-- SET GLOBAL event_scheduler = ON; or run CALL d309_expire_units() periodically.

USE blood_bank_group2_d3;

DROP EVENT IF EXISTS d309_expire_units_daily;
DROP TRIGGER IF EXISTS d309_donor_bu;
DROP TRIGGER IF EXISTS d309_staff_bu;
DROP TRIGGER IF EXISTS d309_donation_bi;
DROP TRIGGER IF EXISTS d309_donation_bu;
DROP TRIGGER IF EXISTS d309_screening_bi;
DROP TRIGGER IF EXISTS d309_screening_bu;
DROP TRIGGER IF EXISTS d309_screening_bd;
DROP TRIGGER IF EXISTS d309_screening_ai;
DROP TRIGGER IF EXISTS d309_screening_au;
DROP TRIGGER IF EXISTS d309_screening_ad;
DROP TRIGGER IF EXISTS d309_unit_bi;
DROP TRIGGER IF EXISTS d309_unit_bu;
DROP TRIGGER IF EXISTS d309_request_bi;
DROP TRIGGER IF EXISTS d309_request_bu;
DROP TRIGGER IF EXISTS d309_issue_bi;
DROP TRIGGER IF EXISTS d309_issue_ai;
DROP TRIGGER IF EXISTS d309_issue_bu;
DROP TRIGGER IF EXISTS d309_issue_bd;
DROP PROCEDURE IF EXISTS d309_check_donation_gap;
DROP PROCEDURE IF EXISTS d309_check_screening_edit;
DROP PROCEDURE IF EXISTS d309_get_screening_status;
DROP PROCEDURE IF EXISTS d309_sync_screening;
DROP PROCEDURE IF EXISTS d309_issue_unit;
DROP PROCEDURE IF EXISTS d309_discard_unit;
DROP PROCEDURE IF EXISTS d309_expire_units;

DELIMITER $$

-- BR18: serialize date changes by donor and use current reads, even if the
-- calling transaction has already taken a REPEATABLE READ snapshot.
CREATE PROCEDURE d309_check_donation_gap(
    IN p_donor_id VARCHAR(20), IN p_date DATE, IN p_ignore_event_id VARCHAR(20)
)
BEGIN
    DECLARE v_donor_id VARCHAR(20);
    DECLARE v_conflicts INT;

    SELECT donor_id INTO v_donor_id
    FROM DONOR WHERE donor_id = p_donor_id FOR UPDATE;
    IF v_donor_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Donation donor does not exist.';
    END IF;

    SELECT COUNT(*) INTO v_conflicts
    FROM DONATION_EVENT
    WHERE donor_id = p_donor_id
      AND donation_date BETWEEN p_date - INTERVAL 55 DAY AND p_date + INTERVAL 55 DAY
      AND (p_ignore_event_id IS NULL OR event_id <> p_ignore_event_id)
    FOR SHARE;

    IF v_conflicts > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Donations must be at least 56 days apart.';
    END IF;
END$$

-- BR23/BR39: serialize test changes by event, then derive status from test rows.
CREATE PROCEDURE d309_check_screening_edit(
    IN p_event_id VARCHAR(20), IN p_test_date DATE, IN p_operation CHAR(1)
)
BEGIN
    DECLARE v_donation_date DATE;
    DECLARE v_status VARCHAR(10);

    SELECT donation_date, screening_result INTO v_donation_date, v_status
    FROM DONATION_EVENT WHERE event_id = p_event_id FOR UPDATE;

    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Screening donation event does not exist.';
    END IF;
    IF p_operation <> 'I' AND v_status <> 'Pending' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Final screening tests cannot be changed.';
    END IF;
    IF p_test_date < v_donation_date THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Test date cannot precede the donation date.';
    END IF;
END$$

CREATE PROCEDURE d309_get_screening_status(
    IN p_event_id VARCHAR(20), OUT p_status VARCHAR(10)
)
BEGIN
    DECLARE v_count INT;
    DECLARE v_positive INT;

    SELECT COUNT(*), COUNT(CASE WHEN result = 'Positive' THEN 1 END)
      INTO v_count, v_positive
    FROM SCREENING_TEST WHERE event_id = p_event_id FOR SHARE;

    SET p_status = CASE
        WHEN v_positive > 0 THEN 'Failed'
        WHEN v_count = 5 THEN 'Passed'
        ELSE 'Pending'
    END;
END$$

CREATE PROCEDURE d309_sync_screening(IN p_event_id VARCHAR(20))
BEGIN
    DECLARE v_status VARCHAR(10);
    CALL d309_get_screening_status(p_event_id, v_status);
    UPDATE DONATION_EVENT
    SET screening_result = v_status
    WHERE event_id = p_event_id AND screening_result <> v_status;
END$$

CREATE TRIGGER d309_donor_bu BEFORE UPDATE ON DONOR FOR EACH ROW
BEGIN
    IF NEW.blood_group <> OLD.blood_group OR NEW.rh_factor <> OLD.rh_factor THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A donor blood group and Rh factor are immutable.';
    END IF;
END$$

CREATE TRIGGER d309_staff_bu BEFORE UPDATE ON STAFF FOR EACH ROW
BEGIN
    IF NEW.bank_id <> OLD.bank_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A staff member cannot change banks.';
    END IF;
END$$

CREATE TRIGGER d309_donation_bi BEFORE INSERT ON DONATION_EVENT FOR EACH ROW
BEGIN
    IF NEW.screening_result <> 'Pending' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A new donation must start as Pending.';
    END IF;
    CALL d309_check_donation_gap(NEW.donor_id, NEW.donation_date, NULL);
END$$

CREATE TRIGGER d309_donation_bu BEFORE UPDATE ON DONATION_EVENT FOR EACH ROW
BEGIN
    DECLARE v_test_conflicts INT;
    DECLARE v_status VARCHAR(10);

    IF NEW.event_id <> OLD.event_id OR NEW.donor_id <> OLD.donor_id
       OR NEW.bank_id <> OLD.bank_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Donation identity and source are immutable.';
    END IF;

    IF NEW.donation_date <> OLD.donation_date OR NEW.volume_ml <> OLD.volume_ml THEN
        IF OLD.screening_result <> 'Pending' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Finalized donation details cannot be changed.';
        END IF;
        IF NEW.donation_date <> OLD.donation_date THEN
            CALL d309_check_donation_gap(NEW.donor_id, NEW.donation_date, OLD.event_id);
            SELECT COUNT(*) INTO v_test_conflicts
            FROM SCREENING_TEST
            WHERE event_id = OLD.event_id AND test_date < NEW.donation_date FOR SHARE;
            IF v_test_conflicts > 0 THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Donation date cannot follow a recorded test.';
            END IF;
        END IF;
    END IF;

    IF NEW.screening_result <> OLD.screening_result THEN
        CALL d309_get_screening_status(OLD.event_id, v_status);
        IF OLD.screening_result <> 'Pending' OR NEW.screening_result <> v_status THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Screening status must follow the recorded tests.';
        END IF;
    END IF;
END$$

CREATE TRIGGER d309_screening_bi BEFORE INSERT ON SCREENING_TEST FOR EACH ROW
    CALL d309_check_screening_edit(NEW.event_id, NEW.test_date, 'I')$$

CREATE TRIGGER d309_screening_bu BEFORE UPDATE ON SCREENING_TEST FOR EACH ROW
BEGIN
    IF NEW.event_id <> OLD.event_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A test cannot move to another donation event.';
    END IF;
    CALL d309_check_screening_edit(OLD.event_id, NEW.test_date, 'U');
END$$

CREATE TRIGGER d309_screening_bd BEFORE DELETE ON SCREENING_TEST FOR EACH ROW
    CALL d309_check_screening_edit(OLD.event_id, NULL, 'D')$$

CREATE TRIGGER d309_screening_ai AFTER INSERT ON SCREENING_TEST FOR EACH ROW
    CALL d309_sync_screening(NEW.event_id)$$

CREATE TRIGGER d309_screening_au AFTER UPDATE ON SCREENING_TEST FOR EACH ROW
    CALL d309_sync_screening(NEW.event_id)$$

CREATE TRIGGER d309_screening_ad AFTER DELETE ON SCREENING_TEST FOR EACH ROW
    CALL d309_sync_screening(OLD.event_id)$$

CREATE TRIGGER d309_unit_bi BEFORE INSERT ON BLOOD_UNIT FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(10);
    DECLARE v_donation_date DATE;

    SELECT screening_result, donation_date INTO v_status, v_donation_date
    FROM DONATION_EVENT WHERE event_id = NEW.event_id FOR SHARE;

    IF v_status IS NULL OR v_status <> 'Passed' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A blood unit requires a Passed donation event.';
    END IF;
    IF NEW.collection_date < v_donation_date THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Collection date cannot precede the donation date.';
    END IF;
    IF NEW.status <> 'Available' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A new blood unit must start as Available.';
    END IF;
END$$

CREATE TRIGGER d309_unit_bu BEFORE UPDATE ON BLOOD_UNIT FOR EACH ROW
BEGIN
    DECLARE v_issue_count INT;

    IF NEW.bank_id <> OLD.bank_id OR NEW.unit_id <> OLD.unit_id
       OR NEW.event_id <> OLD.event_id OR NEW.component_type <> OLD.component_type
       OR NEW.collection_date <> OLD.collection_date OR NEW.expiry_date <> OLD.expiry_date THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Blood unit identity, source, component and dates are immutable.';
    END IF;

    IF NEW.status <> OLD.status THEN
        CASE
            WHEN OLD.status = 'Available' AND NEW.status = 'Issued' THEN
                SELECT COUNT(*) INTO v_issue_count
                FROM ISSUE_RECORD WHERE bank_id = OLD.bank_id AND unit_id = OLD.unit_id FOR SHARE;
                IF v_issue_count <> 1 THEN
                    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Issued status requires an issue record.';
                END IF;
            WHEN OLD.status = 'Available' AND NEW.status = 'Expired' THEN
                IF OLD.expiry_date >= DATE(UTC_TIMESTAMP() + INTERVAL 7 HOUR) THEN
                    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'The blood unit has not expired.';
                END IF;
            WHEN OLD.status IN ('Available', 'Expired') AND NEW.status = 'Discarded' THEN
                SET NEW.status = 'Discarded';
            ELSE
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'This blood unit status transition is not permitted.';
        END CASE;
    END IF;
END$$

CREATE TRIGGER d309_request_bi BEFORE INSERT ON `REQUEST` FOR EACH ROW
BEGIN
    IF NEW.status <> 'Pending' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A new request must start as Pending.';
    END IF;
END$$

CREATE TRIGGER d309_request_bu BEFORE UPDATE ON `REQUEST` FOR EACH ROW
BEGIN
    DECLARE v_count INT;
    DECLARE v_status VARCHAR(20);

    IF NEW.request_id <> OLD.request_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Request identity is immutable.';
    END IF;

    IF NEW.status <> OLD.status OR NEW.hospital_id <> OLD.hospital_id
       OR NEW.blood_group <> OLD.blood_group OR NEW.rh_factor <> OLD.rh_factor
       OR NEW.component_type <> OLD.component_type OR NEW.quantity_needed <> OLD.quantity_needed
       OR NEW.request_date <> OLD.request_date THEN
        SELECT COUNT(*) INTO v_count
        FROM ISSUE_RECORD WHERE request_id = OLD.request_id FOR SHARE;

        IF v_count > 0 AND (
            NEW.hospital_id <> OLD.hospital_id OR NEW.blood_group <> OLD.blood_group
            OR NEW.rh_factor <> OLD.rh_factor OR NEW.component_type <> OLD.component_type
            OR NEW.quantity_needed <> OLD.quantity_needed OR NEW.request_date <> OLD.request_date
        ) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Request details are locked after the first issue.';
        END IF;

        SET v_status = CASE
            WHEN v_count = 0 THEN 'Pending'
            WHEN v_count < NEW.quantity_needed THEN 'Partially Filled'
            ELSE 'Fulfilled'
        END;
        IF NEW.status <> v_status THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Request status must follow the issued quantity.';
        END IF;
    END IF;
END$$

-- BR17/19/20/21/22/32/38/43: lock request first and the full unit key second.
-- The request lock serializes its issued count; the unit lock prevents reuse.
CREATE TRIGGER d309_issue_bi BEFORE INSERT ON ISSUE_RECORD FOR EACH ROW
BEGIN
    DECLARE v_quantity INT;
    DECLARE v_issued_count INT;
    DECLARE v_request_group VARCHAR(2);
    DECLARE v_request_rh CHAR(1);
    DECLARE v_request_component VARCHAR(20);
    DECLARE v_request_date DATE;
    DECLARE v_unit_event_id VARCHAR(20);
    DECLARE v_unit_group VARCHAR(2);
    DECLARE v_unit_rh CHAR(1);
    DECLARE v_unit_component VARCHAR(20);
    DECLARE v_unit_status VARCHAR(12);
    DECLARE v_collection_date DATE;
    DECLARE v_expiry_date DATE;
    DECLARE v_today DATE;

    SELECT quantity_needed, blood_group, rh_factor, component_type, request_date
      INTO v_quantity, v_request_group, v_request_rh, v_request_component, v_request_date
    FROM `REQUEST` WHERE request_id = NEW.request_id FOR UPDATE;

    IF v_quantity IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Issue request does not exist.';
    END IF;

    SELECT event_id, component_type, status, collection_date, expiry_date
      INTO v_unit_event_id, v_unit_component, v_unit_status, v_collection_date, v_expiry_date
    FROM BLOOD_UNIT WHERE bank_id = NEW.bank_id AND unit_id = NEW.unit_id FOR UPDATE;

    IF v_unit_status IS NULL OR v_unit_status <> 'Available' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'The blood unit must exist and be Available.';
    END IF;

    SELECT COUNT(*) INTO v_issued_count
    FROM ISSUE_RECORD WHERE request_id = NEW.request_id FOR SHARE;
    IF v_issued_count >= v_quantity THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'The request is already fulfilled.';
    END IF;

    SET v_today = DATE(UTC_TIMESTAMP() + INTERVAL 7 HOUR);
    IF NOT (NEW.issue_date <=> v_today) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Issue date must match the current Vietnam business date.';
    END IF;
    IF v_today < v_request_date OR v_today < v_collection_date OR v_today > v_expiry_date THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Issue date is outside the permitted date range.';
    END IF;

    SELECT d.blood_group, d.rh_factor INTO v_unit_group, v_unit_rh
    FROM DONATION_EVENT AS de JOIN DONOR AS d ON d.donor_id = de.donor_id
    WHERE de.event_id = v_unit_event_id FOR SHARE;
    IF v_unit_group <> v_request_group OR v_unit_rh <> v_request_rh
       OR v_unit_component <> v_request_component THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Blood group, Rh and component must match the request.';
    END IF;
    -- The D3-07 composite FK verifies the staff and unit belong to the same bank.
END$$

CREATE TRIGGER d309_issue_ai AFTER INSERT ON ISSUE_RECORD FOR EACH ROW
BEGIN
    DECLARE v_issued_count INT;
    SELECT COUNT(*) INTO v_issued_count
    FROM ISSUE_RECORD WHERE request_id = NEW.request_id FOR SHARE;

    UPDATE BLOOD_UNIT SET status = 'Issued'
    WHERE bank_id = NEW.bank_id AND unit_id = NEW.unit_id;

    UPDATE `REQUEST`
    SET status = CASE WHEN v_issued_count = quantity_needed
                      THEN 'Fulfilled' ELSE 'Partially Filled' END
    WHERE request_id = NEW.request_id;
END$$

CREATE TRIGGER d309_issue_bu BEFORE UPDATE ON ISSUE_RECORD FOR EACH ROW
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Issue records cannot be updated.'$$

CREATE TRIGGER d309_issue_bd BEFORE DELETE ON ISSUE_RECORD FOR EACH ROW
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Issue records cannot be deleted.'$$

-- All writes caused by this INSERT belong to one atomic InnoDB statement.
-- When a JDBC transaction is active, the caller owns COMMIT and ROLLBACK.
CREATE PROCEDURE d309_issue_unit(
    IN p_issue_id VARCHAR(20), IN p_request_id VARCHAR(20),
    IN p_bank_id VARCHAR(20), IN p_unit_id VARCHAR(20), IN p_staff_id VARCHAR(20)
)
SQL SECURITY DEFINER
BEGIN
    INSERT INTO ISSUE_RECORD (issue_id, request_id, bank_id, unit_id, issue_date, staff_id)
    VALUES (p_issue_id, p_request_id, p_bank_id, p_unit_id,
            DATE(UTC_TIMESTAMP() + INTERVAL 7 HOUR), p_staff_id);
END$$

CREATE PROCEDURE d309_discard_unit(
    IN p_bank_id VARCHAR(20), IN p_unit_id VARCHAR(20), IN p_staff_id VARCHAR(20)
)
SQL SECURITY DEFINER
BEGIN
    UPDATE BLOOD_UNIT AS u
    JOIN STAFF AS s ON s.bank_id = u.bank_id AND s.staff_id = p_staff_id
    SET u.status = 'Discarded'
    WHERE u.bank_id = p_bank_id AND u.unit_id = p_unit_id
      AND u.status IN ('Available', 'Expired');

    IF ROW_COUNT() <> 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Discard requires storage-bank staff and an Available or Expired unit.';
    END IF;
END$$

CREATE PROCEDURE d309_expire_units()
SQL SECURITY DEFINER
BEGIN
    UPDATE BLOOD_UNIT
    SET status = 'Expired'
    WHERE status = 'Available' AND expiry_date < DATE(UTC_TIMESTAMP() + INTERVAL 7 HOUR);
END$$

DELIMITER ;

-- Schedule the first run at the next midnight in Vietnam (UTC+07:00).
SET @d309_previous_time_zone = @@session.time_zone;
SET SESSION time_zone = '+07:00';
CREATE EVENT d309_expire_units_daily
    ON SCHEDULE EVERY 1 DAY STARTS CURRENT_DATE + INTERVAL 1 DAY
    ENABLE
    DO CALL d309_expire_units();
SET SESSION time_zone = @d309_previous_time_zone;
SET @d309_previous_time_zone = NULL;

SELECT 'D3-09 installed' AS result,
       (SELECT COUNT(*) FROM information_schema.triggers
        WHERE trigger_schema = DATABASE() AND LEFT(trigger_name, 5) = 'd309_') AS rule_triggers,
       @@global.event_scheduler AS event_scheduler;
