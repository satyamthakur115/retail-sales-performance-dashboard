# 🛒 Retail Sales Performance Dashboard

[![SQL](https://img.shields.io/badge/SQL-4479A1?style=flat-square&logo=mysql&logoColor=white)](https://www.mysql.com/)
[![Python](https://img.shields.io/badge/Python-3776AB?style=flat-square&logo=python&logoColor=white)](https://python.org)
[![Pandas](https://img.shields.io/badge/Pandas-150458?style=flat-square&logo=pandas&logoColor=white)](https://pandas.pydata.org/)
[![Tableau](https://img.shields.io/badge/Tableau-E97627?style=flat-square&logo=tableau&logoColor=white)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> 🚀 End-to-end retail analytics system that transforms raw transaction data into actionable business insights using SQL, Python, and Tableau.

---

## 📌 Project Overview

This project models a real retail analytics workflow: ingest raw sales data → clean and transform → load into a normalized SQL warehouse → run multi-dimensional analysis → export dashboard-ready outputs.

**Business Questions Answered:**
- Which regions and stores drive the most revenue?
- What products are underperforming vs targets?
- How does sales performance compare month-over-month and year-over-year?
- Which sales reps are hitting quota and which need support?
- What are the peak shopping periods and seasonal trends?

---

## 🗂️ Project Structure

```
retail-sales-performance-dashboard/
│
├── sql/
│   ├── schema.sql              # Star schema — fact + dimension tables
│   └── analysis_queries.sql    # Revenue, region, product & rep analysis
│
├── python/
│   ├── etl_pipeline.py         # Extract → Transform → Load pipeline
│   └── sales_summary.py        # Generates summary CSV for Tableau input
│
├── data/
│   └── sample_sales_data.csv   # Sample dataset (anonymized)
│
└── README.md
```

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Database | MySQL (Star Schema) |
| ETL | Python 3.10+, Pandas |
| Analysis | SQL Window Functions, CTEs, Aggregates |
| Visualization | Tableau, Excel |
| Version Control | Git / GitHub |

---

## 🗄️ Data Model (Star Schema)

```
                ┌──────────────┐
                │  dim_date    │
                └──────┬───────┘
                       │
┌──────────────┐  ┌────┴──────────┐  ┌──────────────┐
│  dim_product │──│  fact_sales   │──│  dim_store   │
└──────────────┘  └────┬──────────┘  └──────────────┘
                       │
                ┌──────┴───────┐
                │  dim_sales_  │
                │    rep       │
                └──────────────┘
```

A **star schema** was chosen for optimal query performance on analytical (OLAP) workloads.

---

## 📊 Key Analyses

| Analysis | Technique |
|---|---|
| Regional Revenue Ranking | `RANK() OVER (PARTITION BY region)` |
| Rolling 3-Month Avg Revenue | `AVG() OVER (ROWS BETWEEN 2 PRECEDING AND CURRENT)` |
| Product Category Performance | Multi-level `GROUP BY ROLLUP` |
| Sales Rep Quota Attainment | Actual vs target with variance % |
| Seasonal Trend Detection | Month-over-month `LAG()` comparison |
| Top/Bottom 10 Products | `DENSE_RANK()` with `HAVING` filter |

---

## ⚡ Quick Start

### 1. Clone the repo
```bash
git clone https://github.com/satyamthakur115/retail-sales-performance-dashboard.git
cd retail-sales-performance-dashboard
```

### 2. Create the database
```bash
mysql -u root -p < sql/schema.sql
```

### 3. Run the ETL pipeline
```bash
pip install pandas numpy mysql-connector-python faker
python python/etl_pipeline.py
```

### 4. Generate Tableau-ready export
```bash
python python/sales_summary.py
# Output: data/sales_summary_export.csv
```

---

## 🔍 Key SQL Techniques Used

- **Star schema design** for OLAP-optimized querying
- **Window functions**: `RANK`, `DENSE_RANK`, `LAG`, `LEAD`, `AVG OVER`
- **CTEs** for readable, maintainable multi-step analysis
- **GROUP BY ROLLUP** for hierarchical subtotals
- **Conditional aggregation** with `CASE WHEN` inside `SUM`/`COUNT`
- **Indexes on foreign keys and date columns** for sub-second query response

---

## 👤 Author

**Satyam Thakur** — Data Analyst | Database Administrator  
📧 satyamthakur115@gmail.com | [LinkedIn](https://www.linkedin.com/in/satyam-thakur-94a4231b9/) | [GitHub](https://github.com/satyamthakur115)

