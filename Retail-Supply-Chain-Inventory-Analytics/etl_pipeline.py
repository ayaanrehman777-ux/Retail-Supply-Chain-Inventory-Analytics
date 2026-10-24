import os
import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL


# 1. CONNECT TO MYSQL

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

print("Database connected!")


# 2. EXTRACT DATA

products = pd.read_sql("SELECT * FROM products", engine)
suppliers = pd.read_sql("SELECT * FROM suppliers", engine)
stores = pd.read_sql("SELECT * FROM stores", engine)
sales = pd.read_sql("SELECT * FROM sales", engine)
inventory = pd.read_sql("SELECT * FROM inventory", engine)
orders = pd.read_sql("SELECT * FROM purchase_orders", engine)

print("Data extracted successfully!")


# 3. TRANSFORM DATA

# Dimension tables
dim_products = products.copy()
dim_suppliers = suppliers[["supplier_id", "supplier_name", "city"]].copy()
dim_stores = stores.copy()

# Calculate sales revenue
sales["revenue"] = sales["quantity_sold"] * sales["unit_selling_price"]

# Calculate inventory value
inventory = inventory.merge(
    products[["product_id", "unit_cost"]],
    on="product_id",
    how="left"
)

inventory["inventory_value"] = inventory["stock_qty"] * inventory["unit_cost"]

# 3 BASIC DATA VALIDATION CHECKS

if sales["sale_id"].duplicated().any():
    raise ValueError("Duplicate sales found!")

if (sales["quantity_sold"] <= 0).any():
    raise ValueError("Invalid sales quantity!")

if inventory["unit_cost"].isnull().any():
    raise ValueError("Missing product cost!")

inventory = inventory[
    ["store_id", "product_id", "stock_qty", "last_updated", "inventory_value"]
]

# Calculate delivery delay
orders["expected_delivery_date"] = pd.to_datetime(
    orders["expected_delivery_date"]
)

orders["actual_delivery_date"] = pd.to_datetime(
    orders["actual_delivery_date"]
)

orders["delay_days"] = (
    orders["actual_delivery_date"] - orders["expected_delivery_date"]
).dt.days

# Calculate delivery status
orders["delivery_status"] = "Late"

orders.loc[
    orders["actual_delivery_date"] <= orders["expected_delivery_date"],
    "delivery_status"
] = "On Time"

orders.loc[
    orders["actual_delivery_date"].isna(),
    "delivery_status"
] = "Not Delivered"

orders.loc[
    orders["order_status"] == "Cancelled",
    "delivery_status"
] = "Cancelled"

print("Data transformed and validated!")


# 4. LOAD DATA INTO ANALYTICAL DATABASE

tables = {
    "dim_products": dim_products,
    "dim_suppliers": dim_suppliers,
    "dim_stores": dim_stores,
    "fact_sales": sales,
    "fact_inventory": inventory,
    "fact_purchase_orders": orders
}

with engine.begin() as conn:

    # Delete old data
    for name in [
        "fact_sales",
        "fact_inventory",
        "fact_purchase_orders",
        "dim_products",
        "dim_suppliers",
        "dim_stores"
    ]:
        conn.execute(text(f"DELETE FROM retail_analytics.`{name}`"))

    # Insert updated data
    for name, df in tables.items():
        df.to_sql(
            name=name,
            con=conn,
            schema="retail_analytics",
            if_exists="append",
            index=False
        )

        print(f"{name} loaded successfully!")


# 5. FINAL RESULT

print("\nETL COMPLETED SUCCESSFULLY!")

print("Total Revenue:", sales["revenue"].sum())
print("Total Inventory Value:", inventory["inventory_value"].sum())
print("Total Purchase Orders:", len(orders))

engine.dispose()
