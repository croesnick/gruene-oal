defmodule Wahlanalyse2026Ostallgaeu.CsvExport do
  @moduledoc """
  CSV export functionality for election data.

  Generates CSV files with electoral results in German format (semicolon delimiter).
  """

  alias Wahlanalyse2026Ostallgaeu.Area

  @doc """
  Generates a CSV string from a list of areas.

  ## Parameters
    - areas: List of `Area.t()` structs to export

  ## Returns
    - CSV string with semicolon-delimited columns
  """
  @spec generate_csv([Area.t()]) :: String.t()
  def generate_csv(areas) when is_list(areas) do
    # Build lookup map for parent names
    area_map = Map.new(areas, fn a -> {a.id, a} end)

    # Discover all parties dynamically from data
    parties = discover_parties(areas)

    # Header line
    header = build_header(parties)

    # Generate data rows
    rows = Enum.map(areas, fn area -> format_area_row(area, area_map, parties) end)

    # Combine header and rows with semicolon delimiter
    [header | rows]
    |> Enum.map(fn row -> Enum.join(row, ";") end)
    |> Enum.join("\n")
  end

  defp discover_parties(areas) do
    areas
    |> Enum.flat_map(fn a -> a.parteien || [] end)
    |> Enum.map(fn p -> p.kurzbezeichnung end)
    |> Enum.uniq()
    |> Enum.sort_by(fn party ->
      # Sort by typical importance
      case party do
        "CSU" -> 1
        "FREIE WÄHLER/FWO" -> 2
        "AfD" -> 3
        "GRÜNE" -> 4
        "SPD" -> 5
        "Junges Ostallgäu" -> 6
        "ÖDP" -> 7
        "Die Linke" -> 8
        "BP" -> 9
        _ -> 10
      end
    end)
  end

  defp build_header(parties) do
    base_headers = [
      "gebiet_id",
      "gebiet_name",
      "gebiet_typ",
      "gemeinde_name"
    ]

    party_headers =
      parties
      |> Enum.flat_map(fn party ->
        [
          "#{party}_stimmen",
          "#{party}_anteil"
        ]
      end)

    base_headers ++ party_headers
  end

  defp format_area_row(area, area_map, parties) do
    # Find parent gemeinde name
    gemeinde_name = find_gemeinde_name(area, area_map)

    # Base columns
    base = [
      maybe_string(area.id),
      maybe_string(area.name),
      maybe_string(area.type |> to_string()),
      gemeinde_name
    ]

    # Party columns (stimmen and anteil for each party)
    party_columns =
      parties
      |> Enum.flat_map(fn party_name ->
        party = Area.get_party(area, party_name)
        [
          maybe_integer(party && party.stimmen),
          format_float(party && party.anteil)
        ]
      end)

    base ++ party_columns
  end


  defp find_gemeinde_name(area, area_map) do
    case area.type do
      :gemeinde ->
        # Extract name from "09777151 - Stadt Marktoberdorf" format
        extract_gemeinde_name(area.name)

      :verbandsgemeinde ->
        extract_gemeinde_name(area.name)

      :kreis ->
        extract_gemeinde_name(area.name)

      _ ->
        # For stimmbezirk/briefwahlbezirk, find parent gemeinde
        find_parent_gemeinde_name(area.parent_id, area_map)
    end
  end

  defp find_parent_gemeinde_name(parent_id, area_map) do
    case Map.get(area_map, parent_id) do
      nil -> ""
      parent ->
        case parent.type do
          :gemeinde -> extract_gemeinde_name(parent.name)
          :verbandsgemeinde -> extract_gemeinde_name(parent.name)
          _ -> find_parent_gemeinde_name(parent.parent_id, area_map)
        end
    end
  end

  defp extract_gemeinde_name(nil), do: ""
  defp extract_gemeinde_name(name) when is_binary(name) do
    # Remove AGS prefix like "09777151 - " from "09777151 - Stadt Marktoberdorf"
    case Regex.run(~r/^\d+\s*-\s*(.+)$/, name) do
      [_, clean_name] -> clean_name
      nil -> name
    end
  end

  defp maybe_string(nil), do: ""
  defp maybe_string(value) when is_binary(value), do: value
  defp maybe_string(value) when is_atom(value), do: to_string(value)

  defp maybe_integer(nil), do: ""
  defp maybe_integer(value) when is_integer(value), do: Integer.to_string(value)

  defp format_float(nil), do: ""
  defp format_float(value) when is_float(value) do
    # Format with one decimal place, using comma as decimal separator for German Excel
    formatted = :erlang.float_to_binary(value, [decimals: 1])
    String.replace(formatted, ".", ",")
  end
  defp format_float(value) when is_float(value) do
    # Format with one decimal place
    :erlang.float_to_binary(value, [decimals: 1])
  end

  @doc """
  Writes the CSV string to a file path.

  Creates the results directory if it doesn't exist.

  ## Parameters
    - csv_string: CSV formatted string
    - filepath: Destination file path

  ## Returns
    - `:ok` on success
    - `{:error, reason}` on failure
  """
  @spec write_to_file(String.t(), String.t()) :: :ok | {:error, term}
  def write_to_file(csv_string, filepath) do
    # Ensure results directory exists
    filepath |> Path.dirname() |> File.mkdir_p!()

    # Write file with UTF-8 BOM for Excel compatibility
    encoded = utf8_bom(csv_string)
    File.write(filepath, encoded)
  end

  defp utf8_bom(content) when is_binary(content) do
    <<0xEF, 0xBB, 0xBF, content::binary>>
  end
end