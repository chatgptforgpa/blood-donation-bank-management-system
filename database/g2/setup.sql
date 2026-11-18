-- Group 02 | D3-07 | MySQL 8.0.46
-- Run this file on a clean schema for the first installation.
-- Reruns retain existing tables and their data.
-- DONOR.address is NOT NULL as specified in the current D3-05 draft.
-- Referential actions: phone tables (multivalued attributes) CASCADE with their owner;
-- every other FK is RESTRICT so history (donations, units, issues) can never be lost silently.

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
-- Use DROP then CREATE for compatible trigger setup.
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

SELECT DATABASE() AS schema_name, COUNT(*) AS base_table_count
FROM information_schema.tables
WHERE table_schema = DATABASE() AND table_type = 'BASE TABLE';

SHOW CREATE TABLE ISSUE_RECORD;
