-- # BrewFlow Pipeline — Datenherkunftsübersicht (Lineage)
-- 
-- ## Pipeline-Architektur
-- 
-- ```
-- workspace.brewflow_oltp  →  workspace.brewflow_staging  →  workspace.brewflow_warehouse
-- 5 Quelltabellen            5 Staging-Tabellen           5 Dimensionen + 1 Faktentabelle
-- ```
-- 
-- ## Lademethode pro Ebene
-- 
-- | Ebene | Methode | Beschreibung |
-- |---|---|---|
-- | OLTP → Staging | `INSERT OVERWRITE` | Vollständige Kopie bei jedem Lauf; keine Delta-Logik |
-- | Staging → Dimensionen | `MERGE` / `INSERT` | SCD2 für Kunden, Type 1 für Produkte/Filialen, Referenz für Kanäle, Generierung für Kalender |
-- | Staging → Faktentabelle | `MERGE` auf `order_item_id` | Idempotent — bereits geladene Positionen werden übersprungen |
-- 
-- ## Spaltenebene Lineage: OLTP → Staging → Warehouse
-- 
-- ### customers → stg_customers → dim_customer
-- 
-- | OLTP-Spalte | Staging-Spalte | Warehouse-Spalte | Hinweis |
-- |---|---|---|---|
-- | customer_id | customer_id | dim_customer.customer_id | Natürlicher Schlüssel (NOT NULL) |
-- | first_name | first_name | dim_customer.first_name | Type 1 innerhalb der aktuellen Kundenversion |
-- | last_name | last_name | dim_customer.last_name | Type 1 innerhalb der aktuellen Kundenversion |
-- | email | email | dim_customer.email | Type 1 innerhalb der aktuellen Kundenversion |
-- | city | city | dim_customer.city | Type 1 innerhalb der aktuellen Kundenversion |
-- | loyalty_tier | loyalty_tier | dim_customer.loyalty_tier | **SCD2-getrackt** — neue Version bei Änderung |
-- | joined_date | joined_date | dim_customer.effective_from | Erste Version: effective_from = joined_date |
-- | — | — | dim_customer.customer_sk | **IDENTITY-Schlüssel** — BIGINT GENERATED ALWAYS AS IDENTITY |
-- | — | — | dim_customer.effective_to | SCD2 — NULL bei aktueller Version, sonst Enddatum |
-- | — | — | dim_customer.is_current | SCD2 — TRUE bei aktueller Version |
-- 
-- ### stores → stg_stores → dim_store
-- 
-- | OLTP-Spalte | Staging-Spalte | Warehouse-Spalte | Hinweis |
-- |---|---|---|---|
-- | store_id | store_id | dim_store.store_id | Natürlicher Schlüssel (NOT NULL) |
-- | name | name | dim_store.name | Type 1 — vor Ort aktualisiert |
-- | city | city | dim_store.city | Type 1 — vor Ort aktualisiert |
-- | country | country | dim_store.country | Type 1 — vor Ort aktualisiert |
-- | opened_date | opened_date | — | Nicht in Warehouse übernommen |
-- | — | — | dim_store.store_sk | **IDENTITY-Schlüssel** — BIGINT GENERATED ALWAYS AS IDENTITY, stabil |
-- 
-- ### products → stg_products → dim_product
-- 
-- | OLTP-Spalte | Staging-Spalte | Warehouse-Spalte | Hinweis |
-- |---|---|---|---|
-- | product_id | product_id | dim_product.product_id | Natürlicher Schlüssel (NOT NULL) |
-- | name | name | dim_product.name | Type 1 — vor Ort aktualisiert |
-- | category | category | dim_product.category | Type 1 — vor Ort aktualisiert |
-- | unit_price | unit_price | dim_product.unit_price | Type 1 — vor Ort aktualisiert |
-- | — | — | dim_product.product_sk | **IDENTITY-Schlüssel** — BIGINT GENERATED ALWAYS AS IDENTITY, stabil |
-- 
-- ### orders → stg_orders → dim_channel / fact_order_items
-- 
-- | OLTP-Spalte | Staging-Spalte | Warehouse-Spalte | Hinweis |
-- |---|---|---|---|
-- | order_id | order_id | fact_order_items.order_id | Degenerate Dimension (NOT NULL) |
-- | customer_id | customer_id | fact_order_items.customer_sk | → Temporaler Join mit dim_customer |
-- | store_id | store_id | fact_order_items.store_sk | → Join mit dim_store auf store_id |
-- | order_date | order_date | fact_order_items.date_sk | → Join mit dim_date auf calendar_date |
-- | channel | channel | fact_order_items.channel_sk | Lookup in dim_channel auf channel; Dimension aus festen Referenzwerten |
-- | — | — | dim_channel.channel_group | **Fester Kanalwert** — `Physical` / `Digital` |
-- | — | — | dim_channel.channel_sk | **IDENTITY-Schlüssel** — BIGINT GENERATED ALWAYS AS IDENTITY |
-- | total_amount | total_amount | — | Nicht in Faktentabelle übernommen |
-- 
-- ### order_items → stg_order_items → fact_order_items
-- 
-- | OLTP-Spalte | Staging-Spalte | Warehouse-Spalte | Hinweis |
-- |---|---|---|---|
-- | order_item_id | order_item_id | fact_order_items.order_item_id | Natürlicher Schlüssel — MERGE-Key (NOT NULL) |
-- | order_id | order_id | fact_order_items.order_id | Direkt aus stg_order_items übernommen; zusätzlich Join mit stg_orders |
-- | product_id | product_id | fact_order_items.product_sk | → Join mit dim_product auf product_id |
-- | quantity | quantity | fact_order_items.quantity | Kennzahl |
-- | unit_price | unit_price | fact_order_items.unit_price | Einzelpreis aus order_items |
-- | — | — | fact_order_items.order_item_sk | **IDENTITY-Schlüssel** — BIGINT GENERATED ALWAYS AS IDENTITY |
-- | — | — | fact_order_items.revenue | **GENERATED ALWAYS** — CAST(quantity * unit_price AS DECIMAL(8,2)) |
-- 
-- ### dim_date — generierte Kalenderdimension (keine OLTP-Quelle)
-- 
-- | Warehouse-Spalte | Hinweis |
-- |---|---|
-- | dim_date.date_sk | **Generiert** — INT im Format YYYYMMDD (NOT NULL) |
-- | dim_date.calendar_date | **Generiert** — SEQUENCE 2020-01-01 bis 2030-12-31 (NOT NULL) |
-- | dim_date.year | **Generiertes Kalenderattribut** — YEAR(calendar_date) |
-- | dim_date.quarter | **Generiertes Kalenderattribut** — QUARTER(calendar_date) |
-- | dim_date.month | **Generiertes Kalenderattribut** — MONTH(calendar_date) |
-- | dim_date.month_name | **Generiertes Kalenderattribut** — DATE_FORMAT(cal, 'MMMM') |
-- | dim_date.day_of_week | **Generiertes Kalenderattribut** — DATE_FORMAT(cal, 'EEEE') |
-- | dim_date.is_weekend | **Generiertes Kalenderattribut** — DAYOFWEEK(cal) IN (1, 7) |
-- Hinweis: Dimensionsverweise sind keine erzwungenen FK-Constraints.
-- Wiederholbarkeit ist auf unveränderten Quelldaten geprüft.










-- ============================================================
-- Script : 03_copy_to_staging
-- Purpose: Vollständige Kopie der OLTP Tabellen ins Staging
-- Depends: workspace.brewflow_oltp mit fünf Quelltabellen
-- Outputs: workspace.brewflow_staging mit fünf Staging Tabellen
-- Mapping: Alle Quellspalten werden unverändert übernommen
-- ============================================================

-- Kunden kopieren
INSERT OVERWRITE workspace.brewflow_staging.stg_customers
SELECT * FROM workspace.brewflow_oltp.customers;

-- Filialen kopieren
INSERT OVERWRITE workspace.brewflow_staging.stg_stores
SELECT * FROM workspace.brewflow_oltp.stores;

-- Produkte kopieren
INSERT OVERWRITE workspace.brewflow_staging.stg_products
SELECT * FROM workspace.brewflow_oltp.products;

-- Bestellungen kopieren
INSERT OVERWRITE workspace.brewflow_staging.stg_orders
SELECT * FROM workspace.brewflow_oltp.orders;

-- Bestellpositionen kopieren
INSERT OVERWRITE workspace.brewflow_staging.stg_order_items
SELECT * FROM workspace.brewflow_oltp.order_items;