"""Generate a 2,000-row D3-08 snapshot and a complete MySQL rebuild script."""

import argparse
from datetime import date, datetime, timedelta, timezone
from itertools import product
from pathlib import Path

from faker import Faker


SCHEMA = "blood_bank_group2_d3"
TESTS = ("HIV", "HBsAg", "HCV", "Syphilis", "Malaria")
COMPONENTS = ("Whole Blood", "Plasma", "Platelets")
FIXTURE_SHELF_DAYS = {"Whole Blood": 35, "Plasma": 365, "Platelets": 5}
BLOOD_TYPES = tuple(product(("A", "B", "AB", "O"), ("+", "-")))

# Table order also controls insertion order. The first column identifies sample rows.
COLUMNS = {
    "DONOR": ("donor_id", "full_name", "blood_group", "rh_factor", "address", "date_of_birth"),
    "BLOOD_BANK": ("bank_id", "bank_name", "location", "open_time", "close_time"),
    "HOSPITAL": ("hospital_id", "hospital_name", "address"),
    "DONOR_PHONE": ("donor_id", "phone"),
    "BLOOD_BANK_PHONE": ("bank_id", "phone"),
    "HOSPITAL_PHONE": ("hospital_id", "phone"),
    "STAFF": ("staff_id", "bank_id", "full_name", "role", "manager_id"),
    "DONATION_EVENT": ("event_id", "donor_id", "bank_id", "donation_date", "volume_ml", "screening_result"),
    "REQUEST": ("request_id", "hospital_id", "blood_group", "rh_factor", "component_type",
                "quantity_needed", "urgency_level", "request_date", "status"),
    "SCREENING_TEST": ("event_id", "test_type", "result", "test_date"),
    "BLOOD_UNIT": ("bank_id", "unit_id", "event_id", "component_type", "collection_date", "expiry_date", "status"),
    "ISSUE_RECORD": ("issue_id", "request_id", "bank_id", "unit_id", "issue_date", "staff_id"),
}


def sample_id(kind, number):
    return f"S2K{kind}{number:04d}"


def clean_text(text, limit):
    return " ".join(text.split()).replace("\\", "/")[:limit]


def sql_literal(value):
    if value is None:
        return "NULL"
    if isinstance(value, int):
        return str(value)
    return "'" + str(value).replace("'", "''") + "'"


def build_rows(as_of):
    fake = Faker("en_US")
    fake.seed_instance(3082000)
    rows = {table: [] for table in COLUMNS}
    month_start = as_of.replace(day=1)
    last_month_end = month_start - timedelta(days=1)
    last_month_start = last_month_end.replace(day=1)

    for i in range(1, 251):
        donor = sample_id("D", i)
        group, rh = BLOOD_TYPES[(i - 1) % len(BLOOD_TYPES)]
        birth = fake.date_between_dates(as_of - timedelta(days=65 * 365), as_of - timedelta(days=19 * 366))
        rows["DONOR"].append((donor, clean_text(fake.name(), 150), group, rh,
                              clean_text(fake.address(), 255), birth))
        rows["DONOR_PHONE"].append((donor, f"0001{i:06d}"))

    issuer = {}
    for i in range(1, 26):
        bank, hospital = sample_id("B", i), sample_id("H", i)
        rows["BLOOD_BANK"].append((bank, f"Sample Blood Bank {i:02d}",
                                   clean_text(fake.address(), 255), "08:00:00", "17:00:00"))
        rows["HOSPITAL"].append((hospital, f"Sample Hospital {i:02d}", clean_text(fake.address(), 255)))
        rows["BLOOD_BANK_PHONE"].append((bank, f"0002{i:06d}"))
        rows["HOSPITAL_PHONE"].append((hospital, f"0003{i:06d}"))
        manager = sample_id("S", 3 * i - 2)
        issuer[bank] = sample_id("S", 3 * i)
        rows["STAFF"].extend([
            (manager, bank, clean_text(fake.name(), 150), "Manager", None),
            (sample_id("S", 3 * i - 1), bank, clean_text(fake.name(), 150), "Technician", manager),
            (issuer[bank], bank, clean_text(fake.name(), 150), "Nurse", manager),
        ])

    donation_dates = {}
    for i in range(1, 201):
        event = sample_id("E", i)
        donor_number = i if i <= 190 else i - 190
        donor, _, group, rh, _, _ = rows["DONOR"][donor_number - 1]
        donation_bank = sample_id("B", (i - 1) % 25 + 1)
        storage_bank = sample_id("B", i % 25 + 1) if i % 7 == 0 else donation_bank
        component = COMPONENTS[(i - 1) % len(COMPONENTS)]
        donation = as_of - timedelta(days=i % 4)
        issue_day = None
        if i <= 60:
            if i <= 45:
                issue_day = last_month_start + timedelta(days=(i - 1) % last_month_end.day)
            else:
                issue_day = as_of - timedelta(days=min(i % 5, as_of.day - 1))
            donation = issue_day - timedelta(days=2)
        elif 61 <= i <= 68:
            storage_bank, component = sample_id("B", 1), "Whole Blood"
        elif i == 72:
            # Donor 72 is O-. The unit expires two days after the snapshot date.
            component, donation = "Whole Blood", as_of - timedelta(days=33)
        elif 73 <= i <= 82:
            component, donation = "Platelets", as_of - timedelta(days=7)
        elif 171 <= i <= 180:
            donation = as_of - timedelta(days=56 + i - 171)
        elif i > 190:
            donation = donation_dates[donor_number] - timedelta(days=56)
        donation_dates[i] = donation

        if i <= 150:
            results = ["Negative"] * 5
            screening = "Passed"
        elif i <= 160:
            results = ["Negative", "Positive"]
            screening = "Failed"
        elif i <= 170:
            results = ["Negative"] * 3
            screening = "Pending"
        else:
            results = []
            screening = "Pending"

        rows["DONATION_EVENT"].append((event, donor, donation_bank, donation,
                                       (350, 450)[i % 2], screening))
        for test, result in zip(TESTS, results):
            rows["SCREENING_TEST"].append((event, test, result, donation))

        if screening != "Passed":
            continue

        # Units 1 and 2 deliberately reuse the same local ID at different banks.
        unit = sample_id("U", 1 if i == 2 else i)
        expiry = donation + timedelta(days=FIXTURE_SHELF_DAYS[component])
        if issue_day is not None:
            status = "Issued"
        elif 83 <= i <= 87:
            status = "Discarded"
        elif expiry < as_of:
            status = "Expired"
        else:
            status = "Available"
        rows["BLOOD_UNIT"].append((storage_bank, unit, event, component, donation, expiry, status))

        if issue_day is not None:
            request = sample_id("R", i)
            quantity = 3 if i <= 25 else 1
            request_status = "Partially Filled" if quantity > 1 else "Fulfilled"
            hospital = sample_id("H", (i - 1) % 25 + 1)
            urgency = "High" if i % 3 == 0 else "Medium"
            if i % 4 == 0:
                urgency = "Critical"
            rows["REQUEST"].append((request, hospital, group, rh, component, quantity,
                                    urgency, issue_day, request_status))
            rows["ISSUE_RECORD"].append((sample_id("I", i), request, storage_bank, unit,
                                         issue_day, issuer[storage_bank]))

        if 61 <= i <= 90:
            second = COMPONENTS[(COMPONENTS.index(component) + 1) % len(COMPONENTS)]
            second_expiry = donation + timedelta(days=FIXTURE_SHELF_DAYS[second])
            second_status = "Expired" if second_expiry < as_of else "Available"
            rows["BLOOD_UNIT"].append((storage_bank, sample_id("U", 150 + i - 60), event,
                                        second, donation, second_expiry, second_status))

    for i in range(61, 86):
        group, rh = BLOOD_TYPES[(i - 1) % len(BLOOD_TYPES)]
        urgency = "Critical" if i % 4 == 1 else "Low"
        rows["REQUEST"].append((sample_id("R", i), sample_id("H", (i - 1) % 25 + 1),
                                group, rh, COMPONENTS[i % 3], 2, urgency, as_of, "Pending"))
    return rows


def insert_statement(table, rows):
    fields = ", ".join(f"`{column}`" for column in COLUMNS[table])
    values = ",\n".join("        (" + ", ".join(map(sql_literal, row)) + ")" for row in rows)
    return f"    INSERT INTO `{table}` ({fields}) VALUES\n{values};"


def render_sql(rows, as_of):
    inserts = "\n\n".join(insert_statement(table, values) for table, values in rows.items())
    counts = "\n    UNION ALL\n".join(
        f"    SELECT '{table}' AS table_name, COUNT(*) AS sample_rows\n"
        f"    FROM `{table}` WHERE `{fields[0]}` LIKE 'S2K%'"
        for table, fields in COLUMNS.items()
    )
    return f"""-- Group 02 | D3-08 | 2,000 synthetic rows across 12 tables.
-- Snapshot date: {as_of}. Run on the D3-07 schema after setup.sql.
-- This fixture includes historical issuance and precomputed derived statuses.
-- Load before installing D3-09 operational rules. S2K IDs identify these rows.
-- If sample keys already exist, the transaction fails and rolls back.
SET NAMES utf8mb4;
USE `{SCHEMA}`;

DROP PROCEDURE IF EXISTS d308_load_s2k_fixture;
DELIMITER $$
CREATE PROCEDURE d308_load_s2k_fixture()
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

{inserts}

    COMMIT;
END$$
DELIMITER ;

CALL d308_load_s2k_fixture();
DROP PROCEDURE d308_load_s2k_fixture;

WITH sample_counts AS (
{counts}
)
SELECT table_name, sample_rows FROM sample_counts
UNION ALL
SELECT 'TOTAL', SUM(sample_rows) FROM sample_counts;
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    vietnam_time = timezone(timedelta(hours=7))
    parser.add_argument("--as-of", type=date.fromisoformat, default=datetime.now(vietnam_time).date(),
                        help="Snapshot date as YYYY-MM-DD. Defaults to today's date in Vietnam.")
    parser.add_argument("--reference-date", type=date.fromisoformat, default=None,
                        help="Day the report results were taken; rebuild.sql shifts every date by "
                             "(day of the run - reference date). Defaults to --as-of. The current "
                             "package uses --as-of 2026-11-14 --reference-date 2026-11-17.")
    parser.add_argument("--output", type=Path, default=Path(__file__).with_name("seed_2000.sql"))
    args = parser.parse_args()
    rows = build_rows(args.as_of)
    total = sum(map(len, rows.values()))
    if total != 2000 or any(len(table_rows) < 15 for table_rows in rows.values()):
        raise ValueError("Expected exactly 2,000 rows and at least 15 per table.")
    seed_sql = render_sql(rows, args.as_of)
    args.output.write_text(seed_sql, encoding="utf-8")

    source_directory = Path(__file__).resolve().parent
    rebuild_path = args.output.with_name("rebuild.sql")
    if rebuild_path.resolve() == args.output.resolve():
        rebuild_path = args.output.with_name("database_rebuild.sql")
    rebuild_parts = [
        "-- Group 02 | Complete rebuild for the sample database.\n"
        f"-- Snapshot date: {args.as_of}.\n"
        f"-- This script deletes and recreates only {SCHEMA}.\n"
        f"DROP DATABASE IF EXISTS `{SCHEMA}`;",
        (source_directory / "setup.sql").read_text(encoding="utf-8-sig"),
        seed_sql,
        (source_directory / "date_shift.sql").read_text(encoding="utf-8-sig")
        .replace("2026-11-17", str(args.reference_date or args.as_of)),
        (source_directory / "business_rules.sql").read_text(encoding="utf-8-sig"),
        (source_directory / "post_setup.sql").read_text(encoding="utf-8-sig"),
    ]
    rebuild_path.write_text("\n\n".join(rebuild_parts), encoding="utf-8")
    for table, table_rows in rows.items():
        print(f"{table:16} {len(table_rows):5}")
    print(f"{'TOTAL':16} {total:5}\nCreated {args.output.resolve()}")
    print(f"Created {rebuild_path.resolve()}")


if __name__ == "__main__":
    main()
