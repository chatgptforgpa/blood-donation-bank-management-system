# Blood Donation and Blood Bank Management System

PDM Group 02: a Java Swing + JDBC desktop application that manages donors, donations, screening, blood inventory, hospital requests and blood issuance.

The application source is the version completed on 16/11/2026, built on the functional version of 15/11/2026. The database keeps the 12 table baseline; the data shipped with it is sample data generated for testing.

## Structure

| Folder | Contents |
|---|---|
| [`bloodbank-app/`](bloodbank-app/) | Java source, Maven, 13 JUnit tests and run instructions |
| [`database/g2/`](database/g2/) | Schema, 2,000 row seed, triggers/procedures/event and the generator |
| [`database/g2/QUERY/`](database/g2/QUERY/) | Q1 to Q12 in MySQL |
| [`database/g2/RA/`](database/g2/RA/) | RA data, expressions and query trees for the 14/11/2026 snapshot |
| [`database/PDM_Group02_Setup_Workbench.sql`](database/PDM_Group02_Setup_Workbench.sql) | Option to create an empty database, including the VIEW |

## Running the application from GitHub

You need Java 17 or later (tested with JDK 25.0.2), Maven, MySQL Connector/J 8.4.0 (downloaded by Maven) and MySQL 8.0.31 or later (tested on MySQL 8.0.46 and 26.10.0). Get the repository with **Code → Download ZIP** or clone it, then extract it.

1. **Build the sample database:** open `database/g2/rebuild.sql` in MySQL Workbench and run the whole file. It drops and recreates only the schema `blood_bank_group2_d3`, including any data already in that schema; use it when you deliberately want to rebuild the sample database. The dates in the sample data move with the day you run it, so the 12 queries return rows on any day.
2. `rebuild.sql` already creates the view `v_request_outstanding`. You can run `database/g2/test_business_rules.sql` and `database/g2/constraint_tests.sql` (with `--force`) to check the rules; the 12 queries are in `database/g2/QUERY/queries.sql`.
3. In the `bloodbank-app` folder, copy `db.properties.sample` to `db.properties` and fill in the MySQL URL, user and password of your machine.
4. Run `build-and-test.cmd`. The script builds the project, runs the 13 JUnit tests and creates `app.jar`.
5. Open `run-app.cmd` to start the application.

The JAR is created on your machine by the build. `db.properties`, JAR files, `target/`, logs and IDE settings are excluded from Git.

On other operating systems, inside `bloodbank-app` you can use:

```sh
mvn clean verify
java -jar target/bloodbank-app.jar
```

If you already have a working database, configure the application to connect to it. See also the [application guide](bloodbank-app/README.md) and the [database guide](database/g2/README.md).

## Test results

- Maven build succeeds; **13 JUnit tests PASS**.
- **37 integration checks against a real MySQL server PASS**, including commit/rollback and two concurrent issuance scenarios.
- Every row of Q1 to Q12 matches the agreed SQL on the columns of the reference SQL.
- The three results above are from **16/11/2026**, on the source before the changes of 17 and 18/11 (Q11 with EXCEPT, deleting donors/requests, English user interface, at least one phone number required).
- The current version was rerun on **18/11/2026** on MySQL 26.10.0: the 24 service integration checks (LiveCheck) PASS, the issuance transaction check (IssuanceTxCheck) PASS, all six columns of `test_business_rules.sql` PASS, 10/10 statements in `constraint_tests.sql` are rejected as expected, and all 12 queries return rows. **The 13 JUnit tests have not been rerun on this version** (the test machine has no Maven); run `mvn clean verify` before submitting.

Details: [`bloodbank-app/VALIDATION.md`](bloodbank-app/VALIDATION.md). Maven runs the 13 JUnit tests automatically; the integration checks are run separately on a test database.

## Collaboration

Create a branch for each change and open a pull request into `main`. State what changed, which business rule or query it affects, and how it was checked. Do not commit credentials or real donor/patient data.
