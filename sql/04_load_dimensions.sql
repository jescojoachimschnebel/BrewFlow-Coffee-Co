-- # BrewFlow Pipeline — Datenwörterbuch der Dimensionen
-- 
-- ## dim_customer (SCD Type 2 — getracktes Attribut: loyalty_tier)
-- 
-- | Spalte | Datentyp | Beschreibung |
-- |---|---|---|
-- | customer_sk | BIGINT GENERATED ALWAYS AS IDENTITY | Surrogatschlüssel; wird automatisch vergeben und ist nicht manuell einfügbar |
-- | customer_id | INT NOT NULL | Natürlicher Schlüssel aus customers.customer_id; Join-Key zum Fakt |
-- | first_name | STRING | Vorname; beschreibend — bei jedem Lauf vor Ort aktualisiert (keine Historie) |
-- | last_name | STRING | Nachname; beschreibend — bei jedem Lauf vor Ort aktualisiert (keine Historie) |
-- | email | STRING | E-Mail-Adresse; beschreibend — vor Ort aktualisiert |
-- | city | STRING | Wohnort; beschreibend — vor Ort aktualisiert |
-- | loyalty_tier | STRING | Loyalty-Stufe (Bronze/Silver/Gold); SCD2-getrackt — Änderung erzeugt neue Version |
-- | effective_from | DATE NOT NULL | Gültig-ab-Datum; erste Version = COALESCE(joined_date, DATE 2020-01-01), Folgeversionen = CURRENT_DATE() |
-- | effective_to | DATE | Gültig-bis-Datum; NULL für aktuell gültige Version, sonst DATE_SUB(CURRENT_DATE(), 1) |
-- | is_current | BOOLEAN | TRUE für die aktuell gültige Version, FALSE für historische Versionen |
-- 
-- **Annahme zur initialen Loyalty-Historie:** Die OLTP-Quelle speichert nur den aktuellen
-- loyalty_tier pro Kunde — es gibt keine Historie von Tier-Wechseln im Quellsystem. Daher
-- wird angenommen, dass der aktuelle loyalty_tier-Wert rückwirkend ab joined_date gilt.
-- Die erste SCD2-Version jedes Kunden erhält effective_from = joined_date. Da alle ursprünglichen 10
-- joined_date-Werte vor dem 3. Januar 2024 liegen (ältester: 2020-05-30), deckt die erste
-- Version auch eine verspätet eintreffende Bestellung vom 3. Januar 2024 ab.
-- 
-- ## dim_product (SCD Type 1)
-- 
-- | Spalte | Datentyp | Beschreibung |
-- |---|---|---|
-- | product_sk | BIGINT GENERATED ALWAYS AS IDENTITY | Surrogatschlüssel; stabil — bleibt bei MERGE-Updates erhalten |
-- | product_id | INT NOT NULL | Natürlicher Schlüssel aus products.product_id; MERGE-Match-Key |
-- | name | STRING | Produktname; Type 1 — vor Ort überschrieben bei Änderung |
-- | category | STRING | Kategorie (Coffee/Tea/Food/Merchandise); Type 1 — vor Ort überschrieben |
-- | unit_price | DECIMAL(6,2) | Einzelpreis; Type 1 — vor Ort überschrieben bei Änderung |
-- 
-- **Lademethode:** MERGE auf product_id; WHEN MATCHED → UPDATE aller beschreibenden
-- Spalten; WHEN NOT MATCHED → INSERT. product_sk wird nie neu vergeben.
-- 
-- ## dim_store (SCD Type 1)
-- 
-- | Spalte | Datentyp | Beschreibung |
-- |---|---|---|
-- | store_sk | BIGINT GENERATED ALWAYS AS IDENTITY | Surrogatschlüssel; stabil — bleibt bei MERGE-Updates erhalten |
-- | store_id | INT NOT NULL | Natürlicher Schlüssel aus stores.store_id; MERGE-Match-Key |
-- | name | STRING | Filialname; Type 1 — vor Ort überschrieben bei Änderung |
-- | city | STRING | Stadt; Type 1 — vor Ort überschrieben bei Änderung |
-- | country | STRING | Land; Type 1 — vor Ort überschrieben bei Änderung |
-- 
-- **Lademethode:** MERGE auf store_id; WHEN MATCHED → UPDATE aller beschreibenden
-- Spalten; WHEN NOT MATCHED → INSERT. store_sk wird nie neu vergeben.
-- 
-- ## dim_channel (Type 1 — Referenzdimension)
-- 
-- | Spalte | Datentyp | Beschreibung |
-- |---|---|---|
-- | channel_sk | BIGINT GENERATED ALWAYS AS IDENTITY | Surrogatschlüssel; automatisch vergeben |
-- | channel | STRING NOT NULL | Kanalname; feste Werte `in-store` und `mobile-app`; MERGE-Match-Key |
-- | channel_group | STRING | Kanalgruppe; feste Werte `Physical` (für in-store) und `Digital` (für mobile-app) |
-- 
-- **Lademethode:** MERGE mit statischem UNION ALL zweier fester Wertepaare
-- (`in-store`/`Physical`, `mobile-app`/`Digital`). Die Dimension wird aus diesen festen
-- Referenzwerten befüllt; stg_orders.channel dient beim Faktenladen als Lookup-Wert.
-- 
-- ## dim_date (Kalenderdimension 2020–2030)
-- 
-- | Spalte | Datentyp | Beschreibung |
-- |---|---|---|
-- | date_sk | INT NOT NULL | Surrogatschlüssel im Format YYYYMMDD (z. B. 20240105); manuell generiert, kein IDENTITY |
-- | calendar_date | DATE NOT NULL | Kalenderdatum; SEQUENCE von 2020-01-01 bis 2030-12-31 (4 018 Tage) |
-- | year | INT | Jahrgang (2020–2030); generiert aus YEAR(calendar_date) |
-- | quarter | INT | Quartal (1–4); generiert aus QUARTER(calendar_date) |
-- | month | INT | Monat (1–12); generiert aus MONTH(calendar_date) |
-- | month_name | STRING | Monatsname (January … December); generiert aus DATE_FORMAT(cal, 'MMMM') |
-- | day_of_week | STRING | Wochentagname (Monday … Sunday); generiert aus DATE_FORMAT(cal, 'EEEE') |
-- | is_weekend | BOOLEAN | TRUE an Wochenenden; generiert aus DAYOFWEEK(cal) IN (1, 7) |
-- 
-- **Lademethode:** MERGE auf date_sk; WHEN NOT MATCHED → INSERT. Erneute Berechnung
-- aller 4 018 Tage je Lauf; nur fehlende Tage werden eingefügt via EXPLODE(SEQUENCE(…)). Statisch — nach Initialladung nicht
-- mehr verändert. date_sk ist kein IDENTITY; der Schlüssel wird beim INSERT explizit
-- als CAST(DATE_FORMAT(cal, 'yyyyMMdd') AS INT) gesetzt.
-- Hinweis: Dimensionsverweise sind keine erzwungenen FK-Constraints.
-- Wiederholbarkeit ist auf unveränderten Quelldaten geprüft.










-- ============================================================
-- Script : 04_load_dimensions
-- Purpose: Dimensionen laden und Loyalty-Level historisieren
-- Depends: workspace.brewflow_staging
-- Outputs: Fünf Dimensionen in workspace.brewflow_warehouse
-- Mapping: Kunden Produkte Filialen aus Staging
--          Kanäle als Referenzdaten und Kalender generiert
-- Annahme: Initiales Loyalty-Level gilt ab joined_date
-- ============================================================

-- Kunden Schritt 1 Geänderte Versionen beenden
MERGE INTO workspace.brewflow_warehouse.dim_customer AS target
USING workspace.brewflow_staging.stg_customers AS source
ON target.customer_id = source.customer_id
   AND target.is_current = TRUE
WHEN MATCHED
     AND NOT (target.loyalty_tier <=> source.loyalty_tier)
THEN UPDATE SET
    effective_to = DATE_SUB(CURRENT_DATE(), 1),
    is_current = FALSE;

-- Kunden Schritt 2 Neue oder geänderte Versionen einfügen
-- Erstversion beginnt bei joined_date
-- Folgeversion beginnt am aktuellen Ladetag
INSERT INTO workspace.brewflow_warehouse.dim_customer (
    customer_id, first_name, last_name, email, city,
    loyalty_tier, effective_from, effective_to, is_current
)
SELECT
    src.customer_id,
    src.first_name,
    src.last_name,
    src.email,
    src.city,
    src.loyalty_tier,
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM workspace.brewflow_warehouse.dim_customer hist
            WHERE hist.customer_id = src.customer_id
        )
        THEN CURRENT_DATE()
        ELSE COALESCE(src.joined_date, DATE '2020-01-01')
    END,
    CAST(NULL AS DATE),
    TRUE
FROM workspace.brewflow_staging.stg_customers src
WHERE NOT EXISTS (
    SELECT 1
    FROM workspace.brewflow_warehouse.dim_customer dc
    WHERE dc.customer_id = src.customer_id
      AND dc.is_current = TRUE
);

-- Kunden Schritt 3 Beschreibende Attribute aktualisieren
MERGE INTO workspace.brewflow_warehouse.dim_customer AS target
USING workspace.brewflow_staging.stg_customers AS source
ON target.customer_id = source.customer_id
   AND target.is_current = TRUE
WHEN MATCHED THEN UPDATE SET
    first_name = source.first_name,
    last_name = source.last_name,
    email = source.email,
    city = source.city;

-- Produkte Type 1 mit stabilen Schlüsseln
MERGE INTO workspace.brewflow_warehouse.dim_product AS target
USING workspace.brewflow_staging.stg_products AS source
ON target.product_id = source.product_id
WHEN MATCHED THEN UPDATE SET
    name = source.name,
    category = source.category,
    unit_price = source.unit_price
WHEN NOT MATCHED THEN INSERT (
    product_id, name, category, unit_price
) VALUES (
    source.product_id, source.name,
    source.category, source.unit_price
);

-- Filialen Type 1 mit stabilen Schlüsseln
MERGE INTO workspace.brewflow_warehouse.dim_store AS target
USING workspace.brewflow_staging.stg_stores AS source
ON target.store_id = source.store_id
WHEN MATCHED THEN UPDATE SET
    name = source.name,
    city = source.city,
    country = source.country
WHEN NOT MATCHED THEN INSERT (
    store_id, name, city, country
) VALUES (
    source.store_id, source.name, source.city, source.country
);

-- Verkaufskanäle Referenzdaten laden
MERGE INTO workspace.brewflow_warehouse.dim_channel AS target
USING (
    SELECT 'in-store' AS channel, 'Physical' AS channel_group
    UNION ALL
    SELECT 'mobile-app', 'Digital'
) AS source
ON target.channel = source.channel
WHEN MATCHED THEN UPDATE SET
    channel_group = source.channel_group
WHEN NOT MATCHED THEN INSERT (
    channel, channel_group
) VALUES (
    source.channel, source.channel_group
);

-- Kalender 2020 bis einschließlich 2030
MERGE INTO workspace.brewflow_warehouse.dim_date AS target
USING (
    SELECT
        CAST(DATE_FORMAT(cal, 'yyyyMMdd') AS INT) AS date_sk,
        cal AS calendar_date,
        YEAR(cal) AS year,
        QUARTER(cal) AS quarter,
        MONTH(cal) AS month,
        DATE_FORMAT(cal, 'MMMM') AS month_name,
        DATE_FORMAT(cal, 'EEEE') AS day_of_week,
        DAYOFWEEK(cal) IN (1, 7) AS is_weekend
    FROM (
        SELECT EXPLODE(SEQUENCE(
            DATE '2020-01-01',
            DATE '2030-12-31',
            INTERVAL 1 DAY
        )) AS cal
    ) dates
) AS source
ON target.date_sk = source.date_sk
WHEN NOT MATCHED THEN INSERT (
    date_sk, calendar_date, year, quarter, month,
    month_name, day_of_week, is_weekend
) VALUES (
    source.date_sk, source.calendar_date,
    source.year, source.quarter, source.month,
    source.month_name, source.day_of_week, source.is_weekend
);