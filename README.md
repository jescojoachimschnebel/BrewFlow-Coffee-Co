# BrewFlow Coffee Co – Data Warehouse und automatisierte ETL-Pipeline

BrewFlow ist ein Abschlussprojekt zur Datenmodellierung und zum Aufbau eines Data Warehouses. Es verbindet eine operative PostgreSQL-Datenbank mit einer Staging-Ebene, einem dimensionalen Warehouse, einer automatisierten Databricks-Pipeline und einem Power-BI-Bericht.

**Dokumentierter Projektstand: 7. Oktober 2026**

## Projektziel

Bestellungen und Bestellpositionen sollen nachvollziehbar geladen und nach Produkt, Filiale, Verkaufskanal und Zeit ausgewertet werden. Änderungen des Kundenstatus werden historisiert, damit auch verspätet eintreffende Bestellungen der am Bestelldatum gültigen Kundenversion zugeordnet werden können.

## Technologien und Kompetenzen

- PostgreSQL und Databricks SQL
- Relationale Datenmodellierung und Star-Schema
- ETL über OLTP, Staging und Warehouse
- Surrogatschlüssel und Slowly Changing Dimensions (SCD Type 1 und Type 2)
- Temporale Joins und Verarbeitung verspäteter Fakten
- Datenqualität, Kontrollsummen und wiederholbare Ladevorgänge
- Databricks Lakeflow Jobs
- Power BI

## Architektur

Die Daten durchlaufen diese Ebenen:

1. **OLTP:** Fünf Quelltabellen für Kunden, Filialen, Produkte, Bestellungen und Bestellpositionen.
2. **Staging:** Vollständige Kopie der fünf Quelltabellen.
3. **Warehouse:** Fünf Dimensionen und eine Faktentabelle.
4. **Power BI:** Kennzahlen und Auswertungen auf dem Warehouse.

In PostgreSQL heißen die Schemata `brewflow_oltp`, `brewflow_staging` und `brewflow_warehouse`. Die Databricks-Version verwendet dieselben Schema-Namen im Katalog `workspace`.

## Datenmodell

**Granularität:** Eine Zeile in `fact_order_items` entspricht einer Bestellposition.

| Tabelle | Aufgabe |
|---|---|
| `dim_customer` | Kundendimension mit SCD Type 2 für `loyalty_tier` |
| `dim_product` | Produktdimension mit SCD Type 1 |
| `dim_store` | Filialdimension mit SCD Type 1 |
| `dim_channel` | Referenzdimension für `in-store` und `mobile-app` |
| `dim_date` | Kalenderdimension von 2020 bis 2030 |
| `fact_order_items` | Bestellpositionen mit Menge, Einzelpreis und Umsatz |

Der Umsatz ergibt sich aus `quantity * unit_price`. Bestellpositionen und eindeutige Bestellungen werden getrennt gezählt.

## Dokumentierte Ergebnisse

Die folgenden Werte stammen aus dem Ergebnisbericht. Sie unterscheiden den ursprünglichen Beispieldatensatz vom Endstand nach zusätzlichen Testszenarien.

| Kennzahl | Ursprünglicher Bestand | Endstand nach Tests |
|---|---:|---:|
| Aktuelle Kunden | 10 | 11 |
| Kundenversionen | 10 | 12 |
| Bestellungen | 22 | 24 |
| Bestellpositionen / Fakten | 32 | 34 |
| Fehlende Positionen nach dem Laden | 0 | 0 |
| Gesamtumsatz | 169,00 € | 177,00 € |

Der dokumentierte Endstand enthält 97,60 € Umsatz über `in-store` und 79,40 € über `mobile-app`. Die umsatzstärkste Produktkategorie ist Coffee mit 59,70 €, die umsatzstärkste Filiale BrewFlow Westside mit 51,30 €.

## Historisierung und Validierung

Die Kundendimension historisiert Änderungen des Loyalty-Status über `effective_from`, `effective_to` und `is_current`. Der temporale Join berücksichtigt das Bestelldatum. Im dokumentierten Test erhält eine verspätete Bestellung die historische Bronze-Version, obwohl die aktuelle Kundenversion bereits Silver enthält.

Der Fact-Load ergänzt nur neue `order_item_id`. Wiederholte Läufe auf unveränderten Quelldaten erzeugen keine zusätzlichen Fakten. Bereits geladene Positionen werden bei nachträglichen Quellkorrekturen nicht aktualisiert.

Zeilenanzahlen, Eindeutigkeit, fehlende Positionen und Umsätze dienen dem Abgleich von Quelle, Staging, Warehouse und BI-Bericht. In PostgreSQL bestehen Fremdschlüssel im Warehouse. Die Databricks-Skripte verwenden logische Dimensionsverweise, deren Integrität gesondert geprüft werden muss.

## Dateien und Ausführungsreihenfolge

### PostgreSQL

Die Abschnitte einzeln und vollständig in dieser Reihenfolge ausführen:

1. [Quelle und Beispieldaten](sql/BrewFlow_PostgreSQL_Teil_1_Quelle.sql)
2. [Warehouse-Struktur](sql/BrewFlow_PostgreSQL_Teil_2_Warehouse.sql)
3. [ETL und Validierungen](sql/BrewFlow_PostgreSQL_Teil_3_ETL.sql)

Diese Dateien dokumentieren Erstinstallation und Prüfungen. Sie sind kein automatischer Gesamtlauf und nicht durchgehend für eine erneute vollständige Ausführung auf bereits befüllten Schemata vorgesehen.

### Databricks

[BrewFlow Databricks Teil 4](sql/BrewFlow_Databricks_Teil_4.sql) enthält Aufbau, Migration und Testszenarien. Die einzelnen Abschnitte gemäß der [Dokumentation zu Teil 4](documentation/BrewFlow_Final_Project_Teil_4.pdf) ausführen.

Die wiederkehrende Pipeline verwendet anschließend diese Reihenfolge:

1. [03_copy_to_staging.sql](sql/03_copy_to_staging.sql)
2. [04_load_dimensions.sql](sql/04_load_dimensions.sql)
3. [05_load_facts.sql](sql/05_load_facts.sql)

PostgreSQL- und Databricks-Skripte verwenden unterschiedliche SQL-Dialekte. Vor der Ausführung müssen die jeweilige Umgebung, Kataloge und Schemata eingerichtet sein. Aufbau- und Testszenarien gehören in eine separate Übungsumgebung.

## Automatisierung

Die [Pipeline-Vorlage](pipeline/brewflow_nightly_pipeline.yml) beschreibt drei abhängige SQL-Tasks: `copy_to_staging`, `load_dimensions` und `load_facts`.

Vor Verwendung die Platzhalter für die drei Query-IDs und die SQL-Warehouse-ID durch Kennungen der eigenen Databricks-Umgebung ersetzen. Der konfigurierte Zeitplan liegt täglich um **02:00:48 Uhr in Europe/Berlin**. Die Berichte fassen ihn als 02:00-Uhr-Nachtlauf zusammen. Der Ergebnisbericht dokumentiert einen erfolgreichen Scheduler-Lauf am 7. Oktober 2026.

Die Veröffentlichung dieser Vorlage auf GitHub richtet selbst keinen Databricks-Job ein.

## Power BI

Der [Power-BI-Bericht](powerbi/BrewFlow_Final_Project.pbix) enthält eine Übersicht und eine Seite zur Datenprüfung. Er zeigt Umsätze, Bestellungen und Bestellpositionen sowie Auswertungen nach Produktkategorie, Filiale, Stadt, Kanal und Datum.

Zum Öffnen wird Power BI Desktop benötigt. Für eine Datenaktualisierung müssen die Verbindung und Berechtigungen zur eigenen Warehouse-Umgebung eingerichtet werden.

## Projektdokumentation

- [Ergebnisbericht](documentation/BrewFlow_Final_Project_Ergebnisbericht.pdf)
- [Projektzusammenfassung](documentation/BrewFlow_Final_Project_Zusammenfassung.pdf)
- [Präsentation](documentation/BrewFlow_Final_Project_Praesentation.pdf)
- [Teil 1: OLTP-Quelle](documentation/BrewFlow_Final_Project_Teil_1.pdf)
- [Teil 2: Warehouse-Modell](documentation/BrewFlow_Final_Project_Teil_2.pdf)
- [Teil 3: ETL](documentation/BrewFlow_Final_Project_Teil_3.pdf)
- [Teil 4: Databricks und Automatisierung](documentation/BrewFlow_Final_Project_Teil_4.pdf)

Die SQL-Dateien und PDFs geben den vorhandenen Projektstand wieder. Für die öffentliche Pipeline-Vorlage wurden umgebungsspezifische Kennungen durch Platzhalter ersetzt.

## Weiterentwicklung

Als nächster Schritt bietet sich die kontrollierte Verarbeitung von Korrekturen bereits geladener Bestellpositionen an. Dauerhaft protokollierte Validierungsergebnisse würden die Überwachung der Pipeline erleichtern.

## Autor

Jesco-Joachim Schnebel

Data Analytics | SQL | Data Warehousing | Business Intelligence