-- Group 02 | Post-setup steps, run last in rebuild.sql.
-- 1) The view used by Q12 and by the application, so it exists right after a rebuild.
-- 2) Expire any Available unit whose expiry date has already passed. The seed is a
--    snapshot of a fixed date; when the script is run on a later day this brings the
--    derived BLOOD_UNIT.status up to date through the same procedure the daily event uses.

USE blood_bank_group2_d3;

CREATE OR REPLACE VIEW v_request_outstanding AS
SELECT r.request_id, r.blood_group, r.rh_factor,
       r.component_type, r.quantity_needed,
       COUNT(ir.issue_id) AS quantity_filled,
       r.quantity_needed - COUNT(ir.issue_id) AS outstanding_units
FROM REQUEST AS r
LEFT JOIN ISSUE_RECORD AS ir ON ir.request_id = r.request_id
GROUP BY r.request_id, r.blood_group, r.rh_factor,
         r.component_type, r.quantity_needed;

CALL d309_expire_units();

SELECT 'Rebuild finished' AS result,
       (SELECT COUNT(*) FROM information_schema.tables
        WHERE table_schema = DATABASE() AND table_type = 'BASE TABLE') AS base_tables,
       (SELECT COUNT(*) FROM information_schema.views
        WHERE table_schema = DATABASE()) AS views;
