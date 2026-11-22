# Blood Bank App Group 02

Package completed on 16/11/2026, from `bloodbank-app-fixed-20261115.zip`. Java Swing, JDBC, 12 table database baseline. This package adds `app.jar` built from exactly the tested source and updates the test documents.

## Running the built version

**If you downloaded the source from GitHub:** you need Java 17 or later and Maven; first run `build-and-test.cmd` in this folder to create `app.jar`, then follow the configuration and start steps below. The JAR is created by the build and excluded from Git by `.gitignore`. The ZIP built on 16/11 already contains the JAR.

1. Extract the ZIP and open the `bloodbank-app` folder.
2. You need Java 17 or later. `app.jar` already includes Connector/J, so running the app does not need Maven.
3. Copy `db.properties.sample` to `db.properties` and fill in the URL, user and password given by the database team.
4. Open `run-app.cmd` or run `java -jar app.jar`. If the configuration is not valid, the app shows a connection dialog.

If the database is already running, the app connects to it directly; do not run the rebuild every time you open the app. The app package never drops or recreates the database.

## Preparing the database if you do not have one

- Use the agreed database package, for example `g2_fixed_20261114_trigger_compat`. `rebuild.sql` is only for rebuilding the sample database and replaces the data in that schema.
- The default schema is `blood_bank_group2_d3`. The app does not change tables or database business rules.
- Man grants SELECT and the INSERT/UPDATE/DELETE each function needs, plus EXECUTE on `d309_issue_unit`, `d309_discard_unit` and `d309_expire_units`. Do not give the app direct UPDATE on derived status columns.
- If the Event Scheduler is OFF, use the "Mark expired units" button or let the administrator run the schedule as the team planned.

## Build and test

Checked with Maven 3.9.9 and JDK 25.0.2, targeting Java 17. Compiler 3.13.0, Surefire 3.2.5 and the dependencies are pinned in the POM.

```powershell
mvn clean verify
```

Maven runs JUnit for the transaction, the expiry date limits and UI regressions automatically. These tests do not need MySQL. The old transaction harness can still be run by hand on Windows:

```powershell
mvn test-compile
java -cp "target/test-classes;target/classes" bb.service.IssuanceTxCheck
```

The full JAR after the build is `target/bloodbank-app.jar`. `build-and-test.cmd` runs the build and tests and then updates `app.jar`. Close the app before replacing the JAR if Windows says the file is in use. Running the source through Maven with `mvn compile exec:java` also works.

## What was fixed

- 17/11/2026: the Donor tab has a delete button (it asks for confirmation; a donor who has donated is blocked by the foreign key and the app explains why in plain words). The Requests tab can edit the urgency/quantity and delete a request. Q11 now uses `EXCEPT`, Q12 reads from the view `v_request_outstanding`. `Errors` explains violations by constraint name.
- 17/11/2026 (2): the whole interface and every error message are in English (Donor, Donations & Screening, Inventory, Requests, Issuance and Reports tabs); report names use the form `Q1. ...`, without long dashes.
- The Reports tab has all of Q1 to Q12 from the Query Matrix (Q6 fixed to AB+ Platelets, Q7 with the manager) and a stock report.
- Donor reset clears the data and the selection; browsing shows the row count; an old read result never overwrites a newer filter/selection.
- Stock entry takes the expiry date typed by the user, which must be after collection. Collection cannot be in the future; a future expiry is allowed. The 35/365/5 day values of the generator are not enforced.
- Maven runs the tests and builds a JAR with dependencies, together with a file to open the app.

## Checks on a real MySQL server

JUnit does not replace integration tests. On a separate sample database, check that:

1. All rows of Q1 to Q12 match the approved SQL on its columns. Checked on 16/11/2026 with the 14/11/2026 seed; the row count of each report is in `VALIDATION.md`. Row counts can change when the date or the data changes.
2. A new donor can donate for the first time; five Negative results make the event Passed. A unit with a valid expiry that is not one of the 35/365/5 values is also saved correctly.
3. Issuing several valid units commits; one wrong unit rolls back the whole issuance.
4. Two apps issuing the same unit, or taking the last slot of a request: exactly one succeeds.
5. Form reset, browse row counts and load results arriving out of order are checked with headless JUnit; this is separate from the real MySQL flows.

Results of 16/11/2026: **13 JUnit tests and 37 MySQL integration checks all PASS**. Maven runs the 13 JUnit tests automatically; the 37 integration checks are run separately on a test database.

See `VALIDATION.md` for the checks that were run. `CHANGES.md` lists the changes and the reasons; `docs/D3-18_screen_flow_and_UI_Backend_contract.md` describes the operation contract.

The ZIP contains no real database account. `db.properties.sample` leaves the user/password empty; personal settings stay outside the source.
