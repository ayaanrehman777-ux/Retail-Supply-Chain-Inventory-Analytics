--               MySQL workbench codes       


--  Database

CREATE DATABASE retail_supply_chain;

-- 1. PRODUCTS
CREATE TABLE products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    category VARCHAR(50),
    unit_cost NUMERIC(10,2) NOT NULL CHECK (unit_cost >= 0),
    selling_price NUMERIC(10,2) NOT NULL CHECK (selling_price >= 0),
    reorder_level INT NOT NULL DEFAULT 10 CHECK (reorder_level >= 0)
);

-- 2. SUPPLIERS
CREATE TABLE suppliers (
    supplier_id INT PRIMARY KEY,
    supplier_name VARCHAR(100) NOT NULL,
    city VARCHAR(50),
    contact_email VARCHAR(150) UNIQUE
);

-- 3. STORES
CREATE TABLE stores (
    store_id INT PRIMARY KEY,
    store_name VARCHAR(100) NOT NULL,
    city VARCHAR(50),
    region VARCHAR(50)
);

-- 4. INVENTORY
CREATE TABLE inventory (
    store_id INT,
    product_id INT,
    stock_qty INT NOT NULL CHECK (stock_qty >= 0),
    last_updated DATE,
    PRIMARY KEY (store_id, product_id),
    FOREIGN KEY (store_id) REFERENCES stores(store_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- 5. SALES
CREATE TABLE sales (
    sale_id INT PRIMARY KEY,
    store_id INT NOT NULL,
    product_id INT NOT NULL,
    sale_date DATE NOT NULL,
    quantity_sold INT NOT NULL CHECK (quantity_sold > 0),
    unit_selling_price NUMERIC(10,2) NOT NULL CHECK (unit_selling_price >= 0),
    FOREIGN KEY (store_id) REFERENCES stores(store_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- 6. PURCHASE ORDERS
CREATE TABLE purchase_orders (
    order_id INT PRIMARY KEY,
    supplier_id INT NOT NULL,
    store_id INT NOT NULL,
    product_id INT NOT NULL,
    order_date DATE NOT NULL,
    expected_delivery_date DATE NOT NULL,
    actual_delivery_date DATE,
    quantity_ordered INT NOT NULL CHECK (quantity_ordered > 0),
    order_status VARCHAR(20) NOT NULL,
    FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id),
    FOREIGN KEY (store_id) REFERENCES stores(store_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    CHECK (expected_delivery_date >= order_date),
    CHECK (actual_delivery_date IS NULL OR actual_delivery_date >= order_date),
    CHECK (order_status IN ('Pending', 'Delivered', 'Cancelled'))
);



-- 2 Inserting values

-- PRODUCTS
INSERT INTO products VALUES
(101, 'Water Bottle', 'Accessories', 100, 160, 20),
(102, 'Notebook', 'Stationery', 40, 65, 30),
(103, 'Backpack', 'Bags', 500, 750, 10),
(104, 'Headphones', 'Electronics', 800, 1200, 15),
(105, 'Pen Pack', 'Stationery', 20, 35, 40);

-- SUPPLIERS
INSERT INTO suppliers VALUES
(1, 'Alpha Supplies', 'Jaipur', 'alpha@example.com'),
(2, 'Metro Wholesale', 'Delhi', 'metro@example.com'),
(3, 'Prime Distributors', 'Mumbai', 'prime@example.com');

-- STORES
INSERT INTO stores VALUES
(1, 'RetailMart Jaipur', 'Jaipur', 'North'),
(2, 'RetailMart Delhi', 'Delhi', 'North'),
(3, 'RetailMart Mumbai', 'Mumbai', 'West');

-- INVENTORY
INSERT INTO inventory VALUES
(1, 101, 30, '2026-10-20'),
(1, 102, 100, '2026-10-20'),
(1, 103, 20, '2026-10-20'),
(2, 101, 80, '2026-10-20'),
(2, 104, 15, '2026-10-20'),
(3, 105, 200, '2026-10-20');

-- SALES
INSERT INTO sales VALUES
(1001, 1, 101, '2026-10-18', 12, 160),
(1002, 1, 102, '2026-10-18', 8, 65),
(1003, 1, 103, '2026-10-19', 5, 750),
(1004, 2, 104, '2026-10-19', 6, 1200),
(1005, 3, 105, '2026-10-20', 20, 35);

-- PURCHASE ORDERS
INSERT INTO purchase_orders VALUES
(5001, 1, 1, 101, '2026-10-10', '2026-10-14', '2026-10-15', 100, 'Delivered'),
(5002, 2, 1, 103, '2026-10-11', '2026-10-15', '2026-10-15', 50, 'Delivered'),
(5003, 3, 2, 104, '2026-10-16', '2026-10-21', NULL, 40, 'Pending'),
(5004, 1, 3, 105, '2026-10-12', '2026-10-16', '2026-10-18', 200, 'Delivered');


-- 3  Data Validation


SELECT 'Products' AS table_name, COUNT(*) AS total_records
FROM products

UNION ALL

SELECT 'Suppliers', COUNT(*)
FROM suppliers

UNION ALL

SELECT 'Stores', COUNT(*)
FROM stores

UNION ALL

SELECT 'Inventory', COUNT(*)
FROM inventory

UNION ALL

SELECT 'Sales', COUNT(*)
FROM sales

UNION ALL

SELECT 'Purchase Orders', COUNT(*)
FROM purchase_orders;


-- 4  Total Revenue Analysis



SELECT
    SUM(quantity_sold * unit_selling_price) AS total_revenue
FROM sales;

SELECT
    p.product_name,
    SUM(s.quantity_sold * s.unit_selling_price) AS total_revenue

FROM sales s

JOIN products p
ON s.product_id = p.product_id

GROUP BY p.product_id, p.product_name

ORDER BY total_revenue DESC;


-- 5  Store-Wise Revenue Analysis


SELECT
    st.store_name,
    SUM(s.quantity_sold * s.unit_selling_price) AS total_revenue

FROM sales s

JOIN stores st
ON s.store_id = st.store_id

GROUP BY st.store_id, st.store_name

ORDER BY total_revenue DESC;


-- 6  Inventory Risk Analysis

SELECT
    st.store_name,
    p.product_name,
    i.stock_qty,
    p.reorder_level,

    CASE
        WHEN i.stock_qty = 0 THEN 'High Risk'

        WHEN i.stock_qty <= p.reorder_level
        THEN 'Medium Risk'

        ELSE 'Low Risk'
    END AS stock_risk

FROM inventory i

JOIN products p
ON i.product_id = p.product_id

JOIN stores st
ON i.store_id = st.store_id;


-- 7  Supplier Delivery Performance


SELECT
    po.order_id,
    sp.supplier_name,
    po.expected_delivery_date,
    po.actual_delivery_date,

    DATEDIFF(
        po.actual_delivery_date,
        po.expected_delivery_date
    ) AS delay_days,

    CASE
        WHEN po.order_status = 'Cancelled'
        THEN 'Cancelled'

        WHEN po.actual_delivery_date IS NULL
        THEN 'Not Delivered'

        WHEN po.actual_delivery_date <= po.expected_delivery_date
        THEN 'On Time'

        ELSE 'Late'
    END AS delivery_status

FROM purchase_orders po

JOIN suppliers sp
ON po.supplier_id = sp.supplier_id;


-- 8 SQL — CTE + Window Function


WITH store_revenue AS (

    SELECT
        st.store_name,
        SUM(s.quantity_sold * s.unit_selling_price)
        AS total_revenue

    FROM sales s

    JOIN stores st
    ON s.store_id = st.store_id

    GROUP BY st.store_id, st.store_name

)

SELECT
    store_name,
    total_revenue,

    RANK() OVER (
        ORDER BY total_revenue DESC
    ) AS revenue_rank

FROM store_revenue;


-- Analytical Tables (OLTP → OLAP)

-- 1   Analytics Database Create Karo



CREATE DATABASE IF NOT EXISTS retail_analytics;


-- 2   Dimension Tables Create

-- 2.1  Product Dimension

CREATE TABLE retail_analytics.dim_products AS
SELECT
    product_id,
    product_name,
    category,
    unit_cost,
    selling_price,
    reorder_level
FROM products;


-- 2.2  Store Dimension

CREATE TABLE retail_analytics.dim_stores AS
SELECT
    store_id,
    store_name,
    city,
    region
FROM stores;


-- 2.3  Supplier Dimension

CREATE TABLE retail_analytics.dim_suppliers AS
SELECT
    supplier_id,
    supplier_name,
    city
FROM suppliers;


-- 3  Fact Tables Create

-- 3.1 Sales Fact Table

CREATE TABLE retail_analytics.fact_sales AS
SELECT
    sale_id,
    store_id,
    product_id,
    sale_date,
    quantity_sold,
    unit_selling_price,
    quantity_sold * unit_selling_price AS revenue
FROM sales;


-- 3.2  Inventory Fact Table

CREATE TABLE retail_analytics.fact_inventory AS
SELECT
    i.store_id,
    i.product_id,
    i.stock_qty,
    i.last_updated,
    i.stock_qty * p.unit_cost AS inventory_value
FROM inventory i
JOIN products p
ON i.product_id = p.product_id;


-- 3.3  Purchase Orders Fact Table

CREATE TABLE retail_analytics.fact_purchase_orders AS
SELECT
    order_id,
    supplier_id,
    store_id,
    product_id,
    order_date,
    expected_delivery_date,
    actual_delivery_date,
    quantity_ordered,
    order_status,

    DATEDIFF(
        actual_delivery_date,
        expected_delivery_date
    ) AS delay_days,

    CASE
        WHEN order_status = 'Cancelled'
            THEN 'Cancelled'
        WHEN actual_delivery_date IS NULL
            THEN 'Not Delivered'
        WHEN actual_delivery_date <= expected_delivery_date
            THEN 'On Time'
        ELSE 'Late'
    END AS delivery_status

FROM purchase_orders;


-- 4  Analytical Tables Verify

USE retail_analytics;

SHOW TABLES;


SELECT 'dim_products' AS table_name, COUNT(*) AS records
FROM dim_products

UNION ALL

SELECT 'dim_stores', COUNT(*)
FROM dim_stores

UNION ALL

SELECT 'dim_suppliers', COUNT(*)
FROM dim_suppliers

UNION ALL

SELECT 'fact_sales', COUNT(*)
FROM fact_sales

UNION ALL

SELECT 'fact_inventory', COUNT(*)
FROM fact_inventory

UNION ALL

SELECT 'fact_purchase_orders', COUNT(*)
FROM fact_purchase_orders;



-- 5  Revenue & Inventory Verify Karo


SELECT SUM(revenue) AS total_revenue
FROM retail_analytics.fact_sales;

SELECT SUM(inventory_value) AS total_inventory_value
FROM retail_analytics.fact_inventory;




