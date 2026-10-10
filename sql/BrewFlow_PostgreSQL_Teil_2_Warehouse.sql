-- BrewFlow PostgreSQL Teil 2
-- Unveraendert aus den SQL-Abschnitten des Ergebnisberichts exportiert.
-- Abschnitte einzeln in der dokumentierten Reihenfolge ausfuehren.
-- Erstinstallation und Pruefungen. Kein automatischer Gesamtlauf.


-- Ziel


-- Teil A Fakten und Dimensionen bestimmen


-- Teil B SCD Entscheidungen treffen


-- Teil C Warehouse DDL schreiben

-- Teil C Schritt 1 Warehouse Schema erstellen
CREATE SCHEMA IF NOT EXISTS brewflow_warehouse;
SET search_path TO brewflow_warehouse;

-- Kontrolle Aktives Schema
SELECT current_schema() AS active_schema;
-- Teil C Kundendimension mit SCD Type 2
CREATE TABLE dim_customer (
    customer_sk INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id INT NOT NULL,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    city VARCHAR(50),
    loyalty_tier VARCHAR(20),
    effective_from DATE NOT NULL,
    effective_to DATE,
    is_current BOOLEAN DEFAULT TRUE
);

-- Teil C Produktdimension
CREATE TABLE dim_product (
    product_sk INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id INT NOT NULL,
    name VARCHAR(100),
    category VARCHAR(50),
    unit_price DECIMAL(6,2)
);

-- Teil C Filialdimension
CREATE TABLE dim_store (
    store_sk INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    store_id INT NOT NULL,
    name VARCHAR(100),
    city VARCHAR(50),
    country VARCHAR(50)
);

-- Teil C Weitere Dimensionen und Fakten

-- Teil C Kanaldimension
CREATE TABLE dim_channel (
    channel_sk INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    channel VARCHAR(20) NOT NULL,
    channel_group VARCHAR(50)
);

-- Teil C Verkaufskanäle befüllen
INSERT INTO dim_channel (channel, channel_group) VALUES
('in-store', 'Physical'),
('mobile-app', 'Digital');

-- Teil C Kalenderdimension
CREATE TABLE dim_date (
    date_sk INT PRIMARY KEY, -- Format YYYYMMDD
    calendar_date DATE NOT NULL,
    year INT,
    quarter INT,
    month INT,
    month_name VARCHAR(10),
    day_of_week VARCHAR(10),
    is_weekend BOOLEAN
);

-- Teil C Faktentabelle
-- Granularität Eine Zeile pro Bestellposition
CREATE TABLE fact_order_items (
    order_item_sk INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_item_id INT NOT NULL,
    order_id INT NOT NULL,
    customer_sk INT REFERENCES dim_customer(customer_sk),
    product_sk INT REFERENCES dim_product(product_sk),
    store_sk INT REFERENCES dim_store(store_sk),
    channel_sk INT REFERENCES dim_channel(channel_sk),
    date_sk INT REFERENCES dim_date(date_sk),
    quantity INT,
    unit_price DECIMAL(6,2),
    revenue DECIMAL(8,2)
        GENERATED ALWAYS AS (quantity * unit_price) STORED
);

-- Teil D Prüfung 1 Warehouse Tabellen

-- Teil D Prüfung 1 Warehouse Tabellen auflisten
-- Erwartet Genau sechs Tabellen
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'brewflow_warehouse'
  AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- Teil D Prüfung 2 Verkaufskanäle

-- Teil D Prüfung 2 Verkaufskanäle prüfen
SELECT channel_sk, channel, channel_group
FROM brewflow_warehouse.dim_channel
ORDER BY channel_sk;

-- Teil D Prüfung 3 SCD Struktur

-- Teil D Prüfung 3 SCD Struktur prüfen
SELECT column_name, data_type, is_nullable,
       is_identity, column_default
FROM information_schema.columns
WHERE table_schema = 'brewflow_warehouse'
  AND table_name = 'dim_customer'
  AND column_name IN (
      'customer_sk', 'effective_from',
      'effective_to', 'is_current'
  )
ORDER BY ordinal_position;

-- Teil D Prüfung 4 Dimensionsverweise

-- Teil D Prüfung 4 Fremdschlüssel prüfen
SELECT
    kcu.column_name AS fact_column,
    ccu.table_name AS dimension_table,
    ccu.column_name AS dimension_key
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_catalog = kcu.constraint_catalog
   AND tc.constraint_schema = kcu.constraint_schema
   AND tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu
    ON tc.constraint_catalog = ccu.constraint_catalog
   AND tc.constraint_schema = ccu.constraint_schema
   AND tc.constraint_name = ccu.constraint_name
WHERE tc.table_schema = 'brewflow_warehouse'
  AND tc.table_name = 'fact_order_items'
  AND tc.constraint_type = 'FOREIGN KEY'
ORDER BY kcu.column_name;

-- Teil D Prüfung 5 Generierte Umsatzspalte

-- Teil D Prüfung 5 Generierte Umsatzspalte prüfen
SELECT column_name, data_type,
       numeric_precision, numeric_scale,
       is_generated, generation_expression
FROM information_schema.columns
WHERE table_schema = 'brewflow_warehouse'
  AND table_name = 'fact_order_items'
  AND column_name = 'revenue';

-- Abschluss von Teil 2

