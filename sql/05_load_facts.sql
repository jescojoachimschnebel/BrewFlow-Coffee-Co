-- # BrewFlow Pipeline — Datenwörterbuch der Faktentabelle
-- 
-- ## fact_order_items (Granularität: eine Bestellposition)
-- 
-- | Spalte | Datentyp | Beschreibung |
-- |---|---|---|
-- | order_item_sk | BIGINT GENERATED ALWAYS AS IDENTITY | Surrogatschlüssel; automatisch vergeben, nicht manuell einfügbar |
-- | order_item_id | INT NOT NULL | Natürlicher Schlüssel aus order_items.order_item_id; MERGE-Match-Key |
-- | order_id | INT NOT NULL | Bestell-ID direkt aus stg_order_items.order_id; degenerate Dimension |
-- | customer_sk | BIGINT | Logischer Dimensionsverweis → dim_customer.customer_sk; via zeitlichem Join zugewiesen |
-- | product_sk | BIGINT | Logischer Dimensionsverweis → dim_product.product_sk; via Join auf product_id zugewiesen |
-- | store_sk | BIGINT | Logischer Dimensionsverweis → dim_store.store_sk; via Join auf store_id zugewiesen |
-- | channel_sk | BIGINT | Logischer Dimensionsverweis → dim_channel.channel_sk; via Join auf channel zugewiesen |
-- | date_sk | INT | Logischer Dimensionsverweis → dim_date.date_sk; via Join auf calendar_date = order_date zugewiesen |
-- | quantity | INT | Stückzahl aus stg_order_items.quantity; Kennzahl |
-- | unit_price | DECIMAL(6,2) | Einzelpreis aus stg_order_items.unit_price; stammt aus order_items, nicht aus products |
-- | revenue | DECIMAL(8,2) GENERATED ALWAYS AS (CAST(quantity * unit_price AS DECIMAL(8,2))) | **Generierte Spalte** — wird automatisch berechnet; wird im ETL-INSERT ausgelassen |
-- 
-- ## Laden-Logik
-- 
-- **Methode:** MERGE INTO fact_order_items auf order_item_id; WHEN NOT MATCHED → INSERT.
-- Bereits geladene Positionen werden übersprungen (kein WHEN MATCHED-Zweig).
-- Dadurch ist der Ladevorgang idempotent — mehrfaches Ausführen erzeugt keine Duplikate.
-- 
-- ## Join-Strategie
-- 
-- | Quell-Join | Join-Bedingung | Zweck |
-- |---|---|---|
-- | stg_order_items ⋈ stg_orders | oi.order_id = o.order_id | Liefert customer_id, store_id, channel, order_date |
-- | ⋈ dim_customer | o.customer_id = dc.customer_id AND o.order_date >= dc.effective_from AND (dc.effective_to IS NULL OR o.order_date <= dc.effective_to) | **Temporaler Join** — wählt die zum Bestelldatum gültige Kundenversion |
-- | ⋈ dim_product | oi.product_id = dp.product_id | Liefert product_sk |
-- | ⋈ dim_store | o.store_id = ds.store_id | Liefert store_sk |
-- | ⋈ dim_channel | o.channel = dch.channel | Liefert channel_sk |
-- | ⋈ dim_date | o.order_date = dd.calendar_date | Liefert date_sk |
-- 
-- ## Zeitliche Zuordnung der Kundenversion
-- 
-- Der zeitliche Join auf dim_customer wählt die SCD2-Version, deren Gültigkeitszeitraum
-- (effective_from bis effective_to) das order_date umschließt. Dies funktioniert auch für
-- verspätet eintreffende Bestellungen: Eine Bestellung vom 3. Januar 2024 wird der ersten
-- Kundenversion zugeordnet, deren effective_from = joined_date (bei den ursprünglichen 10 Kunden vor Jan 2024) ist —
-- unabhängig davon, wann die Bestellung physisch im Staging ankommt.
-- 
-- ## Kennzahlen
-- 
-- | Kennzahl | Quelle | Berechnung |
-- |---|---|---|
-- | quantity | stg_order_items.quantity | Direkt übernommen |
-- | unit_price | stg_order_items.unit_price | Direkt übernommen; stammt aus order_items, nicht aus dim_product |
-- | revenue | **Generiert** | DECIMAL(8,2) GENERATED ALWAYS AS (CAST(quantity * unit_price AS DECIMAL(8,2))) |
-- 
-- revenue wird nicht im INSERT-Statement gesetzt — die Spalte wird automatisch von
-- Delta aus quantity und unit_price berechnet, sobald die Zeile eingefügt wird.
-- Hinweis: Dimensionsverweise sind keine erzwungenen FK-Constraints.
-- Wiederholbarkeit ist auf unveränderten Quelldaten geprüft.










-- ============================================================
-- Script : 05_load_facts
-- Purpose: Bestellpositionen ins Warehouse laden
-- Depends: Staging Bestellungen und Bestellpositionen
--          Alle fünf Warehouse Dimensionen
-- Outputs: workspace.brewflow_warehouse.fact_order_items
-- Grain  : Eine Zeile pro OLTP Bestellposition
-- Mapping: quantity und unit_price aus stg_order_items
--          Kundenversion anhand des Bestelldatums
--          revenue wird automatisch berechnet
-- ============================================================

MERGE INTO workspace.brewflow_warehouse.fact_order_items AS target
USING (
    SELECT
        oi.order_item_id,
        oi.order_id,
        dc.customer_sk,
        dp.product_sk,
        ds.store_sk,
        dch.channel_sk,
        dd.date_sk,
        oi.quantity,
        oi.unit_price
    FROM workspace.brewflow_staging.stg_order_items oi
    JOIN workspace.brewflow_staging.stg_orders o
        ON oi.order_id = o.order_id

    -- Zum Bestelldatum gültige Kundenversion
    JOIN workspace.brewflow_warehouse.dim_customer dc
        ON o.customer_id = dc.customer_id
       AND o.order_date >= dc.effective_from
       AND (
           dc.effective_to IS NULL
           OR o.order_date <= dc.effective_to
       )

    JOIN workspace.brewflow_warehouse.dim_product dp
        ON oi.product_id = dp.product_id
    JOIN workspace.brewflow_warehouse.dim_store ds
        ON o.store_id = ds.store_id
    JOIN workspace.brewflow_warehouse.dim_channel dch
        ON o.channel = dch.channel
    JOIN workspace.brewflow_warehouse.dim_date dd
        ON o.order_date = dd.calendar_date
) AS source
ON target.order_item_id = source.order_item_id

-- Bereits geladene Positionen werden übersprungen
WHEN NOT MATCHED THEN INSERT (
    order_item_id,
    order_id,
    customer_sk,
    product_sk,
    store_sk,
    channel_sk,
    date_sk,
    quantity,
    unit_price
) VALUES (
    source.order_item_id,
    source.order_id,
    source.customer_sk,
    source.product_sk,
    source.store_sk,
    source.channel_sk,
    source.date_sk,
    source.quantity,
    source.unit_price
);