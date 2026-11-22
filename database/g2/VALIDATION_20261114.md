# Check of the 14/11/2026 package

Query reference date: 14/11/2026. Seed included: 14/11/2026.

Run on MySQL 8.0.46, in a separate test database. The expected row counts below were checked against the scenarios in the fixture; this is evidence that the package works and does not replace the explanation of each query in the final report.

- Rebuilt with `rebuild.sql` twice in a row: PASS. Each time there are 12 tables and 2,000 rows.
- The six business checks in `test_business_rules.sql`: PASS.
- Critical: 22 requests, 7 without an issue record and 15 with one.
- VIEW Q12: total outstanding is 100, equal to total requested minus total issued.

| Query | Expected rows | Actual rows | Result |
|---|---:|---:|---|
| Q1 | 4 | 4 | PASS |
| Q2 | 10 | 10 | PASS |
| Q3 | 25 | 25 | PASS |
| Q4 | 1 | 1 | PASS |
| Q5 | 3 | 3 | PASS |
| Q6 | 4 | 4 | PASS |
| Q7 | 75 | 75 | PASS |
| Q8 | 7 | 7 | PASS |
| Q9 | 15 | 15 | PASS |
| Q10 | 25 | 25 | PASS |
| Q11 | 0 | 0 | PASS |
| Q12 | 24 | 24 | PASS |

Q11 (at that time) was a compatibility audit. A valid seed has no violation, so 0 rows is correct.

The RA expressions and trees cover Q1, Q2, Q3 and Q8, with 4, 10, 25 and 7 rows. Tree images that show row counts must use the same date and dataset as the SQL run.

The generator is the previously fixed version: running it again creates `seed_2000.sql` and `rebuild.sql`. The RA files and tree images are a snapshot and must be updated separately when the date or the data changes.

## Check of the trigger syntax fix

- The fixed package was built on MySQL 8.0.46.
- `fix_staff_triggers.sql` run twice in a row: PASS; it only replaces the two triggers that check that staff do not manage themselves.
- The data checksum of all 12 tables is the same before and after running the patch.
- An INSERT or UPDATE that makes a staff member their own manager is blocked with SQLSTATE 45000.
- The six business checks still PASS; Q8 has 7 rows and Q9 has 15 rows.
- Seed, generator, SQL queries and RA are unchanged from the 14/11 package; only the trigger creation syntax in setup and rebuild was fixed.
