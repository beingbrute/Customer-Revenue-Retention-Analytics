"""
Load the cleaned retail data into a local PostgreSQL database for the dimensional model.

Creates the database `retail_dw` (if it does not exist) and the schema `staging`, then loads:
  - staging.transactions            data/processed/retail_transactions_clean.csv.gz (1,033,036 rows)
  - staging.product_classifications data/processed/analytics/genai_product_classifications.csv
  - staging.customer_segments       data/processed/analytics/customer_rfm_segments.csv
  - staging.monthly_revenue_python  data/processed/analytics/monthly_revenue.csv
                                    (the notebook's monthly totals, used only to check the star schema)

The star schema itself is built by the SQL files in this folder (run them in order).

Usage:
    python dimensional_model\\load_staging.py
    python dimensional_model\\load_staging.py --port 5432 --user postgres

The password is asked for when the script runs and is not stored anywhere.
"""
import argparse
import csv
import getpass
import gzip
import io
import os
import sys
from pathlib import Path

import psycopg2

ROOT = Path(__file__).resolve().parents[1]
PROCESSED = ROOT / "data" / "processed"
TRANSACTIONS = PROCESSED / "retail_transactions_clean.csv.gz"
PRODUCTS = PROCESSED / "analytics" / "genai_product_classifications.csv"
SEGMENTS = PROCESSED / "analytics" / "customer_rfm_segments.csv"
MONTHLY = PROCESSED / "analytics" / "monthly_revenue.csv"
DB_NAME = "retail_dw"

DDL = """
DROP SCHEMA IF EXISTS staging CASCADE;
CREATE SCHEMA staging;

CREATE TABLE staging.transactions (
    invoice_no         TEXT          NOT NULL,
    stock_code         TEXT          NOT NULL,
    description        TEXT,
    quantity           INTEGER       NOT NULL,
    invoice_date       TIMESTAMP     NOT NULL,
    unit_price         NUMERIC(18,4) NOT NULL,
    customer_id        BIGINT,
    country            TEXT          NOT NULL,
    source_year        TEXT          NOT NULL,
    transaction_type   TEXT          NOT NULL,
    line_category      TEXT          NOT NULL,
    line_value         NUMERIC(20,4) NOT NULL,
    data_quality_flag  TEXT          NOT NULL,
    analysis_eligible  BOOLEAN       NOT NULL
);

CREATE TABLE staging.product_classifications (
    stock_code        TEXT PRIMARY KEY,
    product_category  TEXT NOT NULL,
    abc_class         TEXT
);

CREATE TABLE staging.customer_segments (
    customer_id       BIGINT PRIMARY KEY,
    customer_segment  TEXT NOT NULL
);

CREATE TABLE staging.monthly_revenue_python (
    month               DATE PRIMARY KEY,
    gross_sales         NUMERIC(20,4) NOT NULL,
    cancellation_value  NUMERIC(20,4) NOT NULL,
    net_revenue         NUMERIC(20,4) NOT NULL
);
"""


def subset(path, columns):
    """Return an in-memory CSV holding only the named columns."""
    out = io.StringIO()
    writer = csv.writer(out)
    with open(path, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            writer.writerow([row[c] for c in columns])
    out.seek(0)
    return out


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--host", default="localhost")
    p.add_argument("--port", default="5432")
    p.add_argument("--user", default="postgres")
    args = p.parse_args()

    missing = [str(f.relative_to(ROOT)) for f in (TRANSACTIONS, PRODUCTS, SEGMENTS, MONTHLY) if not f.exists()]
    if missing:
        print(f"ERROR: missing input files: {missing}. Run the Python notebooks first.")
        sys.exit(2)

    password = os.environ.get("PGPASSWORD") or getpass.getpass(f"PostgreSQL password for {args.user}: ")
    connect = lambda db: psycopg2.connect(host=args.host, port=args.port, user=args.user,
                                          password=password, dbname=db)

    con = connect("postgres")
    con.autocommit = True
    with con.cursor() as cur:
        cur.execute("SELECT 1 FROM pg_database WHERE datname = %s", (DB_NAME,))
        if cur.fetchone() is None:
            cur.execute(f"CREATE DATABASE {DB_NAME}")
            print(f"Created database {DB_NAME}")
    con.close()

    con = connect(DB_NAME)
    with con, con.cursor() as cur:
        cur.execute(DDL)

        with gzip.open(TRANSACTIONS, "rt", encoding="utf-8") as f:
            cur.copy_expert("COPY staging.transactions FROM STDIN WITH (FORMAT csv, HEADER true, NULL '')", f)

        cur.copy_expert("COPY staging.product_classifications FROM STDIN WITH (FORMAT csv, NULL '')",
                        subset(PRODUCTS, ["stock_code", "product_category", "abc_class"]))
        cur.copy_expert("COPY staging.customer_segments FROM STDIN WITH (FORMAT csv)",
                        subset(SEGMENTS, ["customer_id", "customer_segment"]))
        cur.copy_expert("COPY staging.monthly_revenue_python FROM STDIN WITH (FORMAT csv)",
                        subset(MONTHLY, ["month", "gross_sales", "cancellation_value", "estimated_net_revenue"]))

        for table in ("transactions", "product_classifications", "customer_segments", "monthly_revenue_python"):
            cur.execute(f"SELECT COUNT(*) FROM staging.{table}")
            print(f"staging.{table:<24} {cur.fetchone()[0]:>10,} rows")
    con.close()
    print("Done. Next: run 01_dimensions.sql in pgAdmin (database retail_dw).")


if __name__ == "__main__":
    main()
