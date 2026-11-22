-- Group 02 | Date shift, run in rebuild.sql after the seed and before the business rules.
-- The sample data is a snapshot whose reference day is 2026-11-17, the day the results in the
-- report were taken. The queries compare dates with CURRENT_DATE, so a fixed snapshot would drift
-- on a later day: units would expire and "last month" would move, and some queries would return
-- nothing. This step moves every date column by the number of days between the reference day and
-- the day the script runs. The sample is then always "as of today" and the queries keep their rows.
-- MySQL specific: DATEDIFF and a user variable.

USE blood_bank_group2_d3;

SET @shift_days = DATEDIFF(CURRENT_DATE, DATE '2026-11-17');

UPDATE DONOR          SET date_of_birth   = date_of_birth   + INTERVAL @shift_days DAY;
UPDATE DONATION_EVENT SET donation_date   = donation_date   + INTERVAL @shift_days DAY;
UPDATE SCREENING_TEST SET test_date       = test_date       + INTERVAL @shift_days DAY;
UPDATE BLOOD_UNIT     SET collection_date = collection_date + INTERVAL @shift_days DAY,
                          expiry_date     = expiry_date     + INTERVAL @shift_days DAY;
UPDATE `REQUEST`      SET request_date    = request_date    + INTERVAL @shift_days DAY;
UPDATE ISSUE_RECORD   SET issue_date      = issue_date      + INTERVAL @shift_days DAY;
