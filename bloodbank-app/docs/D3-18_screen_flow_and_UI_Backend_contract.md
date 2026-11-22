# D3-18 | Screen flow and UI/Backend contract

UI framework: Java Swing (part of the JDK, no external UI library). Backend: plain JDBC, MySQL Connector/J 8.4.0, Java 17+.

## 1. Screens (tabs)

| Tab | UI class | Service | Function |
|---|---|---|---|
| Donor | DonorPanel | DonorService | Search, register, edit name/address/date of birth/phones |
| Donations & Screening | DonationPanel | DonationService | Check the 56 day rule, record a donation, enter/delete test results |
| Inventory | InventoryPanel | InventoryService | Filter stock, enter units from a Passed donation, discard, mark expired |
| Requests | RequestPanel | RequestService | Create/filter requests, view their issue records |
| Issuance | IssuancePanel | IssuanceService | Choose a request + staff member, pick several units, issue them in one transaction |
| Reports | ReportPanel | ReportService | 13 reports: Q1 to Q12 and stock |

Main flow: Donor → Donation (Pending) → five Negative tests (Passed) → Stock entry (Available) → Blood request (Pending) → Issuance (Partially Filled/Fulfilled, units become Issued).

## 2. Operation contract

Business dates use Asia/Ho_Chi_Minh. The UI takes dates as yyyy-MM-dd. Every error is returned as an `AppException` whose message is shown directly; the UI does not interpret error codes itself.

| Operation | Input | Output | Validation in the app | Constraint enforced by the database |
|---|---|---|---|---|
| DonorService.register | name, blood group, Rh, address, date of birth, list of phones | new donor_id | name/address not empty; group A/B/AB/O; Rh +/-; date of birth before today; valid phone format, duplicates removed | CHECK on blood group/Rh, NOT NULL |
| DonorService.update | donor_id, name, address, date of birth, phones | none | as above | Changing blood group/Rh is blocked by a trigger (BR37), so the app does not allow it |
| DonationService.nextEligibleDate | donor_id | date the donor can donate again, or null if never donated | donor exists | none |
| DonationService.record | donor_id, bank_id, donation date, volume ml | new event_id, status Pending | date not in the future; volume greater than 0 | BR18: at least 56 days apart (both directions); UNIQUE (donor_id, donation_date) |
| DonationService.saveTests | event_id, test date, map of type→Positive/Negative | none | type is one of the 5 types; valid result; date not in the future | BR39: test date not before the donation date; each type once; screening_result is derived by the database |
| DonationService.deleteTest | event_id, test type | none | valid type | Only allowed while the donation is still Pending |
| InventoryService.register | bank_id, event_id, component, collection date, expiry date | new unit_id, status Available | collection required and not in the future; expiry required and after collection; future expiry allowed | BR23: the donation must be Passed; BR34: collection not before the donation date |
| InventoryService.discard | bank_id, unit_id, staff_id | none | not empty | Procedure d309_discard_unit: staff of the same bank; unit Available or Expired |
| InventoryService.expireNow | none | number of units set to Expired | none | d309_expire_units |
| RequestService.create | hospital_id, group, Rh, component, quantity, urgency, date | new request_id, status Pending | quantity greater than 0; date not in the future | CHECK on the value domains |
| IssuanceService.candidateUnits | request_id, staff_id | Available units, not expired, matching group/Rh/component, in the staff member's bank, soonest expiry first | none | none |
| IssuanceService.issue | request_id, staff_id, list of unit_id | list of issue_id | at least one unit; no duplicate IDs; number of units not above what is still needed | d309_issue_unit and triggers: BR15, BR17, BR19 to BR22, BR32, BR38 |

## 3. Transaction rules (D3-10)

- `IssuanceService.issue` opens one JDBC transaction (autocommit off), locks the REQUEST row with `SELECT ... FOR UPDATE`, then calls `d309_issue_unit` for each unit in turn. The database triggers then lock BLOOD_UNIT, request first and unit second, as designed in D3-06.
- The backend owns commit/rollback. If one unit fails, all issue records of that issuance are rolled back.
- Forms never edit derived statuses directly. The app only sends the valid initial status Pending/Available when it creates a record; later status changes are kept by triggers and procedures.
- Every query uses a PreparedStatement with parameters. Login details stay outside the source (db.properties or the connection dialog).

## 4. Error mapping

| Source | Shown as |
|---|---|
| SQLSTATE 45000 (SIGNAL from a trigger/procedure) | The MESSAGE_TEXT as is |
| Codes 1062, 1451, 1452, 3819, 1048 | A matching English message (duplicate key, still referenced, wrong reference, CHECK violation, missing data) |
| Codes 1213, 1205 (deadlock, lock wait) | The system is busy, try again |
| Other | The error code and the original message |

## 5. Scope notes

- Reports Q1 to Q5 match the approved queries. Q2 only lists donors who have donated before; recording a donation still allows a first donation.
- The unit expiry follows the baseline rule `expiry_date > collection_date`; the values used to generate the sample data are not hard rules in the app.
- Browsing shows the row count; each read channel uses a load token to drop old results when the filter/selection changes. Write operations still report their own commit or error.
- The Reserved status, transfers and unit movement history are future work and are not in the UI.
