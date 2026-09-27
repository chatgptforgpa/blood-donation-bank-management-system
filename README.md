# Blood Donation and Blood Bank Management System

Course project for managing donors, donation events, blood units, hospital requests, and blood issuance.

## Current work (Week 3)

| Area | Owner | Deliverable | Target |
| --- | --- | --- | --- |
| Data Modelling | Thư, Khôi | Final business rules and ERDPlus diagram; relational schema draft | 29 Sep 2026 |
| Queries | Bảo Thy, Kim Ngân | Query Matrix v2 draft for DM review | 30 Sep 2026 |
| Queries | Bảo Thy, Kim Ngân | Query Matrix v2 final after DM feedback | 2 Oct 2026 |
| Database Design | Mẫn, Project Leader | Constraint Matrix v1 and transaction plan | 2 Oct 2026 |
| Java Dev - Frontend | Trúc Linh | Main screens, app flow, and data needs; Screen Flow draft | 2 Oct 2026 |
| Java Dev - Backend | Trí Phúc | JDBC direction, DAO flow, and database operations draft | 2 Oct 2026 |

The ERDPlus diagram is the reference for the conceptual data model. Business rules and the relational schema should be versioned alongside it as the team finalizes them. Java Dev can draft screens and application flow now; database operations should be checked against the finalized DM schema and constraints.

## Planned folders

- `docs/data-model/` - ERDPlus export, business rules, and schema
- `docs/queries/` - Query Matrix and SQL coverage
- `docs/java-dev/` - screen flow, data needs, JDBC/DAO and DB operation drafts
- `database/` - DDL, constraints, migrations, and seed data
- `src/` - application source code

Add each folder when its first reviewed file is ready. Do not commit credentials or real donor/patient data.

## Collaboration

Create a branch for each change and open a pull request into `main`. State what changed, which business rule or query it affects, and how it was checked. Keep unfinished assumptions visible in the pull request rather than silently treating them as final.
