# Learnings

## Dependencies Added
- floki ~> 0.36.0 (HTML parsing)
- jason ~> 1.4.4 (JSON encoding/decoding)
- req ~> 0.5.17 (HTTP client)
- credo ~> 1.7.17 (code quality analysis, dev/test only)
- dialyxir ~> 1.4.7 (dialyzer integration, dev/test only)

## Project Structure Directories Created
- data/ - for data files
- results/ - for analysis results
- test/fixtures/ - for test data fixtures

## Configuration Notes
- All dependencies installed and mixing successfully
- Production dependencies: None (only credo and dialyxir for dev/test)
- Project using Elixir 1.19

## Lessons Learned
- Dependencies with only: [:dev, :test] and runtime: false prevent them from being loaded in production
- floki requires only dev/test, as it's for HTML scraping/analysis tasks
- jason used for JSON parsing, typically only needed in dev/test or parsing APIs
- req is for HTTP client requests
## Schema Structure (Area Module)

- **Single struct handles all area types**: `%Wahlanalyse2026Ostallgaeu.Area{}` with `type` field (:kreis, :gemeinde, :verbandsgemeinde, :stimmbezirk, :briefwahlbezirk)
- **German field names match source data**: stimmberechtigte, waehler, ungueltige, gueltige, parteien
- **parteien is a map**: `%{"CSU" => %{stimmen: 1416311, anteil: 37.3, veraenderung: -3.1}, ...}`
- **Next: Add validators and functions** (not yet - YAGNI)
- **Module conflict resolution**: Migrated from area.ex to schema.ex, disabled conflicting module with .disabled extension
