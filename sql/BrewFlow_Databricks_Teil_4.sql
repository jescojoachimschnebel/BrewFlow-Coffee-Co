-- BrewFlow Final Project Teil 4
-- Schritt 1 Umgebung prüfen

SELECT
    current_catalog() AS active_catalog,
    current_schema() AS active_schema;


    -- BrewFlow Final Project Teil 4
-- Schritt 1 OLTP Schema und Tabellen erstellen

USE CATALOG workspace;

CREATE SCHEMA IF NOT EXISTS brewflow_oltp;

USE SCHEMA brewflow_oltp;

-- Tabelle Kunden
CREATE TABLE customers (
    customer_id  INT NOT NULL,
    first_name   STRING NOT NULL,
    last_name    STRING NOT NULL,
    email        STRING,
    city         STRING,
    loyalty_tier STRING,
    joined_date  DATE
) USING DELTA;

-- Tabelle Filialen
CREATE TABLE stores (
    store_id    INT NOT NULL,
    name        STRING,
    city        STRING,
    country     STRING,
    opened_date DATE
) USING DELTA;

-- Tabelle Produkte
CREATE TABLE products (
    product_id INT NOT NULL,
    name       STRING,
    category   STRING,
    unit_price DECIMAL(6,2)
) USING DELTA;

-- Tabelle Bestellungen
CREATE TABLE orders (
    order_id     INT NOT NULL,
    customer_id  INT,
    store_id     INT,
    order_date   DATE,
    channel      STRING,
    total_amount DECIMAL(8,2)
) USING DELTA;

-- Tabelle Bestellpositionen
CREATE TABLE order_items (
    order_item_id INT NOT NULL,
    order_id      INT,
    product_id    INT,
    quantity      INT,
    unit_price    DECIMAL(6,2)
) USING DELTA;


-- Kontrolle Fünf OLTP Tabellen im Katalog workspace

SHOW TABLES IN workspace.brewflow_oltp;

-- BrewFlow Final Project Teil 4
-- Schritt 1 OLTP Beispieldaten laden

USE CATALOG workspace;
USE SCHEMA brewflow_oltp;

-- Kunden 10 Zeilen
INSERT INTO customers VALUES
(1, 'Sofia', 'Morales', 'sofia.m@example.com', 'Madrid', 'Bronze', DATE '2022-03-15'),
(2, 'Lucas', 'Becker', 'lucas.b@example.com', 'Berlin', 'Silver', DATE '2021-07-20'),
(3, 'Emma', 'Johansson', 'emma.j@example.com', 'Stockholm', 'Gold', DATE '2020-11-01'),
(4, 'Noah', 'Kim', 'noah.k@example.com', 'Seoul', 'Bronze', DATE '2023-01-10'),
(5, 'Amelia', 'Patel', 'amelia.p@example.com', 'London', 'Silver', DATE '2022-09-05'),
(6, 'Liam', 'Zhang', 'liam.z@example.com', 'Shanghai', 'Bronze', DATE '2023-04-18'),
(7, 'Isla', 'Rossi', 'isla.r@example.com', 'Rome', 'Gold', DATE '2021-02-28'),
(8, 'Mateo', 'Oliveira', 'mateo.o@example.com', 'Lisbon', 'Silver', DATE '2022-06-12'),
(9, 'Zara', 'Hassan', 'zara.h@example.com', 'Dubai', 'Bronze', DATE '2023-08-22'),
(10, 'James', 'O''Brien', 'james.o@example.com', 'Dublin', 'Gold', DATE '2020-05-30');

-- Filialen 5 Zeilen
INSERT INTO stores VALUES
(1, 'BrewFlow Central', 'Madrid', 'Spain', DATE '2019-03-01'),
(2, 'BrewFlow Mitte', 'Berlin', 'Germany', DATE '2020-06-15'),
(3, 'BrewFlow Old Town', 'Stockholm', 'Sweden', DATE '2020-09-10'),
(4, 'BrewFlow Westside', 'London', 'UK', DATE '2021-04-22'),
(5, 'BrewFlow Riverside', 'Lisbon', 'Portugal', DATE '2021-11-08');

-- Produkte 8 Zeilen
INSERT INTO products VALUES
(1, 'Espresso', 'Coffee', 2.50),
(2, 'Cappuccino', 'Coffee', 3.80),
(3, 'Cold Brew', 'Coffee', 4.20),
(4, 'Matcha Latte', 'Tea', 4.00),
(5, 'Chamomile Tea', 'Tea', 2.80),
(6, 'Avocado Toast', 'Food', 6.50),
(7, 'Blueberry Muffin', 'Food', 3.20),
(8, 'BrewFlow Tumbler', 'Merchandise', 18.00);

-- Bestellungen 22 Zeilen
INSERT INTO orders VALUES
(101, 1, 1, DATE '2024-01-05', 'in-store', 7.00),
(102, 2, 2, DATE '2024-01-07', 'in-store', 5.00),
(103, 3, 3, DATE '2024-01-09', 'mobile-app', 10.70),
(104, 4, 1, DATE '2024-01-12', 'in-store', 6.50),
(105, 5, 4, DATE '2024-01-14', 'mobile-app', 4.00),
(106, 1, 1, DATE '2024-01-20', 'in-store', 5.70),
(107, 6, 2, DATE '2024-01-22', 'mobile-app', 4.20),
(108, 7, 5, DATE '2024-01-25', 'in-store', 9.30),
(109, 8, 5, DATE '2024-01-28', 'in-store', 2.50),
(110, 3, 3, DATE '2024-02-02', 'mobile-app', 18.00),
(111, 9, 1, DATE '2024-02-05', 'in-store', 3.80),
(112, 10, 4, DATE '2024-02-08', 'mobile-app', 6.50),
(113, 2, 2, DATE '2024-02-11', 'in-store', 6.60),
(114, 5, 4, DATE '2024-02-14', 'mobile-app', 8.00),
(115, 1, 1, DATE '2024-02-18', 'in-store', 4.20),
(116, 8, 5, DATE '2024-02-22', 'in-store', 6.40),
(117, 4, 1, DATE '2024-02-25', 'mobile-app', 7.80),
(118, 7, 5, DATE '2024-02-28', 'in-store', 4.00),
(119, 10, 4, DATE '2024-03-03', 'in-store', 22.00),
(120, 6, 2, DATE '2024-03-07', 'mobile-app', 7.00),
(121, 3, 3, DATE '2024-03-10', 'mobile-app', 9.00),
(122, 5, 4, DATE '2024-03-14', 'in-store', 10.80);

-- Bestellpositionen 32 Zeilen
INSERT INTO order_items VALUES
(1001, 101, 2, 1, 3.80),
(1002, 101, 7, 1, 3.20),
(1003, 102, 1, 2, 2.50),
(1004, 103, 3, 1, 4.20),
(1005, 103, 6, 1, 6.50),
(1006, 104, 6, 1, 6.50),
(1007, 105, 4, 1, 4.00),
(1008, 106, 1, 1, 2.50),
(1009, 106, 7, 1, 3.20),
(1010, 107, 3, 1, 4.20),
(1011, 108, 5, 1, 2.80),
(1012, 108, 6, 1, 6.50),
(1013, 109, 1, 1, 2.50),
(1014, 110, 8, 1, 18.00),
(1015, 111, 2, 1, 3.80),
(1016, 112, 6, 1, 6.50),
(1017, 113, 2, 1, 3.80),
(1018, 113, 5, 1, 2.80),
(1019, 114, 4, 2, 4.00),
(1020, 115, 3, 1, 4.20),
(1021, 116, 7, 2, 3.20),
(1022, 117, 2, 1, 3.80),
(1023, 117, 4, 1, 4.00),
(1024, 118, 4, 1, 4.00),
(1025, 119, 8, 1, 18.00),
(1026, 119, 4, 1, 4.00),
(1027, 120, 2, 1, 3.80),
(1028, 120, 7, 1, 3.20),
(1029, 121, 1, 1, 2.50),
(1030, 121, 6, 1, 6.50),
(1031, 122, 2, 2, 3.80),
(1032, 122, 7, 1, 3.20);


-- Kontrolle OLTP Zeilenanzahlen
-- Erwartet 10 / 5 / 8 / 22 / 32

SELECT 'customers' AS tbl, COUNT(*) AS rows
FROM workspace.brewflow_oltp.customers
UNION ALL
SELECT 'stores', COUNT(*)
FROM workspace.brewflow_oltp.stores
UNION ALL
SELECT 'products', COUNT(*)
FROM workspace.brewflow_oltp.products
UNION ALL
SELECT 'orders', COUNT(*)
FROM workspace.brewflow_oltp.orders
UNION ALL
SELECT 'order_items', COUNT(*)
FROM workspace.brewflow_oltp.order_items;


-- BrewFlow Final Project Teil 4
-- Schritt 1 Kontrolle Bestellsummen
-- Erwartet 22 Zeilen und überall match = true

SELECT
    o.order_id,
    o.total_amount AS order_total,
    SUM(oi.quantity * oi.unit_price) AS items_total,
    o.total_amount = SUM(oi.quantity * oi.unit_price) AS match
FROM workspace.brewflow_oltp.orders o
JOIN workspace.brewflow_oltp.order_items oi
    ON o.order_id = oi.order_id
GROUP BY
    o.order_id,
    o.total_amount
ORDER BY o.order_id;


-- BrewFlow Final Project Teil 4
-- Schritt 1 Zusammenfassung der Bestellsummenprüfung
-- Erwartet 22 / 22 / 0

WITH totals AS (
    SELECT
        o.order_id,
        o.total_amount,
        SUM(oi.quantity * oi.unit_price) AS items_total
    FROM workspace.brewflow_oltp.orders o
    LEFT JOIN workspace.brewflow_oltp.order_items oi
        ON o.order_id = oi.order_id
    GROUP BY o.order_id, o.total_amount
)
SELECT
    COUNT(*) AS checked_orders,
    COUNT_IF(total_amount = items_total) AS matching_orders,
    COUNT_IF(
        items_total IS NULL
        OR total_amount IS NULL
        OR total_amount <> items_total
    ) AS mismatching_orders
FROM totals;

-- BrewFlow Final Project Teil 4
-- Schritt 3 Drei Schema Architektur erstellen

USE CATALOG workspace;

CREATE SCHEMA IF NOT EXISTS brewflow_oltp;
CREATE SCHEMA IF NOT EXISTS brewflow_staging;
CREATE SCHEMA IF NOT EXISTS brewflow_warehouse;

-- Kontrolle Alle drei BrewFlow Schemata anzeigen
SHOW SCHEMAS IN workspace LIKE 'brewflow*';

-- BrewFlow Final Project Teil 4
-- Schritt 4 Warehouse DDL — sechs Delta-Tabellen
-- Keine PK/FK-Constraints, keine INSERTs, keine ETL-Befehle

USE CATALOG workspace;
USE SCHEMA brewflow_warehouse;

-- 1. dim_customer (SCD Type 2 für loyalty_tier)
CREATE TABLE IF NOT EXISTS workspace.brewflow_warehouse.dim_customer (
    customer_sk    BIGINT GENERATED ALWAYS AS IDENTITY,
    customer_id    INT NOT NULL,
    first_name     STRING,
    last_name      STRING,
    email          STRING,
    city           STRING,
    loyalty_tier   STRING,
    effective_from DATE NOT NULL,
    effective_to   DATE,
    is_current     BOOLEAN
) USING DELTA;

-- 2. dim_product (SCD Type 1)
CREATE TABLE IF NOT EXISTS workspace.brewflow_warehouse.dim_product (
    product_sk     BIGINT GENERATED ALWAYS AS IDENTITY,
    product_id     INT NOT NULL,
    name           STRING,
    category       STRING,
    unit_price     DECIMAL(6,2)
) USING DELTA;

-- 3. dim_store (SCD Type 1)
CREATE TABLE IF NOT EXISTS workspace.brewflow_warehouse.dim_store (
    store_sk       BIGINT GENERATED ALWAYS AS IDENTITY,
    store_id       INT NOT NULL,
    name           STRING,
    city           STRING,
    country        STRING
) USING DELTA;

-- 4. dim_channel (Type 1 Referenzdimension)
CREATE TABLE IF NOT EXISTS workspace.brewflow_warehouse.dim_channel (
    channel_sk     BIGINT GENERATED ALWAYS AS IDENTITY,
    channel        STRING NOT NULL,
    channel_group STRING
) USING DELTA;

-- 5. dim_date (Kalenderdimension 2020–2030)
CREATE TABLE IF NOT EXISTS workspace.brewflow_warehouse.dim_date (
    date_sk        INT NOT NULL,
    calendar_date  DATE NOT NULL,
    year           INT,
    quarter        INT,
    month          INT,
    month_name     STRING,
    day_of_week    STRING,
    is_weekend     BOOLEAN
) USING DELTA;

-- 6. fact_order_items (Granularität: Bestellposition)
CREATE TABLE IF NOT EXISTS workspace.brewflow_warehouse.fact_order_items (
    order_item_sk BIGINT GENERATED ALWAYS AS IDENTITY,
    order_item_id INT NOT NULL,
    order_id      INT NOT NULL,
    customer_sk   BIGINT,
    product_sk    BIGINT,
    store_sk      BIGINT,
    channel_sk    BIGINT,
    date_sk       INT,
    quantity      INT,
    unit_price    DECIMAL(6,2),
    revenue       DECIMAL(8,2) GENERATED ALWAYS AS (CAST(quantity * unit_price AS DECIMAL(8,2)))
) USING DELTA;


-- Teil 4 Schritt 4 Kontrolle Warehouse Tabellen
-- Erwartet Sechs Tabellen

SHOW TABLES IN workspace.brewflow_warehouse;


-- Teil 4 Schritt 4 Kontrolle Kundendimension
-- Erwartet Identity Schlüssel und SCD Type 2 Spalten

SHOW CREATE TABLE workspace.brewflow_warehouse.dim_customer;


-- Teil 4 Schritt 4 Kontrolle Faktentabelle
-- Erwartet Fünf Dimensionsschlüssel und generierte Umsatzspalte

SHOW CREATE TABLE workspace.brewflow_warehouse.fact_order_items;



-- BrewFlow Final Project Teil 4
-- Schritt 5 Staging Tabellen vorbereiten
-- Leere Delta Tabellen mit den Spalten der OLTP Quelle

CREATE TABLE IF NOT EXISTS workspace.brewflow_staging.stg_customers
USING DELTA
AS SELECT * FROM workspace.brewflow_oltp.customers WHERE 1 = 0;

CREATE TABLE IF NOT EXISTS workspace.brewflow_staging.stg_stores
USING DELTA
AS SELECT * FROM workspace.brewflow_oltp.stores WHERE 1 = 0;

CREATE TABLE IF NOT EXISTS workspace.brewflow_staging.stg_products
USING DELTA
AS SELECT * FROM workspace.brewflow_oltp.products WHERE 1 = 0;

CREATE TABLE IF NOT EXISTS workspace.brewflow_staging.stg_orders
USING DELTA
AS SELECT * FROM workspace.brewflow_oltp.orders WHERE 1 = 0;

CREATE TABLE IF NOT EXISTS workspace.brewflow_staging.stg_order_items
USING DELTA
AS SELECT * FROM workspace.brewflow_oltp.order_items WHERE 1 = 0;


-- Kontrolle Erwartet fünf Staging Tabellen

SHOW TABLES IN workspace.brewflow_staging;


-- Schritt 5 Kontrolle Staging nach dem Kopieren
-- Erwartet 10 / 5 / 8 / 22 / 32

SELECT 'stg_customers' AS tbl, COUNT(*) AS rows
FROM workspace.brewflow_staging.stg_customers
UNION ALL
SELECT 'stg_stores', COUNT(*)
FROM workspace.brewflow_staging.stg_stores
UNION ALL
SELECT 'stg_products', COUNT(*)
FROM workspace.brewflow_staging.stg_products
UNION ALL
SELECT 'stg_orders', COUNT(*)
FROM workspace.brewflow_staging.stg_orders
UNION ALL
SELECT 'stg_order_items', COUNT(*)
FROM workspace.brewflow_staging.stg_order_items;


-- Kontrolle Dimensionen nach dem ersten Laden
-- Erwartet 10 / 10 / 8 / 5 / 2 / 4018

SELECT 'dim_customer' AS tbl, COUNT(*) AS rows
FROM workspace.brewflow_warehouse.dim_customer
UNION ALL
SELECT 'dim_customer_current', COUNT(*)
FROM workspace.brewflow_warehouse.dim_customer
WHERE is_current = TRUE
UNION ALL
SELECT 'dim_product', COUNT(*)
FROM workspace.brewflow_warehouse.dim_product
UNION ALL
SELECT 'dim_store', COUNT(*)
FROM workspace.brewflow_warehouse.dim_store
UNION ALL
SELECT 'dim_channel', COUNT(*)
FROM workspace.brewflow_warehouse.dim_channel
UNION ALL
SELECT 'dim_date', COUNT(*)
FROM workspace.brewflow_warehouse.dim_date;


-- Kontrolle Fakten nach dem ersten Laden
-- Erwartet 32 / 32 / 32 / 0 / 169.00

SELECT
    (
        SELECT COUNT(*)
        FROM workspace.brewflow_staging.stg_order_items
    ) AS staging_positions,
    COUNT(*) AS fact_rows,
    COUNT(DISTINCT f.order_item_id) AS unique_positions,
    (
        SELECT COUNT(*)
        FROM workspace.brewflow_staging.stg_order_items oi
        WHERE NOT EXISTS (
            SELECT 1
            FROM workspace.brewflow_warehouse.fact_order_items loaded
            WHERE loaded.order_item_id = oi.order_item_id
        )
    ) AS missing_positions,
    SUM(f.revenue) AS total_revenue
FROM workspace.brewflow_warehouse.fact_order_items f;


-- Teil 4 Kontrolle nach dem zweiten Pipeline Durchlauf
-- Erwartet 10 / 10 / 8 / 5 / 2 / 4018 / 32 / 32 / 169.00

SELECT 'dim_customer' AS check_name, COUNT(*) AS value
FROM workspace.brewflow_warehouse.dim_customer
UNION ALL
SELECT 'dim_customer_current', COUNT(*)
FROM workspace.brewflow_warehouse.dim_customer
WHERE is_current = TRUE
UNION ALL
SELECT 'dim_product', COUNT(*)
FROM workspace.brewflow_warehouse.dim_product
UNION ALL
SELECT 'dim_store', COUNT(*)
FROM workspace.brewflow_warehouse.dim_store
UNION ALL
SELECT 'dim_channel', COUNT(*)
FROM workspace.brewflow_warehouse.dim_channel
UNION ALL
SELECT 'dim_date', COUNT(*)
FROM workspace.brewflow_warehouse.dim_date
UNION ALL
SELECT 'fact_order_items', COUNT(*)
FROM workspace.brewflow_warehouse.fact_order_items
UNION ALL
SELECT 'unique_order_items', COUNT(DISTINCT order_item_id)
FROM workspace.brewflow_warehouse.fact_order_items
UNION ALL
SELECT 'total_revenue', SUM(revenue)
FROM workspace.brewflow_warehouse.fact_order_items;


-- Teil 4 Szenario A
-- Sofia von Bronze auf Silver umstellen

UPDATE workspace.brewflow_oltp.customers
SET loyalty_tier = 'Silver'
WHERE customer_id = 1;

-- Kontrolle Änderung in der Quelle
SELECT customer_id, first_name, last_name, loyalty_tier
FROM workspace.brewflow_oltp.customers
WHERE customer_id = 1;


-- Szenario A Kontrolle SCD Type 2
-- Erwartet Zwei Versionen für Sofia

SELECT
    customer_sk,
    customer_id,
    first_name,
    loyalty_tier,
    effective_from,
    effective_to,
    is_current
FROM workspace.brewflow_warehouse.dim_customer
WHERE customer_id = 1
ORDER BY effective_from;


-- Teil 4 Szenario B
-- Neuer Kunde mit Bestellung und Bestellposition

INSERT INTO workspace.brewflow_oltp.customers VALUES
(11, 'Priya', 'Sharma', 'priya.s@example.com',
 'Mumbai', 'Bronze', CURRENT_DATE());

INSERT INTO workspace.brewflow_oltp.orders VALUES
(123, 11, 3, CURRENT_DATE(), 'mobile-app', 4.20);

INSERT INTO workspace.brewflow_oltp.order_items VALUES
(1033, 123, 3, 1, 4.20);


-- Szenario B Kontrolle
-- Erwartet 11 / 12 / 33 / 173.20

SELECT 'current_customers' AS check_name, COUNT(*) AS value
FROM workspace.brewflow_warehouse.dim_customer
WHERE is_current = TRUE
UNION ALL
SELECT 'customer_versions', COUNT(*)
FROM workspace.brewflow_warehouse.dim_customer
UNION ALL
SELECT 'fact_rows', COUNT(*)
FROM workspace.brewflow_warehouse.fact_order_items
UNION ALL
SELECT 'total_revenue', SUM(revenue)
FROM workspace.brewflow_warehouse.fact_order_items;


-- Teil 4 Szenario C
-- Verspätete Bestellung aus Januar 2024 anlegen

INSERT INTO workspace.brewflow_oltp.orders VALUES
(124, 1, 1, DATE '2024-01-03', 'in-store', 3.80);

INSERT INTO workspace.brewflow_oltp.order_items VALUES
(1034, 124, 2, 1, 3.80);



-- Szenario C Kontrolle Historische Kundenzuordnung
-- Erwartet customer_sk 1, Bronze, is_current false

SELECT
    f.order_item_id,
    f.order_id,
    dd.calendar_date AS order_date,
    f.customer_sk,
    dc.loyalty_tier,
    dc.is_current,
    f.revenue
FROM workspace.brewflow_warehouse.fact_order_items f
JOIN workspace.brewflow_warehouse.dim_customer dc
    ON f.customer_sk = dc.customer_sk
JOIN workspace.brewflow_warehouse.dim_date dd
    ON f.date_sk = dd.date_sk
WHERE f.order_item_id = 1034;


-- Teil 4 Abschlusskontrolle nach Szenario A B und C
-- Erwartet 11 / 12 / 24 / 34 / 34 / 34 / 0 / 177.00

SELECT 'current_customers' AS check_name, COUNT(*) AS value
FROM workspace.brewflow_warehouse.dim_customer
WHERE is_current = TRUE
UNION ALL
SELECT 'customer_versions', COUNT(*)
FROM workspace.brewflow_warehouse.dim_customer
UNION ALL
SELECT 'source_orders', COUNT(*)
FROM workspace.brewflow_oltp.orders
UNION ALL
SELECT 'source_positions', COUNT(*)
FROM workspace.brewflow_oltp.order_items
UNION ALL
SELECT 'fact_rows', COUNT(*)
FROM workspace.brewflow_warehouse.fact_order_items
UNION ALL
SELECT 'unique_positions', COUNT(DISTINCT order_item_id)
FROM workspace.brewflow_warehouse.fact_order_items
UNION ALL
SELECT 'missing_positions', COUNT(*)
FROM workspace.brewflow_oltp.order_items oi
WHERE NOT EXISTS (
    SELECT 1
    FROM workspace.brewflow_warehouse.fact_order_items f
    WHERE f.order_item_id = oi.order_item_id
)
UNION ALL
SELECT 'total_revenue', SUM(revenue)
FROM workspace.brewflow_warehouse.fact_order_items;