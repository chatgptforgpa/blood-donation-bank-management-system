# Changes to the application package

## Packaging additions of 16/11/2026

Direct source: `bloodbank-app-fixed-20261115.zip`.

| Part | Added | Reason |
|---|---|---|
| `app.jar` | JAR built from exactly the 15/11 source, with the JDBC driver and dependencies | `run-app.cmd` needs this file to open the app; the source ZIP did not have it |
| `VALIDATION.md` | Results of 16/11: 13 JUnit tests, 37 MySQL checks and comparison of Q1 to Q12 | The old document only covered the 14/11 check and Q1 to Q5 |
| `README.md` | Updated package version and test scope | Instructions match the new ZIP |

The Java source, POM and run files are unchanged from the 15/11 ZIP.

## Functional changes already in the 15/11/2026 version

Source: `bloodbank-app (1).zip`. The fix keeps the 12 table schema, Vietnam dates and the database's issuance mechanism.

| Part | Fixed | Reason |
|---|---|---|
| ReportService | Q1 to Q5 match the approved SQL; Q7 shows the manager; Q6, Q9, Q10, Q11 added (reference date is the Vietnam date) | Meets the required queries and the agreed scope |
| DonorPanel | Reset clears the input fields and the selection | Avoids keeping old donor data when registering a new donor |
| Ui and the panels | Row count for browsing, stale load results are dropped | Shows the correct row count and the current parent/filter |
| InventoryService and InventoryPanel | Expiry is entered by the user and must be after collection | Follows the baseline instead of the 35/365/5 rule of the fixture |
| Biz | Removed the unused fixed shelf life function | Avoids two sources for shelf life rules |
| POM and tests | Pinned compiler, JUnit runs automatically, JAR with dependencies | Clear build/test and easy app start |
| README and the UI/Backend contract | Updated the stock entry signature, queries and test command | Documents match the delivered code |

The purpose of the business queries did not change; no tables, transfers or changes to the database triggers/procedures were added.
