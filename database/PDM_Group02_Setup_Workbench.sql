-- PDM GROUP 02 | MYSQL WORKBENCH SETUP | 14/11/2026
-- Baseline: 12 tables, 57 columns. MySQL Server 8.0.46.
-- Sheet: https://docs.google.com/spreadsheets/d/1X1iE0wYwKcnhw66ZnQz6dabMXmqYn8rZbz-dnuRe4aA/edit
-- Sources: selected g2_fixed_20261112.zip + the approved Q12 view.
--
-- CACH CHAY:
-- 1. Mo file nay trong MySQL Workbench va ket noi MySQL Server.
-- 2. Chay toan bo file (Ctrl+Shift+Enter), khong chi chay mot dong DELIMITER.
-- 3. Refresh SCHEMAS; chon blood_bank_group2_d3.
-- 4. Result grid cuoi file: 12 tables, 57 columns, 20 triggers,
--    7 procedures, 1 view va 1 scheduled event.
--
-- File khoi tao database TRONG, khong nap sample data.
-- CREATE TABLE IF NOT EXISTS khong thay doi cau truc bang da ton tai.
-- Cai lai trigger/procedure khi ung dung dang dung ghi du lieu.
-- Neu can seed 2.000 dong cu: dung rebuild.sql trong ZIP fixed cu,
-- sau do chay file nay de bo sung VIEW (giu nguyen cac dong du lieu).
-- Seed lich su cua ZIP phai duoc nap truoc khi cai trigger nghiep vu.
--
-- Backend goi d309_issue_unit / d309_discard_unit va quan ly COMMIT/ROLLBACK.
-- Tai khoan app can EXECUTE tren procedure duoc dung va quyen cot phu hop;
-- trang thai dan xuat duoc cap nhat qua luong nghiep vu da khai bao.
-- Event het han chi tu chay neu event_scheduler = ON. File khong doi global.
-- Co the goi CALL d309_expire_units(); de cap nhat het han khi can.

-- ============================================================
-- PHAN 1. DATABASE + 12 TABLES + PK/FK/UNIQUE/CHECK + INDEX
-- ============================================================
CREATE DATABASE IF NOT EXISTS blood_bank_group2_d3
    DEFAULT CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_as_cs;

USE blood_bank_group2_d3;

CREATE TABLE IF NOT EXISTS DONOR (
    donor_id VARCHAR(20) NOT NULL,
    full_name VARCHAR(150) NOT NULL,
    blood_group VARCHAR(2) NOT NULL,
    rh_factor CHAR(1) NOT NULL,
    address VARCHAR(255) NOT NULL,
    date_of_birth DATE NOT NULL,
    PRIMARY KEY (donor_id),
    CONSTRAINT chk_donor_blood_group CHECK (blood_group IN ('A', 'B', 'AB', 'O')),
    CONSTRAINT chk_donor_rh_factor CHECK (rh_factor IN ('+', '-'))
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS BLOOD_BANK (
    bank_id VARCHAR(20) NOT NULL,
    bank_name VARCHAR(150) NOT NULL,
    location VARCHAR(255) NOT NULL,
    open_time TIME NOT NULL,
    close_time TIME NOT NULL,
    PRIMARY KEY (bank_id),
    CONSTRAINT chk_bank_hours CHECK (close_time > open_time)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS HOSPITAL (
    hospital_id VARCHAR(20) NOT NULL,
    hospital_name VARCHAR(150) NOT NULL,
    address VARCHAR(255) NOT NULL,
    PRIMARY KEY (hospital_id)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS DONOR_PHONE (
    donor_id VARCHAR(20) NOT NULL,
    phone VARCHAR(25) NOT NULL,
    PRIMARY KEY (donor_id, phone),
    CONSTRAINT fk_donor_phone_donor FOREIGN KEY (donor_id)
        REFERENCES DONOR (donor_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS BLOOD_BANK_PHONE (
    bank_id VARCHAR(20) NOT NULL,
    phone VARCHAR(25) NOT NULL,
    PRIMARY KEY (bank_id, phone),
    CONSTRAINT fk_blood_bank_phone_bank FOREIGN KEY (bank_id)
        REFERENCES BLOOD_BANK (bank_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS HOSPITAL_PHONE (
    hospital_id VARCHAR(20) NOT NULL,
    phone VARCHAR(25) NOT NULL,
    PRIMARY KEY (hospital_id, phone),
    CONSTRAINT fk_hospital_phone_hospital FOREIGN KEY (hospital_id)
        REFERENCES HOSPITAL (hospital_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS STAFF (
    staff_id VARCHAR(20) NOT NULL,
    bank_id VARCHAR(20) NOT NULL,
    full_name VARCHAR(150) NOT NULL,
    `role` VARCHAR(20) NOT NULL,
    manager_id VARCHAR(20) NULL DEFAULT NULL,
    PRIMARY KEY (staff_id),
    CONSTRAINT uq_staff_bank UNIQUE (staff_id, bank_id),
    CONSTRAINT chk_staff_role CHECK (`role` IN ('Manager', 'Technician', 'Nurse', 'Receptionist')),
    CONSTRAINT fk_staff_bank FOREIGN KEY (bank_id)
        REFERENCES BLOOD_BANK (bank_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_staff_manager FOREIGN KEY (manager_id)
        REFERENCES STAFF (staff_id) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS DONATION_EVENT (
    event_id VARCHAR(20) NOT NULL,
    donor_id VARCHAR(20) NOT NULL,
    bank_id VARCHAR(20) NOT NULL,
    donation_date DATE NOT NULL,
    volume_ml INT NOT NULL,
    screening_result VARCHAR(10) NOT NULL DEFAULT 'Pending',
    PRIMARY KEY (event_id),
    CONSTRAINT uq_donation_donor_date UNIQUE (donor_id, donation_date),
    CONSTRAINT chk_donation_volume CHECK (volume_ml > 0),
    CONSTRAINT chk_donation_screening CHECK (screening_result IN ('Pending', 'Passed', 'Failed')),
    CONSTRAINT fk_donation_donor FOREIGN KEY (donor_id)
        REFERENCES DONOR (donor_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_donation_bank FOREIGN KEY (bank_id)
        REFERENCES BLOOD_BANK (bank_id) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS `REQUEST` (
    request_id VARCHAR(20) NOT NULL,
    hospital_id VARCHAR(20) NOT NULL,
    blood_group VARCHAR(2) NOT NULL,
    rh_factor CHAR(1) NOT NULL,
    component_type VARCHAR(20) NOT NULL,
    quantity_needed INT NOT NULL,
    urgency_level VARCHAR(10) NOT NULL,
    request_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'Pending',
    PRIMARY KEY (request_id),
    -- Supports the month-window searches on request_date (Q3 and Q10).
    KEY ix_request_date (request_date),
    CONSTRAINT chk_request_blood_group CHECK (blood_group IN ('A', 'B', 'AB', 'O')),
    CONSTRAINT chk_request_rh_factor CHECK (rh_factor IN ('+', '-')),
    CONSTRAINT chk_request_component CHECK (component_type IN ('Whole Blood', 'Plasma', 'Platelets')),
    CONSTRAINT chk_request_quantity CHECK (quantity_needed > 0),
    CONSTRAINT chk_request_urgency CHECK (urgency_level IN ('Low', 'Medium', 'High', 'Critical')),
    CONSTRAINT chk_request_status CHECK (status IN ('Pending', 'Partially Filled', 'Fulfilled')),
    CONSTRAINT fk_request_hospital FOREIGN KEY (hospital_id)
        REFERENCES HOSPITAL (hospital_id) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS SCREENING_TEST (
    event_id VARCHAR(20) NOT NULL,
    test_type VARCHAR(20) NOT NULL,
    result VARCHAR(10) NOT NULL,
    test_date DATE NOT NULL,
    PRIMARY KEY (event_id, test_type),
    CONSTRAINT chk_screening_test_type CHECK (test_type IN ('HIV', 'HBsAg', 'HCV', 'Syphilis', 'Malaria')),
    CONSTRAINT chk_screening_test_result CHECK (result IN ('Positive', 'Negative')),
    CONSTRAINT fk_screening_test_event FOREIGN KEY (event_id)
        REFERENCES DONATION_EVENT (event_id) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS BLOOD_UNIT (
    bank_id VARCHAR(20) NOT NULL,
    unit_id VARCHAR(20) NOT NULL,
    event_id VARCHAR(20) NOT NULL,
    component_type VARCHAR(20) NOT NULL,
    collection_date DATE NOT NULL,
    expiry_date DATE NOT NULL,
    status VARCHAR(12) NOT NULL DEFAULT 'Available',
    PRIMARY KEY (bank_id, unit_id),
    -- Supports the available-stock expiry search and the daily expiry job.
    KEY ix_blood_unit_status_expiry (status, expiry_date),
    CONSTRAINT chk_blood_unit_component CHECK (component_type IN ('Whole Blood', 'Plasma', 'Platelets')),
    CONSTRAINT chk_blood_unit_expiry CHECK (expiry_date > collection_date),
    CONSTRAINT chk_blood_unit_status CHECK (status IN ('Available', 'Reserved', 'Issued', 'Expired', 'Discarded')),
    CONSTRAINT fk_blood_unit_bank FOREIGN KEY (bank_id)
        REFERENCES BLOOD_BANK (bank_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_blood_unit_event FOREIGN KEY (event_id)
        REFERENCES DONATION_EVENT (event_id) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS ISSUE_RECORD (
    issue_id VARCHAR(20) NOT NULL,
    request_id VARCHAR(20) NOT NULL,
    bank_id VARCHAR(20) NOT NULL,
    unit_id VARCHAR(20) NOT NULL,
    issue_date DATE NOT NULL,
    staff_id VARCHAR(20) NOT NULL,
    PRIMARY KEY (issue_id),
    CONSTRAINT uq_issue_unit UNIQUE (bank_id, unit_id),
    CONSTRAINT uq_issue_staff_unit UNIQUE (staff_id, unit_id),
    CONSTRAINT fk_issue_request FOREIGN KEY (request_id)
        REFERENCES `REQUEST` (request_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_issue_unit FOREIGN KEY (bank_id, unit_id)
        REFERENCES BLOOD_UNIT (bank_id, unit_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_issue_staff_bank FOREIGN KEY (staff_id, bank_id)
        REFERENCES STAFF (staff_id, bank_id) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB;

-- Use triggers for the no-self-management rule on the self-referencing FK.
DROP TRIGGER IF EXISTS trg_staff_manager_bi;
DROP TRIGGER IF EXISTS trg_staff_manager_bu;

DELIMITER $$

CREATE TRIGGER trg_staff_manager_bi
BEFORE INSERT ON STAFF
FOR EACH ROW
BEGIN
    IF NEW.manager_id = NEW.staff_id THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A staff member cannot manage themself.';
    END IF;
END$$

CREATE TRIGGER trg_staff_manager_bu
BEFORE UPDATE ON STAFF
FOR EACH ROW
BEGIN
    IF NEW.manager_id = NEW.staff_id THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A staff member cannot manage themself.';
    END IF;
END$$

DELIMITER ;

-- ============================================================
-- PHAN 2. TRIGGER + PROCEDURE + EVENT NGHIEP VU
-- ============================================================
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

-- ============================================================
-- PHAN 3. VIEW Q12: TINH SO UNIT CON THIEU TREN TUNG REQUEST
-- ============================================================
CREATE OR REPLACE VIEW v_request_outstanding AS
SELECT r.request_id, r.blood_group, r.rh_factor,
       r.component_type, r.quantity_needed,
       COUNT(ir.issue_id) AS quantity_filled,
       r.quantity_needed - COUNT(ir.issue_id) AS outstanding_units
FROM REQUEST AS r
LEFT JOIN ISSUE_RECORD AS ir ON ir.request_id = r.request_id
GROUP BY r.request_id, r.blood_group, r.rh_factor,
         r.component_type, r.quantity_needed;

-- ============================================================
-- PHAN 4. KIEM TRA SAU KHI CAI DAT
-- ============================================================
SELECT DATABASE() AS schema_name,
       (SELECT COUNT(*) FROM information_schema.tables
        WHERE table_schema = DATABASE() AND table_type = 'BASE TABLE') AS base_tables,
       (SELECT COUNT(*) FROM information_schema.columns AS c
        JOIN information_schema.tables AS t
          ON t.table_schema = c.table_schema AND t.table_name = c.table_name
        WHERE c.table_schema = DATABASE() AND t.table_type = 'BASE TABLE') AS table_columns,
       (SELECT COUNT(*) FROM information_schema.triggers
        WHERE trigger_schema = DATABASE()) AS triggers_created,
       (SELECT COUNT(*) FROM information_schema.routines
        WHERE routine_schema = DATABASE() AND routine_type = 'PROCEDURE') AS procedures_created,
       (SELECT COUNT(*) FROM information_schema.views
        WHERE table_schema = DATABASE()) AS views_created,
       (SELECT COUNT(*) FROM information_schema.events
        WHERE event_schema = DATABASE()) AS scheduled_events,
       @@global.event_scheduler AS event_scheduler;

SHOW FULL TABLES;
