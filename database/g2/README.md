# Group 02 - Database D3

MySQL package for the 12 table baseline. The included seed has exactly 2,000 rows, generated on 14/11/2026. The results in the report use 17/11/2026 as the reference date. When `rebuild.sql` runs, every date column is moved by the number of days between 17/11/2026 and the day it runs (`date_shift.sql`), so on any day the data is "as of today" and all 12 queries return rows.

## Building the sample database

1. Use MySQL 8.0.46 and an account that can create databases, tables, triggers, procedures and events.
2. In MySQL Workbench, open `rebuild.sql` and run the whole file.
3. Check that the result shows 12 tables, a seed total of 2,000 and the message that the business rules are installed.
4. Open `test_business_rules.sql` in a separate tab and run the whole file. The expected result is six PASS columns.
5. Run the whole `rebuild.sql` again, then the smoke test again, to check that the database can be rebuilt.
6. The 12 queries are in `QUERY/queries.sql` (single files: `QUERY/SQL 1.sql` to `SQL 12.sql`). The view `v_request_outstanding` used by Q12 is created in `rebuild.sql`.

`rebuild.sql` drops and recreates only the database `blood_bank_group2_d3`, including all data already in it. It is the entry point for rebuilding the sample database.

The rebuild file is already assembled in order: create tables, load the seed, shift the dates (`date_shift.sql`), install the business rules and the final step (`post_setup.sql`). All setup SQL is in one file so it can be run from the start in Workbench.

## Regenerating the seed (optional)

You do not need to regenerate the seed to run on another day, because `rebuild.sql` shifts the dates itself. Only regenerate it if you want a new dataset; the results in the report will then no longer match. In this folder, install the library and run the generator with Python.

```powershell
python -m pip install -r requirements.txt
python generate_seed_2000.py
```

By default the generator uses today's date in Vietnam and recreates both `seed_2000.sql` and `rebuild.sql`.
To test with a specific date, pass the date as a parameter. For example, to prepare a dataset for 22/11/2026, use the command below.

```powershell
python generate_seed_2000.py --as-of 2026-11-22
```

After regenerating, run `rebuild.sql` and update the expected/actual results of the queries for the same reference date. Time based queries need the same seed and the same reference date for their results to be compared.

The `RA` folder in this package is a snapshot of 14/11/2026, with the data `Blood_Bank.txt`, four expressions Q1/Q2/Q3/Q8 and four query trees (drawn with RelaX). The generator only recreates the seed and the rebuild file; with another date, the RA data, the dates in the expressions and the tree/result images must be updated too.

The seed contains historical issue records and precomputed statuses. The rebuild file loads them before installing the business triggers used for day to day operations.

## Submitted scripts (D5)

Section 2.3 "What to submit" of the assignment only requires **two scripts**: one that builds the database from an empty server, and a second one with the 12 commented queries. The assignment also requires INSERT/UPDATE/DELETE statements, a COMMIT/ROLLBACK transaction and constraint tests, but does not require separate files for them. The last column shows which file meets which requirement.

| File | Contents | Assignment (section 2.3) |
|---|---|---|
| `rebuild.sql` | One script run from start to end: DROP + CREATE database, 12 tables, seed, triggers/procedures/event, indexes, view `v_request_outstanding`, then a call to `d309_expire_units()`. Can be run twice in a row. | **Required**: database build script |
| `QUERY/queries.sql` | The 12 queries in one file, each with its English question and the SQL technique used. `QUERY/SQL 1.sql` … `SQL 12.sql` are kept for running one at a time. | **Required**: second script |
| `dml_transactions.sql` | INSERT/UPDATE/DELETE on each main table, one COMMIT transaction (issuing 2 units) and one ROLLBACK transaction. Run once, right after `rebuild.sql`. | Required content; a separate file is the team's choice |
| `constraint_tests.sql` | 10 statements that must be rejected (duplicate key, missing foreign key, CHECK, trigger). Run with `mysql --force`. | The assignment requires the tests, not the file; submitted as evidence |
| `setup.sql`, `seed_2000.sql`, `date_shift.sql`, `business_rules.sql`, `post_setup.sql` | The five parts that `generate_seed_2000.py` joins into `rebuild.sql`. | Not needed separately: already inside `rebuild.sql` |
| `test_business_rules.sql` | Smoke test of six business rules, ending with the integrity check "issued with the wrong blood group" (always 0 rows). | Optional: extra test by the team |

DBMS tested: MySQL 8.0.46 and MySQL Community Server 26.10.0 (macOS). Q11 uses `EXCEPT`, which needs MySQL 8.0.31 or later.

## Changes of 18/11/2026

- `date_shift.sql` added to `rebuild.sql`, run after the seed and before the business rules. Before, the seed was a fixed snapshot, so running on another day gave empty results: from 19/11 Q6 was empty, from 25/11 Q1 was empty, and in December Q3 and Q10 were empty. Now every date column is moved by `DATEDIFF(CURRENT_DATE, '2026-11-17')`.
- The database was rebuilt and the 12 queries were run for every day from 18/11/2026 to 30/06/2027 (simulating the date with `SET timestamp`): no errors, no empty query. 10 queries keep the same row count; Q3 and Q10 work on calendar months, so their row counts change with the day of the month (at least 6 and 9 rows).
- `generate_seed_2000.py` has a new `--reference-date` option. The current data matches `--as-of 2026-11-14 --reference-date 2026-11-17`. Faker does not fix the names, so regenerating gives different names and addresses.
- Q9 is an 8 table join (7 INNER JOINs); its comment in `queries.sql` was corrected.
- The four query trees Q1, Q2, Q3, Q8 were redrawn with RelaX (same style, same font size) and saved as `RA/tree - 1.png` … `tree - 8.png`, replacing the old `result - *.jpg` images. The row count at each node matches the MySQL result.

## Changes of 17/11/2026

- Q11 is now a set query with `EXCEPT`: the blood group/Rh/component combinations that are still requested but have no usable unit left. The old Q11 was always empty, so it did not meet "every query must return rows"; that check moved to `test_business_rules.sql`.
- The phone tables (multivalued attributes) use `ON DELETE CASCADE ON UPDATE CASCADE`; the other foreign keys keep `RESTRICT`.
- Added `CHECK (close_time > open_time)` on `BLOOD_BANK` and the index `ix_request_date` for Q3/Q10.
- `rebuild.sql` also creates the Q12 view and marks overdue units as expired when the database is rebuilt after the snapshot date (`post_setup.sql`).

## Data for the Query Matrix

- There are 22 Critical requests: 15 with issue records and 7 without.
- Q6 keeps the AB+ Platelets scenario of the original Query Matrix and lists the matching usable units. `S2KR0077` is a matching Critical request that illustrates this scenario.
- Q8 uses the Critical requests without issue records. Q9 uses the Critical requests that have issue records.
- Q11 (`EXCEPT`) returns the combinations that are still needed but out of stock; on the 14/11/2026 seed these are B+ Platelets and O+ Platelets.
- Q7 computes the share of Expired units among all units per bank and component, with the formula of the original query.

## Connecting the backend

The backend calls `d309_issue_unit` and `d309_discard_unit` with the parameters declared in `business_rules.sql`. When JDBC transactions are used, the backend owns commit/rollback.

Man sets up the database account used by the app as described at the top of `business_rules.sql`. The app account needs EXECUTE on the procedures it uses and read/write rights on the columns it needs. Updates of `BLOOD_UNIT.status` must go through the procedures so that discarding checks that the staff member belongs to the same bank. The real account details are configured by the team during integration.

For automatic expiry, check `SHOW VARIABLES LIKE 'event_scheduler';`. If the Event Scheduler is OFF, the administrator turns it on or schedules a daily call to `d309_expire_units()` in the chosen way.

## Changes in this package

- Restored the generator that creates Critical requests both with and without issue records, so Q8/Q9 have suitable sample data.
- The generator also writes `rebuild.sql`, so one run creates the database, the seed and the business mechanisms. This entry point can be run from the start twice.
- `requirements.txt` records the Faker version instead of packaging a local Python environment.
- `README.md` explains how to rebuild, how to generate a seed for a given date and the backend integration steps.
- Kept the 12 SQL queries and four RA expressions from `g2 (4)`; the only fix is the alias `eS` to `e` in Q4.
- Synchronized the RA data with the 14/11/2026 seed and recreated the Q8 query tree with its result of seven unissued requests.
- See `VALIDATION_20261114.md` for the MySQL check and the row counts of Q1 to Q12.

## Trigger syntax fix

The two triggers on STAFF use `DROP TRIGGER IF EXISTS` and then `CREATE TRIGGER`, with the same checks. MySQL supports `CREATE TRIGGER IF NOT EXISTS` from 8.0.29; this version avoids that syntax.

If the database already has the STAFF table, open `fix_staff_triggers.sql` and run the whole file to replace the two triggers. The patch does not drop tables or reload the seed. Use `rebuild.sql` only when building the sample database from scratch.
