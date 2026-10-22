import os
import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, URL

# 1. Load database credentials
load_dotenv()

# 2. Connect to MySQL analytical database
db_url = URL.create(
    drivername="mysql+pymysql",
    username=os.getenv("DB_USER"),
    password=os.getenv("DB_PASSWORD"),
    host=os.getenv("DB_HOST"),
    port=int(os.getenv("DB_PORT", "3306")),
    database="retail_analytics"
)

engine = create_engine(db_url)

# 3. Tables to export
tables = [
    "dim_products",
    "dim_stores",
    "dim_suppliers",
    "fact_sales",
    "fact_inventory",
    "fact_purchase_orders"
]

# 4. Create folder for CSV files
os.makedirs("powerbi_data", exist_ok=True)

# 5. Export each table
for table in tables:

    df = pd.read_sql_table(table, engine)

    df.to_csv(
        f"powerbi_data/{table}.csv",
        index=False
    )

    print(f"{table} exported successfully!")

print("ALL TABLES EXPORTED SUCCESSFULLY!")