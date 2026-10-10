-- BrewFlow PostgreSQL Teil 3
-- Unveraendert aus den SQL-Abschnitten des Ergebnisberichts exportiert.
-- Abschnitte einzeln in der dokumentierten Reihenfolge ausfuehren.
-- Erstinstallation und Pruefungen. Kein automatischer Gesamtlauf.


-- Ziel und bestätigtes Ergebnis


-- Architektur und Ausführungsreihenfolge


-- Anpassungen an der Aufgabenvorlage


-- Schritt 1 Staging erstellen

-- Teil 3 Schritt 1 Staging erstellen
CREATE SCHEMA IF NOT EXISTS brewflow_staging;
CREATE TABLE IF NOT EXISTS brewflow_staging.stg_customers
    (LIKE brewflow_oltp.customers);
CREATE TABLE IF NOT EXISTS brewflow_staging.stg_stores
    (LIKE brewflow_oltp.stores);
CREATE TABLE IF NOT EXISTS brewflow_staging.stg_products
    (LIKE brewflow_oltp.products);
CREATE TABLE IF NOT EXISTS brewflow_staging.stg_orders
    (LIKE brewflow_oltp.orders);
CREATE TABLE IF NOT EXISTS brewflow_staging.stg_order_items
    (LIKE brewflow_oltp.order_items);

-- Kontrolle Fünf Staging Tabellen
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'brewflow_staging'
  AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- Schritt 2 OLTP Daten ins Staging kopieren

-- 01_copy_to_staging.sql
-- Staging vollständig aus der OLTP neu laden
BEGIN;
TRUNCATE TABLE
    brewflow_staging.stg_customers,
    brewflow_staging.stg_stores,
    brewflow_staging.stg_products,
    brewflow_staging.stg_orders,
    brewflow_staging.stg_order_items;

INSERT INTO brewflow_staging.stg_customers
SELECT * FROM brewflow_oltp.customers;
INSERT INTO brewflow_staging.stg_stores
SELECT * FROM brewflow_oltp.stores;
INSERT INTO brewflow_staging.stg_products
SELECT * FROM brewflow_oltp.products;
INSERT INTO brewflow_staging.stg_orders
SELECT * FROM brewflow_oltp.orders;
INSERT INTO brewflow_staging.stg_order_items
SELECT * FROM brewflow_oltp.order_items;
COMMIT;

-- Kontrolle Erwartet 10 / 5 / 8 / 22 / 32
SELECT 'stg_customers' AS tbl, COUNT(*) AS rows
FROM brewflow_staging.stg_customers
UNION ALL SELECT 'stg_stores', COUNT(*)
FROM brewflow_staging.stg_stores
UNION ALL SELECT 'stg_products', COUNT(*)
FROM brewflow_staging.stg_products
UNION ALL SELECT 'stg_orders', COUNT(*)
FROM brewflow_staging.stg_orders
UNION ALL SELECT 'stg_order_items', COUNT(*)
FROM brewflow_staging.stg_order_items;

-- Schritt 3 Dimensionen laden

-- 02_load_dimensions.sql
BEGIN;

-- Kunden Geänderte Loyalty Versionen beenden
UPDATE brewflow_warehouse.dim_customer dc
SET effective_to = CURRENT_DATE - 1,
    is_current = FALSE
FROM brewflow_staging.stg_customers src
WHERE dc.customer_id = src.customer_id
  AND dc.is_current = TRUE
  AND dc.loyalty_tier IS DISTINCT FROM src.loyalty_tier;

-- Kunden Neue oder geänderte Versionen ergänzen
INSERT INTO brewflow_warehouse.dim_customer (
    customer_id, first_name, last_name, email, city,
    loyalty_tier, effective_from, effective_to, is_current
)
SELECT
    src.customer_id, src.first_name, src.last_name,
    src.email, src.city, src.loyalty_tier,
    CASE
        WHEN EXISTS (
            SELECT 1 FROM brewflow_warehouse.dim_customer hist
            WHERE hist.customer_id = src.customer_id
        ) THEN CURRENT_DATE
        ELSE COALESCE(
            (SELECT MIN(o.order_date)
             FROM brewflow_staging.stg_orders o
             WHERE o.customer_id = src.customer_id),
            src.joined_date, CURRENT_DATE
        )
    END,
    NULL, TRUE
FROM brewflow_staging.stg_customers src
WHERE NOT EXISTS (
    SELECT 1 FROM brewflow_warehouse.dim_customer dc
    WHERE dc.customer_id = src.customer_id
      AND dc.is_current = TRUE
);

-- Kunden Übrige Attribute nach Type 1 aktualisieren
UPDATE brewflow_warehouse.dim_customer dc
SET first_name = src.first_name,
    last_name = src.last_name,
    email = src.email,
    city = src.city
FROM brewflow_staging.stg_customers src
WHERE dc.customer_id = src.customer_id
  AND dc.is_current = TRUE;

-- Schritt 3 Produkte Filialen und Kalender

-- 02_load_dimensions.sql Fortsetzung
-- Produkte Type 1 mit stabilen Surrogatschlüsseln
UPDATE brewflow_warehouse.dim_product dp
SET name = src.name, category = src.category,
    unit_price = src.unit_price
FROM brewflow_staging.stg_products src
WHERE dp.product_id = src.product_id;

INSERT INTO brewflow_warehouse.dim_product (
    product_id, name, category, unit_price
)
SELECT src.product_id, src.name, src.category, src.unit_price
FROM brewflow_staging.stg_products src
WHERE NOT EXISTS (
    SELECT 1 FROM brewflow_warehouse.dim_product dp
    WHERE dp.product_id = src.product_id
);

-- Filialen Type 1 mit stabilen Surrogatschlüsseln
UPDATE brewflow_warehouse.dim_store ds
SET name = src.name, city = src.city, country = src.country
FROM brewflow_staging.stg_stores src
WHERE ds.store_id = src.store_id;

INSERT INTO brewflow_warehouse.dim_store (store_id, name, city, country)
SELECT src.store_id, src.name, src.city, src.country
FROM brewflow_staging.stg_stores src
WHERE NOT EXISTS (
    SELECT 1 FROM brewflow_warehouse.dim_store ds
    WHERE ds.store_id = src.store_id
);

-- dim_channel Bereits in Teil 2 befüllt
-- Kalender 2020 bis 2030 erzeugen
INSERT INTO brewflow_warehouse.dim_date (
    date_sk, calendar_date, year, quarter, month,
    month_name, day_of_week, is_weekend
)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INT,
    d::DATE,
    EXTRACT(YEAR FROM d)::INT,
    EXTRACT(QUARTER FROM d)::INT,
    EXTRACT(MONTH FROM d)::INT,
    TO_CHAR(d, 'FMMonth'),
    TO_CHAR(d, 'FMDay'),
    EXTRACT(ISODOW FROM d) IN (6, 7)
FROM GENERATE_SERIES(
    TIMESTAMP '2020-01-01',
    TIMESTAMP '2030-12-31',
    INTERVAL '1 day'
) AS gs(d)
ON CONFLICT (date_sk) DO NOTHING;
COMMIT;

-- Schritt 3 Dimensionen überprüfen

-- Skript 02 Kontrolle Dimensionen
-- Erwartet 10 / 10 / 8 / 5 / 2 / 4018
SELECT 'dim_customer' AS tbl, COUNT(*) AS rows
FROM brewflow_warehouse.dim_customer
UNION ALL SELECT 'dim_customer_current', COUNT(*)
FROM brewflow_warehouse.dim_customer WHERE is_current = TRUE
UNION ALL SELECT 'dim_product', COUNT(*)
FROM brewflow_warehouse.dim_product
UNION ALL SELECT 'dim_store', COUNT(*)
FROM brewflow_warehouse.dim_store
UNION ALL SELECT 'dim_channel', COUNT(*)
FROM brewflow_warehouse.dim_channel
UNION ALL SELECT 'dim_date', COUNT(*)
FROM brewflow_warehouse.dim_date;

-- Schritt 4 Bestellpositionen laden

-- 03_load_facts.sql
BEGIN;

-- Eindeutigkeit der Quellposition sichern
CREATE UNIQUE INDEX IF NOT EXISTS uq_fact_order_items_order_item_id
ON brewflow_warehouse.fact_order_items (order_item_id);

-- Fakten mit zeitlicher Kundenzuordnung laden
INSERT INTO brewflow_warehouse.fact_order_items (
    order_item_id, order_id, customer_sk, product_sk,
    store_sk, channel_sk, date_sk, quantity, unit_price
)
SELECT
    oi.order_item_id, oi.order_id,
    dc.customer_sk, dp.product_sk, ds.store_sk,
    dch.channel_sk, dd.date_sk, oi.quantity, oi.unit_price
FROM brewflow_staging.stg_order_items oi
JOIN brewflow_staging.stg_orders o
    ON oi.order_id = o.order_id
JOIN brewflow_warehouse.dim_customer dc
    ON o.customer_id = dc.customer_id
   AND o.order_date >= dc.effective_from
   AND (dc.effective_to IS NULL
        OR o.order_date <= dc.effective_to)
JOIN brewflow_warehouse.dim_product dp
    ON oi.product_id = dp.product_id
JOIN brewflow_warehouse.dim_store ds
    ON o.store_id = ds.store_id
JOIN brewflow_warehouse.dim_channel dch
    ON o.channel = dch.channel
JOIN brewflow_warehouse.dim_date dd
    ON o.order_date = dd.calendar_date
ON CONFLICT (order_item_id) DO NOTHING;
COMMIT;

-- Schritt 4 Vollständigkeit der Fakten prüfen

-- Skript 03 Kontrolle Geladene Bestellpositionen
-- Erwartet 32 / 32 / 32 / 0
SELECT
    (SELECT COUNT(*)
     FROM brewflow_staging.stg_order_items) AS staging_positions,
    COUNT(*) AS fact_rows,
    COUNT(DISTINCT f.order_item_id) AS unique_positions,
    (
        SELECT COUNT(*)
        FROM brewflow_staging.stg_order_items oi
        WHERE NOT EXISTS (
            SELECT 1
            FROM brewflow_warehouse.fact_order_items loaded
            WHERE loaded.order_item_id = oi.order_item_id
        )
    ) AS missing_positions
FROM brewflow_warehouse.fact_order_items f;

-- Schritt 5 Umsatz nach Kategorie und Kanal

-- Ende zu Ende Prüfung Umsatz nach Produktkategorie
SELECT dp.category, SUM(f.revenue) AS total_revenue
FROM brewflow_warehouse.fact_order_items f
JOIN brewflow_warehouse.dim_product dp
    ON f.product_sk = dp.product_sk
GROUP BY dp.category
ORDER BY total_revenue DESC;

-- Ende zu Ende Prüfung Umsatz nach Verkaufskanal
SELECT dch.channel, SUM(f.revenue) AS total_revenue
FROM brewflow_warehouse.fact_order_items f
JOIN brewflow_warehouse.dim_channel dch
    ON f.channel_sk = dch.channel_sk
GROUP BY dch.channel
ORDER BY dch.channel;

-- Schritt 5 Nachweise der Umsatzauswertungen


-- Schritt 5 Zweiten Durchlauf validieren

-- Kontrolle nach dem zweiten Pipeline Durchlauf
SELECT 'stg_customers' AS check_name, COUNT(*) AS value
FROM brewflow_staging.stg_customers
UNION ALL SELECT 'stg_stores', COUNT(*)
FROM brewflow_staging.stg_stores
UNION ALL SELECT 'stg_products', COUNT(*)
FROM brewflow_staging.stg_products
UNION ALL SELECT 'stg_orders', COUNT(*)
FROM brewflow_staging.stg_orders
UNION ALL SELECT 'stg_order_items', COUNT(*)
FROM brewflow_staging.stg_order_items
UNION ALL SELECT 'dim_customer', COUNT(*)
FROM brewflow_warehouse.dim_customer
UNION ALL SELECT 'dim_customer_current', COUNT(*)
FROM brewflow_warehouse.dim_customer WHERE is_current = TRUE
UNION ALL SELECT 'dim_product', COUNT(*)
FROM brewflow_warehouse.dim_product
UNION ALL SELECT 'dim_store', COUNT(*)
FROM brewflow_warehouse.dim_store
UNION ALL SELECT 'dim_channel', COUNT(*)
FROM brewflow_warehouse.dim_channel
UNION ALL SELECT 'dim_date', COUNT(*)
FROM brewflow_warehouse.dim_date
UNION ALL SELECT 'fact_order_items', COUNT(*)
FROM brewflow_warehouse.fact_order_items
UNION ALL SELECT 'unique_order_items', COUNT(DISTINCT order_item_id)
FROM brewflow_warehouse.fact_order_items
UNION ALL SELECT 'total_revenue', SUM(revenue)
FROM brewflow_warehouse.fact_order_items;

-- Schritt 5 Nachweis des zweiten Durchlaufs


-- Abschluss und Geltungsbereich

