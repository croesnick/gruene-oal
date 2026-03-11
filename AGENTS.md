# Wahlanalyse Kommunalwahl 2026 Ostallgäu

## Coding

Follow these rules:

- DO red/green TDD
- DO use credo and dialyxir to verify the code quality
- DO YAGNI and SRP
- DO favor functional implementation patterns
- DO use the strengths of Elixir, like pattern matching in function headers, guards, ...
- DO use your Edit and Grep tools, DON'T USE bash file commands (ls, sed, find, awk, grep, ...)
- **MUST**: Always perform sanity calculations to validate data integrity. For every numeric value derived from external sources:
  - Calculate expected values independently (e.g., `anteil = stimmen / gueltige * 100`)
  - Compare with stored values and report discrepancies
  - Add validation checks to catch data corruption or parsing errors
  - Run `mix validate` regularly to verify data trustworthiness
