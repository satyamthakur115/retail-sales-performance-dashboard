"""
Retail Sales Performance Dashboard — ETL Pipeline
Author: Satyam Thakur
Description: Extract raw CSV sales data → Transform & clean →
             Load into MySQL star schema.
Run:  python etl_pipeline.py
"""

import os
import random
import mysql.connector
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from decimal import Decimal

# ─── Config ────────────────────────────────────────────────
DB_CONFIG = {
    "host":     "localhost",
    "user":     "root",
    "password": "your_password_here",    # update this
    "database": "retail_sales_db"
}

NUM_RECORDS = 5000
START_DATE  = datetime(2023, 1, 1)
END_DATE    = datetime(2024, 12, 31)


# ─── Extract ────────────────────────────────────────────────
def generate_raw_data() -> pd.DataFrame:
    """Simulate raw sales data export with intentional data quality issues."""
    print("📥 Extracting raw data...")
    random.seed(42)

    dates      = [START_DATE + timedelta(days=random.randint(0, (END_DATE - START_DATE).days))
                  for _ in range(NUM_RECORDS)]
    store_ids  = [random.randint(1, 6) for _ in range(NUM_RECORDS)]
    product_ids= [random.randint(1, 8) for _ in range(NUM_RECORDS)]
    rep_ids    = [random.randint(1, 15) for _ in range(NUM_RECORDS)]
    quantities = [random.randint(1, 10) for _ in range(NUM_RECORDS)]
    discounts  = [round(random.choice([0, 0, 0, 5, 10, 15, 20]), 2)
                  for _ in range(NUM_RECORDS)]

    df = pd.DataFrame({
        "sale_date":    dates,
        "store_id":     store_ids,
        "product_id":   product_ids,
        "rep_id":       rep_ids,
        "quantity":     quantities,
        "discount_pct": discounts,
        "ref_number":   [f"TXN-{random.randint(100000, 999999)}" for _ in range(NUM_RECORDS)]
    })

    # Inject data quality issues for realistic ETL demo
    df.loc[df.sample(frac=0.02).index, "quantity"]  = -1       # invalid negatives
    df.loc[df.sample(frac=0.01).index, "store_id"]  = None     # null store
    df.loc[df.sample(frac=0.005).index, "sale_date"] = None    # null dates

    print(f"  ✅ Extracted {len(df):,} raw records")
    return df


# ─── Transform ──────────────────────────────────────────────
def transform(df: pd.DataFrame) -> pd.DataFrame:
    """Clean, validate and enrich the raw data."""
    print("\n🔄 Transforming data...")
    initial_count = len(df)

    # Drop rows with null critical fields
    df = df.dropna(subset=["sale_date", "store_id", "product_id"])
    print(f"  • Dropped {initial_count - len(df)} rows with null critical fields")

    # Remove invalid quantities
    invalid_qty = df[df["quantity"] <= 0].shape[0]
    df = df[df["quantity"] > 0]
    print(f"  • Removed {invalid_qty} rows with invalid quantities")

    # Standardize date column
    df["sale_date"] = pd.to_datetime(df["sale_date"])

    # Derive date_id (YYYYMMDD integer — matches dim_date primary key)
    df["date_id"] = df["sale_date"].dt.strftime("%Y%m%d").astype(int)

    # Ensure correct types
    df["store_id"]   = df["store_id"].astype(int)
    df["product_id"] = df["product_id"].astype(int)
    df["rep_id"]     = df["rep_id"].astype(int)
    df["quantity"]   = df["quantity"].astype(int)

    # Clip discount to valid range [0, 50]
    df["discount_pct"] = df["discount_pct"].clip(0, 50)

    print(f"  ✅ Clean records ready to load: {len(df):,}")
    return df


# ─── Populate dim_date ──────────────────────────────────────
def load_dim_date(conn) -> None:
    """Populate the date dimension table for the full date range."""
    print("\n📅 Loading dim_date...")
    cursor = conn.cursor()
    cursor.execute("SELECT COUNT(*) FROM dim_date")
    if cursor.fetchone()[0] > 0:
        print("  ⏭️  dim_date already populated — skipping")
        cursor.close()
        return

    current = START_DATE
    rows    = []
    while current <= END_DATE:
        rows.append((
            int(current.strftime("%Y%m%d")),
            current.strftime("%Y-%m-%d"),
            current.isoweekday(),
            current.strftime("%A"),
            current.isocalendar()[1],
            current.month,
            current.strftime("%B"),
            (current.month - 1) // 3 + 1,
            current.year,
            current.weekday() >= 5
        ))
        current += timedelta(days=1)

    cursor.executemany("""
        INSERT IGNORE INTO dim_date
            (date_id, full_date, day_of_week, day_name, week_number,
             month_number, month_name, quarter, fiscal_year, is_weekend)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """, rows)
    conn.commit()
    print(f"  ✅ Loaded {len(rows)} date records")
    cursor.close()


# ─── Load ───────────────────────────────────────────────────
def load(df: pd.DataFrame, conn) -> None:
    """Bulk insert clean data into fact_sales."""
    print("\n📤 Loading into fact_sales...")
    cursor = conn.cursor()

    # Fetch product price/cost lookup
    cursor.execute("SELECT product_id, unit_cost, unit_price FROM dim_product")
    product_lookup = {row[0]: (float(row[1]), float(row[2])) for row in cursor.fetchall()}

    rows = []
    skipped = 0
    for _, row in df.iterrows():
        pid = int(row["product_id"])
        if pid not in product_lookup:
            skipped += 1
            continue
        unit_cost, unit_price = product_lookup[pid]
        rows.append((
            int(row["date_id"]),
            pid,
            int(row["store_id"]),
            int(row["rep_id"]),
            row["ref_number"],
            int(row["quantity"]),
            unit_price,
            unit_cost,
            float(row["discount_pct"])
        ))

    cursor.executemany("""
        INSERT INTO fact_sales
            (date_id, product_id, store_id, rep_id, transaction_ref,
             quantity, unit_price, unit_cost, discount_pct)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
    """, rows)
    conn.commit()
    print(f"  ✅ Inserted {len(rows):,} records ({skipped} skipped — unknown product)")
    cursor.close()


def main():
    print("🚀 Retail Sales ETL Pipeline")
    print("=" * 40)

    conn = mysql.connector.connect(**DB_CONFIG)

    load_dim_date(conn)

    raw_df   = generate_raw_data()
    clean_df = transform(raw_df)
    load(clean_df, conn)

    conn.close()
    print("\n✅ ETL complete! Run analysis_queries.sql for insights.")


if __name__ == "__main__":
    main()
