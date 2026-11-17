-- Replace only the two STAFF manager guards on an existing database.
-- Run the entire file in MySQL Workbench so DELIMITER is applied.
USE blood_bank_group2_d3;

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

SELECT TRIGGER_NAME, ACTION_TIMING, EVENT_MANIPULATION
FROM information_schema.TRIGGERS
WHERE TRIGGER_SCHEMA = DATABASE()
  AND TRIGGER_NAME IN ('trg_staff_manager_bi', 'trg_staff_manager_bu');
