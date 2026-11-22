# Test results of 16/11/2026

Source: `bloodbank-app-fixed-20261115.zip`. The 16/11 package adds the built JAR and updates the documents; the Java source, POM and run files of the 15/11 version are unchanged. The database baseline is still 12 tables.

The source on GitHub is the tested source. The JAR of the built package is recreated with `build-and-test.cmd` after downloading the source; the JAR and local account settings are excluded from Git.

## Build and JUnit

- Maven 3.9.9, JDK 25.0.2, compiled with release Java 17.
- `mvn verify`: BUILD SUCCESS.
- **13 JUnit tests PASS, 0 failures, 0 errors, 0 skipped**: seven inventory date limits, one test that runs the nine existing transaction assertions, four data load/count tests and one donor reset test.
- The transaction test uses a fake JDBC layer; the UI tests run headless. They run inside Maven and do not need MySQL.
- `app.jar` is copied from the successfully built `target/bloodbank-app.jar`. The JAR contains MySQL Connector/J 8.4.0 and the needed dependencies, declares Main-Class `bb.ui.App` and the JDBC driver service.
- All 31 application classes in the JAR match the build output byte for byte, with Java 17 class version. No database account is included.

## Real MySQL

Separate MySQL 8.0.46 test server, seed of 14/11/2026, run on 16/11/2026. **37 integration checks** were run and all PASS, including:

- Browsing 250 donors, 200 donation events, 180 units and 85 requests.
- Q1 to Q12 compared on every result row using the columns of the approved SQL; row order is ignored and the number of times each row appears is kept. The results match, not only the row counts. Q8 and Q9 have extra display columns in the app; the comparison uses the columns of the reference SQL.
- Q7 shows the manager ID and name; the wastage formula keeps the correct counts.
- Registering/editing a donor with phones; a name with a single quote is handled by parameters.
- A new donor can donate for the first time; the 56 day gap is still blocked by the database.
- A unit cannot be entered before the event is Passed; five Negative results make the event Passed.
- An optional expiry two days after collection is stored exactly; an expiry equal to collection or left empty is rejected.
- A batch whose second unit has the wrong component leaves no issue record and no half updated status.
- A valid batch commits all units and the request status; a Fulfilled request cannot be issued more.
- Two issuances of the same unit, or taking the last slot of a request: exactly one commits.
- Discarding through the procedure still works.

| Report | Rows when run on 16/11 with the 14/11 seed |
|---|---:|
| Q1 | 4 |
| Q2 | 10 |
| Q3 | 25 |
| Q4 | 1 |
| Q5 | 3 |
| Q6 | 4 |
| Q7 | 75 |
| Q8 | 7 |
| Q9 | 15 |
| Q10 | 25 |
| Q11 | 0 |
| Q12 | 24 |
| Usable stock | 97 |

Row counts can change when the reference date or the data changes. The reports were compared before adding the records used to test the functions.

Q6 uses the AB+ Platelets scope of the agreed question. Q11 (at that time) looked for issues with the wrong blood group, Rh or component; 0 rows is the right result when the data has no violation.

## Scope of the interface and packaging checks

- The UI tests run headless: donor reset, browse row counts, dropping results or errors of stale read requests. The tests use a latch to control the completion order.
- The 16/11 check did not rerun the whole interface by hand. The production UI files are the same as the 14/11 version, which was checked visually before.
- The new package has `app.jar`, `run-app.cmd`, `build-and-test.cmd`, the source and `db.properties.sample`. Opening the app needs Java 17 or later and the team's MySQL connection settings; running the included JAR does not need Maven.
- Maven only runs the 13 JUnit tests. The 37 MySQL checks are done with a separate harness on a test database and are not part of the default `mvn verify`.

The integration checks were run on a separate test database; no database in use was dropped or changed. The delivered package contains no account settings of the test environment.
