# Blood Donation and Blood Bank Management System

Course project for managing donors, donation events, blood units, hospital requests, and blood issuance.



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
