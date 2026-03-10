# Wahlanalyse Kreistagswahl 2026 Ostallgäu

3#MV|## TL;DR

5#XN|> **Quick Summary**: Elixir-CLI-Skripte zum Download und zur Analyse der Kreistagswahl 2026 Ostallgäu. HTML-Scraping mit Floki, JSON-Speicherung mit Hierarchie, CSV-Export + interaktive HTML-Karten.
> 
> **Deliverables**:
> - `mix download` - Lädt alle Wahldaten (~250 JSON-Dateien)
> - `mix analyse` - Analysiert Grüne/AfD-Stärke
> - `mix export.csv` - Erstellt CSV mit Rankings
> - `mix export.map` - Erstellt interaktive HTML-Karten
> - `data/*.json` - Strukturierte Wahldaten mit Hierarchie
> - `results/analyse.csv` - CSV mit Rankings (Excel-kompatibel)
> - `results/karte_gruene.html` - Interaktive Karte: Grüne-Stärke
> - `results/karte_afd.html` - Interaktive Karte: AfD-Stärke
> - `priv/geojson/ostallgaeu.geojson` - Gemeindegrenzen für Karte
> 
> **Estimated Effort**: Medium
> **Parallel Execution**: YES - 4 waves
> **Critical Path**: Dependencies → Parser → Crawler → Download → Analyse → Export

## Context

### Original Request
- Ein Skript zum Download aller Wahldaten von https://wahlen.osrz-akdb.de/sw-p/777000/4/20260308/kreistagswahl_kreis/
- Ein Skript zur Analyse der Wahlbezirke mit starker Grünen/AfD-Präsenz
- Strukturierte JSON-Speicherung mit einfacher programmatischer Ladbarkeit

### Interview Summary
**Key Discussions**:
- **Datenformat**: JSON-Dateien (eine pro Gebiet) mit Parent-Child-Referenzen
- **Detaillierung**: Alle Ebenen (Kreis → Gemeinden/VG → Wahlbezirke)
- **Analyse-Kriterien**: Alle Gebiete sortiert, Überperformance, CSV + HTML-Karten
- **Bewerberdaten**: Ja, inklusive Einzelkandidaten-Stimmen
- **Test-Strategie**: TDD mit ExUnit, credo + dialyxir für Qualität

**Research Findings**:
- Website liefert HTML (kein JSON-API)
- Hierarchie: 1 Kreis → 10 direkte Gemeinden + 10 VGs → ~249 Wahlbezirke
- URL-Muster für alle Entity-Typen identifiziert
- Deutsches Zahlenformat: `.` als Tausendertrennzeichen, `,` als Dezimaltrennzeichen
- GeoJSON-Quelle: geofeatures-ags-germany (MIT-Lizenz, AGS-Support)

### Metis Review
**Identified Gaps** (addressed):
- HTML-Parser-Wahl: Floki (Elixir-Standard)
- JSON-Schema: Explizit definiert mit Feldnamen
- Dateinamenskonvention: `{type}_{id}.json`
- Edge Cases: Fehlende Gebiete, Null-Stimmen, Unicode


## Work Objectives

### Core Objective
Mix-Tasks für Daten-Download, -Analyse und -Export erstellen: `mix download`, `mix analyse`, `mix export.csv`, `mix export.map`. Fokus auf Grüne/AfD-Verteilung mit nutzerfreundlicher Aufbereitung.

### Concrete Deliverables
- `lib/wahlanalyse2026_ostallgaeu/parser.ex` - HTML-Parser-Modul
- `lib/wahlanalyse2026_ostallgaeu/crawler.ex` - URL-Hierarchie-Crawler
- `lib/wahlanalyse2026_ostallgaeu/analysis.ex` - Analyse-Logik
- `lib/wahlanalyse2026_ostallgaeu/csv_export.ex` - CSV-Export-Logik
- `lib/wahlanalyse2026_ostallgaeu/geojson.ex` - GeoJSON-Handling
- `lib/mix/tasks/download.ex` - Download Mix-Task
- `lib/mix/tasks/analyse.ex` - Analyse Mix-Task
- `lib/mix/tasks/export_csv.ex` - CSV-Export Mix-Task
- `lib/mix/tasks/export_map.ex` - Karten-Export Mix-Task
- `data/*.json` - ~250 JSON-Dateien mit Wahldaten
- `results/analyse.csv` - CSV mit Rankings
- `results/karte_gruene.html` - Interaktive Grüne-Karte
- `results/karte_afd.html` - Interaktive AfD-Karte

### Definition of Done
- [ ] `mix download` erstellt ~250 JSON-Dateien in `data/`
- [ ] `mix export.csv` erstellt `results/analyse.csv`
- [ ] `mix export.map` erstellt beide HTML-Karten
- [ ] `mix test` läuft durch (TDD)
- [ ] `mix credo` ohne Warnungen
- [ ] `mix dialyzer` ohne Fehler

### Must Have
- Floki für HTML-Parsing
- Jason für JSON-Encoding
- Req für HTTP-Requests
- TDD mit ExUnit
- Hierarchische JSON-Struktur
- Leaflet.js (embedded in HTML)
- GeoJSON from geofeatures-ags-germany

### Must NOT Have (Guardrails)
- KEIN Phoenix-Web-Framework
- KEINE Datenbank (Ecto/PostgreSQL)
- KEIN externes Visualisierungs-Library (nur Leaflet in HTML)
- KEIN Caching (ETS/GenServer)
- KEINE historischen Vergleiche (nur 2026)
- KEINE Landratswahl/Gemeinderatswahlen

### Core Objective
Zwei Mix-Tasks erstellen: `mix download` für Daten-Scraping und `mix analyse` für Wahlanalyse mit Fokus auf Grüne/AfD-Verteilung.

### Concrete Deliverables
- `lib/wahlanalyse2026_ostallgaeu/parser.ex` - HTML-Parser-Modul
- `lib/wahlanalyse2026_ostallgaeu/crawler.ex` - URL-Hierarchie-Crawler
- `lib/wahlanalyse2026_ostallgaeu/analysis.ex` - Analyse-Logik
- `lib/mix/tasks/download.ex` - Download Mix-Task
- `lib/mix/tasks/analyse.ex` - Analyse Mix-Task
- `data/*.json` - ~250 JSON-Dateien mit Wahldaten
- `results/heatmap.json` - Heatmap-Export

### Definition of Done
- [ ] `mix download` erstellt ~250 JSON-Dateien in `data/`
- [ ] `mix analyse` gibt Rankings aus und erstellt `results/heatmap.json`
- [ ] `mix test` läuft durch (TDD)
- [ ] `mix credo` ohne Warnungen
- [ ] `mix dialyzer` ohne Fehler

### Must Have
- Floki für HTML-Parsing
- Jason für JSON-Encoding
- HTTP-Client (Req oder HTTPoison)
- TDD mit ExUnit
- Hierarchische JSON-Struktur

### Must NOT Have (Guardrails)
- KEIN Phoenix-Web-Framework
- KEINE Datenbank (Ecto/PostgreSQL)
- KEINE Visualisierung (nur Daten-Export)
- KEIN Caching (ETS/GenServer)
- KEINE historischen Vergleiche (nur 2026)
- KEINE Landratswahl/Gemeinderatswahlen

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: YES (ExUnit)
- **Automated tests**: YES (TDD)
- **Framework**: ExUnit (Elixir built-in)
- **Quality Tools**: credo (~> 1.7), dialyxir (~> 1.4)

### QA Policy
Every task MUST include agent-executed QA scenarios.
Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

- **CLI/Scripts**: Use Bash — Run mix commands, check file existence, validate JSON

---

## Execution Strategy

113#TP|### Parallel Execution Waves

```
Wave 1 (Start Immediately — foundation):
├── Task 1: Dependencies + Project Setup [quick]
├── Task 2: JSON Schema Definition [quick]
└── Task 3: HTML Parser Module (TDD) [deep]

Wave 2 (After Wave 1 — crawling):
├── Task 4: URL Crawler Module (TDD) [deep]
└── Task 5: Download Mix Task [quick]

Wave 3 (After Wave 2 — analysis + export):
├── Task 6: Analysis Module (TDD) [deep]
├── Task 7: Analyse Mix Task [quick]
├── Task 8: CSV Export Mix Task [quick]
└── Task 9: GeoJSON Download + HTML Map Generator [visual-engineering]

Wave 4 (After Wave 3 — verification):
├── Task 10: Integration Test [deep]
└── Task 11: Quality Gates (credo + dialyzer) [quick]

Wave FINAL (After ALL tasks):
├── Task F1: Plan Compliance Audit (oracle)
├── Task F2: Code Quality Review (unspecified-high)
├── Task F3: Real Manual QA (unspecified-high)
└── Task F4: Scope Fidelity Check (deep)
```

### Dependency Matrix

- **1-3**: — — 4, 5
- **4**: 1, 3 — 5
- **5**: 1, 3, 4 — 6, 7, 8, 9
- **6**: 2, 5 — 7, 8, 9
- **7**: 5, 6 — 10
- **8**: 5, 7 — 10
- **9**: 5, 7 — 10
- **10**: 5, 8, 9 — 11, F1-F4
- **11**: 10 — F1-F4

---

145#VM|
- [ ] 1. Dependencies + Project Setup

  **What to do**:
  - Add dependencies to `mix.exs`: `{:floki, "~> 0.36"}, {:jason, "~> 1.4"}, {:req, "~> 0.5"}`
  - Add dev/test dependencies: `{:credo, "~> 1.7", only: [:dev, :test], runtime: false}, {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}`
  - Create directories: `data/`, `results/`, `test/fixtures/`
  - Add `.gitignore` entries for `data/` and `results/`

  **Must NOT do**:
  - DO NOT add Phoenix, Ecto, or any web framework
  - DO NOT add caching libraries (ETS, GenServer-based)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: [`elixir-developer`]

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 2, 3)
  - **Blocks**: Tasks 4, 5
  - **Blocked By**: None

  **References**:
  - `mix.exs:22-27` - Current deps function

  **Acceptance Criteria**:
  - [ ] `mix deps.get` runs without errors
  - [ ] Directories `data/`, `results/`, `test/fixtures/` exist

  **QA Scenarios**:
  ```
  Scenario: Dependencies install correctly
    Tool: Bash
    Steps: mix deps.get && mix deps.compile
    Expected Result: Exit code 0
    Evidence: .sisyphus/evidence/task-1-deps-install.txt
  ```

  **Commit**: YES
  - Message: `chore: add dependencies and project structure`

- [ ] 2. JSON Schema Definition

  **What to do**:
  - Create `lib/wahlanalyse2026_ostallgaeu/schema.ex` with struct definitions
  - Fields: `id`, `type`, `name`, `parent_id`, `children`, `wahlbeteiligung`, `stimmberechtigte`, `waehler`, `ungueltige`, `gueltige`, `parteien`, `bewerber`, `ergebnis_stand`

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: [`elixir-developer`]

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 3)
  - **Blocks**: Tasks 3, 6
  - **Blocked By**: None

  **Acceptance Criteria**:
  - [ ] Schema module compiles without warnings

  **QA Scenarios**:
  ```
  Scenario: Schema compiles
    Tool: Bash
    Steps: mix compile
    Expected Result: Exit code 0
    Evidence: .sisyphus/evidence/task-2-schema-compile.txt
  ```

  **Commit**: NO (groups with Task 3)

- [ ] 3. HTML Parser Module (TDD)

  **What to do**:
  - Create `lib/wahlanalyse2026_ostallgaeu/parser.ex`
  - Create test file `test/parser_test.exs`
  - Implement: `parse_kreis/1`, `parse_gemeinde/1`, `parse_stimmbezirk/1`, `parse_briefwahlbezirk/1`, `parse_german_number/1`
  - Save sample HTML to `test/fixtures/` for tests

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: [`elixir-developer`]

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2)
  - **Blocks**: Tasks 4, 5
  - **Blocked By**: None

  **Acceptance Criteria**:
  - [ ] `mix test test/parser_test.exs` passes

  **QA Scenarios**:
  ```
  Scenario: Parser tests pass
    Tool: Bash
    Steps: mix test test/parser_test.exs
    Expected Result: All tests pass
    Evidence: .sisyphus/evidence/task-3-parser-tests.txt
  ```

  **Commit**: YES
  - Message: `feat: add HTML parser module with TDD`

- [ ] 4. URL Crawler Module (TDD)

  **What to do**:
  - Create `lib/wahlanalyse2026_ostallgaeu/crawler.ex`
  - Create test file `test/crawler_test.exs`
  - Implement: `crawl_kreis/1`, `crawl_hierarchy/1`, `extract_child_urls/2`
  - Extract all ~250 URLs from the hierarchy

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: [`elixir-developer`]

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 2 (after Wave 1)
  - **Blocks**: Task 5
  - **Blocked By**: Tasks 1, 3

  **Acceptance Criteria**:
  - [ ] `mix test test/crawler_test.exs` passes
  - [ ] Crawler finds all expected URL types

  **QA Scenarios**:
  ```
  Scenario: Crawler tests pass
    Tool: Bash
    Steps: mix test test/crawler_test.exs
    Expected Result: All tests pass
    Evidence: .sisyphus/evidence/task-4-crawler-tests.txt
  ```

  **Commit**: YES
  - Message: `feat: add URL crawler module with TDD`

- [ ] 5. Download Mix Task

  **What to do**:
  - Create `lib/mix/tasks/download.ex`
  - Implement `mix download` that:
    1. Crawls all URLs
    2. Fetches HTML for each
    3. Parses to JSON structs
    4. Saves to `data/{type}_{id}.json`
  - Add progress output and error handling

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: [`elixir-developer`]

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 2 (after Task 4)
  - **Blocks**: Tasks 6, 7
  - **Blocked By**: Tasks 1, 3, 4

  **Acceptance Criteria**:
  - [ ] `mix download` creates ~250 JSON files
  - [ ] JSON files are valid and parseable

  **QA Scenarios**:
  ```
  Scenario: Download creates files
    Tool: Bash
    Steps: mix download && ls data/*.json | wc -l
    Expected Result: ~250 files
    Evidence: .sisyphus/evidence/task-5-download.txt
  ```

  **Commit**: YES
  - Message: `feat: add download mix task`

- [ ] 6. Analysis Module (TDD)

  **What to do**:
  - Create `lib/wahlanalyse2026_ostallgaeu/analysis.ex`
  - Create test file `test/analysis_test.exs`
  - Implement:
    - `load_all_data/0` - Load all JSON files
    - `rank_by_party/2` - Rank areas by party percentage
    - `above_average_areas/2` - Find areas above Kreis average
    - `export_heatmap/1` - Export heatmap JSON

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: [`elixir-developer`]

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 3 (after Wave 2)
  - **Blocks**: Task 7
  - **Blocked By**: Tasks 2, 5

  **Acceptance Criteria**:
  - [ ] `mix test test/analysis_test.exs` passes
  - [ ] Rankings are correct (top areas have highest percentages)

  **QA Scenarios**:
  ```
  Scenario: Analysis tests pass
    Tool: Bash
    Steps: mix test test/analysis_test.exs
    Expected Result: All tests pass
    Evidence: .sisyphus/evidence/task-6-analysis-tests.txt
  ```

  **Commit**: YES
  - Message: `feat: add analysis module with TDD`

366#HQ|- [ ] 7. Analyse Mix Task

  **What to do**:
  - Create `lib/mix/tasks/analyse.ex`
  - Implement `mix analyse` that:
    1. Loads all JSON data
    2. Ranks areas by Grüne and AfD percentages
    3. Prints summary to stdout (top 10, above-average count)
    4. Returns data for export tasks

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: [`elixir-developer`]

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 3 (after Task 6)
  - **Blocks**: Tasks 8, 9
  - **Blocked By**: Tasks 5, 6

  **Acceptance Criteria**:
  - [ ] `mix analyse` outputs summary to stdout

  **QA Scenarios**:
  ```
  Scenario: Analyse creates output
    Tool: Bash
    Steps: mix analyse
    Expected Result: Prints rankings summary, exit 0
    Evidence: .sisyphus/evidence/task-7-analyse.txt
  ```

  **Commit**: YES
  - Message: `feat: add analyse mix task`

- [ ] 8. CSV Export Mix Task

  **What to do**:
  - Create `lib/mix/tasks/export_csv.ex`
  - Create `lib/wahlanalyse2026_ostallgaeu/csv_export.ex`
  - Implement `mix export.csv` that:
    1. Loads all JSON data
    2. Creates `results/analyse.csv` with columns:
       - `gebiet_id`, `gebiet_name`, `gebiet_typ`, `parent_name`
       - `gruene_stimmen`, `gruene_anteil`, `gruene_rang`
       - `afd_stimmen`, `afd_anteil`, `afd_rang`
       - `ueber_durchschnitt_gruene`, `ueber_durchschnitt_afd`

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: [`elixir-developer`]

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Task 9)
  - **Blocks**: Task 11
  - **Blocked By**: Tasks 5, 7

  **Acceptance Criteria**:
  - [ ] `mix export.csv` creates `results/analyse.csv`
  - [ ] CSV is valid and opens in Excel/LibreOffice

  **QA Scenarios**:
  ```
  Scenario: CSV export works
    Tool: Bash
    Steps: mix export.csv && head -5 results/analyse.csv
    Expected Result: Valid CSV with header row
    Evidence: .sisyphus/evidence/task-8-csv.txt
  ```

  **Commit**: YES
  - Message: `feat: add CSV export`

- [ ] 9. GeoJSON Download + HTML Map Generator

  **What to do**:
  - Create `lib/mix/tasks/export_map.ex`
  - Create `lib/wahlanalyse2026_ostallgaeu/geojson.ex` for GeoJSON handling
  - Download GeoJSON for Ostallgäu municipalities from official source (BayernAtlas/Geodatenportal)
  - Create `results/karte_gruene.html` - Interactive map with color scale:
    - White (0%) → Light Green (10%) → Dark Green (20%+)
    - Hover shows: Gebietsname, Grüne %
  - Create `results/karte_afd.html` - Interactive map with color scale:
    - White (0%) → Light Blue (10%) → Dark Blue (20%+)
    - Hover shows: Gebietsname, AfD %
  - Use Leaflet.js for map rendering (embedded in HTML)

  **GeoJSON Source** (research pending):
  - Option A: BayernAtlas WFS API with AGS filter
  - Option B: Geodatenportal Bayern - Verwaltungsgebiete
  - Option C: Download manually and include in `priv/geojson/`

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering`
    - Reason: Map visualization with color scales and interactivity
  - **Skills**: [`elixir-developer`]

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Task 8)
  - **Blocks**: Task 11
  - **Blocked By**: Tasks 5, 7

  **Acceptance Criteria**:
  - [ ] GeoJSON file downloaded to `priv/geojson/ostallgaeu.geojson`
  - [ ] `mix export.map` creates both HTML files
  - [ ] HTML maps are interactive (hover, zoom)
  - [ ] Color scale matches defined gradient

  **QA Scenarios**:
  ```
  Scenario: Map export works
    Tool: Bash
    Steps: mix export.map && ls -la results/karte_*.html
    Expected Result: Both HTML files exist, contain Leaflet.js
    Evidence: .sisyphus/evidence/task-9-map.txt

  Scenario: Map opens in browser
    Tool: Playwright
    Steps: Open results/karte_afd.html, hover over a municipality
    Expected Result: Tooltip shows name and percentage
    Evidence: .sisyphus/evidence/task-9-map-interactive.png
  ```

  **Commit**: YES
  - Message: `feat: add interactive map export with Leaflet`

- [ ] 10. Integration Test

  **What to do**:
  - Create `test/integration_test.exs`
  - Test full workflow: download → analyse → export.csv → export.map
  - Verify all output files exist and are valid

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: [`elixir-developer`]

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 4 (after Wave 3)
  - **Blocks**: Task 11
  - **Blocked By**: Tasks 5, 8, 9

  **Acceptance Criteria**:
  - [ ] `mix test test/integration_test.exs` passes

  **QA Scenarios**:
  ```
  Scenario: Integration tests pass
    Tool: Bash
    Steps: mix test test/integration_test.exs
    Expected Result: All tests pass
    Evidence: .sisyphus/evidence/task-10-integration.txt
  ```

  **Commit**: YES
  - Message: `test: add integration tests`

- [ ] 11. Quality Gates (credo + dialyzer)

  **What to do**:
  - Run `mix credo` and fix all warnings
  - Run `mix dialyzer` and fix all type errors
  - Ensure `mix test` passes with full coverage

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: [`elixir-developer`]

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 4 (after Task 10)
  - **Blocked By**: Task 10

  **Acceptance Criteria**:
  - [ ] `mix credo` exits with code 0
  - [ ] `mix dialyzer` exits with code 0
  - [ ] `mix test` shows all tests passing

  **QA Scenarios**:
  ```
  Scenario: Quality gates pass
    Tool: Bash
    Steps: mix credo && mix dialyzer && mix test
    Expected Result: All exit code 0
    Evidence: .sisyphus/evidence/task-11-quality.txt
  ```

  **Commit**: YES
  - Message: `fix: resolve credo and dialyzer warnings`

559#MH|---

## Final Verification Wave (MANDATORY)

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Run `mix credo` + `mix dialyzer` + `mix test`. Review all files.
  Output: `Credo [PASS/FAIL] | Dialyzer [PASS/FAIL] | Tests [N pass/N fail] | VERDICT`

- [ ] F3. **Real Manual QA** — `unspecified-high`
  Run `mix download`, `mix analyse`, `mix export.csv`, `mix export.map`. Verify all outputs.
  Output: `Download [N files] | CSV [valid] | Maps [interactive] | VERDICT`

- [ ] F4. **Scope Fidelity Check** — `deep`
  Verify no Phoenix, no Ecto, no external visualization libraries.
  Output: `Tasks [N/N compliant] | Scope Creep [CLEAN/N issues] | VERDICT`

---

## Commit Strategy

- **Multiple atomic commits** per task (see individual tasks)
- Pre-commit: `mix test && mix credo && mix dialyzer`

---

## Success Criteria

### Verification Commands
```bash
mix deps.get          # Dependencies installiert
mix download          # ~250 JSON-Dateien in data/
mix analyse           # Zusammenfassung auf stdout
mix export.csv        # results/analyse.csv erstellt
mix export.map        # results/karte_*.html erstellt
mix test              # Alle Tests grün
mix credo             # Keine Warnungen
mix dialyzer          # Keine Typ-Fehler
```

### Final Checklist
- [ ] Alle "Must Have" implementiert
- [ ] Alle "Must NOT Have" vermieden
- [ ] Alle Tests bestanden
- [ ] Quality Gates bestanden
- [ ] CSV-Export funktioniert
- [ ] HTML-Karten sind interaktiv

---

## GeoJSON Source Reference

**Recommended**: `https://github.com/m-ad/geofeatures-ags-germany`
- License: MIT
- AGS Support: Yes (matches our Gemeinde-IDs)
- File: `11_gemeinden_hoch.geo.json`
- Filter: AGS starting with "09777" (Ostallgäu municipalities)

**Alternative**: BKG VG250 (requires registration, Shapefile conversion needed)


### Verification Commands
```bash
mix deps.get          # Dependencies installiert
mix download          # ~250 JSON-Dateien in data/
mix analyse           # Rankings + heatmap.json in results/
mix test              # Alle Tests grün
mix credo             # Keine Warnungen
mix dialyzer          # Keine Typ-Fehler
```

### Final Checklist
- [ ] Alle "Must Have" implementiert
- [ ] Alle "Must NOT Have" vermieden
- [ ] Alle Tests bestanden
- [ ] Quality Gates bestanden
