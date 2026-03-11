defmodule Mix.Tasks.Export.Csv do
  @moduledoc """
  Mix task to export election data to CSV.

  Usage: mix export.csv

  Generates a CSV file with electoral results for the Grüne and AfD parties.
  """

  require Logger

  @moduledoc "Exports election data to CSV format"
  @doc false
  def run(_args) do
    Logger.info("Starting CSV export...")

    # Load all data
    Logger.info("Loading election data...")
    areas = Wahlanalyse2026Ostallgaeu.Analysis.load_all_data()

    if areas == [] do
      Logger.error("No election data found. Please ensure data/ directory contains JSON files.")
      System.halt(1)
    end

    Logger.info("Found #{length(areas)} areas")

    # Generate CSV
    Logger.info("Generating CSV...")
    csv_string = Wahlanalyse2026Ostallgaeu.CsvExport.generate_csv(areas)

    # Write to file
    filepath = Path.join(File.cwd!(), "results/analyse.csv")
    Logger.info("Writing CSV to: #{filepath}")

    case Wahlanalyse2026Ostallgaeu.CsvExport.write_to_file(csv_string, filepath) do
      :ok ->
        Logger.info("✓ CSV export completed successfully!")
        Logger.info("File: #{filepath}")
        File.stat!(filepath)

      {:error, reason} ->
        Logger.error("✗ Failed to write CSV file: #{reason}")
        System.halt(1)
    end
  end
end
