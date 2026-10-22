import os
import pandas as pd

from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL


# 1. DATABASE CONNECTION

load_dotenv()

db_url = URL.create(
    drivername="mysql+pymysql",
    username=os.getenv("DB_USER"),
    password=os.getenv("DB_PASSWORD"),
    host=os.getenv("DB_HOST", "localhost"),
    port=int(os.getenv("DB_PORT", "3306")),
    database=os.getenv("DB_NAME")
)

engine = create_engine(db_url)

print("Database connection configured!")



# 2. EXTRACT


print("\nExtracting data...")

tables = [
    "products",
    "suppliers",
    "stores",
    "inventory",
    "sales",
    "purchase_orders"
]

data = {}

with engine.connect() as connection:

    for table in tables:

        query = text(f"SELECT * FROM `{table}`")

        data[table] = pd.read_sql(
            query,
            connection
        )

        print(
            f"{table}: {len(data[table])} records extracted"
        )



# 3. TRANSFORM DIMENSIONS

dim_products = data["products"].copy()

dim_suppliers = data["suppliers"][
    ["supplier_id", "supplier_name", "city"]
].copy()

dim_stores = data["stores"].copy()


# 4. TRANSFORM SALES

fact_sales = data["sales"].copy()

fact_sales["revenue"] = (
    fact_sales["quantity_sold"]
    * fact_sales["unit_selling_price"]
)


# 5. TRANSFORM INVENTORY

fact_inventory = data["inventory"].merge(
    data["products"][
        ["product_id", "unit_cost"]
    ],
    on="product_id",
    how="left",
    validate="many_to_one"
)

if fact_inventory["unit_cost"].isnull().any():
    raise ValueError("Inventory product cost missing!")

fact_inventory["inventory_value"] = (
    fact_inventory["stock_qty"]
    * fact_inventory["unit_cost"]
)

fact_inventory = fact_inventory[
    [
        "store_id",
        "product_id",
        "stock_qty",
        "last_updated",
        "inventory_value"
    ]
]



# 6. TRANSFORM PURCHASE ORDERS


fact_orders = data["purchase_orders"].copy()

fact_orders["expected_delivery_date"] = pd.to_datetime(
    fact_orders["expected_delivery_date"]
)

fact_orders["actual_delivery_date"] = pd.to_datetime(
    fact_orders["actual_delivery_date"]
)

fact_orders["delay_days"] = (
    fact_orders["actual_delivery_date"]
    - fact_orders["expected_delivery_date"]
).dt.days


def get_delivery_status(row):

    if row["order_status"] == "Cancelled":
        return "Cancelled"

    if pd.isna(row["actual_delivery_date"]):
        return "Not Delivered"

    if (
        row["actual_delivery_date"]
        <= row["expected_delivery_date"]
    ):
        return "On Time"

    return "Late"


fact_orders["delivery_status"] = fact_orders.apply(
    get_delivery_status,
    axis=1
)


# 7. DATA VALIDATION


print("\nValidating data...")

if fact_sales["sale_id"].duplicated().any():
    raise ValueError("Duplicate sale IDs found!")

if fact_orders["order_id"].duplicated().any():
    raise ValueError("Duplicate order IDs found!")

if (fact_sales["quantity_sold"] <= 0).any():
    raise ValueError("Invalid sales quantity!")

if (fact_inventory["stock_qty"] < 0).any():
    raise ValueError("Negative stock found!")

if fact_sales["revenue"].isnull().any():
    raise ValueError("Missing revenue values!")

print("Data validation successful!")



# 8. LOAD INTO MYSQL OLAP


print("\nLoading analytical tables...")

analytics_tables = {
    "dim_products": dim_products,
    "dim_suppliers": dim_suppliers,
    "dim_stores": dim_stores,
    "fact_sales": fact_sales,
    "fact_inventory": fact_inventory,
    "fact_purchase_orders": fact_orders
}


with engine.begin() as connection:

    for table in [
        "fact_sales",
        "fact_inventory",
        "fact_purchase_orders",
        "dim_products",
        "dim_suppliers",
        "dim_stores"
    ]:
        connection.execute(
            text(f"DELETE FROM retail_analytics.`{table}`")
        )

    for table, dataframe in analytics_tables.items():

        dataframe.to_sql(
            name=table,
            con=connection,
            schema="retail_analytics",
            if_exists="append",
            index=False
        )

        print(f"{table} loaded successfully!")


# 9. FINAL RESULT

print("\nETL PIPELINE COMPLETED SUCCESSFULLY!")

print("Total Revenue:", fact_sales["revenue"].sum())

print(
    "Total Inventory Value:",
    fact_inventory["inventory_value"].sum()
)

print("Total Purchase Orders:", len(fact_orders))

engine.dispose()